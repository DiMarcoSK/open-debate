---
name: architect-debate
description: Turn a raw product idea into a researched, debated design doc with ADRs (MADR 4.0), C4, design tokens (W3C DTCG), style tile, per-feature spec/plan/tasks (Spec Kit style) and an executable backlog to a polished, launched product (CSV/JSON/gh export). Triggers: I want to build, I have an idea, SDD, design doc, RFC, ADR, architecture debate, /debate (any language). Runs intake, web research with scout subagents, an agenda of contested decisions, blind proposals in parallel from a panel picked for the idea (always architecture, UI/UX and product; plus software design, art direction and brandbook, security, AI, data, mobile, GCP, AWS or Kubernetes when the brief calls for them), critiques with verified quotes, fact-check, rebuttal, weighted judge, independent audit, gates.
---

Standards: lean arc42 design doc, backlog with epics, INVEST vertical slices, walking skeleton, DoR/DoD and critical path, C4 in mermaid, ISO/IEC 25010 + ATAM scenarios, ADRs in MADR 4.0, EARS requirements, GitHub Spec Kit style specs, W3C DTCG tokens, WCAG 2.2 contrast, Nielsen heuristics, STRIDE.
Case state in `references/protocol.md`. Scripts in `{{SCRIPTS}}/` (below, `$S`).

Language: talk to the user in the language they write in. Every file of the case (brief, research, proposals, decisions, SDD, specs, backlog) is written in English, whatever the input language. Every Task prompt ends with `Write in English.`

## Session mode (default: /debate; one specialist per subagent)

Before the intake: if `open-debate` is on the PATH, run `open-debate upgrade --check` and, when there is a new version, say so in 1 line.

Phase 0, intake in grill mode: the final product is only concise if the brief is. Ask in rounds, 1 topic per round,
up to 3 questions per round, each with 2-4 options and your recommendation marked as the default. Topics, in this order:
1. goal, who uses it, 90-day success metric; 2. load (users, req/day, peak); 3. deadline, team, cost ceiling/month;
4. top 3 quality drivers; 5. sensitive data and regulation; 6. platform, competitors and visual references.
Grill, on every answer:
- A vague answer ("everyone", "fast", "cheap", "scalable") comes back as a question with a number or an example: "how many?", "in how long?", "up to how much/month?".
- A contradiction between answers (4-week deadline with 9 features; zero cost with a 99.99 SLA) is pointed out and the user picks what gives.
- Scope cut: list the features mentioned and ask for the MVP: what ships on day 1, what goes later, what goes away. Ask "if you could launch only 1 flow, which one?".
- Ask why behind every hard requirement until you reach the real constraint; a requirement without an owner becomes an assumption.
- The grill ends when goal, metric, primary user, MVP, deadline and cost ceiling have a concrete answer, or when the user asks to move on (cap of 5 rounds).
Before moving on, show the brief in 6 lines (problem, user, metric, MVP, out of scope, constraints) and ask for confirmation.
No answer: assume and mark `[assumed, owner <name>, <week>]`. Run `$S/new-debate.sh "<idea>" <dest>` (dest defaults to `cases` at the project root), fill `brief.md` in English, adjust `constitution.md`, run `$S/gate.sh <case> brief` until it passes.
Panel: `debate-arch`, `debate-ux` and `debate-pm` always sit. The optional seats come from the brief: run `$S/panel.sh <case>`, which shows the panel and the brief word that triggered each seat (catalog in `references/panel.conf`):

| Seat | Joins when the brief has |
|---|---|
| debate-design | screens: web, app, dashboard, portal, backoffice |
| debate-brand | a public face: brand, B2C, consumer, store, launch, landing |
| debate-sec | personal, financial, health or regulated data (GDPR, LGPD, PCI) |
| debate-ai | LLM, RAG, agent, ML, recommendation |
| debate-data | analytics, BI, ETL, pipeline, reports, streaming |
| debate-mobile | iOS, Android, native app, offline, push |
| debate-gcp, debate-aws, debate-k8s | the cloud or cluster named |

