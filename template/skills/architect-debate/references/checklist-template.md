# Checklist - <nn> <slug>

Gate antes de implementar. Tudo marcado ou tem dono e issue.

- [ ] cada US tem criterio testavel em 1 linha e ao menos 1 requisito nao funcional com numero
- [ ] cada decisao aponta um ADR com alternativa rejeitada
- [ ] nenhum `[assumido]` sem dono e semana no mesmo colchete
- [ ] cada path async tem timeout, retry com teto, DLQ, idempotencia
- [ ] SLI e alerta definidos para o fluxo principal
- [ ] tokens do SDD usados, contraste AA, foco e teclado cobertos (ou `sem UI` com motivo)
- [ ] estados Vazio/Loading/Erro/Sucesso escritos (ou `sem UI` com motivo)
- [ ] nenhum item da lista banida sem override escrito
- [ ] escopo fecha no prazo com o time atual
