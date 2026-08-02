---
name: eng-ui-system
description: >
  Use ao construir ou revisar interface de painel operacional multi-tenant: componente novo,
  escolha de cor, token do Tailwind v4, card, badge, tabela, gráfico recharts,
  estado vazio/loading/erro, tipografia, espaçamento, responsivo,
  acessibilidade. Guarda o design system preto+laranja e o kit de
  components/ui já existente — consulte ANTES de criar componente ou escolher
  cor, para não duplicar o que já existe nem quebrar o significado da paleta.
  Triggers: "componente", "cor", "token", "tailwind", "card", "badge",
  "gráfico", "chart", "tabela", "layout", "responsivo", "dark mode",
  "está feio", "kanban", "stat".
schema: agentskills/v1
---

# Skill: eng-ui-system

O design system dos painéis. Os tokens são transplantados sem alteração entre os produtos — se você mudar um, mude em todos ou registre por que divergiram.

## Quando usar

Antes de criar qualquer componente, escolher qualquer cor, ou dizer que uma tela está pronta.

---

## 1. O que já existe (não recrie)

`src/components/ui/` — leia antes de escrever. É pequeno, cabe inteiro na cabeça.

| Componente | Para quê |
|------------|----------|
| `Card` / `CardHeader` | container padrão de bloco; header com `title`, `subtitle`, `action` |
| `StatTile` | número único com label e ícone opcional |
| `Badge` | status `good` / `warning` / `critical`, com ícone |
| `SubmitButton` | botão de form com `pending` via `useFormStatus` — variantes `primary`/`outline`/`danger` |
| `ConfirmForm` | ação destrutiva com confirmação |
| `GoalProgress` | barra de progresso de meta |
| `BalanceMeter` | saldo da conta de anúncio |
| `PeriodFilter` | seletor de período |
| `NavTabs` | navegação de seção |
| `ViewToggle` | alterna visualização |
| `CopyField` | campo com botão copiar |
| `ClinicSwitcher` | troca de tenant |
| `CreativesTable` / `CreativesShowcase` | criativos em tabela ou grade |

**Regra de promoção:** componente vira `ui/` só quando é usado em **duas telas**. Antes disso mora em `components/<domínio>/` — `goals/`, `kanban/`, `pipelines/`, `reports/`, `whatsapp/`.

---

## 2. Tokens — cor só sai daqui

Definidos em `src/app/globals.css`, expostos ao Tailwind v4 via `@theme inline`. **Não existe `tailwind.config.js`.**

Classe Tailwind ← token CSS:

```
bg-page  bg-surface  border-surface-border
text-ink  text-ink-secondary  text-ink-muted
text-accent  bg-accent  text-accent-ink  border-accent/40
text-status-good | -warning | -serious | -critical
--series-1..8      (categórico: séries de gráfico)
--stage-1..6, --stage-won, --stage-lost   (ordinal: colunas do kanban)
```

Hex literal em componente é bug. A exceção é `Badge`, que usa `color-mix(in oklab, var(--status-x) 14%, transparent)` para o fundo — copie esse padrão em vez de inventar uma cor de fundo nova.

Detalhamento da paleta, os porquês e a validação: **`references/paleta.md`**. Leia antes de adicionar qualquer cor.

### As três regras de cor

1. **Uma cor de destaque só.** `--accent` é o laranja `#ff7a1a`. Não existe segunda cor de marca. Gradiente roxo→azul é proibido neste design system.
2. **Vermelho é incidente, não desfecho normal.** `LOST` no kanban usa cinza recessivo, não `--status-critical`. Lead perdido é operação normal; pintar de vermelho deixa o quadro permanentemente alarmante e treina a CRC a ignorar vermelho — que é a cor que precisa funcionar quando o canal do WhatsApp cair.
3. **Ordinal usa rampa, categórico usa matizes.** Estágio de funil tem ordem (`NEW` antes de `WON`) → **um matiz, degraus de luminosidade** (`--stage-1..6`). Série de gráfico não tem ordem → matizes distintos (`--series-1..8`). Trocar os dois faz o kanban virar arco-íris e o gráfico ficar ilegível.

---

## 3. Vocabulário visual

Copiado do `Card` e do `StatTile` reais — siga, não reinvente:

