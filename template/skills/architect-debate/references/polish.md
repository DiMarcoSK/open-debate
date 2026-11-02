# Polish - what separates "it works" from "a polished product"

Every tag becomes at least 1 item in BACKLOG.md (`#tag` in the `{...}` block); gate.sh fails a missing tag (`brand` only counts when the case has BRANDBOOK.md).
The basics go in the DoD of every item (states, focus, real copy). The Polish phase audits and refines the whole.

| Tag | Polished when (measurable criterion) |
|---|---|
| design-system | tokens.css is the only source of color/type/spacing in the code; base components (button, input, select, table, badge, dialog, toast, skeleton) with hover, focus, disabled, error; living catalog (Storybook or a /ui route) |
| states | every screen with Empty, Loading (skeleton shaped like the content), Error, Success and Partial, with the SDD copy |
| a11y | WCAG 2.2 AA: axe with no serious/critical violation, primary flow by keyboard only, screen reader (VoiceOver and NVDA) on the primary flow, visible focus, 24 px targets |
| responsive | 360, 768, 1280 and 1920 px with no horizontal scroll; a dense table becomes a list at 360 |
| motion | state transitions 120-240 ms with the token easing; prefers-reduced-motion respected |
| copy | microcopy reviewed per screen (verb, number, tone), errors say what to do, plain-language glossary without jargon |
| perf | Core Web Vitals p75: LCP < 2.5 s, INP < 200 ms, CLS < 0.1; JS budget per route; SDD API p95 measured |
| onboarding | first run with sample data; time to first value measured and under the SDD goal |
| signature | SDD signature moment implemented and reviewed by design |
| brand | only with BRANDBOOK.md: logo in its versions, favicon and app icon; every key screen matches section 7; copy reviewed against the voice of section 2 |
| visual-qa | screenshot visual regression (Playwright) on key screens; design QA per screen against style-tile.html |
| observability | primary flow SLO, RED metrics, logs with trace id, alert with an owner |
| security | SDD STRIDE mitigations, authz tested per role, secrets in a vault, CSP/HSTS, dependencies scanned in CI |
| data | backup with tested restore, migration with tested rollback, RPO/RTO verified |
| analytics | product events measure the 90-day success metric (primary flow funnel) |
| docs | 1-command setup README, runbook per service, ADRs updated, changelog |
| launch | beta with real users, feedback channel, go-live checklist, rehearsed rollback |
