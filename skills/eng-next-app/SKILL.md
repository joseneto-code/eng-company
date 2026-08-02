---
name: eng-next-app
description: >
  Use ao criar ou alterar qualquer coisa em src/app/** de um SaaS multi-tenant:
  página, layout, rota dinâmica, Server Action, route handler, guarda de auth,
  cache/revalidação, fronteira servidor↔cliente, proxy/middleware, entrypoint
  público. Next.js 16 App Router + React 19 — a API mudou em relação ao que
  está no treino, então siga o que está aqui e no repo, não a memória.
  Triggers: "criar página", "nova rota", "server action", "formulário",
  "use client", "layout", "params", "revalidate", "auth", "middleware",
  "route handler", "loading", "error boundary".
schema: agentskills/v1
---

# Skill: eng-next-app

Convenções de App Router já estabelecidas em produção.

> [!warning] Este não é o Next.js que você conhece
> O `AGENTS.md` de um repo assim costuma avisar: a versão instalada tem breaking changes em relação aos dados de treino. Antes de escrever API que você "lembra", **leia `node_modules/next/dist/docs/`** ou copie do arquivo vizinho no repo.

## Quando usar

Qualquer arquivo em `src/app/**`. Também na hora de decidir se algo é Server Component, Client Component ou Server Action — que é a decisão que mais custa refazer.

---

## 1. Estrutura de rota

```
src/app/
  (app)/[orgSlug]/[clinicSlug]/     ← área logada, escopada por tenant
    layout.tsx                      ← nav + clinic switcher
    page.tsx                        ← dashboard
    <feature>/page.tsx              ← a tela
    <feature>/actions.ts            ← as mutações daquela tela
  w/[orgSlug]/                      ← entrypoint público (link rastreado)
  api/webhooks/…                    ← route handlers
  login/  convite/[token]/  sem-acesso/
```

**Regra:** `actions.ts` mora ao lado da `page.tsx` que o usa. Server Action compartilhada entre telas vira função em `src/lib/<domínio>/`, não um `actions.ts` global.

---

## 2. Página = Server Component

Padrão completo, na ordem:

```tsx
export default async function MetasPage({
  params,
}: {
  params: Promise<{ orgSlug: string; clinicSlug: string }>;
}) {
  const { orgSlug, clinicSlug } = await params;          // 1. params é Promise
  const ctx = await requireClinic(orgSlug, clinicSlug);  // 2. guarda de tenant
  if (!canSeeFinancials(ctx.role, ctx.clinic)) notFound(); // 3. guarda de papel

  const canManage = can(ctx.role, "clinic:configure");

  const [active, archived] = await forUser(ctx.user.id, async (tx) => {  // 4. dado
    // ...
  });

  const rows: GoalRow[] = active.map((g) => ({ ... }));   // 5. shape serializável

  return <GoalsManager goals={rows} canManage={canManage} />;  // 6. render
}
```

Os seis passos, sempre nessa ordem. Cada um existe por um motivo:

1. **`params` é `Promise` no Next 16.** `await` obrigatório.
2. **`requireClinic` resolve tenant e devolve 404** — 404 e não 403 de propósito: dizer "existe, mas você não pode" permite descobrir a carteira de clientes da agência chutando slugs.
3. Papel é separado de tenant (ver `eng-rls-multitenant` §1).
4. Dado só por `forUser`. **`prisma` direto em `src/app/**` é bloqueado pelo eslint.**
5. **Mapeie para um shape serializável antes de passar ao Client Component.** `Decimal` e `Date` do Prisma não atravessam — use `.toString()` e `.toISOString()`.
6. Server Component não tem estado. Interatividade vai para um Client Component filho.

### Por que o guarda está aqui e não no proxy

O proxy roda a cada request, inclusive em assets e navegações do router cache — uma consulta ao Postgres ali é imposto sobre tudo. E o adapter `pg` não roda em edge, então resolver isso empurraria o proxy para runtime Node só por isso.

O proxy faz o que é barato e local: valida o JWT e manda para `/login` quem não tem sessão. Quem tem sessão mas não tem membership é barrado no Server Component, com 404. **E mesmo se esse arquivo tiver um bug, o RLS devolve vazio.** São duas barreiras independentes — esse é o ponto.

---

## 3. Server Action

```ts
"use server";

type Result = { ok: true } | { ok: false; error: string };

export async function createGoal(
  orgSlug: string,
  clinicSlug: string,
  input: GoalInput,
): Promise<Result> {
  const ctx = await requireClinic(orgSlug, clinicSlug);   // 1. SEMPRE
  requireCapability(ctx, "clinic:configure");             // 2. SEMPRE

  if (!input.periodStart) return { ok: false, error: "Informe o período." };  // 3

  try {
    await forUser(ctx.user.id, (tx) => tx.goal.create({ ... }));  // 4
    revalidatePath(`/${orgSlug}/${clinicSlug}/metas`);            // 5
    return { ok: true };
  } catch (err) {
    return { ok: false, error: err instanceof Error ? err.message : "Falha ao criar." };
  }
}
```

**Server Action é endpoint público.** Qualquer um pode chamá-la com qualquer argumento. A página ter checado permissão não conta — os guardas se repetem em toda action, sem exceção.

- **Validação devolve `{ ok: false, error }`**, em PT-BR, pronto para exibir. Não estoure para o formulário.
- **`requireCapability` estoura de propósito** — action que falha por permissão não pode parecer que funcionou.
- **`revalidatePath` com o caminho exato** que a mutação afetou. Sem isso o usuário salva e vê o valor velho.
- Onde houver `zod` no projeto, use para o parse do input antes das checagens manuais.

---

## 4. `"use client"` — a fronteira

Leva `"use client"` só quem precisa de: estado (`useState`), evento (`onClick`), hook de browser (`useFormStatus`, `useRouter`), ou biblioteca que só roda no cliente (`recharts`).

**Empurre a fronteira para baixo.** Página inteira como Client Component para ter um botão interativo manda todo o dado pelo wire e mata o streaming. O padrão é: página server → `<Manager>` client pequeno.

Formulário, o caminho curto:

```tsx
<form action={async (fd) => { await createGoal(orgSlug, clinicSlug, parse(fd)); }}>
  <SubmitButton pendingText="Criando...">Criar meta</SubmitButton>
</form>
```

`SubmitButton` já resolve `pending` via `useFormStatus`. Não escreva estado de loading à mão.

---

## 5. Entrypoints públicos

Três, e todos seguem o mesmo desenho: **resolver → escopar → agir**.

| Rota | Para quê |
|------|----------|
| `/w/[orgSlug]` | link rastreado; captura `gclid`/`fbclid`/UTMs e redireciona |
| `/r/[token]` | relatório compartilhado por link |
| `/api/webhooks/*` | Evolution / Meta |

```ts
const clinicId = await forPublicResolve((tx) =>
  tx.$queryRaw`select app.resolve_clinic_by_slug(${slug})`
);
if (!clinicId) return notFound();
await forService(clinicId, (tx) => { /* agora sim */ });
```

Webhook: **valide a assinatura antes de qualquer coisa** e grave em `webhook_events` (unique no id do provedor) antes de processar. Provedor reenvia; a idempotência é do banco.

---

## 6. Cache e estados

- Server Component busca dado a cada request por padrão nestes projetos — dado de tenant não é cacheável entre usuários. Não adicione `revalidate` global.
- `loading.tsx` por rota que faz query pesada. Sem ele, a navegação parece travada.
- `error.tsx` no `layout` da área logada — erro de action não pode virar tela branca.
- **Estado vazio é entregável.** Lista sem itens diz o que fazer, não some.

---

## 7. Checklist

- [ ] `params` com `await` (é `Promise`)
- [ ] `requireClinic` na página **e** em cada Server Action
- [ ] `requireCapability` em toda action que muta
- [ ] Zero `import { prisma }` em `src/app/**`
- [ ] `Decimal`/`Date` convertidos antes de cruzar para o cliente
- [ ] `revalidatePath` com o caminho exato
- [ ] `"use client"` só onde precisa, o mais fundo possível
- [ ] `loading.tsx` onde a query é pesada
- [ ] Estado vazio escrito
- [ ] Textos em PT-BR
- [ ] `npm run lint && npm run typecheck` passando

## Anti-patterns

- ❌ Server Action sem `requireClinic` porque "a página já checou"
- ❌ `"use client"` no topo da página para ter um `onClick`
- ❌ Passar objeto do Prisma direto para Client Component
- ❌ `redirect()` dentro de Server Action para sinalizar erro de validação
- ❌ Consulta ao Postgres no proxy/middleware
- ❌ 403 onde deveria ser 404 num recurso de tenant
- ❌ Escrever API de Next "de memória" sem conferir a versão instalada

## Relacionado

- `eng-rls-multitenant` — `forUser`/`forService`, a barreira de baixo
- `eng-ui-system` — o que renderizar dentro da página
- Referência viva: `src/app/(app)/[orgSlug]/[clinicSlug]/metas/` (página + actions)

---

<sub>Feito por José Neto.</sub>
