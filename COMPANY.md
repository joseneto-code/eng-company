---
schema: agentcompanies/v1
kind: company
slug: eng-company
name: Eng Company
description: Company de engenharia — banco de dados e front-end para SaaS multi-tenant em Next.js + Prisma + Postgres/Supabase.
version: 1.0.0
license: MIT
authors:
  - name: José Neto
homepage: https://github.com/joseneto-code/eng-company
tags: [engineering, database, frontend, nextjs, prisma, postgres, rls, multi-tenant]
includes:
  - agents/ceo
  - agents/eng-orquestrador
  - agents/eng-database
  - agents/eng-frontend
  - teams/engenharia
  - skills/eng-prisma-schema
  - skills/eng-rls-multitenant
  - skills/eng-query-performance
  - skills/eng-next-app
  - skills/eng-ui-system
metadata:
  paperclip:
    instance: default
---

# Eng Company

Uma company de 4 agentes que sabe construir e manter **SaaS multi-tenant** em Next.js + Prisma + Postgres com RLS.

## Goal

Entregar mudanças de produto que não quebram o isolamento entre clientes e não acumulam dívida de interface.

## North star

**Zero vazamento entre tenants.** É a métrica que não admite tendência — ou é zero, ou o produto acabou.

Secundárias:
- Nenhuma tabela em `public` sem RLS (`app.tables_without_rls()` volta vazio no CI)
- Toda tela com os três estados escritos: vazio, carregando, erro
- Nenhuma migration destrutiva em fase única

## Operating principles

1. **Dado antes de tela.** Interface sobre shape instável é retrabalho de RLS.
2. **Duas barreiras independentes.** RLS no banco *e* guarda na aplicação. Nenhuma das duas confia na outra.
3. **RLS isola tenant, app autoriza papel.** Misturar os dois torna a policy inauditável.
4. **Falha silenciosa é a inimiga.** Errar isolamento não gera exceção — gera o dado errado na tela do cliente errado. Por isso toda regra aqui vem com verificação.
5. **Comente o porquê, não o quê.** É o que impede o próximo leitor de desfazer a decisão.
6. **Escopo que cresce sozinho é como projeto morre.** O CEO existe para puxar o freio.

## Hierarquia

```
board (humano)
  └── ceo                    tier CEO   — o quê e em que ordem
        └── eng-orquestrador tier PM    — decompõe e delega
              ├── eng-database  tier IC — schema, RLS, índices, queries
              └── eng-frontend  tier IC — páginas, actions, componentes
```

Diagrama e fluxo completo: [`docs/orquestracao.md`](docs/orquestracao.md).

---

<sub>Feito por José Neto.</sub>
