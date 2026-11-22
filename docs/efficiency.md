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

Input dominates. Outputs are short by design, because every role has a line cap. The critique phase grows with the square of the panel. Adding a seat costs more than its own two calls, which is why a seat the agenda adds must own a contested decision, and why the agenda adds 2 at most.

Input is also paid per turn, not per call. An agent that opens 5 files over 4 turns resends the harness's system prompt, its tool definitions and everything read so far on each one. The two largest cuts below remove turns and shrink what each turn resends.

## Already applied

| What | Why it saves |
|---|---|
| Case files inlined in the prompt (CLI, `INLINE=1`) | Each call gets the files it reads inside its prompt, in a fixed order: persona, files, task. It answers in 1 turn instead of opening them one turn at a time. Files come from the call's room, so blindness holds. Measured on a proposal over the fixture files with Claude Code and haiku: 6 turns down to 1, 19.5k input tokens down to 10.2k (-47%), cost -29%, same output. Claude Code takes the prompt on stdin and inlines up to 320 KB; the other harnesses take it as an argument, which Linux caps at 128 KiB, so they inline up to 96 KB. Past that a file stays out and the agent opens it. In a real run, before stdin, the 2 card groups that cited every spec passed 96 KB and took 4 and 6 turns, 350k of the run's 1.8M tokens. In the critique phase, rival proposals carry line numbers for the `file:line` of a veto. |
| Lean headless Claude Code | `claude -p` loads the user's MCP servers, skills, hooks, CLAUDE.md and every built-in tool definition, and resends them on every turn. The panel only reads and searches, so the call runs with `--tools Read,Glob,Grep,WebSearch,WebFetch --strict-mcp-config --disable-slash-commands --safe-mode`, and other tools could not run there anyway. Measured on 1 trivial call on a machine with several MCP servers: 119.7k input tokens down to 6.4k (-95%), same answer. `--safe-mode` also keeps the user's hooks out: in a real run, a Stop hook asked the research call for one more turn and its reply replaced research.md. A Claude Code without a flag keeps the call without it. |
| 5-minute cache writes (Claude Code) | A call that answers in 1 turn writes its prompt to the cache and never reads it. Claude Code writes with the 1-hour TTL, at 2x the input price; `FORCE_PROMPT_CACHING_5M=1` writes at 1.25x, and 5 minutes still cover every turn of a research call. In the real run, 40 calls of 1 turn wrote 861k tokens: at Sonnet prices, US$ 5.17 with the 1-hour TTL against US$ 3.23 with the 5-minute one. |
| Read once, in 1 turn (session) | debate-rules.md has every subagent open all its files in the same turn, in parallel, and never twice. A file that is inlined is never opened. |
| Each call reads only the files it needs | The SDD, audit and fix calls read `decision.md` without `adr/`, because `adr/` is split from it. A spec gets its scope line from the decision index in the prompt and reads `adr/` instead of the whole `decision.md`. The backlog reads `adr/`, not `decision.md`. This saves about 1 `decision.md` (up to 150 lines) per call. |
| Cards read only their own specs | A card group reads the spec folders its items cite, not `specs/` whole. |
| An exhausted model is skipped | A quota failure costs 1 call. The rest of the run does not hit the same wall `RETRIES` more times per call. |
| Rebuttal only for vetoed seats | A seat without a veto against it keeps its first proposal, with no call. |
| Short answers where nothing is wrong | An approved audit is 1 line. A subagent answers `OK <file>`, so the orchestrator's context does not grow with each artifact. |
| Gates do not fail on form | A quote whose inner quotes the model escaped (`\"Check again\"`) still matches the text: in a real run it caused 3 of 5 critique repairs. An `[assumed]` without an owner fails the spec, SDD, decision, brand or backlog gate, so it gets its repair, instead of failing `validate` after the run. |
| Repairs carry the gate reason | 1 targeted retry instead of a rerun of the phase. A gate fails only at 50% over the line cap, because a redo costs more than a few extra lines. |
| Rooms for proposals and critiques | The agent's folder holds only what it may read, so it does not open, and pay for, files it should not see. |
| Stable prompt prefix | The persona comes first, then the inlined files in a fixed order, then the task. Providers with prompt caching reuse the prefix across calls of the same agent. |
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
| Drop the sections of a persona that belong to other phases | A few hundred tokens a call, but persona sections are not split cleanly by phase (the pm's backlog rules apply to the backlog fix, and its method frames the critique). The risk to quality is not worth it. |
| Bundle the files in session mode | The orchestrator would paste or bundle content into its own context, which grows with every wave. Reading in parallel in 1 turn gets the same turn count. |
| Reuse research across cases | Research answers a specific brief. A stale finding is worse than a fresh search. |
