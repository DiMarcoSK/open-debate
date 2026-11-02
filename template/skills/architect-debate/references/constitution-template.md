# Constitution - project principles, any violation needs a written override

1. The cost ceiling rules: an item without an estimated cost/month does not enter the MVP.
2. Small team: managed before self-hosted; modular monolith and 1 repo until a driver proves otherwise.
3. Evidence: a number without a source (research.md) or arithmetic is opinion.
4. Sensitive data: least access, secrets in a manager, backup with tested restore, RPO/RTO stated.
5. Async: capped retry, timeout per hop, DLQ, idempotency key. No exactly-once over at-least-once transport.
6. Versioned contracts, additive changes only, a breaking change ships v2 with an adapter. Expand-contract migrations.
7. Visual: no default palette, tokens with measured AA contrast, written states, visual-contract.md banned list.
8. The MVP cuts by deadline; backlog with the reason in 1 line.
9. A decision becomes an ADR with the rejected alternative, the reason and the dissent.
