# Constitution - principios do projeto, 1 violacao exige override escrito

1. Custo teto manda: item sem custo/mes estimado nao entra no MVP.
2. Time pequeno: gerenciado antes de proprio; monolito modular e 1 repo ate um driver provar o contrario.
3. Evidencia: numero sem fonte (research.md) ou sem calculo e opiniao.
4. Dados sensiveis: acesso minimo, segredo em gerenciador, backup com restore testado, RPO/RTO declarados.
5. Async: retry com teto, timeout por hop, DLQ, chave de idempotencia. Sem exactly-once sobre transporte at-least-once.
6. Contrato versionado, mudanca so aditiva, quebra vira v2 com adapter. Migracao expand-contract.
7. Visual: sem paleta padrao, tokens com contraste AA medido, estados escritos, lista banida de visual-contract.md.
8. MVP corta por prazo; backlog com motivo em 1 linha.
9. Decisao vira ADR com alternativa rejeitada, motivo e dissenso.
