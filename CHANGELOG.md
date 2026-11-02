# Changelog

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
