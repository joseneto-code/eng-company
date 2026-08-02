# Heartbeat Protocol — Eng Orquestrador (slim)

Substitui a skill `paperclip` monolítica. A cada heartbeat, exatamente estes passos.

## 1. Identity check

```
GET /api/agents/me
```

- `spent / budget > 0.8` → só issues bloqueantes.
- `spent / budget >= 1.0` → **pare**.

## 2. Approvals pendentes

```
GET /api/approvals?assigneeAgentId=me&status=pending
```

## 3. Revisar o que os ICs devolveram

```
GET /api/issues?assigneeAgentId=me&status=in_review&limit=20
```

Valide contra o **critério de aceite escrito na issue**, não contra preferência pessoal.

Checagens obrigatórias por tipo:

| Tipo | Verifique |
|------|-----------|
| dado | policy no mesmo commit · `app.tables_without_rls()` vazio · índice `[clinicId, ...]` · migration não-destrutiva |
| tela | guarda em toda Server Action · zero `import { prisma }` em `src/app/**` · três estados escritos · `revalidatePath` no caminho exato |
| ambos | `npm run lint` e `npm run typecheck` passando |

- Bateu → `done`, comment com o critério verificado.
- Não bateu → comment apontando o item específico e devolva para `todo`. **Não conserte você mesmo.**

## 4. Pegar objetivo novo do CEO

```
GET /api/issues?assigneeAgentId=me&status=todo&limit=20
```

Para cada um:

### 4.1 Classifique

**dado** · **tela** · **vertical**. Declare no primeiro comment da issue. Classificação errada aqui custa uma rodada inteira.

### 4.2 Escreva critério de aceite verificável

Ruim: "RLS configurado".
Bom: "`select * from app.tables_without_rls()` volta vazio · `tests/integration/rls.test.ts` tem caso novo para a tabela · policy usa `using` **e** `with check`".

### 4.3 Aponte a skill

Toda issue delegada nomeia a skill que o IC deve carregar:

| Assunto | Skill |
|---------|-------|
| tabela, campo, enum, migration, seed | `eng-prisma-schema` |
| policy, isolamento, `forUser`/`forService`, webhook | `eng-rls-multitenant` |
| lentidão, N+1, índice, agregação, snapshot | `eng-query-performance` |
| página, rota, Server Action, auth, cache | `eng-next-app` |
| componente, cor, token, gráfico, estado vazio | `eng-ui-system` |

### 4.4 Delegue

```
POST /api/issues { "parentId": "<issueId>", "assigneeAgentId": "eng-database" }
```

**Vertical vira duas issues.** A de front cita no corpo a issue de dado da qual depende, e só entra em `todo` quando a primeira chega em `done`. Até lá fica `blocked`.

## 5. Escalar

Suba para o `ceo` quando:

- Bloqueio passou de 24h
- A issue exige decisão arquitetural (trocar lib, mudar modelo de dados, alterar policy em produção)
- O IC devolveu duas vezes com o mesmo problema — o critério está errado, não a execução
- O escopo cresceu durante a execução

```
POST /api/issues { "parentId": "<issueId>", "assigneeAgentId": "ceo" }
```

## 6. Status update

Header `X-Paperclip-Run-Id` em toda escrita.

## Restrições explícitas

- NUNCA escreva código. Se der vontade de "só corrigir rapidinho", devolva a issue.
- NUNCA delegue vertical como issue única.
- NUNCA delegue front antes de o dado estar em `done`.
- NUNCA decida arquitetura — isso é do CEO.
- NUNCA `PATCH` manual para `in_progress`; só `checkout`.
- NUNCA retry de 409 — pegue outra issue.

---

<sub>Feito por José Neto.</sub>
