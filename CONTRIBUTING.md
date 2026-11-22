# Contributing

## Structure

```text
install.sh        one-line installer
bin/open-debate   CLI: dispatches commands
lib/harnesses.sh  catalog: where and how each harness installs
lib/render.sh     translates personas into each harness's format
lib/install.sh    init, update, uninstall, doctor, models
template/
  commands/       1 opencode command per command (debate.md, opd-brainstorm.md)
  entry/          commands.conf, the command registry, and 1 folder per command with its skill per mode
  skills/architect-debate/
    SKILL.md      session mode protocol
    personas/     specialists, the canonical source (debate-specialist takes the seats the agenda makes, from references/specialist-template.md)
    references/   templates and rules copied into each case
    scripts/      gates and CLI mode; harness.sh is the headless adapter, status.sh reads a case
test/             suite, fixtures and fake CLIs
docs/harnesses.md harness matrix and the evidence for each
```

`{{SCRIPTS}}`, `{{SCRIPTS_ABS}}`, `{{SKILL_DIR}}`, `{{HARNESS}}`, `{{HARNESS_NAME}}`, `{{DELEGATE}}`, `{{DELEGATION}}`, `{{FRONTMATTER}}` and `{{ARGS}}` in the templates are resolved at install time.

## Adding a command

A command (`/debate`, `/opd-brainstorm`) is installed in every harness from 1 registry line and 3 files:

1. `template/entry/commands.conf`: `name|argument hint|description`. The installer, `ready in`, `doctor` and `harnesses` read it.
2. `template/entry/<name>/subagents.md` and `template/entry/<name>/cli.md`: the skill for harnesses with subagents and for headless harnesses, with `name: <name>` and `{{FRONTMATTER}}` at the end of the description line (Claude Code gets its `allowed-tools` there). `{{ARGS}}` becomes what the user typed; a `{{DELEGATION}}` line pulls in `entry/delegation.md`.
3. `template/commands/<name>.md`: the opencode command, with the `agent:` that runs it.
4. Keep the protocol in `skills/architect-debate/` (`SKILL.md` or a file in `references/`) and point the entries to it: 1 source, the entries stay thin. A new orchestrator persona with `mode: primary` becomes an opencode agent only; any other persona becomes an agent everywhere.

`comandos_instalados` in `test/run.sh` checks every registered command in every harness; a command with a CLI subcommand also gets a case in `bin/open-debate`.

## Adding a harness

1. `lib/harnesses.sh`: add the ID to `HARNESSES` and a block to `h_load`. Without file-based agents, use `H_MODE="cli"`.
2. `lib/render.sh`: if the agent format is new, handle it in `render_agent` and `agent_file`.
3. `scripts/harness.sh`: add the headless call to `h_run`, the extraction to `h_texto` and the binary to `h_binario`. Use read-only mode and never turn on automatic approval.
4. `test/stub/harness`: imitate the CLI's real output. Add the ID to the lists in `test/run.sh`.
5. `docs/harnesses.md`: add the matrix row with the real evidence. Only write "tested for real" after `open-debate doctor --live` passes.

## Rules

- Everything is in English: commits, docs, prompts, templates, gate keywords and CLI messages. User input can be in any language; panel triggers in `panel.conf` list English and Portuguese words.
- POSIX shell, with no dependencies beyond `jq`, `awk` and `perl`. Linux `sh` is dash and awk may be mawk: no bashisms or gawkisms.
- Gates are deterministic. If a rule matters, it becomes a check in `gates.sh`, not just a prompt instruction.
- A gate bug gets a fixture and a test in `test/run.sh`.
- In `test/run.sh`, use `nao` instead of `! cmd`, and 1 command per line: `set -e` ignores the other forms.
- Tests never call a real harness: the suite's `PATH` is isolated on purpose.
- Never include a local path, private provider or key in `template/`. The suite fails.

## Format changes

Agents and `gates.sh` are a contract: gates read words and formats from the templates (`Concessao`, `### Veto contra`, `Dn:`, `Capacidade:`, the `Total` column). When changing a template, update the gate, the fixture and the agent together. `citacoes.awk`, `placar.awk` and `backlog.awk` redo what agents claim; a new claim that can be recomputed belongs there.

## Adding a specialist

A domain that only some ideas need (payments, clinical workflow, game economy) does not need a catalog seat: the judge makes a case seat for it in the agenda, from `references/specialist-template.md`. Add a catalog seat only for a domain that comes up often and needs its own role checks.

1. Add `personas/debate-<x>.md` with the same frontmatter. State what it owns, what it does not own, its method and its proposal format, with `Posicoes` first.
2. Add its line to `models.conf`, to `references/panel.conf` (`base` or `optional` with its trigger words), and to the specialist list in `template/entry/subagents.md`.
3. Add its role checks and line ceiling to `gates.sh`, a `proposal-<x>.md` fixture, and the first words of its `You are the ...` line to `test/stub/harness`.

## Tests

```sh
npm test
open-debate doctor --live    # 1 real call on each installed harness
```

Tests register with `t` (runs in order, for anything that installs or changes the installation, in its own HOME) or `tp` (runs in a parallel pool of `JOBS`, default the CPU count, with its own `WORK` and `STUB_STATE`). Prefer `tp`. Process count drives the suite time, so gates and stubs favor 1 `awk` over a loop of `grep`. `TEMPOS=<file> npm test` records the seconds per test. CI runs on Ubuntu and macOS, with shellcheck. A prompt change can only be validated by a real debate: record the model used and the result in the PR.
