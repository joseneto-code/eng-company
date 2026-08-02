# Heartbeat Protocol — Eng Database (slim)

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

## 3. Checkout

```
POST /api/issues/{issueId}/checkout
```

**409 Conflict** → outro agente está nela. **Não faça retry.** Pegue outra.

## 4. Carregar a skill que a issue aponta

O orquestrador nomeia a skill no corpo. Carregue **essa**, não todas.

## 5. Executar

Leia a issue e os últimos 10 comments. Não leia o histórico inteiro.

### Fluxo de alteração de schema

```
1. Editar prisma/schema.prisma  (+ comentário explicando a DECISÃO, não o campo)
2. npx prisma migrate dev --name <verbo-curto>
3. Policy em prisma/policies/04_policies.sql:
     tabela com clinic_id  → adicione o nome ao array `rw` do laço
     append-only           → bloco 2 (select + insert, SEM update/delete)
     chega por join        → bloco 4, EXISTS (só se a tabela for pequena)
4. npm run db:policies
5. tests/integration/rls.test.ts  → caso novo para a tabela
6. npm run typecheck && npm run lint && npm test
```

`prisma db push` não é usado neste projeto. Migration é o artefato versionado.

### Verificação antes de dizer que acabou

```sql
select * from app.tables_without_rls();                    -- vazio
select rolname, rolbypassrls from pg_roles
 where rolname in ('app_runtime', 'protocolo_app');        -- ambos false
select tablename, policyname, cmd from pg_policies
 where schemaname='public' and with_check is null and cmd <> 'SELECT';
```

E o teste de isolamento: dois usuários de clínicas diferentes, o segundo não vê **nada** do primeiro.

## 6. Status update

Header `X-Paperclip-Run-Id` em toda escrita.

- **Done** → comment com o critério de aceite item a item + `done`.
- **Blocked** → comment com o bloqueio + `blocked` + tag no `eng-orquestrador`.
- **Precisa de humano** → `request_confirmation`, nunca pergunta aberta.

## 7. Delegação de subtask

Se a issue exige trabalho de tela:

```
POST /api/issues { "parentId": "<issueId>", "assigneeAgentId": "eng-frontend" }
```

Sempre com `parentId`. Nunca delegue cancelando.

## Restrições explícitas

- NUNCA `migrate reset`, `DROP`, ou comando em produção sem `request_confirmation`.
- NUNCA migration destrutiva em fase única.
- NUNCA tabela nova sem policy no mesmo commit.
- NUNCA `set_config(..., false)`.
- NUNCA aponte `DATABASE_URL` para `postgres` ou `service_role`.
- NUNCA meça performance conectado como `postgres` — sem RLS o número mente.
- NUNCA edite componente ou CSS. Crie subtask para `eng-frontend`.
- NUNCA retry de 409. NUNCA continue com `spent >= budget`. NUNCA logue secret inteiro.

---

<sub>Feito por José Neto.</sub>
