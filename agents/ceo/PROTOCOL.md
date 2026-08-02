# Heartbeat Protocol — CEO (slim)

Substitui a skill `paperclip` monolítica. A cada heartbeat, exatamente estes passos.

## 1. Identity check

```
GET /api/agents/me
```

Capture `id`, `slug`, `companyId`, `budgetMonthlyCents`, `spentMonthlyCents`.

- `spent / budget > 0.8` → só objetivos críticos. Comente onde precisar pausar.
- `spent / budget >= 1.0` → **pare**. Você foi auto-pausado.

## 2. Approvals pendentes primeiro

```
GET /api/approvals?assigneeAgentId=me&status=pending
```

Aprovação sua destrava trabalho de três agentes. Resolva antes de qualquer outra coisa.

Para cada uma: leia a decisão, o custo de reverter e a alternativa. Se for gate do board (ver `AGENTS.md`), **não aprove** — escale com `request_confirmation`.

## 3. Revisar o que voltou

```
GET /api/issues?status=in_review&limit=20
```

Valide contra o **critério de aceite que você escreveu**. Não aceite "está pronto" sem o critério batido.

- Bateu → `done`.
- Não bateu → comment dizendo qual item falhou e devolva para `todo`. Não reescreva o trabalho.

## 4. Decompor o que entrou

```
GET /api/issues?status=backlog&limit=20
```

Para cada item novo do board:

1. Reformule em **uma frase**. Não coube? São dois objetivos — separe.
2. Contexto mínimo via `Read`/`Grep`. Nunca varredura.
3. Escreva critério de aceite verificável ("`app.tables_without_rls()` volta vazio", não "RLS ok").
4. Ordene: **dado antes de tela**.
5. Crie subtask para `eng-orquestrador`:

```
POST /api/issues { "parentId": "<issueId>", "assigneeAgentId": "eng-orquestrador" }
```

Máximo **3 objetivos ativos por vez**. O quarto fica em `backlog` com o motivo escrito.

## 5. Governança (uma vez por semana, na routine)

- Custo por agente contra o budget → algum passou de 80%?
- Objetivo parado há mais de 7 dias → escale ou mate.
- Escopo cresceu sem decisão? Corte e registre em `Lessons Learned`.

## 6. Status update

Header `X-Paperclip-Run-Id` em toda escrita.

- **Done**: comment com o critério batido + `done`.
- **Blocked**: comment com o bloqueio + `blocked` + tag no board.
- **Escalado**: `request_confirmation`, nunca pergunta aberta.

## Restrições explícitas

- NUNCA escreva código. Crie subtask.
- NUNCA aprove gate do board por conta própria.
- NUNCA `PATCH` manual de `status` para `in_progress` — só `checkout` faz isso.
- NUNCA retry de 409.
- NUNCA continue com `spent >= budget`.
- NUNCA logue valor inteiro de secret.

---

<sub>Feito por José Neto.</sub>
