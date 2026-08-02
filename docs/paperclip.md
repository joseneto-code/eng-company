# Publicar no Paperclip

Este repositório **é** um package `agentcompanies/v1`. Não precisa de conversão: `COMPANY.md` na raiz, `.paperclip.yaml` ao lado, `agents/`, `teams/` e `skills/` na estrutura que o `paperclipai company import` espera.

---

## 1. Pré-requisitos

- Uma instância Paperclip rodando (local, Docker ou SSH)
- `ANTHROPIC_API_KEY` configurada como secret na instância
- CLI: `paperclipai` (ou `npx paperclipai`, ou `docker exec <container> paperclipai`)

Descubra onde sua instância vive:

```bash
paperclipai doctor
paperclipai env
```

| Modo | Config em | CLI |
|------|-----------|-----|
| `local-native` | `~/.paperclip/instances/<id>/` | `paperclipai <cmd>` |
| `local-docker` | `<compose>/data/.paperclip/instances/<id>/` | `docker exec <container> paperclipai <cmd>` |
| `ssh-native` | `~/.paperclip/instances/<id>/` (remoto) | `ssh <host> paperclipai <cmd>` |
| `ssh-docker` | `<compose>/data/.paperclip/instances/<id>/` (remoto) | `ssh <host> docker exec <container> paperclipai <cmd>` |

---

## 2. Preencher o mandato (obrigatório)

Um único arquivo precisa ser editado antes do import:

```
agents/ceo/references/mandato.md
```

Sem ele o CEO decide no vácuo — não sabe qual produto, qual tenancy, qual objetivo do trimestre.

Se o seu modelo de tenancy usa nomes diferentes de `organization` / `clinic` / `clinic_id` / `protocolo_app`, ajuste também as skills:

```bash
grep -rn "clinic_id\|protocolo_app\|accessible_clinics" skills/
```

As skills citam nomes concretos de propósito — é o que faz o agente reconhecer o código real em vez de raciocinar sobre abstração. Trocar os nomes é esperado; deixar abstrato não é.

---

## 3. Configurar o secret

Nunca em texto puro no markdown.

```bash
paperclipai configure --section secrets
# defina ANTHROPIC_API_KEY
```

O `.paperclip.yaml` só **declara** a exigência:

```yaml
inputs:
  env:
    ANTHROPIC_API_KEY: { kind: secret, requirement: required }
```

---

## 4. Import — sempre dry-run primeiro

```bash
# 1. revisar o que vai entrar
paperclipai company import . --dry-run

# 2. criar de verdade
paperclipai company import .

# 3. anote o company-id do output
export PC_COMPANY_ID=<uuid>
```

Atualizações posteriores usam o mesmo comando com `--company-id`:

```bash
paperclipai company import . --company-id $PC_COMPANY_ID --dry-run
paperclipai company import . --company-id $PC_COMPANY_ID
```

---

## 5. Verificar

```bash
paperclipai agent list --company-id $PC_COMPANY_ID
```

Esperado — quatro agentes com a hierarquia montada:

| slug | reportsTo | tier | modelo |
|------|-----------|------|--------|
| `ceo` | — | CEO | `claude-opus-4-7` |
| `eng-orquestrador` | `ceo` | PM | `claude-sonnet-4-6` |
| `eng-database` | `eng-orquestrador` | IC | `claude-opus-4-7` |
| `eng-frontend` | `eng-orquestrador` | IC | `claude-opus-4-7` |

```bash
paperclipai dashboard get --company-id $PC_COMPANY_ID
paperclipai doctor
```

Se `agent list` vier vazio ou faltando agente, o frontmatter do `AGENTS.md` correspondente está incompleto — `slug` e `kind` ausentes fazem o import falhar **em silêncio**.

---

## 6. Primeira tarefa

```bash
paperclipai task create --company-id $PC_COMPANY_ID \
  --assignee ceo \
  --title "Ler agents/ceo/references/mandato.md e propor os 3 primeiros objetivos"
```

O CEO decompõe, escreve critério de aceite e delega ao `eng-orquestrador` — que classifica em dado/tela/vertical e desce para os ICs. O caminho completo está em [`orquestracao.md`](orquestracao.md).