Adjust by what the brief means, not only by the word (ex: a product without screens drops `design`; an idea going public adds `brand`), save with `$S/panel.sh <case> --save <agents>` and state the panel in 1 line. Cap of 8 seats.
Design roles: debate-design decides what each screen holds (flows, inventory, wireframes, states); debate-ux reviews those screens in the critique (`## Review debate-design`) and owns usability, accessibility and the UI system; debate-brand creates the brand and TOKENS and, after the SDD, writes BRANDBOOK.md adapting the screens to the brand. Without debate-brand, TOKENS belongs to debate-ux.
Options: `--panel design,brand` becomes `$S/panel.sh <case> --save design brand` (the base seats join on their own); `--rounds N` cuts phases (1 = proposal only, 2 = +critique and fact-check, 3 = +rebuttal); `--no-research` writes `research.md` with `skipped: ...`; `--no-factcheck` skips phase 4.

Phases 1-6, each row is 1 wave of Tasks. `reads` and `writes` go in the Task prompt, with the case's absolute path:

| Phase | Subagent(s), in parallel | Reads | Writes | Gate |
|---|---|---|---|---|
| 1 research | debate-research (opens debate-scout per question) | brief.md, research-template.md | research.md | `gate.sh <case> research` |
| 1b agenda | debate-judge, `phase agenda`, with the panel in the prompt | brief.md, constitution.md, research.md, agenda-template.md | agenda.md | `gate.sh <case> agenda`; then grill 2: the agenda decisions that depend on user preference (not on evidence) become up to 3 questions with a default; the answer goes into brief.md before the proposals |
| 2 proposal | whole panel | brief.md, constitution.md, research.md, agenda.md, debate-rules.md, visual-contract.md (design, ux, brand) | proposals/<agent>.md | `gate.sh <case> proposal` |
| 3 critique | whole panel | brief.md, research.md, agenda.md, debate-rules.md, rival proposals | critiques/<agent>.md | `gate.sh <case> critique` |
| 4 fact-check | debate-research, `phase fact-check` | proposals/, critiques/, research-template.md | research-check.md | does not block |
| 5 rebuttal | only the agents listed by `gate.sh <case> vetoed` | brief.md, research.md, research-check.md, own proposal, vetoes against it, rivals | proposals/<agent>-r2.md | does not block |
| 6a decision | debate-judge, `phase decision` | everything above, adr-template.md | decision.md | `gate.sh <case> decision` (splits adr/) |
| 6b SDD | debate-judge, `phase sdd` | decision.md, adr/, sdd-template.md, visual-contract.md | SDD.md | `gate.sh <case> sdd` (generates style-tile.html, tokens.json, tokens.css) |
| 6c audit | debate-auditor, `phase audit` | SDD.md, brief.md, constitution.md, decision.md, adr/, research-check.md, audit-template.md | audit.md | `gate.sh <case> audit`; `Verdict: FIX`: debate-judge `phase fix` re-emits the SDD and the sdd gate runs again |
| 6d brand (only with debate-brand) | debate-brand, `phase brand` | brief.md, SDD.md, decision.md, proposals/debate-brand(-r2).md, proposals/debate-design.md, critiques/debate-ux.md, brandbook-template.md, visual-contract.md | BRANDBOOK.md | `gate.sh <case> brand` |

Failed gate: 1 repair Task to the same agent with `FIX: <gate reason>`; fails again, stop and report. An existing case resumes: `$S/gate.sh <case> status` shows each phase, the next one and stale outputs.
In phases 2 and 3, the Task prompt names only the files in the Reads column: an agent that does not get a rival's path stays blind.

