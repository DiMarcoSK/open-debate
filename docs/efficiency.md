# Efficiency: time and tokens

A debate makes dozens of calls. This page shows where the time and tokens go, what open-debate already does to cut them, the settings that make a run cheaper, and the ideas that were weighed and left out.

## Measure first

`open-debate status <case>` reads `raw/metrics.tsv` and prints the cost of the case so far:

```text
cost: 41 calls, 2310 s of model time, 2 repair(s); the slowest was f6-decision (190 s)
tokens: 612000 over 41 call(s) with usage; f1 6% f1b 2% f2 21% f3 18% f4 7% f5 9% f6 16% f7 9% f8 12%
```

Each row of `metrics.tsv` is one logical call: tag, agent, seconds, attempts, exit code, harness, input tokens and output tokens. Input includes cached tokens. Tokens are recorded when the harness reports usage in its output: opencode, Claude Code, Cursor, Droid, Gemini CLI and Antigravity. Codex, Pi, dsh, Cline and custom commands show `-`.

The tag prefix is the phase: `f1` research, `f1b` agenda, `f2` proposals, `f3` critiques, `f4` fact-check, `f5` rebuttal, `f6` decision, SDD, audit and brand, `f7` specs, `f8` backlog.

## Where it goes

With a panel of P seats, S specs and G card groups, a full run makes about:

| Phase | Calls | What drives the cost |
|---|---|---|
| research, agenda | 2 | web pages read by the researcher |
| proposals | P | each seat reads brief, research and agenda |
| critiques | P | each seat reads every rival proposal: P x (P - 1) proposal reads |
| fact-check, rebuttal | 1 + up to P | the fact-check reads every proposal and critique |
| decision, SDD, audit | 3 to 5 | the judge reads everything above once |
| specs | S | SDD and ADRs per spec |
| backlog | 3 to 5 | tracks, backlog, completeness audit |
| cards | G | 1 per group of up to 10 items |

Input dominates. Outputs are short by design, because every role has a line cap. The critique phase grows with the square of the panel. Adding a seat costs more than its own two calls.

## Already applied

| What | Why it saves |
|---|---|
| Each call reads only the files it needs | The SDD, audit and fix calls read `decision.md` without `adr/`, because `adr/` is split from it. A spec gets its scope line from the decision index in the prompt and reads `adr/` instead of the whole `decision.md`. The backlog reads `adr/`, not `decision.md`. This saves about 1 `decision.md` (up to 150 lines) per call. |
| Cards read only their own specs | A card group reads the spec folders its items cite, not `specs/` whole. |
| An exhausted model is skipped | A quota failure costs 1 call. The rest of the run does not hit the same wall `RETRIES` more times per call. |
| Rebuttal only for vetoed seats | A seat without a veto against it keeps its first proposal, with no call. |
| Short answers where nothing is wrong | An approved audit is 1 line. A subagent answers `OK <file>`, so the orchestrator's context does not grow with each artifact. |
| Repairs carry the gate reason | 1 targeted retry instead of a rerun of the phase. A gate fails only at 50% over the line cap, because a redo costs more than a few extra lines. |
| Rooms for proposals and critiques | The agent's folder holds only what it may read, so it does not open, and pay for, files it should not see. |
| Stable prompt prefix | The persona comes first and the task after it. Providers with prompt caching reuse the prefix across calls of the same agent. |
| Parallel waves | The panel runs at the same time (`PARALLEL=6`). Wall time is the slowest call, not the sum. Card groups also run in parallel. |

## Settings for a cheaper run

| Setting | Saves | Costs |
|---|---|---|
| `--rounds 2` | the rebuttal, up to P calls | vetoed seats do not answer |
| `--rounds 1` | critiques, fact-check and rebuttal, about 2P + 1 calls | no adversarial check |
| `FACTCHECK=0` | 1 large call | wrong numbers are not zeroed |
| `REVIEW=0` | the SDD and backlog audits, 2 to 4 calls | no independent check |
| `CARDS=0` | G calls | the backlog has no step-by-step cards |
| `--panel` with fewer seats | 2 or more calls per seat, plus critique reads | fewer viewpoints |
| `open-debate models profile mixed <model>` | strong-model tokens on everything but the deciding seats | none on quality where it counts |
| `MAX_CALLS=N` | a hard cap on spend | the run stops when the cap is reached; running again resumes |

## Weighed and left out

| Idea | Why not |
|---|---|
| Summarize proposals before the judge | The judge rules on literal quotes and on matrix arithmetic. A summary drops exactly what the gates check. |
| Compress artifacts with abbreviations | Artifacts are the inputs of later phases and the deliverable for people. `debate-rules.md` already enforces terse writing: 1 idea per line, tables, no filler. Abbreviations would hurt quality and gate matching for little gain. |
| Diff-based repairs | Gates check the whole file, and merging patches from a model is fragile. Repairs are a minority of calls. |
| One call for several seats | Breaks blindness, the point of the proposal phase. |
| Reuse research across cases | Research answers a specific brief. A stale finding is worse than a fresh search. |
