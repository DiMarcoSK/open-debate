# Checklist - <nn> <slug>

Gate before implementing. Everything checked, or it has an owner and an issue.

- [ ] every US has a testable criterion in 1 line and at least 1 non-functional requirement with a number
- [ ] every decision points to an ADR with a rejected alternative
- [ ] no `[assumed]` without owner and week in the same bracket
- [ ] every async path has timeout, capped retry, DLQ, idempotency
- [ ] SLI and alert defined for the primary flow
- [ ] SDD tokens used, AA contrast, focus and keyboard covered (or `no UI` with the reason)
- [ ] Empty/Loading/Error/Success states written (or `no UI` with the reason)
- [ ] no banned-list item without a written override
- [ ] scope fits the deadline with the current team
