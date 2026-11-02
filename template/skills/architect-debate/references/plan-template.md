# Plan <nn> - <slug>

## 1. Stack e servicos

Tabela item | decisao | ADR | motivo, max 8 linhas. Sem servico sem motivo contra a alternativa.

## 2. Dados e migracoes

Entidades e dono, schema expand-contract, migracao backward compatible, rollback testado.

## 3. Contratos e sequencia

Endpoints ou eventos versionados, fluxo principal em ate 8 linhas (ou bloco mermaid sequenceDiagram).

## 4. Falhas e limites

Por path async: timeout por hop, retry com teto, DLQ, chave de idempotencia, limite de fila.

## 5. Observabilidade

SLI do fluxo, metricas RED, log estruturado com trace id, alerta com dono.

## 6. Testes

1 teste por requisito do spec, verbo + condicao + resultado. Fitness function afetada.
