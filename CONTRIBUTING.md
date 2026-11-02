# Contributing

## Structure

```text
install.sh        one-line installer
bin/open-debate   CLI: dispatches commands
lib/harnesses.sh  catalog: where and how each harness installs
lib/render.sh     translates personas into each harness's format
lib/install.sh    init, update, uninstall, doctor, models
template/
  commands/       opencode's /debate command
  entry/          orchestrator for the other harnesses, per mode
  skills/architect-debate/
    SKILL.md      session mode protocol
    personas/     specialists, the canonical source
    references/   templates and rules copied into each case
    scripts/      gates and CLI mode; harness.sh is the headless adapter
test/             suite, fixtures and fake CLIs
docs/harnesses.md harness matrix and the evidence for each
```

`{{SCRIPTS}}`, `{{SCRIPTS_ABS}}`, `{{SKILL_DIR}}`, `{{HARNESS}}`, `{{HARNESS_NAME}}`, `{{DELEGATE}}` and `{{DELEGATION}}` in the templates are resolved at install time.

## Adding a harness

1. `lib/harnesses.sh`: add the ID to `HARNESSES` and a block to `h_load`. Without file-based agents, use `H_MODE="cli"`.
2. `lib/render.sh`: if the agent format is new, handle it in `render_agent` and `agent_file`.
3. `scripts/harness.sh`: add the headless call to `h_run`, the extraction to `h_texto` and the binary to `h_binario`. Use read-only mode and never turn on automatic approval.
4. `test/stub/harness`: imitate the CLI's real output. Add the ID to the lists in `test/run.sh`.
5. `docs/harnesses.md`: add the matrix row with the real evidence. Only write "tested for real" after `open-debate doctor --live` passes.

## Rules

- Commits, documentation and the README are in English. Prompts, templates, gates and CLI messages are in Portuguese.
- POSIX shell, with no dependencies beyond `jq`, `awk` and `perl`. Linux `sh` is dash and awk may be mawk: no bashisms or gawkisms.
- Gates are deterministic. If a rule matters, it becomes a check in `gates.sh`, not just a prompt instruction.
- A gate bug gets a fixture and a test in `test/run.sh`.
- In `test/run.sh`, use `nao` instead of `! cmd`, and 1 command per line: `set -e` ignores the other forms.
- Tests never call a real harness: the suite's `PATH` is isolated on purpose.
- Never include a local path, private provider or key in `template/`. The suite fails.

## Format changes

Agents and `gates.sh` are a contract: gates read words from the templates (`Concessao`, `Veto`, `Lacunas`). When changing a template, update the gate, the fixture and the agent together.

## Tests

```sh
npm test
open-debate doctor --live    # 1 real call on each installed harness
```

CI runs on Ubuntu and macOS, with shellcheck. A prompt change can only be validated by a real debate: record the model used and the result in the PR.