Phase 7, specs: `$S/make-specs.sh <case> <slugs from the decision.md index>`; 1 Task per spec in parallel (debate-arch, `phase spec`, for spec/plan/tasks; debate-design, or debate-ux without design on the panel, fills spec section 6 when there is UI), then `$S/gate.sh <case> specs`, repair at the source until zero.

Phase 8, backlog to the polished product:
1. Wave in parallel: debate-ux `phase backlog-design` writes `backlog/design.md`; debate-arch `phase backlog-eng` writes `backlog/eng.md`. Both read SDD.md, adr/, specs/, polish.md, backlog-template.md and, if it exists, BRANDBOOK.md. Gate: `$S/gate.sh <case> tracks`.
2. debate-pm `phase backlog` writes `BACKLOG.md` (reads the 2 drafts, SDD, ADRs, specs/*/tasks.md, BRANDBOOK.md if it exists, polish.md, backlog-template.md). Gate: `$S/gate.sh <case> backlog` (coverage of every polish.md tag, every spec and every ADR, acyclic dependencies, S/M/L estimate, DoD, capacity); once approved it exports `backlog.csv` (Jira/Linear/GitHub Projects), `backlog.json` and `backlog-gh.sh` (review before running) and prints days per phase and the critical path.

Phase 9, delivery in chat (max 16 lines, in the user's language; artifact names and ids as they are):

```
Case: <path>
Summary: <SDD section 0 in 2 lines>
Decisions: <ADR-NNNN title, max 6>
Architecture: <shape + cloud + cost/month>
Panel: <agents>
Visual direction: <concept> - <display>/<body>, accent <hex>; open style-tile.html (and BRANDBOOK.md with debate-brand)
Specs: <NN slug, ...>
Backlog: <N items, D days, fits|cut at <deadline>>; critical path <Bxx -> ...>; BACKLOG.md and backlog.csv
Dissent that may reopen: <1 line>
Open questions: <max 3, with a default>
```

## CLI mode (`debate.sh`, any harness with a headless mode)

Each specialist runs as an isolated process, with its persona in the prompt; nothing needs to be installed in the harness. In phases 2 and 3 the process runs in a room: a directory with only what it may read. Same protocol, same gates, up to the backlog. This is the path for harnesses without subagents (agy, pi, dsh, cline), CI, batch reruns and a table of mixed harnesses. opencode free models refuse headless calls (`Free usage limit reached`): use session mode with them.

```sh
$S/new-debate.sh "<idea>" [dest-cases]
HARNESS=<id> $S/debate.sh <case> [rounds]
MIX="claude codex gemini" HARNESS=claude $S/debate.sh <case>   # panel spread across harnesses
$S/validate.sh <case> [--brief]
$S/gate.sh <case> status          # where it stopped, next phase, stale outputs, cost
FROM=critique HARNESS=<id> $S/debate.sh <case>   # archives critique onward and redoes it
```

Env: `HARNESS`, `MODEL` (empty = harness default), `MODEL_FALLBACK`, `MIX`, `ROUTES` (`debate-arch=claude debate-ux=codex:<model>`), `HARNESS_CMD` (with `HARNESS=custom`), `RETRIES=2`, `TIMEOUT=600` s per call, `BACKOFF=20` s, `PARALLEL=6`, `MAX_CALLS=0` (no cap), `MIN_LINES=5`, `PANEL` (empty = meta.txt or the brief; the base always joins), `FROM`, `RESEARCH=1`, `AGENDA=1`, `FACTCHECK=1`, `SPECS=1`, `REVIEW=1` (audit), `REPAIR=1`, `FRESH=0`, `OVERWRITE=0`.

## Models

In opencode, `models.conf` sets 1 free model per agent, from different families (parallel without fighting over the same limit, less similar opinions). In the other harnesses the agents inherit the session model; edit the agent's `model` line or use `MIX` to diversify. `$S/models.sh check` checks against `opencode models`; `$S/models.sh apply` writes them into the agents and swaps a model that left the catalog for the spare. Run `check` before a long debate.
