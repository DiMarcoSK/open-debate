# open-debate

[![CI](https://github.com/DiMarcoSK/open-debate/actions/workflows/ci.yml/badge.svg)](https://github.com/DiMarcoSK/open-debate/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

From a raw idea to a specified product, through a debate between agents, in the harness you already use.

You describe the idea. A panel of specialists researches it, agrees on which decisions are actually in dispute, proposes blindly, attacks each other's proposals citing file and line, goes through a fact-check, and a judge decides with a weighted matrix that an independent auditor then reviews. The result is a set of artifacts a team can execute, not a chat transcript.

```text
you:  /debate alert triage platform for a small SOC

phase 1 research: ok, 18 findings
phase 1b agenda: 5 contested decisions
panel: arch, ux, pm + design, brand, sec (from the brief)
phase 2 proposal: 6/6 ok, ux repaired (ink/paper contrast)
phase 3 critique: 4/4 ok
phase 6 decision: 5 ADRs, 4 specs; audit: 1 defect fixed
phase 8 backlog: 42 items, 61 days, critical path B01 -> B07 -> B19 -> B33
```

The numbers above illustrate the output format. Write the idea and answer the intake in any language: the agent talks back in yours, and every artifact is written in English.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/DiMarcoSK/open-debate/main/install.sh | sh
```

The installer puts the `open-debate` command in `~/.local/bin`, finds the harnesses on your machine and installs `/debate` in each one. Running it again, or `open-debate upgrade`, updates. Every push to `main` that passes CI moves the `stable` tag; installed copies check it once a day and print a notice when a new version is out (`OPEN_DEBATE_NO_UPDATE_CHECK=1` turns it off). It requires macOS or Linux, `jq` and `perl`. On Windows, use WSL.

With Node, without a global install:

```sh
npx github:DiMarcoSK/open-debate init
```

Then open your harness and run `/debate <your idea>`. To check your setup:

```sh
open-debate doctor          # dependencies and installation
open-debate doctor --live   # 1 real call on each installed harness
```

## Harnesses

| Harness | ID | Invocation | Panel runs as |
|---|---|---|---|
| [opencode](https://opencode.ai) | `opencode` | `/debate` | subagents, one model per agent |
| Claude Code | `claude` | `/debate` | subagents |
| Codex CLI | `codex` | `$debate` | subagents |
| Cursor | `cursor` | `/debate` | subagents |
| Gemini CLI | `gemini` | `/debate` | subagents |
| oh-my-pi | `omp` | `/skill:debate` | subagents |
| Factory Droid | `droid` | `/debate` | subagents |
| GitHub Copilot CLI | `copilot` | `/debate` | subagents |
| Qwen Code | `qwen` | `/debate` | subagents |
| Antigravity CLI | `agy` | `/debate` | headless processes |
| DeepSeek Harness | `dsh` | `/debate` | headless processes |
| Pi | `pi` | `/skill:debate` | headless processes |
| Cline | `cline` | `/debate` | headless processes |

Any other CLI with a headless mode also works, with no code changes. What differs between harnesses, and which ones were tested with real calls, is in [docs/harnesses.md](docs/harnesses.md).

`init` uses whatever it detects. To choose:

```sh
open-debate init --harness claude,codex    # only these
open-debate init --all                     # every supported harness
open-debate init --project                 # current project instead of user level
```

## What you get

| Artifact | Contents |
|---|---|
| `research.md` | Findings with URLs, prior art, prices and limits, gaps |
| `agenda.md` | The 3-8 decisions in dispute, with options, owner and deciding driver |
| `decision.md`, `adr/` | Weighted matrix and MADR 4.0 ADRs, with rejected alternatives, dissent and a ruling on every veto |
| `SDD.md`, `audit.md` | Lean arc42 design doc, with C4 in mermaid, capacity, failures and STRIDE, plus its independent audit |
| `style-tile.html`, `tokens.json`, `tokens.css` | Visual direction with measured WCAG 2.2 contrast, W3C DTCG tokens |
| `BRANDBOOK.md` | With `debate-brand` on the panel: brand platform, voice, logo, color, type, and every key screen adapted to the brand |
| `specs/` | `spec.md`, `plan.md` and `tasks.md` per feature, GitHub Spec Kit style, with EARS requirements |
| `BACKLOG.md`, `backlog.csv`, `backlog.json`, `backlog-gh.sh` | Backlog through launch, with dependencies, estimates and critical path |

## Why it works

- **A shared agenda.** The judge lists the disputed decisions before anyone proposes. Every proposal takes a position on each one, so the judge compares answers to the same questions.
- **Blind proposals.** Each specialist writes before seeing the others. From the command line, proposals and critiques run in a working directory that holds only what the agent may read.
- **Critiques need evidence.** A veto requires a literal quote, a problem with a number and a concrete replacement. The gate looks the quote up in the cited file and rejects it if it is not there. Every veto gets a ruling.
- **A number without a source is an opinion.** Every number cites `research.md` or shows the math, and a citation to a finding that does not exist is rejected. Whatever the fact-check marks wrong scores zero in the matrix.
- **The judge does not grade its own work.** An independent auditor lists provable defects in the SDD, and only those get corrected.
- **Deterministic gates.** Scripts, not an LLM, check each phase and redo the math: contrast, matrix totals, weights, capacity, spec task coverage, dependency cycles. On failure, the agent gets the reason and 1 repair attempt.
- **Resumes where it stopped.** Each phase is a file. A provider limit halfway through loses no work, and `status` shows where the case stands.

## Usage

### In a session

```text
/debate <idea> [--panel design,brand,sec] [--rounds 1-3] [--no-research] [--no-factcheck]
```

The agent asks up to 6 intake questions and runs the phases. The case lives in `cases/<slug>/`. Running `/debate` again on an existing case resumes from the first phase that fails its gate.

### From the command line

Runs the whole protocol, from research to backlog, with each specialist in an isolated process. Use it for CI, batch reruns and any harness with a headless mode. Nothing has to be installed in the harness, it only needs to be logged in.

```sh
case=$(open-debate new "alert triage")
$EDITOR "$case/brief.md"
open-debate run "$case" --harness claude
```

opencode's free models refuse headless calls, so use a session with them.

To see where a case stands, or to redo part of it after editing an earlier artifact:

```sh
open-debate status "$case"              # each phase, the next one, stale outputs, calls and model time
open-debate run "$case" --from critique # archives that phase and the later ones in raw/archive, then redoes them
```

`raw/metrics.tsv` records time, attempts, outcome and tokens per call, and `status` shows the share of tokens per phase, so you can see which phase is worth cutting. See [efficiency](docs/efficiency.md). `Ctrl-C` ends the calls in flight, and a second run on the same case is refused.

### When a model runs out

A model that runs out of quota does not end the debate. The call moves to the next model in the chain, and the run fails only when none is left:

```sh
open-debate run "$case" --harness claude --fallback sonnet,codex:,gemini:
```

The chain is the agent's model, then `--fallback` (`MODEL_FALLBACK`) in order, where a bare model stays on the same harness and `harness:model` or `harness:` switches harness, then the `--mix` harnesses. A rate limit first waits with backoff; if it persists, the call moves on. A model out of quota is skipped for the rest of the run, so the next calls do not hit it again.

In a session, the orchestrator does the same. In opencode it asks `open-debate models next <case> <agent>` for the next model and repeats the call with it: first the `fallback=` list in `models.conf`, then the spare, the strong model on a paid profile, and then every other free model in the catalog. A model out of quota stays out for 6 hours. Only with no model left does the agent leave the panel; with fewer than 2 left, the debate stops and resumes where it stopped.

### Mixed panel

A debate gets better when opinions come from different model families. If you have access to more than one CLI, spread the panel across them:

```sh
open-debate run "$case" --harness claude --mix claude,codex,gemini
```

`--harness` runs research, judge and backlog, and `--mix` rotates the panel. See [per-agent routes](docs/harnesses.md#models).

### Commands

| Command | What it does |
|---|---|
| `init`, `update`, `uninstall` | Manage the installation; accept `--harness`, `--all`, `--project` and `--force` |
| `doctor [--live]` | Checks dependencies and installation; `--live` makes 1 real call |
| `harnesses` | Lists supported harnesses and the state of each |
| `models check\|apply\|free\|profile\|next` | Check, apply, list opencode models, set the cost profile or get the fallback for an agent |
| `new`, `run`, `status`, `panel` | Create, execute and inspect a case, and show the panel the brief triggers |
| `specs` | Create specs by hand, for use with `SPECS=0` |
| `gate`, `validate` | Run the gates for one phase or the whole case |
| `backlog`, `tile` | Export the backlog and the style tile |

`run` variables: `HARNESS`, `MODEL`, `MODEL_FALLBACK` (space-separated chain), `MIX`, `ROUTES`, `HARNESS_CMD`, `PANEL`, `FROM`, `RETRIES=2`, `TIMEOUT=600`, `BACKOFF=20`, `PARALLEL=6` (simultaneous calls, 0 for no limit), `MAX_CALLS=0` (hard limit per run, 0 for none), `MIN_LINES=5`, `RESEARCH=1`, `AGENDA=1`, `FACTCHECK=1`, `SPECS=1`, `REVIEW=1` (audit), `REPAIR=1`, `FRESH=0`.

## The protocol

```mermaid
flowchart TD
  A[Intake: brief and constitution] --> B[Research with parallel scouts]
  B --> B2[Agenda of disputed decisions]
  B2 --> C[Blind panel proposals]
  C --> D[Critiques with quotes]
  D --> E[Fact-check]
  E --> F[Rebuttal by vetoed agents]
  F --> G[Judge: matrix, ADRs, SDD, tokens]
  G --> G2[Independent audit of the SDD]
  G2 --> H[Per-feature specs]
  H --> I[Design and engineering tracks]
  I --> J[Backlog through launch]
```

| Phase | Agent | Gate |
|---|---|---|
| 0 intake | orchestrator | no empty brief field |
| 1 research | `debate-research`, `debate-scout` | 5+ distinct URLs, 5+ findings with a source, gaps section |
| 1b agenda | `debate-judge` | 3-8 decisions, 2+ options, owner on the panel, deciding driver |
| 2 proposal | panel | position on every agenda item, concession, only existing finding ids, length; plus role checks (C4, contrast, cost and IAM, rollback, STRIDE) |
| 3 critique | panel | 1-3 vetoes, none against itself, quote found in the cited file, concession |
| 4 fact-check | `debate-research` | non-blocking |
| 5 rebuttal | vetoed agents | non-blocking |
| 6 decision and SDD | `debate-judge` | weights total 100, matrix math checks out, every agenda item, veto and wrong claim ruled on, 3+ MADR ADRs, 3-6 specs, dissent; SDD with every ADR, tokens identical to the decision, no placeholders |
| 6 audit | `debate-auditor` | verdict; defects go back to the judge |
| 6d brandbook | `debate-brand`, only when on the panel | sections 1-8, tokens identical to the SDD with contrast, logo, voice, every key screen adapted |
| 7 specs | `debate-arch`, `debate-design` | EARS, cited ADRs exist, every user story has tasks |
| 8 backlog | `debate-ux`, `debate-arch`, `debate-pm` | 15+ items, covers specs, tasks, ADRs and polish, no cycles, capacity math checks out and the plan fits |

Details in [`protocol.md`](template/skills/architect-debate/references/protocol.md) and the [debate rules](template/skills/architect-debate/references/debate-rules.md).

## Customization

**Models.** On opencode, `models.conf` sets 1 model per agent, under a cost profile: `free` (default, free models only), `mixed` (a stronger model only on the seats that decide: orchestrator, judge, auditor, architecture) and `strong` (the stronger model everywhere, most tokens). Switch with `open-debate models profile mixed <provider/model>`, any id from `opencode models`. Free models come and go from the catalog: `update` swaps only the ones that left, to the `spare` and then a different free model per agent, so the panel does not pile on one rate limit. `open-debate models check` shows the state. On other harnesses, the agent inherits the session model, and you can pin another on its `model` line. Your choice survives `update`.

**Panel.** Three seats always sit: `debate-arch` (software architecture), `debate-ux` (UI and UX: usability goals, accessibility, the UI system and a review of every screen) and `debate-pm` (problem, metric, MVP cut, assumptions; it also writes the backlog). Research and judge always run outside the panel. The other seats join when the brief calls for them, up to 8 in total:

| Seat | Joins when the brief mentions |
|---|---|
| `debate-design` | screens: web, app, dashboard, portal. Decides what each screen holds; `debate-ux` reviews it in the critique phase |
| `debate-brand` | a public face: brand, B2C, consumers, store, launch. Art and creative director: brand identity and tokens, then `BRANDBOOK.md` adapting the designer's screens to the brand |
| `debate-sec` | personal, financial, health or regulated data |
| `debate-ai` | LLMs, RAG, agents, ML |
| `debate-data` | analytics, BI, ETL, pipelines, reports |
| `debate-mobile` | iOS, Android, offline, push |
| `debate-gcp`, `debate-aws`, `debate-k8s` | that cloud or a cluster |

`open-debate panel <case>` shows the panel the brief triggers and the word that triggered each seat; `--save design,brand` records a choice. `--panel design,brand` on `run` picks the seats by hand, and the base seats are added anyway. Triggers live in [`panel.conf`](template/skills/architect-debate/references/panel.conf), in English and Portuguese; the "Out of scope" line and negative answers ("none", "no", "nenhum") never trigger a seat. For another cloud, create a persona modeled on `debate-aws.md` and add it there.

**Principles.** `constitution.md` is copied into each case, and the intake can adjust it. Breaking a principle requires a written override.

## Limitations

- Artifacts are always in English: gates check English headings and keywords. Input can be in any language.
- Gates check form, traceability and numbers, not decision quality. Review the SDD and ADRs.
- Blindness has limits. From the command line, the agent's working directory holds no rival output, but this is not an OS sandbox. In a session, blindness comes from the prompt naming only the allowed files, plus each harness's subagent isolation.
- Cost and duration depend on the models. A full debate makes dozens of calls.
- On a harness with a single model, proposals tend to look alike. Use a mixed panel.
- Windows only through WSL.

## Development

```sh
npm test
```

The suite uses no network or LLM: fake CLIs in `test/stub/` walk the whole protocol, one per harness. See [CONTRIBUTING.md](CONTRIBUTING.md) and [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE)
