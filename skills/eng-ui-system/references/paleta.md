# Paleta — tokens completos e os porquês

Fonte de verdade: `src/app/globals.css` do produto. Os valores abaixo são os do design system de referência — idênticos entre os produtos por transplante deliberado.

Tema **fixo escuro** — `color-scheme: dark`, sem toggle. Não escreva `dark:`.

---

## Superfície e tinta

| Token | Valor | Uso |
|-------|-------|-----|
| `--page-plane` | `#0a0a0b` | fundo da página |
| `--surface` | `#151517` | card, tile, tooltip |
| `--surface-border` | `rgba(255,255,255,.09)` | borda de tudo |
| `--ink-primary` | `#f7f5f2` | texto principal, valores |
| `--ink-secondary` | `#c9c4bc` | texto de apoio |
| `--ink-muted` | `#8f8a82` | label, metadado, estado recessivo |
| `--gridline` | `#26262a` | grade de gráfico |
| `--baseline` | `#38383d` | eixo de gráfico |

O `body` carrega dois `radial-gradient` de `--accent-soft` (canto superior esquerdo e direito), `background-attachment: fixed`. É o único gradiente do sistema — não adicione outro.

---

## Destaque — uma só

| Token | Valor |
|-------|-------|
| `--accent` | `#ff7a1a` |
| `--accent-soft` | `rgba(255,122,26,.14)` — fundo de realce, o glow do body |
| `--accent-ring` | `rgba(255,122,26,.42)` — foco |
| `--color-accent-ink` | `#1d0f03` — texto **sobre** o laranja |

Não existe segunda cor de marca. Gradiente roxo→azul (indigo→violet) é proibido neste design system — é a assinatura visual de interface gerada por IA.

---

## Status — quatro degraus, e o vermelho é caro

| Token | Valor | Significa |
|-------|-------|-----------|
| `--status-good` | `#2eb862` | ok |
| `--status-warning` | `#fab219` | atenção |
| `--status-serious` | `#ec835a` | grave |
| `--status-critical` | `#e04a4a` | **incidente** |

`--status-critical` é orçamento reservado. Gaste em: canal do WhatsApp caiu, sync falhou, conta de anúncio sem saldo, integração desconectada. **Não** gaste em: lead perdido, meta não batida, item arquivado, campanha pausada.

O motivo é operacional, não estético: a CRC olha esta tela o dia inteiro. Vermelho que aparece o tempo todo vira ruído, e aí o vermelho que importa não interrompe ninguém.

Fundo de badge: `color-mix(in oklab, var(--status-x) 14%, transparent)` — 16% no warning. Não invente outro percentual.

---

## Séries — categórico (8 matizes)

```
--series-1  #ff7a1a   --series-5  #1baf7a
--series-2  #ffb45c   --series-6  #d95926
--series-3  #e8a04c   --series-7  #9085e9
--series-4  #c98500   --series-8  #e66767
```

Para dado **sem ordem**: campanhas, plataformas, criativos. Use na sequência — `series-1` é a série principal e coincide com o accent de propósito.

---

## Estágios do kanban — ordinal (rampa)

Aqui houve um desvio deliberado do plano original, que pedia 8 cores distintas.

**Estágio de funil não é dado categórico.** Trocar a ordem muda o significado — `NEW` antes de `WON` não é a mesma coisa que o contrário. Isso o torna **ordinal**, e dado ordinal pede **um matiz com degraus de luminosidade monótonos**, para que o leitor veja a ordem na própria cor.

Oito matizes distintos gastariam o canal de identidade re-codificando o que a posição da coluna já mostra, e o quadro viraria arco-íris.

| Token | Valor | Estágio |
|-------|-------|---------|
| `--stage-1` | `#7a3d0a` | NEW — acabou de chegar |
| `--stage-2` | `#9c4f0d` | QUALIFYING — em triagem |
| `--stage-3` | `#c26310` | QUALIFIED — é paciente de verdade |
| `--stage-4` | `#e07a15` | SCHEDULED — tem hora marcada |
| `--stage-5` | `#ff9440` | ATTENDED — sentou na cadeira |
| `--stage-6` | `#ffc47a` | PROPOSAL — orçamento na mão |

Mais quente = mais perto de fechar.

**Rampa validada** (`scripts/validate_palette.js --ordinal --mode dark --surface #151517`): luminosidade monótona, todos os vãos ΔL ≥ 0.06, ponta escura a 2,17:1 contra a superfície (mínimo ordinal 2:1), dispersão de matiz 18°.

### Os dois terminais são estado, não posição

```
--stage-won   = var(--status-good)   /* 7,08:1 na superfície */
--stage-lost  = var(--ink-muted)     /* 5,32:1 — "arquivado", sem gritar */
```

`LOST` **não** usa o vermelho crítico, pelo motivo da seção de status.

---

## Adicionar uma cor nova — o processo

Antes de tudo: **quase sempre a resposta é reusar um token existente.** Se ainda assim for necessário:

1. **Classifique o dado.** Tem ordem? → rampa ordinal. Não tem? → matiz categórico. É estado? → escala de status.
2. **Não crie um sexto status.** Se o produto precisa de mais que good/warning/serious/critical, o problema é a modelagem do estado, não a paleta.
3. **Meça o contraste** contra `--surface` (`#151517`): texto ≥ 4.5:1, elemento gráfico/rampa ordinal ≥ 2:1.
4. **Rampa ordinal** precisa de luminosidade monótona e ΔL ≥ 0.06 entre degraus consecutivos.
5. **Não colida com o accent** a menos que seja a série principal.
6. Declare em `:root` **e** exponha em `@theme inline` — sem o segundo passo a classe Tailwind não existe.
7. Aplique nos **dois** repos, ou registre por que divergiram.

## Como expor ao Tailwind v4

```css
:root { --minha-cor: #xxxxxx; }

@theme inline {
  --color-minha-cor: var(--minha-cor);   /* → classes text-minha-cor, bg-minha-cor */
}
```

O prefixo `--color-` é o que gera a classe utilitária. Sem `tailwind.config.js` — o Tailwind v4 lê daqui.

---

<sub>Feito por José Neto.</sub>
