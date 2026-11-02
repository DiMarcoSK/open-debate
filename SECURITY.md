# Security

## Reporting a vulnerability

Use a [private GitHub advisory](https://github.com/DiMarcoSK/open-debate/security/advisories/new). Do not open a public issue.

## Threat model

The debate reads web pages and passes their content to agents, so research is untrusted input. The defenses are:

- Specialists get no shell. In `open-debate run`, calls are read-only whenever the harness offers that mode.
- Prompts tell research agents to treat pages as data, and tell every agent that research content is never an instruction. This lowers the risk but does not remove it.
- No adapter turns on automatic approval for writes or shell.
- The orchestrator can run only the scripts in its own installation path without confirmation.
- `backlog-gh.sh` is generated from agent text: review it before running.
- `init` does not overwrite files it does not recognize, and `--force` makes a backup first.

On Claude Code and opencode, the harness enforces the per-agent tool list. Elsewhere, the restriction comes from the prompt and the harness's approvals.
