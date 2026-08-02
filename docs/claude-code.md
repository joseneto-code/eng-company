# Usar no Claude Code

Mesma hierarquia do Paperclip, transporte diferente: em vez de issues por API, a delegação acontece pela ferramenta `Agent` dentro da conversa.

---

## 1. Instalar

```bash
git clone https://github.com/joseneto-code/eng-company.git
cd eng-company
```

**Windows (PowerShell):**
```powershell
.\scripts\install.ps1
```

**macOS / Linux:**
```bash
./scripts/install.sh
```

O script copia:

```
.claude/agents/*.md   →  ~/.claude/agents/
skills/*              →  ~/.claude/skills/
```

Instalação global de propósito: assim os agentes carregam em **qualquer** repositório que você abrir — que é onde eles trabalham. O package não é o produto; o produto é o repo do lado.

Para instalar só num projeto:

```bash
./scripts/install.sh --project /caminho/do/produto
```

Verifique com `/agents` e `/help` no Claude Code.

---

## 2. Usar

Chame o agente por nome. O ponto de entrada normal é o `eng-ceo`:

```
usa o eng-ceo: quero que o dentista consiga definir meta de faturamento e ver o progresso
```

Ele decompõe, ordena e delega. Para tarefa já concreta, pule tiers:

```
usa o eng-orquestrador: a página de relatórios está levando 4s pra carregar
usa o eng-database: adiciona a tabela de procedimentos com RLS
usa o eng-frontend: o kanban não rola direito no mobile
```

As skills carregam sozinhas pelo `description` — ou invoque direto:

```
/eng-rls-multitenant
/eng-ui-system
```

---

## 3. Qual agente para qual pedido

| Seu pedido | Agente |
|------------|--------|
| "o que fazemos primeiro", "planeja a sprint", "vale a pena migrar X" | `eng-ceo` |
| "quero que o usuário consiga X" (feature inteira) | `eng-ceo` |
| "implementa X" (escopo já claro, atravessa dado e tela) | `eng-orquestrador` |
| "cria tabela", "policy", "está lento", "índice", "migration" | `eng-database` |
| "cria a página", "componente", "cor", "gráfico", "mobile" | `eng-frontend` |

Tabela completa de roteamento: [`orquestracao.md §5`](orquestracao.md#5-roteamento--a-tabela-que-o-orquestrador-usa).

---

## 4. Diferenças em relação ao Paperclip

| | Paperclip | Claude Code |
|---|---|---|
| Definição do agente | `agents/<slug>/AGENTS.md` | `.claude/agents/<slug>.md` |
| Heartbeat | `PROTOCOL.md` + issues via API | invocação direta |
| Delegação | `POST /api/issues` com `parentId` | ferramenta `Agent` |
| Estado entre execuções | issue tracker | a conversa |
| Budget / auto-pause | `.paperclip.yaml` | não existe — o custo é o da sua sessão |
| Routine agendada | `cronExpression` | `/loop` ou `/schedule` |
| Skills | `skills/<slug>/SKILL.md` | as **mesmas** — `agentskills/v1` é comum aos dois |

O `PROTOCOL.md` não é lido pelo Claude Code. Ele descreve o ciclo de heartbeat, que só existe no Paperclip. As regras que valem nos dois modos moram no `AGENTS.md` / `.claude/agents/*.md`.

---

## 5. Adaptar ao seu produto

As skills citam nomes concretos (`clinic_id`, `protocolo_app`, `app.accessible_clinics()`, os tokens `--stage-*`) de propósito: é o que faz o agente reconhecer o código real em vez de raciocinar sobre abstração.

Se o seu modelo de tenancy usa outros nomes:

```bash
grep -rn "clinic_id\|protocolo_app\|accessible_clinics" skills/
```

Troque pelos seus e rode o install de novo. Deixar abstrato é o único caminho errado — a skill perde exatamente o que a torna útil.

Preencha também `agents/ceo/references/mandato.md`: é de onde o CEO sabe o que você está construindo.

---

## 6. Atualizar

```bash
git pull
./scripts/install.sh
```

O install sobrescreve. Se você editou as skills localmente, versione seu fork em vez de editar por cima.

---

<sub>Feito por José Neto.</sub>
