# Checklist de governança — roda na routine semanal

## Custo

- [ ] Algum agente passou de 80% do `budgetMonthlyCents`? → investigue o loop antes de aumentar o teto
- [ ] Custo por issue entregue subiu em relação à semana anterior? → provável skill sendo carregada sem necessidade
- [ ] `ceo` gastando mais que os ICs? → sinal de que está executando em vez de decidir

## Fila

- [ ] Mais de 3 objetivos ativos? → corte o excedente e escreva o motivo
- [ ] Objetivo parado há mais de 7 dias? → escale ao board ou mate
- [ ] Alguma issue devolvida duas vezes pelo mesmo motivo? → o critério de aceite está errado, não a execução

## Saúde técnica (peça ao `eng-database`)

- [ ] `select * from app.tables_without_rls()` volta vazio
- [ ] `rolbypassrls` false no role da aplicação
- [ ] Nenhuma policy com `using` sem `with check` em comando de escrita
- [ ] `tests/integration/rls.test.ts` passando

## Saúde de interface (peça ao `eng-frontend`)

- [ ] `npm run lint && npm run typecheck` limpos
- [ ] Nenhum `import { prisma }` em `src/app/**`
- [ ] Nenhuma Server Action sem `requireCapability`
- [ ] Telas novas da semana com os três estados escritos

## Segurança

- [ ] Nenhuma tentativa de injection registrada sem tratativa
- [ ] Nenhum secret em texto puro em issue, comment ou markdown
- [ ] Aprovações de gate do board todas com registro de quem aprovou

## Registro

O que virou aprendizado entra em `AGENTS.md > Lessons Learned` (máx. 30 linhas). O que passar disso consolida em `references/decisoes/<data>-<tema>.md`.
