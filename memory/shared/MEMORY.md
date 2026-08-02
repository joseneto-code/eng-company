# MEMORY — compartilhada pela company

> Mantenha **abaixo de 5 KB**. Isto entra em toda sessão de todo agente.
> O que não precisa estar em toda sessão vai para `daily/<YYYY-MM-DD>.md`
> ou `decisions/<data>-<tema>.md`.

## Invariantes (nunca mudam sem decisão do board)

1. **Zero vazamento entre tenants.** RLS no Postgres é a primeira barreira; a aplicação é a segunda. Nenhuma confia na outra.
2. **RLS isola tenant, app autoriza papel.** Misturar torna a policy inauditável.
3. **Dado antes de tela.** Sempre.
4. **Nenhuma tabela em `public` sem RLS.** `app.tables_without_rls()` volta vazio ou o CI falha.
5. **Uma cor de destaque só.** Vermelho é reservado a incidente.

## Decisões vigentes

| Data | Decisão | Onde está o porquê |
|------|---------|--------------------|
| — | Opus nos ICs, Sonnet no PM | `docs/paperclip.md §7` |
| — | Máx. 3 objetivos ativos por vez | `agents/ceo/PROTOCOL.md §4` |
| — | Vertical vira sempre duas issues | `agents/eng-orquestrador/references/politica-delegacao.md` |

## Estado atual

- **Produto:** _(preencher — ver `agents/ceo/references/mandato.md`)_
- **Objetivos ativos:** _(máx. 3)_
- **Bloqueios:** _(nenhum)_

## Consolidação

Mensal: o que passou de 30 linhas em `Lessons Learned` de qualquer agente vira arquivo em `decisions/`. Esta MEMORY.md fica só com o que é invariante.
