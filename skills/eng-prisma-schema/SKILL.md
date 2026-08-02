---
name: eng-prisma-schema
description: >
  Use ao modelar ou alterar o banco de um SaaS multi-tenant com Prisma 7 +
  Postgres/Supabase: criar tabela, adicionar campo, enum novo, relação,
  migration, seed, escolha de tipo. Traz as convenções já decididas nestes
  repos (uuid nativo, clinicId desnormalizado, append-only, Decimal, datas
  UTC) e o passo a passo de migration + policies. NÃO cobre policy de RLS
  em si (eng-rls-multitenant) nem tuning de query (eng-query-performance).
  Triggers: "criar tabela", "adicionar campo", "migration", "prisma",
  "schema", "enum", "relação", "seed", "db push", "modelar".
schema: agentskills/v1
---

# Skill: eng-prisma-schema

Convenções de modelagem já pagas em produção: um banco desenhado do zero com RLS, e um anterior que serve de contraexemplo em dois pontos.

## Quando usar

Qualquer alteração de estrutura: tabela, coluna, enum, índice de unicidade, relação. Também na hora de decidir *tipo* de coluna, que é onde a decisão fica cara depois.

---

## 1. As convenções que já foram decididas

### Id é uuid **nativo**

```prisma
id String @id @default(uuid()) @db.Uuid
```

`@db.Uuid`, não texto. O RLS compara `user_id = app.current_user_id()` e essa função devolve `uuid` — com coluna de texto, **cada linha avaliada pela policy paga um cast e perde o índice**. Base que nasceu com id de texto carrega essa dívida; em tabela nova, nunca repita.

### `clinicId` desnormalizado onde a tabela cresce

Tabelas que *teriam* como chegar na clínica por join (`Message`, `AdInsight`, `AttributionTouch`, `LeadEvent`) carregam `clinicId` mesmo assim.

Não é preguiça: é o que faz a policy virar **index scan** em vez de dois joins por linha, justamente nas tabelas que crescem mais rápido.

> Regra prática: **dezenas de linhas por clínica** → pode chegar por join (`pipeline_stages`, `meta_balance_snapshots`). **Milhares e crescendo** → desnormaliza `clinicId` e indexa.

### Nome de tabela em snake_case

```prisma
model AdInsight {
  // ...
  @@map("ad_insights")
}
```

As policies são escritas em SQL cru contra `public.ad_insights`. Modelo em PascalCase, tabela em snake_case plural — sempre com `@@map`, senão a policy não acha a tabela.

### Enum semântico > string livre

O caso que vale copiar é `StageKind`: a coluna do kanban tem nome, cor e ordem **livres** (o dentista customiza), mas declara um **papel semântico** fixo. É isso que permite calcular taxa de comparecimento sem fazer parsing do nome que o cliente deu à coluna.

```prisma
enum StageKind { NEW QUALIFYING QUALIFIED SCHEDULED ATTENDED PROPOSAL WON LOST }
```

Sempre que o produto precisar *entender* um valor, ele é enum. String livre é só para o que o produto apenas exibe.

### Dinheiro é `Decimal`, e não atravessa a fronteira

```prisma
dailyBudget Decimal? @db.Decimal(12, 2)
```

`Decimal` do Prisma não serializa para Client Component. Converta na fronteira:

```ts
dailyBudget: clinic.dailyBudget?.toString() ?? null,
```

### Data civil é `@db.Date` + meia-noite UTC

Meta que vale "de 01/03 a 31/03" não tem hora. Guarde `@db.Date` e construa sempre assim:

```ts
function toUtcDay(iso: string): Date {
  return new Date(`${iso}T00:00:00.000Z`);
}
```

Sem o `Z`, o fuso do servidor Vercel (UTC) e o do navegador (BRT) discordam em um dia, e a meta some do período.

### Append-only quando a tabela é fonte de verdade

`lead_events` e `audit_logs` só recebem `INSERT`. Um lead em `WON` também *passou* por `SCHEDULED`, e o estado atual não guarda isso. Se der para editar o histórico, ele deixa de ser fonte de verdade — inclusive para um bug nosso.

No schema isso é intenção; quem **impõe** é a ausência de policy de UPDATE/DELETE (ver `eng-rls-multitenant`).

### Idempotência de webhook é tabela, não `try/catch`

`webhook_events` com unique no id do provedor é a barreira #1 contra evento duplicado. Provedor reenvia; a barreira precisa ser do banco.

---

## 2. Fluxo de uma alteração

```
1. Editar prisma/schema.prisma  (+ comentário explicando a decisão)
2. npx prisma migrate dev --name <verbo-curto>
3. Escrever/ajustar a policy em prisma/policies/04_policies.sql
   → tabela com clinic_id: adicionar o nome ao array `rw` do laço
   → tabela append-only: adicionar ao array do bloco 2
   → tabela que chega por join: bloco 4, com EXISTS
4. npm run db:policies
5. Rodar o teste de isolamento (tests/integration/rls.test.ts)
6. npm run typecheck && npm run lint
```

**`prisma db push` não é usado nestes projetos.** Migration é o artefato versionado; `db push` apaga o rastro.

### Migration destrutiva → duas fases

Nunca `DROP COLUMN` no mesmo deploy em que o código para de usá-la. Vercel serve a versão velha e a nova por alguns segundos.

1. Deploy A: adiciona a coluna nova, escreve nas duas, lê da velha.
2. Backfill.
3. Deploy B: lê da nova.
4. Deploy C: remove a velha.

---

## 3. Checklist antes de fechar

- [ ] Id `@db.Uuid`, não `String` puro
- [ ] `@@map("snake_case_plural")`
- [ ] Tabela nova tem policy no **mesmo commit** — `app.tables_without_rls()` volta vazio
- [ ] Se cresce rápido: `clinicId` desnormalizado + `@@index([clinicId, createdAt])`
- [ ] Dinheiro em `Decimal`, serializado com `.toString()` na fronteira
- [ ] Data civil em `@db.Date` + `toUtcDay`
- [ ] Comentário explicando **por que**, não o que
- [ ] Enum onde o produto precisa entender o valor
- [ ] Migration nomeada com verbo curto (`add_goal_metrics`, não `update1`)
- [ ] `npm run db:seed` ainda passa

## Anti-patterns

- ❌ `String` como id "porque é mais simples" → perde índice em toda policy
- ❌ Tabela criada sem policy, "adiciono depois" → o CI falha, e se não falhasse seria vazamento
- ❌ `Float` para dinheiro
- ❌ `DateTime` para data civil (meta, período de relatório)
- ❌ `status String` onde deveria ser enum
- ❌ Editar migration já aplicada em produção — crie outra

## Relacionado

- `eng-rls-multitenant` — a policy que a tabela nova precisa
- `eng-query-performance` — o índice que a policy nova precisa
- Referência viva: o `prisma/schema.prisma` do seu produto — sobretudo os comentários do topo

---

<sub>Feito por José Neto.</sub>