- **Raio:** `rounded-xl` em card, `rounded-lg` em tile, `rounded-full` em botão e badge.
- **Superfície:** `bg-surface/70` + `backdrop-blur-xl` em card; `bg-surface/50` em tile.
- **Borda:** `border border-surface-border`, com `hover:border-accent/40` onde é interativo.
- **Profundidade:** `shadow-[0_1px_0_0_rgba(255,255,255,0.04)_inset]` — luz interna, não sombra projetada.
- **Label:** `text-xs font-medium uppercase tracking-wider text-ink-muted`.
- **Valor:** `text-xl font-semibold text-ink`.
- **Título de card:** `text-sm font-semibold tracking-wide text-ink`.
- **Ícone:** `lucide-react`, `size-3.5`/`size-4`, `strokeWidth={2}` (2.25 em badge).
- **Espaçamento:** `space-y-4` entre blocos, `p-5` em card, `p-4` em tile, `gap-1.5`/`gap-3` interno.

Tema é **fixo escuro** (`color-scheme: dark`). Não há toggle claro/escuro — não escreva `dark:` nem `@media (prefers-color-scheme)`.

---

## 4. Gráficos

`recharts`, em Client Component. Séries saem de `--series-1..8`, nessa ordem.

Antes de escrever o primeiro gráfico novo, carregue a skill **`dataviz`** — ela tem a metodologia de escolha de forma, eixos e legenda. Esta skill define só o *que* usar de cor aqui; a `dataviz` define *como* montar a visualização.

Regras locais:
- Eixo e grade em `--gridline` / `--baseline`, nunca em `--ink-*`.
- Tooltip com fundo `--surface` e borda `--surface-border`.
- Moeda em `pt-BR`: `Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" })`.
- Gráfico sem dado no período mostra estado vazio, não eixo vazio.

---

## 5. Os três estados que sempre faltam

Tela não está pronta sem os três. É o item que mais volta em review:

| Estado | O que fazer |
|--------|-------------|
| **Vazio** | Frase curta dizendo o que aconteceu + a ação que resolve. "Nenhuma meta ativa. Crie a primeira para acompanhar o mês." |
| **Carregando** | `loading.tsx` na rota pesada; `SubmitButton` cobre o form |
| **Erro** | `error.tsx` no layout da área; action devolve `{ ok:false, error }` exibido perto do campo |

---

## 6. Acessibilidade e responsivo (mínimo que se cobra)

- Texto em `--ink-muted` sobre `--surface` tem contraste medido; **não invente cinza mais claro**.
- Cor nunca é o único portador de significado — `Badge` traz ícone junto com a cor por isso.
- `<dl>/<dt>/<dd>` em par label→valor (o `StatTile` faz), `<table>` real em tabela.
- Foco visível: não remova outline sem colocar `ring-accent-ring` no lugar.
- Botão de ícone puro precisa de `aria-label`.
- Mobile primeiro no kanban e nas tabelas: tabela larga rola dentro do próprio container (`overflow-x-auto`), a **página nunca rola na horizontal**.

---

## 7. Checklist

- [ ] Componente que eu ia criar já existe em `ui/`?
- [ ] Zero hex literal — tudo em token
- [ ] Uma cor de destaque só
- [ ] Vermelho reservado para incidente
- [ ] Ordinal em rampa, categórico em matizes
- [ ] Raio/borda/superfície seguindo `Card` e `StatTile`
- [ ] Estado vazio, carregando e erro escritos
- [ ] `overflow-x-auto` no container largo, não no body
- [ ] Ícone puro com `aria-label`
- [ ] Textos PT-BR
- [ ] Nada de `dark:` (tema é fixo)

## Anti-patterns

- ❌ Criar `Button` novo porque `SubmitButton` "não serve" — estenda a variante
- ❌ Segunda cor de marca
- ❌ Vermelho em lead perdido, coluna arquivada, ou qualquer estado normal
- ❌ 8 matizes diferentes nas colunas do kanban
- ❌ `bg-[#1a1a1a]` em vez de `bg-surface`
- ❌ Instalar biblioteca de UI nova (shadcn, MUI, chakra) — o kit é próprio de propósito
- ❌ Tela entregue sem estado vazio
- ❌ Densidade de landing page num painel operacional

## References

- `references/paleta.md` — tokens completos, os porquês e como validar uma cor nova

## Relacionado

- `eng-next-app` — onde o componente é renderizado, e a fronteira server/client
- `dataviz` (global) — metodologia de visualização de dados
- Landing page de campanha usa sistema estético **diferente** — não misture com o painel

---

<sub>Feito por José Neto.</sub>
