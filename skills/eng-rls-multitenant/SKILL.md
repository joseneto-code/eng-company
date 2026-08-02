---
name: eng-rls-multitenant
description: >
  Use SEMPRE que o assunto for isolamento entre clientes num SaaS multi-tenant:
  criar/alterar policy de Row Level Security, escolher entre forUser e
  forService, entrypoint público (webhook, link rastreado, relatório
  compartilhado), suspeita de vazamento entre tenants, auditoria de RLS,
  role do banco, pgBouncer. Consulte antes de aprovar qualquer acesso novo a
  dado. Triggers: "RLS", "policy", "multi-tenant", "vazou dado", "isolamento",
  "forUser", "forService", "outro cliente viu", "bypassrls", "webhook".
schema: agentskills/v1
---

# Skill: eng-rls-multitenant

O isolamento entre clientes destes produtos é **do Postgres**, não do código. Esta skill guarda como ele funciona e como não quebrá-lo.

> [!warning] Falha silenciosa
> Errar RLS não gera erro — gera resultado. O dado errado aparece na tela do cliente errado e ninguém percebe até alguém reclamar. Por isso todo item aqui tem verificação, não só regra.

## Quando usar

- Tabela nova (a policy é parte do mesmo commit)
- Job, cron, webhook ou qualquer código sem usuário logado
- Entrypoint público: `/w/[slug]`, `/r/[token]`, `/api/webhooks/*`
- Suspeita de vazamento
- Antes de aprovar PR que toca `prisma/policies/` ou `src/lib/db/`

---

## 1. A divisão que precisa estar clara antes de escrever qualquer policy

| Camada | Responde | Onde mora |
|--------|----------|-----------|
| **RLS** | *De quem é este dado?* Isolamento entre **tenants**. | `prisma/policies/` |
| **App** | *Este papel pode fazer isso?* Autorização por **papel**. | `src/lib/auth/require.ts` + `capabilities.ts` |

Misturar os dois deixa as policies impossíveis de auditar. "CRC não vê investimento" é regra de papel → `capabilities.ts`. "Clínica A não vê lead da B" é tenant → RLS.

---

## 2. Os dois únicos jeitos de tocar o banco

`src/lib/db/tenant.ts`. O eslint bloqueia `import { prisma }` dentro de `src/app/**` — se você está tentando contornar isso, pare e leia esta seção.

### `forUser(userId, fn)` — requisição de alguém logado

```ts
await forUser(ctx.user.id, (tx) =>
  tx.goal.create({ data: { clinicId: ctx.clinic.id, ... } })
);
```

Tudo que a transação vê fica limitado às clínicas onde esse usuário tem membership. Não existe como ampliar o escopo por dentro.

### `forService(clinicId, fn)` — job, cron, webhook

```ts
await forService(clinicId, (tx) => tx.adInsight.createMany({ ... }));
```

`clinicId` é o **primeiro argumento obrigatório de propósito**. Não existe job "de todas as clínicas": quem precisa varrer várias faz **fan-out — uma invocação por clínica**. Aqui não há usuário para o RLS resolver, então o tipo é a única defesa; ele tem que doer quando alguém esquecer.

### `forPublicResolve(fn)` — a escapatória

Só para os entrypoints que precisam **descobrir de qual clínica se trata antes de ter escopo**: webhook, `/w/`, `/r/`.

Dentro dela só funcionam as funções `security definer` de `app.resolve_*` (ver `03_resolvers.sql`), que devolvem o mínimo. Qualquer outra query volta vazia — não tem escopo setado, e é assim que deve ser.

**Padrão:** resolve → pega o `clinicId` → sai e reabre com `forService(clinicId, ...)`.

---

## 3. Por que `set_config(..., true)`

```ts
await tx.$executeRaw`select set_config('app.user_id', ${userId}, true)`;
```

O terceiro argumento `true` significa `SET LOCAL`: **escopo de transação**, não de conexão.

Isso não é detalhe. O Supabase usa **pgBouncer em transaction mode na porta 6543** — a conexão volta ao pool a cada commit e pode servir outro usuário no milissegundo seguinte. Com `false`, a identidade do usuário anterior continua setada e o próximo request lê o dado da clínica errada.

É o bug mais caro possível neste produto e ele não gera exceção nenhuma.

---

## 4. Escrever a policy

`prisma/policies/04_policies.sql`. Idempotente — `drop policy if exists` antes de cada `create`.

### Caso 1 — tabela com `clinic_id` (o comum)

**Não escreva um bloco novo.** Adicione o nome ao array do laço:

