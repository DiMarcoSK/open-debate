# Changelog

## 0.4.0

A panel picked for the idea, with a fixed core and a design trio that hands work to each other.

### Added

- Base seats that always sit: `debate-arch`, `debate-ux` and `debate-pm`. `run` adds any that are missing from `--painel`.
- `debate-ux`, the UI and UX specialist: usability goals with numbers, WCAG 2.2 AA plan, interaction patterns, UI system and state copy. In the attack phase it reviews every screen of `debate-design` (`## Revisao debate-design`), and the judge treats each `ajustar` as binding.
- `debate-brand`, the art and creative director: brand platform, voice, logo, color and type as TOKENS. After the SDD, phase 6d writes `BRANDBOOK.md`, with the SDD tokens unchanged and every key screen adapted to the brand. The backlog then covers the new `#marca` tag.
- Optional seats `debate-ai`, `debate-data`, `debate-mobile` and `debate-aws`, each with its own method, format and role gate.
- Automatic panel: without `--painel`, the optional seats come from what the brief says (`references/painel.conf`). `open-debate painel <case>` shows the choice and why.
- `debate-pm` now proposes in the debate (problem, metric, MVP cut, premises, milestones) besides writing the backlog.

### Changed

- `debate-design` is now the software product designer: flows, screen inventory, wireframes and states. Art direction moved to `debate-brand`, and TOKENS belong to `debate-brand`, or to `debate-ux` without a brand seat.
- The design backlog track is written by `debate-ux`.
- Test suite about 4x faster (7 min to under 2 on a laptop): tests run in a parallel pool, installer hashes every file in a single process, and gates, style tile and stubs spawn far fewer processes.

## 0.3.0

Better planning, sharper specialists, gates that verify instead of trusting, and a faster run.

### Added

- Phase 1b, `agenda.md`: the judge lists the 3-8 decisions in dispute before any proposal. Every proposal takes a position on each one and the decision must close each one. `AGENDA=0` skips it. Older cases with proposals keep working.
- `debate-sec`, an optional panel seat for threat model, authorization, LGPD and PCI duties and audit trail. `run` suggests it when the brief declares regulated data.
- `debate-auditor`, an independent review of the SDD. It returns a verdict and a list of provable defects, and the judge corrects only those.
- `open-debate status <case>`: each phase, the next one, stale outputs, calls and model time.
- `open-debate run --from <phase>`: archives that phase and the later ones in `raw/arquivo` and redoes them.
- `raw/metricas.tsv`: time, attempts and outcome per call, with a summary at the end of the run.
- `PARALELO` limits simultaneous calls and `MAX_CHAMADAS` limits calls per run.

### Changed

- Gates now verify what they used to take on trust. Attack quotes must exist in the cited file. Finding ids must exist in `research.md`. Weights must total 100, and each matrix total is recomputed. Every veto and every claim the fact-check marked wrong needs a ruling. The SDD must list every ADR and carry the decision's tokens unchanged. Specs must use EARS, cite existing ADRs and have tasks for every user story. The backlog must cover every spec task and fit the capacity, which the gate recomputes. Each output has a line ceiling, with 50% tolerance.
- From the command line, proposals and attacks run in a working directory holding only what the agent may read, so parallel calls and repairs cannot read a rival's output.
- `debate-gcp` and `debate-k8s` were rewritten with their own method and format: load and quota math for GCP, a break-even verdict on running a cluster at all for Kubernetes. Every specialist now states what it owns and what it does not.
- Rebuttal runs only for agents that received a veto, which saves those calls.
- The audit replaces the judge's full rewrite of the SDD. A clean SDD is no longer re-emitted.
- On Claude Code, `debate-scout` uses Haiku: scouts answer one factual question each, and research spends most of its time on them.
- Installing is about 2 times faster: files without placeholders are copied in bulk, and hashing no longer starts a perl process per file on macOS.
- The test suite runs the harness matrix in parallel.

### Fixed

- The capacity formula left out days per week: `devs x weeks x 0.7` was reported as days. It is now `devs x weeks x 5 x 0.7`.
- From the command line, agents tried to write the file themselves, got a permission denial and answered with a request for access, which became the output. The task now says the final answer is the file's content.
- A rate limit was treated as a login failure, so a 429 ended the run. It now waits with exponential backoff and jitter. Login and quota failures still stop at once.
- Words like "rate limit" inside an agent's answer could be misread as a provider error. Only the end of the failed output is inspected now.
- `Ctrl-C` and `TERM` waited for the running call to finish and left parallel calls running. They now end every call in flight.
- Two runs on the same case overwrote each other. The second is now refused, and a lock left by a dead run is reclaimed.
- Banned visuals were only caught by `validate`, at the end. They now fail at the phase, where they get a repair.

### Migration

Run `open-debate update`. Existing cases resume normally: without `agenda.md`, a case with proposals skips the agenda. Backlog gates are stricter, so an older `BACKLOG.md` may need the new `Capacidade` line. The `fase revisao` task is now `fase correcao`.

## 0.2.0

open-debate no longer depends on opencode.

### Added

- Support for Claude Code, Codex CLI, Cursor, Gemini CLI, Antigravity CLI, oh-my-pi, Pi, DeepSeek Harness, Factory Droid, GitHub Copilot CLI, Qwen Code and Cline, in addition to opencode.
- `HARNESS=custom` with `HARNESS_CMD`: any CLI with a headless mode, with no code changes.
- Mixed panels across harnesses (`--mesa claude,codex,gemini`) and per-agent routes (`ROTAS`).
- One-line installer (`install.sh`) and automatic harness detection in `init`.
- `open-debate harnesses` and `open-debate doctor --live`, which makes 1 real call through the adapter.
- `open-debate run` reaches the backlog on its own: phase 7 generates the specs from the `decision.md` index, with a gate and repair. `SPECS=0` keeps the manual flow.

### Changed

- Canonical personas live in `template/skills/architect-debate/personas/` and are translated at install time.
- `init` now uses the detected harnesses. `update`, `uninstall` and `doctor` act on what is installed, or on `--harness`.
- Outside opencode, `run` is read-only whenever the harness offers that mode.
- Documentation and commits are now in English. Prompts, templates and gates remain in Portuguese.

### Fixed

- The backlog gate read the first `{...}` on a line as metadata, rejecting items with routes like `/v1/alerts/{id}`.
- Harness login failures and timeouts now show their reason in `summary.log`.
- Headless calls close stdin: CLIs waiting for piped input used to hang in scripts.

### Migration

A 0.1 install on opencode stays valid: run `open-debate update`.

## 0.1.0

First release as a product, extracted from opencode's `architect-debate` skill.

### Added

- `open-debate` CLI: `init`, `update`, `uninstall`, `doctor`, `models`, `new`, `run`, `specs`, `gate`, `validate`, `backlog`, `tile`.
- Global or per-project installation, with a manifest: edits are not overwritten and `--force` makes a backup.
- Suite with no network or LLM, with a fake `opencode` walking the whole protocol.

### Changed

- Script paths are resolved at install time. `modelos.sh` finds the agents from its own skill.
- `debate.sh` requires `perl` explicitly.

### Fixed

- Orchestrator bash permission: the `*architect-debate/scripts/*` pattern matched any command containing that text. It now allows only the exact scripts path.
- ADR gates rejected accented `Opções`, `Decisão` and `Confirmação`.
- Accented `## Pós-lançamento` was not recognized in the backlog: items fell into the previous phase.
