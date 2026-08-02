# Mandato — preencha ao adotar esta company

Este arquivo é o único que **precisa** ser editado depois do clone. Os agentes leem daqui o que estão construindo; sem isso o CEO decide no vácuo.

## Produto

- **Nome:**
- **O que é, em uma frase:**
- **Quem usa, e com que frequência:** _(ex.: "a secretária olha o kanban o dia inteiro; o dono abre o relatório uma vez por semana" — isso muda a régua de densidade da interface)_
- **Repositório:**

## Modelo de tenancy

O desenho padrão desta company assume hierarquia de dois níveis (organização → unidade) com membership por usuário. Ajuste os nomes:

- **Tenant raiz:** `organization` → _seu nome:_
- **Tenant folha:** `clinic` → _seu nome:_
- **Coluna de escopo nas tabelas:** `clinic_id` → _sua coluna:_
- **Role do banco sem `bypassrls`:** `protocolo_app` → _seu role:_

> Se você renomear qualquer um destes, faça um `grep` nas skills (`skills/eng-rls-multitenant`, `skills/eng-prisma-schema`) e ajuste — elas citam os nomes concretos de propósito, para o agente reconhecer o código real em vez de raciocinar sobre abstração.

## Objetivo do trimestre

- **Goal:**
- **Como se sabe que bateu:**
- **O que explicitamente NÃO vamos fazer:**

## KPIs

| KPI | Alvo | Onde medir |
|-----|------|------------|
| Tabelas sem RLS | 0 | `select * from app.tables_without_rls()` |
| Vazamento entre tenants | 0 | `tests/integration/rls.test.ts` |
| Migration destrutiva em fase única | 0 | review de PR |
| | | |

## Gates deste produto

Além dos gates padrão do `AGENTS.md`, este produto exige aprovação do board para:

-
-

## Contexto que os agentes precisam saber

Coisas que não estão no código e não dá para inferir dele:

-