---

## 7. O que já vem configurado

### Roteamento de modelo

Sonnet no PM (roteamento é trabalho de classificação), Opus no CEO e nos dois ICs.

Opus nos ICs é deliberado e contra a intuição de custo: uma policy de RLS errada **não gera exceção** — gera o dado do cliente A na tela do cliente B, e ninguém percebe até alguém reclamar. Modelo barato sai caro onde a falha é silenciosa.

### Heartbeat

Só o `ceo` tem schedule (`0 9 * * 1` — segunda, 9h, America/Sao_Paulo). Todo o resto acorda por atribuição. Heartbeat agendado custa mesmo com o agente ocioso.

### Budgets

```
company           US$ 400/mês
ceo               US$  80      pensa muito, executa pouco
eng-orquestrador  US$  60      Sonnet
eng-database      US$ 120
eng-frontend      US$ 120
```

80% dispara warning, 100% auto-pausa o agente. Ajuste em `.paperclip.yaml > budgets`.

### Concurrency

```yaml
maxConcurrentAgents: 3
maxConcurrentPerAgent: 1
```

`maxConcurrentPerAgent: 1` não é preferência: dois runs do `eng-database` em paralelo podem gerar duas migrations com o mesmo timestamp e travar o `migrate deploy`.

### PROTOCOL.md slim

Cada agente tem o seu, e o `AGENTS.md` traz a instrução de override:

> **Leia `PROTOCOL.md` em vez de invocar a skill `paperclip` padrão.**

Isso substitui a skill monolítica (~3.000 tokens) por 40-90 linhas por papel — economia de `3.000 × 4 agentes × N heartbeats/dia`.

---

## 8. Editar depois do import

O Paperclip trata o markdown como canônico. Edite o arquivo, não a API.

| Mudou | Ação |
|-------|------|
| `AGENTS.md`, `PROTOCOL.md`, `references/*`, `skills/*` | hot reload — o agente lê no próximo heartbeat |
| `.paperclip.yaml`, `COMPANY.md`, estrutura de pastas | `paperclipai company import . --company-id $PC_COMPANY_ID` |
| `config.json` da instância ou env do servidor | reiniciar o processo |
| `.env` do compose | `docker compose up -d --force-recreate paperclip` (só `restart` não basta) |

**Faça backup antes de editar config:** `<arquivo>.bak-YYYYMMDD-HHMMSS`.

**Sessão já aberta cacheia o system prompt.** Depois de mudar `AGENTS.md`, force uma sessão nova para ver o efeito.

---

## 9. Armadilhas conhecidas

- **Frontmatter incompleto** (sem `slug` ou `kind`) → import falha em silêncio, agente não aparece
- **Slug renomeado depois de criado** → quebra `reportsTo` e `includes` em outros packages. Slug é estável, não renomeie
- **Cron em shorthand** → use sempre as 5 partes (`0 9 * * 1`)
- **Agente novo sem `budgetMonthlyCents`** → um loop derruba a company inteira
- **`dangerouslySkipPermissions: true`** → só em ambiente controlado. Este package não usa
- **Cache TTL de 5 min** — mexer em prompt global invalida a hierarquia de cache abaixo dele

---

## 10. Adicionar um agente

```
[1] mkdir -p agents/<novo-slug>
[2] agents/<novo-slug>/AGENTS.md      (copie o tier mais próximo: ceo / orquestrador / IC)
[3] agents/<novo-slug>/PROTOCOL.md
[4] .paperclip.yaml → agents.<novo-slug> (adapter + budget)
[5] COMPANY.md → includes: += agents/<novo-slug>
[6] eng-orquestrador/references/politica-delegacao.md → linha na tabela de roteamento
[7] docs/orquestracao.md → nó novo no diagrama
[8] paperclipai company import . --company-id $PC_COMPANY_ID --dry-run
[9] paperclipai company import . --company-id $PC_COMPANY_ID
```

Os passos 6 e 7 não são burocracia: agente que ninguém sabe quando chamar não recebe trabalho.

---

<sub>Feito por José Neto.</sub>
