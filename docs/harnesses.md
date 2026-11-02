# Harnesses

open-debate has 2 sides, and each harness connects to them in its own way.

- **Installation:** `open-debate init` translates the canonical personas into the harness's native format.
- **Headless execution:** `open-debate run` calls the harness as a process, with the persona inside the prompt. It does not depend on the installation.

## Modes

| Mode | How the panel runs | Harnesses |
|---|---|---|
| `native` | The harness's own agents, command and permissions, with one model per agent | opencode |
| `subagents` | The `debate` skill orchestrates from the main session and delegates to installed agents | Claude Code, Codex, Cursor, Gemini, oh-my-pi, Droid, Copilot, Qwen |
| `cli` | The `debate` skill runs the intake and launches each specialist as a headless process | Antigravity, Pi, dsh, Cline |

`cli` mode exists because not every harness has file-based agents. Pi has no subagents. dsh defines presets per profile, with no agent files. Antigravity has agents, but its docs publish only some tool names and warn that a wrong name can hang the subagent, so it runs headless. Isolated processes keep proposals blind in all these cases.

Orchestration always stays in the main session, because on several harnesses a subagent cannot start another subagent. For the same reason, outside opencode the specialists get their own web tools and use `debate-scout` only where the harness allows it.

## Matrix

| ID | Harness | Skills (user) | Agents (user) | Invocation | Headless | Evidence |
|---|---|---|---|---|---|---|
| `opencode` | opencode | `~/.config/opencode/skills` | `~/.config/opencode/agents` | `/debate` | `opencode run --format json` | installation tested; headless needs a paid model |
| `claude` | Claude Code | `~/.claude/skills` | `~/.claude/agents` | `/debate` | `claude -p --output-format json` | tested for real, including a reduced debate |
| `omp` | oh-my-pi | `~/.omp/agent/skills` | `~/.omp/agent/agents` | `/skill:debate` | `omp -p --no-session` | tested for real |
| `codex` | Codex CLI | `~/.agents/skills` | `~/.codex/agents/*.toml` | `$debate` | `codex exec -o <file>` | docs |
| `cursor` | Cursor | `~/.cursor/skills` | `~/.cursor/agents` | `/debate` | `cursor-agent -p --output-format json` | docs |
| `gemini` | Gemini CLI | `~/.gemini/skills` | `~/.gemini/agents` | `/debate` | `gemini -p --output-format json` | docs |
| `agy` | Antigravity CLI | `~/.gemini/config/skills` | none installed | `/debate` | `agy -p --output-format json` | docs |
| `pi` | Pi | `~/.pi/agent/skills` | no subagents | `/skill:debate` | `pi -p --no-session` | docs |
| `dsh` | DeepSeek Harness | `$DSH_HOME/skills` | no agent files | `/debate` | `dsh --profile headless` | docs |
| `droid` | Factory Droid | `~/.factory/skills` | `~/.factory/droids` | `/debate` | `droid exec -o json` | docs |
| `copilot` | GitHub Copilot CLI | `~/.copilot/skills` | `~/.copilot/agents/*.agent.md` | `/debate` | `copilot -p -s` | docs |
| `qwen` | Qwen Code | `~/.qwen/skills` | `~/.qwen/agents` | `/debate` | `qwen -p -o json` | docs |
| `cline` | Cline | `~/.cline/skills` | none installed | `/debate` | `cline -p` | CLI flags; real call pending login |

**Tested for real** means the adapter made a real call to the CLI and the harness saw the agents. On opencode, free models refuse headless calls, so a real call needs a paid model. **Docs** means the adapter follows the official documentation and passes the suite against a fake CLI that imitates the output format, but has not been called for real yet. Check yours with:

```sh
open-debate doctor --live --harness codex
```

The command makes 1 small call and proves login, flags and text extraction. Please open an issue if it fails: these CLIs change formats quickly.

## What each harness restricts

Only opencode and Claude Code enforce a per-agent tool list in this project. On the others, the restriction comes from the persona prompt and the harness's own approvals.

In `open-debate run`, calls are read-only whenever the harness offers that mode, and `debate.sh` writes the files from the returned text. No adapter turns on automatic approval for writes or shell.

## Models

On opencode, `modelos.conf` sets 1 model per agent. Elsewhere, the agent inherits the session model. To pin a model, edit the agent's `model` line, or uncomment it where it ships commented out (Codex, Copilot, oh-my-pi). Your choice survives `update`.

On a harness with a single model, proposals tend to look alike. For different model families, use a mixed panel:

```sh
open-debate run <case> --harness claude --mesa claude,codex,gemini
```

`--mesa` rotates the panel across the harnesses. `--harness` sets who runs research, judge and backlog. For full control, use routes:

```sh
ROTAS="debate-arch=claude debate-design=codex:<model>" open-debate run <case> --harness claude
```

On Claude Code, `debate-scout` is installed with `model: haiku` and the other agents inherit the session model. Change that line to pick another one; `update` keeps your choice.

Parallel calls hit provider limits together. If a run keeps waiting on limits, lower `PARALELO`.

## Other CLIs

Any CLI with a headless mode works with no code changes. The command receives `$PROMPT` and `$MODEL`, and whatever it prints becomes the answer:

```sh
HARNESS=custom HARNESS_CMD='amp -x "$PROMPT"' open-debate run <case>
```

For full support, follow [Adding a harness](../CONTRIBUTING.md#adding-a-harness).

## Notes

- `gemini` and `agy` share `~/.gemini`. Antigravity CLI also reads `~/.gemini/skills`, so installing both shows the skill twice there.
- Cursor reads `~/.claude/agents` and `~/.codex/agents`, and oh-my-pi reads `~/.claude/commands`. With several installed, each one prefers its own directory.
- Gemini CLI is being replaced by Antigravity CLI for free and Google One accounts.
- dsh is in developer preview, and its docs warn of breaking changes. Its model comes from the `headless` profile configuration, so `MODEL` does not apply.
- Cursor may require a real terminal in automation, according to third-party reports. `TIMEOUT` ends the call if that happens.
