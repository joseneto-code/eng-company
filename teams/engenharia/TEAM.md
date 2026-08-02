---
schema: agentcompanies/v1
kind: team
slug: engenharia
name: Engenharia
manager: eng-orquestrador
includes:
  - agents/eng-database
  - agents/eng-frontend
---

# Time de Engenharia

Reporta ao `eng-orquestrador`, que reporta ao `ceo`.

Dois ICs com fronteira dura entre eles:

| Agente | Domínio | Não encosta em |
|--------|---------|----------------|
| `eng-database` | `prisma/`, `src/lib/db/`, `src/lib/<domínio>/` | componente, CSS, rota |
| `eng-frontend` | `src/app/`, `src/components/` | schema, policy, migration |

A fronteira é dura de propósito. Quando um IC precisa do outro, o caminho é **subtask com `parentId`** — nunca "faço rapidinho aqui". É o que mantém a issue de dado revisável contra critério de dado, e a de tela contra critério de tela.

## Ordem de execução

Numa feature vertical, `eng-database` **sempre** primeiro. `eng-frontend` fica em `blocked` até a issue de dado chegar em `done`.

Motivo: tela construída sobre shape que ainda vai mudar é retrabalho, e neste produto o retrabalho é de RLS — o tipo caro.

---

<sub>Feito por José Neto.</sub>
