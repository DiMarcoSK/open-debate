# Completeness - from an empty repository to a launched, operated product

The backlog is complete when a team that executes it in order, and nothing else, ends with the product launched and operated.
debate-auditor checks BACKLOG.md stage by stage in `phase backlog-audit`; each gap becomes an item in `phase backlog-fix`.

| # | Stage | Covered when the backlog has | Applies when |
|---|---|---|---|
| 1 | Repository and tooling | repo, 1-command setup, lint and format, env config with an example file, secrets out of the repo | always |
| 2 | Environments and infrastructure | local, staging and production, created by code; domain, DNS and TLS for what is public | always |
| 3 | Delivery pipeline | build, test and deploy on every merge, migrations in the pipeline, rehearsed rollback | always |
| 4 | Data | schema and migrations per entity of the SDD, seed or sample data, backup with a tested restore | the product stores data |
| 5 | Identity and access | sign up, sign in, sign out, recovery, roles and the authorization checks of the SDD | there are users or roles |
| 6 | Features | every user story of every spec, P1 before launch, the rest placed or cut on purpose | always |
| 7 | Integrations | per external service of the SDD: account, keys, sandbox, client, error and limit handling | the SDD names an external service |
| 8 | Interface | every screen of the inventory with its states, the design system, the brand when there is a brandbook | there is UI |
| 9 | Quality | unit, integration and end-to-end tests of the primary flow, test data, performance and accessibility checks in CI | always |
| 10 | Security and compliance | the SDD threat mitigations, privacy policy and terms, consent, data export and deletion where the law asks | always; legal parts with personal data |
| 11 | Observability and operations | logs, metrics, traces, alerts with an owner, runbook per service, error tracking | always |
| 12 | Launch | beta, go-live checklist, store or marketplace submission when there is one, launch communication | always |
| 13 | After launch | support channel, feedback loop, dependency updates, cost and budget alerts | always |

## Audit format (backlog/audit.md)

```
# Backlog completeness audit

Verdict: COMPLETE | GAPS

## Stages

| Stage | Status | Items or reason |
|---|---|---|
| 1 Repository and tooling | covered | B01 B02 |
| 7 Integrations | n/a | the SDD names no external service |
| 10 Security and compliance | gap | G1 |

## Gaps

| ID | Stage | Missing work | Source | Acceptance |
|---|---|---|---|---|
| G1 | 10 | Publish privacy policy and terms before the beta | brief | both pages linked from sign-up |
```

Rules the gate checks: 1 row per stage, status `covered`, `gap` or `n/a`; a covered stage cites the B ids that deliver it and they exist in BACKLOG.md; `n/a` carries the reason; `GAPS` has 1+ `| Gn |` row with a source (SDD-n, ADR-NNNN, spec NN or brief).
