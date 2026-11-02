# Plan <nn> - <slug>

## 1. Stack and services

Table item | decision | ADR | reason, max 8 rows. No service without a reason against the alternative.

## 2. Data and migrations

Entities and owner, expand-contract schema, backward compatible migration, tested rollback.

## 3. Contracts and sequence

Versioned endpoints or events, primary flow in up to 8 lines (or a mermaid sequenceDiagram block).

## 4. Failures and limits

Per async path: timeout per hop, capped retry, DLQ, idempotency key, queue limit.

## 5. Observability

Flow SLI, RED metrics, structured logs with trace id, alert with an owner.

## 6. Tests

1 test per spec requirement, verb + condition + result. Affected fitness function.
