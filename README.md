# open-debate

[![CI](https://github.com/FelipeDiMarco/open-debate/actions/workflows/ci.yml/badge.svg)](https://github.com/FelipeDiMarco/open-debate/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

From a raw idea to a specified product, through a debate between agents, in the harness you already use.

You describe the idea. A panel of specialists researches it, proposes blindly, attacks each other's proposals citing file and line, goes through a fact-check, and a judge decides with a weighted matrix. The result is a set of artifacts a team can execute, not a chat transcript.

```text
you:  /debate alert triage platform for a small SOC

fase 1 pesquisa: ok, 18 achados
fase 2 proposta: 4/4 ok, design reparado (contraste tinta/papel)
fase 3 ataque: 4/4 ok
fase 6 decisao: 5 ADRs, 4 specs
fase 8 backlog: 42 itens, 61 dias, caminho critico B01 -> B07 -> B19 -> B33
```

The numbers above illustrate the output format. Agents and artifacts currently work in Brazilian Portuguese, see [Limitations](#limitations).

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/FelipeDiMarco/open-debate/main/install.sh | sh
```

The installer puts the `open-debate` command in `~/.local/bin`, finds the harnesses on your machine and installs `/debate` in each one. Running it again updates. It requires macOS or Linux, `jq` and `perl`. On Windows, use WSL.

With Node, without a global install:

```sh
npx github:FelipeDiMarco/open-debate init
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
| `decision.md`, `adr/` | Weighted matrix and MADR 4.0 ADRs, with rejected alternatives and dissent |
| `SDD.md` | Lean arc42 design doc, with C4 in mermaid, capacity, failures and STRIDE |
| `style-tile.html`, `tokens.json`, `tokens.css` | Visual direction with measured WCAG 2.2 contrast, W3C DTCG tokens |
| `specs/` | `spec.md`, `plan.md` and `tasks.md` per feature, GitHub Spec Kit style, with EARS requirements |
| `BACKLOG.md`, `backlog.csv`, `backlog.json`, `backlog-gh.sh` | Backlog through launch, with dependencies, estimates and critical path |

## Why it works

- **Blind proposals.** Each specialist writes before seeing the others.
- **Attacks need evidence.** A veto requires a literal quote, a problem with a number and a concrete replacement. Criticism without a concession is discarded.
- **A number without a source is an opinion.** Every number cites `research.md` or shows the math. Whatever the fact-check marks wrong scores zero in the matrix.
- **Deterministic gates.** Scripts, not an LLM, check each phase: computed contrast, complete ADRs, dependencies without cycles. On failure, the agent gets the reason and 1 repair attempt.
- **Resumes where it stopped.** Each phase is a file. A provider limit halfway through loses no work.

## Usage

### In a session

```text
/debate <idea> [--painel arch,design,gcp,k8s] [--rounds 1-3] [--sem-pesquisa] [--sem-factcheck]
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

### Mixed panel

A debate gets better when opinions come from different model families. If you have access to more than one CLI, spread the panel across them:

```sh
open-debate run "$case" --harness claude --mesa claude,codex,gemini
```

`--harness` runs research, judge and backlog, and `--mesa` rotates the panel. See [per-agent routes](docs/harnesses.md#models).

### Commands

| Command | What it does |
|---|---|
| `init`, `update`, `uninstall` | Manage the installation; accept `--harness`, `--all`, `--project` and `--force` |
| `doctor [--live]` | Checks dependencies and installation; `--live` makes 1 real call |
| `harnesses` | Lists supported harnesses and the state of each |
| `models check\|apply\|free` | Check, apply or list opencode models |
| `new`, `run` | Create and execute a case |
| `specs` | Create specs by hand, for use with `SPECS=0` |
| `gate`, `validate` | Run the gates for one phase or the whole case |
| `backlog`, `tile` | Export the backlog and the style tile |

`run` variables: `HARNESS`, `MODEL`, `MODEL_FALLBACK`, `MESA`, `ROTAS`, `HARNESS_CMD`, `PAINEL`, `RETRIES=2`, `TIMEOUT=600`, `MIN_LINES=5`, `RESEARCH=1`, `FACTCHECK=1`, `SPECS=1`, `REVIEW=1`, `REPAIR=1`, `FRESH=0`.

## The protocol

```mermaid
flowchart TD
  A[Intake: brief and constitution] --> B[Research with parallel scouts]
  B --> C[Blind panel proposals]
  C --> D[Attacks with citations]
  D --> E[Fact-check]
  E --> F[Rebuttal]
  F --> G[Judge: matrix, ADRs, SDD, tokens]
  G --> H[Per-feature specs]
  H --> I[Design and engineering tracks]
  I --> J[Backlog through launch]
```

| Phase | Agent | Gate |
|---|---|---|
| 0 intake | orchestrator | no empty brief field |
| 1 research | `debate-research`, `debate-scout` | 5+ distinct URLs, gaps section |
| 2 proposal | panel | concession; C4 and ADRs (arch); contrast and states (design) |
| 3 attack | panel | veto, literal quote, concession |
| 4 fact-check | `debate-research` | non-blocking |
| 5 rebuttal | panel | non-blocking |
| 6 decision and SDD | `debate-judge` | 3+ MADR ADRs, 3-6 specs, dissent, SDD without placeholders |
| 7 specs | `debate-arch`, `debate-design` | `validate` passes |
| 8 backlog | `debate-design`, `debate-arch`, `debate-pm` | 15+ items, covers specs, ADRs and polish, no cycles |

Details in [`protocol.md`](template/skills/architect-debate/references/protocol.md) and the [debate rules](template/skills/architect-debate/references/regras-debate.md).

## Customization

**Models.** On opencode, `modelos.conf` sets 1 model per agent. The defaults are free models, which come and go from the catalog: run `open-debate models check` before a long debate. On other harnesses, the agent inherits the session model, and you can pin another on its `model` line. Your choice survives `update`.

**Panel.** The default panel is `arch`, `design`, `gcp` and `k8s`, so the infrastructure discussion assumes Google Cloud. For another cloud, create a `debate-aws.md` persona modeled on `debate-gcp.md`, in `template/skills/architect-debate/personas/`, and pass `--painel arch,design,aws`.

**Principles.** `constitution.md` is copied into each case, and the intake can adjust it. Breaking a principle requires a written override.

## Limitations

- Templates, prompts and gates are in Portuguese, so artifacts come out in pt-BR.
- Gates check form and numbers, not decision quality. Review the SDD and ADRs.
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