```sql
rw text[] := array[
  'procedures', 'pipelines', 'contacts', 'leads', /* ... */,
  'sua_tabela_nova'
];
```

Gerar em laço é deliberado: policy escrita à mão é onde mora o erro de digitação que abre o tenant. No laço, **ou todas estão certas ou nenhuma está**.

### Caso 2 — append-only

Duas policies separadas, `select` e `insert`. **Nenhuma de update/delete** — a ausência é o que nega, inclusive para um bug nosso.

```sql
create policy lead_events_read on public.lead_events
  for select using (clinic_id = any (app.accessible_clinics()));
create policy lead_events_append on public.lead_events
  for insert with check (clinic_id = any (app.accessible_clinics()));
```

### Caso 3 — chega na clínica por join

Só quando a tabela é **pequena** (dezenas de linhas por clínica). O `EXISTS` por linha é barato ali e inaceitável em `messages`:

```sql
create policy pipeline_stages_tenant on public.pipeline_stages
  for all using (
    exists (select 1 from public.pipelines p
            where p.id = pipeline_id
              and p.clinic_id = any (app.accessible_clinics()))
  )
  with check ( /* mesma expressão */ );
```

> `using` **e** `with check`, sempre os dois. Só `using` bloqueia a leitura e libera a escrita cruzada.

### Caso 4 — infraestrutura, só serviço

```sql
create policy webhook_events_service on public.webhook_events
  for all using (app.is_service() and (clinic_id is null or clinic_id = app.clinic_scope()))
  with check ( /* mesma expressão */ );
```

Nenhum usuário tem motivo para ler payload cru de webhook — que contém conversa de paciente.

### Helpers disponíveis (`app.*`)

| Função | Devolve |
|--------|---------|
| `app.accessible_clinics()` | clínicas que o escopo atual alcança |
| `app.accessible_orgs()` | orgs que o escopo atual alcança |
| `app.admin_orgs()` | orgs onde o usuário é admin |
| `app.visible_users()` | usuários visíveis |
| `app.effective_user_id()` | usuário do escopo atual |
| `app.clinic_scope()` | clínica do modo serviço |
| `app.is_service()` | está em modo serviço? |
| `app.tables_without_rls()` | **deve voltar vazio** — o CI falha se não voltar |

---

## 5. O role da aplicação

- `DATABASE_URL` aponta para `protocolo_app`, que **não tem `bypassrls`**. É isso que faz as policies valerem em runtime.
- `02_app_role.sql` roda `alter role app_runtime nobypassrls` toda vez — reverter sempre, porque "dar bypassrls para resolver" derruba o isolamento em silêncio.
- Senha do role **não aparece em arquivo nenhum**: só no `.env` e no Vercel.
- Os roles do Supabase (`authenticated`) precisam de `grant select` para o Realtime funcionar — sem isso o erro é "permission denied" em vez de resultado vazio, e o kanban ao vivo simplesmente não conecta.

---

## 6. Verificação (não pule)

```sql
-- 1. Nenhuma tabela sem RLS
select * from app.tables_without_rls();     -- tem que voltar vazio

-- 2. O role da app não tem bypass
select rolname, rolbypassrls from pg_roles
 where rolname in ('app_runtime', 'protocolo_app');   -- ambos false

-- 3. Toda policy tem with check onde escreve
select tablename, policyname, cmd from pg_policies
 where schemaname = 'public' and with_check is null and cmd <> 'SELECT';
```

E o teste que vale mais que os três: `tests/integration/rls.test.ts` — dois usuários de clínicas diferentes, o segundo não enxerga **nada** do primeiro. Policy nova sem caso novo nesse teste não está pronta.

## Anti-patterns

- ❌ `set_config(..., false)` → identidade vaza pelo pool do pgBouncer
- ❌ `prisma` importado direto em `src/app/**` → o eslint existe por isso
- ❌ Job "de todas as clínicas" com um `forService` só → use fan-out
- ❌ `using` sem `with check`
- ❌ Tabela nova sem policy no mesmo commit
- ❌ Regra de papel dentro da policy ("CRC não vê investimento") → isso é `capabilities.ts`
- ❌ `service_role` key ou usuário `postgres` como `DATABASE_URL`
- ❌ Query de negócio dentro de `forPublicResolve`

## Relacionado

- `eng-prisma-schema` — a tabela que a policy protege
- `eng-next-app` — `requireClinic` / `requireCapability`, a segunda barreira
- Referência viva: `prisma/policies/` e `src/lib/db/tenant.ts` do seu produto

---

<sub>Feito por José Neto.</sub>
