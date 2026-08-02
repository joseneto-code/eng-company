---
name: eng-query-performance
description: >
  Use quando o assunto for custo de query em SaaS multi-tenant: página lenta,
  timeout de transação, N+1, índice faltando, EXPLAIN, agregação pesada,
  snapshot diário, paginação, sincronização de API externa (Meta/Google Ads).
  Cobre também os limites do Prisma + pgBouncer (maxWait, timeout, connection
  pool) e quando pré-agregar em vez de calcular na hora.
  Triggers: "lento", "timeout", "N+1", "índice", "explain", "otimizar query",
  "paginação", "agregação", "snapshot", "connection pool", "muitas linhas".
schema: agentskills/v1
---

# Skill: eng-query-performance

Onde o custo aparece nestes produtos e o que fazer com ele.

## Quando usar

Página demorando, transação estourando timeout, sync de plataforma travando, ou antes de escrever uma agregação nova sobre tabela que cresce.

---

## 1. Diagnóstico antes de otimização

Nunca "otimize" sem medir. A ordem:

1. **É uma query ou são 200?** Ligue o log do Prisma em dev:
   ```ts
   new PrismaClient({ adapter, log: ["query"] })
   ```
   Se a mesma query aparece N vezes com `where id = ...` diferente, é N+1 → resolve com `include`/`select` ou um `findMany` com `in`.
2. **É a query ou é a policy?** `EXPLAIN (ANALYZE, BUFFERS)`. Se aparecer `Seq Scan` numa tabela grande com filtro `clinic_id = any (...)`, o problema é índice, não SQL.
3. **É o banco ou é a rede?** Sync de Meta/Google Ads quase nunca é o Postgres — é a API externa. Meça separado antes de mexer no schema.

---

## 2. Índices: a regra dos três

Toda tabela multi-tenant que cresce precisa de:

```prisma
@@index([clinicId])                    // o RLS filtra por aqui em TODA query
@@index([clinicId, createdAt])         // listagem ordenada por data
@@index([clinicId, <coluna de filtro>]) // o filtro que a tela realmente usa
```

**A ordem das colunas importa.** `clinicId` primeiro sempre: é o predicado que a policy injeta em 100% das queries, então ele é o que mais reduz o conjunto.

Índice de unicidade para idempotência (webhook, sync) é obrigatório, não opcional:

```prisma
@@unique([adAccountId, date, campaignId])   // upsert de insight não duplica
```

### O caso que trava o RLS

Se o id da tabela for `String` em vez de `@db.Uuid`, a policy compara texto com uuid, paga um cast por linha e **descarta o índice**. É dívida conhecida em base que nasceu com id de texto. Sintoma: query rápida no `psql` como `postgres`, lenta como `protocolo_app`.

---

## 3. Limites de transação (Prisma + pgBouncer)

```ts
export type TenantTxOptions = {
  maxWait?: number;  // ms esperando conexão do pool. Default Prisma: 2000
  timeout?: number;  // ms de vida da transação. Default: 5000 — curto para jobs
};
```

- **Request de usuário:** deixe o default. Se 5s não bastam, o problema é a query.
- **Job de sync:** passe `timeout` explícito. `forService(clinicId, fn, { timeout: 60_000 })`.
- **Nunca** abra uma transação e chame API externa lá dentro. A conexão fica presa no pool esperando a rede. Busque tudo, feche, depois grave.

```ts
// ❌ segura conexão do pool durante a chamada HTTP
await forService(clinicId, async (tx) => {
  const data = await metaApi.fetchInsights();
  await tx.adInsight.createMany({ data });
});

// ✅
const data = await metaApi.fetchInsights();
await forService(clinicId, (tx) => tx.adInsight.createMany({ data }), { timeout: 30_000 });
```

**Concorrência:** fan-out por clínica usa `p-limit`, já nas dependências. Sem limite, 40 clínicas em paralelo estouram o pool do pgBouncer e todas as requisições de usuário passam a esperar 2s por conexão.

```ts
const limit = pLimit(5);
await Promise.all(clinics.map((c) => limit(() => syncClinic(c.id))));
```

---

## 4. Pré-agregar vs. calcular na hora

A decisão já tomada nestes produtos: **métrica de dashboard vem de tabela de snapshot**, não de `SUM()` sobre a tabela de eventos.

| Tabela | Papel |
|--------|-------|
| `ad_insights` | linha crua por campanha/dia, vinda da plataforma |
| `metric_snapshots` | agregado por conta/dia — o que o gráfico lê |
| `clinic_daily_metrics` | agregado do funil por clínica/dia — leads, agendamentos, faturamento |
| `lead_events` | append-only, fonte de verdade do funil por etapa |

Por que duas fontes de progresso de meta: metas de **plataforma** (gasto, cliques, CPA) leem `metric_snapshots`; metas de **funil** (leads reais, agendamentos, faturamento, ROI) leem `clinic_daily_metrics`. Elas não se substituem — o lead da plataforma e o lead que virou paciente são números diferentes de propósito.

**Regra:** se a tela mostra uma série temporal, ela lê snapshot. Se você está escrevendo `groupBy` com `_sum` sobre uma tabela de eventos numa página, provavelmente falta um snapshot.

O snapshot é escrito por job idempotente (`upsert` na chave `[escopo, data]`), o que permite reprocessar um dia sem duplicar.

---

## 5. Paginação

Nunca `findMany` sem `take` numa tabela de tenant. Mesmo que hoje tenha 30 linhas.

- Listagem de tela: `take` + `skip` está ok (conjuntos pequenos por clínica).
- Kanban / conversa: **cursor**, não offset — `skip` fica linear conforme cresce.
- Export/relatório: processe em lotes, não carregue tudo na memória do Vercel.

---

## 6. Checklist

- [ ] `@@index([clinicId])` existe na tabela nova
- [ ] Índice composto na ordem `clinicId` → coluna de filtro/ordenação
- [ ] Id é `@db.Uuid` (senão a policy perde o índice)
- [ ] Unique para idempotência de upsert/webhook
- [ ] Nenhuma chamada de rede dentro de transação
- [ ] Job com `timeout` explícito
- [ ] Fan-out com `p-limit`
- [ ] `findMany` de tenant tem `take`
- [ ] Série temporal lê snapshot, não `SUM()` de evento
- [ ] `EXPLAIN ANALYZE` rodado como o **role da app**, não como `postgres`

## Anti-patterns

- ❌ Medir performance conectado como `postgres` — o RLS não roda e o número mente
- ❌ Adicionar índice "por garantia" sem `EXPLAIN` — índice custa em toda escrita
- ❌ `SELECT *` via Prisma sem `select` em tabela larga (payload de webhook, corpo de mensagem)
- ❌ Aumentar `timeout` como solução para query lenta
- ❌ `Promise.all` sem limite sobre a lista de clínicas
- ❌ Calcular ROI do mês inteiro a cada render

## Relacionado

- `eng-prisma-schema` — a decisão de desnormalizar `clinicId` é performance de RLS
- `eng-rls-multitenant` — a policy é parte do plano de execução, não um enfeite

---

<sub>Feito por José Neto.</sub>
