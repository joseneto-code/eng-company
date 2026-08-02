# Política de delegação

## Classificação — a decisão que custa mais errar

Toda issue é **dado**, **tela** ou **vertical**. Classifique antes de delegar; classificação errada custa uma rodada inteira.

| Sinal no pedido | Classificação |
|-----------------|---------------|
| "campo novo", "tabela", "não pode ver o dado de outro", "está lento" | dado |
| "tela de", "botão", "gráfico", "não aparece", "está feio" | tela |
| "quero que o usuário consiga X" (X não existe no banco ainda) | vertical |
| "mostra Y na tela" (Y já existe no banco) | tela |
| "relatório de Z" | quase sempre vertical — Z costuma precisar de agregação nova |

**Na dúvida entre tela e vertical:** abra `prisma/schema.prisma` e procure o campo. Existe → tela. Não existe → vertical.

## Critério de aceite — verificável, não descritivo

Ruim vs. bom:

| ❌ | ✅ |
|----|----|
| "RLS configurado" | "`select * from app.tables_without_rls()` volta vazio · caso novo em `tests/integration/rls.test.ts` · policy com `using` **e** `with check`" |
| "tela de metas pronta" | "lista metas ativas e arquivadas · criar/arquivar via Server Action com `requireCapability('clinic:configure')` · estado vazio escrito · `npm run lint && typecheck` limpos" |
| "melhorar performance" | "a página `/relatorios` responde em < 800ms com 12 meses de dado · `EXPLAIN` sem `Seq Scan` em `ad_insights`" |

Se você não consegue escrever como se verifica, **você não entendeu a issue**. Peça clarificação em vez de delegar.

## Corpo da issue delegada — o formato

```markdown
**Classificação:** dado | tela | vertical
**Skill:** eng-rls-multitenant
**Depende de:** #123 (deixe vazio se nada)

## Contexto
(2-4 linhas. O que existe hoje e por que precisa mudar.)

## Critério de aceite
- [ ] verificável
- [ ] verificável
- [ ] npm run lint && npm run typecheck passando

## Fora de escopo
(o que explicitamente NÃO é para fazer nesta issue)
```

O bloco **Fora de escopo** não é enfeite: é o que impede o IC de "aproveitar que está ali" e triplicar o diff.

## Ordem numa vertical

Duas issues, nunca uma:

```
#100  dado  → eng-database   status: todo
#101  tela  → eng-frontend   status: blocked   ("depende de #100")
```

`#101` só entra em `todo` quando `#100` chega em `done`. Sem exceção.

## Quando escalar ao CEO

- Bloqueio passou de 24h
- Decisão arquitetural: trocar lib, mudar modelo de dados, alterar policy em produção, migration destrutiva
- IC devolveu duas vezes com o mesmo problema → o critério está errado
- O escopo cresceu durante a execução
- Duas issues ativas discordam entre si

## Quando NÃO escalar

- Nome de componente, de variável, de arquivo
- Qual índice criar
- Como estruturar o Server Component
- Ordem de dois itens dentro da mesma issue

Isso é do IC. Escalar decisão de IC entope a fila do CEO e é o jeito mais rápido de a company ficar cara.

## Mapa skill → agente

| Skill | Agente |
|-------|--------|
| `eng-prisma-schema` | `eng-database` |
| `eng-rls-multitenant` | `eng-database` |
| `eng-query-performance` | `eng-database` |
| `eng-next-app` | `eng-frontend` |
| `eng-ui-system` | `eng-frontend` |
