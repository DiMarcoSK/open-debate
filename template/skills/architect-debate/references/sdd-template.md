# SDD - <product name>

## 0. Summary

5 lines for someone who reads only this: problem, main decision, cost/month, deadline, biggest risk.

## 1. Context and goal

Goal in 1 sentence, who uses it, the problem that goes away, 90-day success metric. Non-goals in 1 line each.

## 2. Constraints, assumptions and drivers

Deadline, team, cost ceiling, load, sensitive data. An unconfirmed assumption carries `[assumed, owner <name>, <week>]`.
Quality drivers: 3 scenarios `stimulus -> response -> measure`. Evidence: research.md (ids cited in the text).

## 3. Decisions

| ADR | Decision | Rejected alternative | Driver |

1 row per ADR in adr/, no paragraph.

## 4. Architecture

C4 context and container in a mermaid block. Capacity with the arithmetic (average rps, peak, data/year).
Modules and versioned contracts. Data: owner per entity, consistency, backup, RPO/RTO.
Failures per path: timeout, capped retry, DLQ, idempotency key. Security: STRIDE top 3.
Every service with req/day and cost/month.

## 5. Experience and visual direction (gated by visual-contract.md)

JTBD and critical task with a steps/seconds goal. Usability goals and WCAG 2.2 AA plan (debate-ux).
Flows with step counts and screen inventory (debate-design), with the debate-ux review fixes applied.
Concept: <metaphor>, convention kept and broken; with debate-brand on the panel, the brand lives in BRANDBOOK.md.
Literal TOKENS block with contrast ratios. Type scale, spacing, radius, elevation, motion.
Key screens as ASCII wireframes. Written states: Empty, Loading, Error, Success, Partial.
Signature moment with cost. Banned list confirmed absent, or a written override per item.

## 6. Cuts and backlog

What stayed out of the MVP and why, 1 line each.

## 7. Acceptance tests, SLO and fitness functions

1 test per kept item, verb + condition + result. Primary flow SLO. Fitness functions in CI.

## 8. Risks, dissent and open questions

Risk register: | Risk | Prob (L/M/H) | Impact (L/M/H) | Mitigation | Owner |, max 5. Dissent recorded in the ADRs. Max 3 open questions.
