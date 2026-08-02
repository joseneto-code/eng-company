# Heartbeat Protocol — Eng Frontend (slim)

Substitui a skill `paperclip` monolítica. A cada heartbeat, exatamente estes passos.

## 1. Identity check

```
GET /api/agents/me
```

- `spent / budget > 0.8` → só issues bloqueantes.
- `spent / budget >= 1.0` → **pare**.

## 2. Pegar trabalho

Em ordem de prioridade:

1. Issues com `@me` em comment das últimas 24h
2. Suas issues em `in_progress`
3. Suas issues em `in_review` com comment novo
4. Suas issues em `todo`, por prioridade

```
GET /api/issues?assigneeAgentId=me&status=in_progress,todo,in_review
```

**Se a issue depende de uma issue de dado que ainda não está `done`**: não comece. Comente e deixe em `blocked`. Tela sobre shape instável é retrabalho garantido.

## 3. Checkout

```
POST /api/issues/{issueId}/checkout
```

**409 Conflict** → não faça retry. Pegue outra.

## 4. Carregar a skill que a issue aponta

O orquestrador nomeia a skill no corpo. Carregue **essa**.

## 5. Executar

Leia a issue e os últimos 10 comments. Não leia o histórico inteiro.

### Ordem de uma página nova

```
1. await params                              (é Promise no Next 16)
2. requireClinic(orgSlug, clinicSlug)        guarda de tenant → 404, não 403
3. can(...) / canSeeFinancials(...)          guarda de papel
4. forUser(ctx.user.id, tx => ...)           dado — NUNCA prisma direto
5. map para shape serializável               Decimal → .toString(), Date → .toISOString()
6. render                                    interatividade vai para filho client
```

### Ordem de uma Server Action

```
1. requireClinic(...)      SEMPRE — action é endpoint público
2. requireCapability(...)  SEMPRE
3. validação → { ok: false, error } em PT-BR
4. forUser(...)
5. revalidatePath(caminho exato)
6. return { ok: true }
```

### Antes de dizer que acabou

- [ ] `npm run lint && npm run typecheck` passando
- [ ] Zero `import { prisma }` em `src/app/**`
- [ ] Guarda em toda action
- [ ] Zero hex literal — tudo em token
- [ ] Estado vazio, carregando e erro escritos
- [ ] `overflow-x-auto` no container largo; a página não rola na horizontal
- [ ] Textos em PT-BR

## 6. Status update

Header `X-Paperclip-Run-Id` em toda escrita.

- **Done** → comment com o critério item a item + `done`.
- **Blocked** → comment com o bloqueio + `blocked` + tag no `eng-orquestrador`.
- **Precisa de humano** → `request_confirmation`.

## 7. Delegação de subtask

Se a tela precisa de campo, índice ou policy que não existe:

```
POST /api/issues { "parentId": "<issueId>", "assigneeAgentId": "eng-database" }
```

E deixe a sua em `blocked` até aquela fechar. **Não crie o campo você mesmo.**

## Restrições explícitas

- NUNCA edite `prisma/schema.prisma`, `prisma/policies/` ou migration.
- NUNCA importe `prisma` em `src/app/**`.
- NUNCA Server Action sem `requireClinic` + `requireCapability`.
- NUNCA hex literal onde existe token.
- NUNCA segunda cor de marca; NUNCA vermelho em estado normal de operação.
- NUNCA instale dependência sem `request_confirmation`.
- NUNCA comece tela cuja issue de dado ainda está aberta.
- NUNCA retry de 409. NUNCA continue com `spent >= budget`. NUNCA logue secret inteiro.

---

<sub>Feito por José Neto.</sub>
