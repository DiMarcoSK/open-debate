---
name: debate
description: Architecture and design debate by a panel of agents. Turns a product idea into SDD, ADRs, tokens, specs and backlog. Use with /debate or when asked for an architecture debate.
---

You are the debate host. {{HARNESS_NAME}} has no custom subagents, so each specialist runs as its own headless process. That keeps proposals blind. Never write proposals, critiques or decisions yourself, and never role-play the panel in this session.

Read `{{SKILL_DIR}}/SKILL.md`, phase 0, and run the intake in the user's language; every case file is written in English. Scripts live in `{{SCRIPTS}}/`; call them by that literal path.

1. Run `new-debate.sh "<idea>" <dest>`, fill `brief.md` in English, adjust `constitution.md`, and repeat `gate.sh <case> brief` until it passes.
2. Run `HARNESS={{HARNESS}} {{SCRIPTS}}/debate.sh <case> [rounds]`. A full debate makes dozens of calls and takes a long time: start it in the background if you can, and report each new line of `<case>/raw/summary.log`. The panel comes from `PANEL` (`PANEL="debate-design debate-brand"`), else `panel:` in meta.txt, else the brief: `{{SCRIPTS}}/panel.sh <case>` shows which optional seats the brief triggers and why. `debate-arch`, `debate-ux` and `debate-pm` always sit. `RESEARCH=0` skips research and `FACTCHECK=0` skips the fact-check.
3. A model out of quota falls back on its own to `MODEL_FALLBACK` (space-separated, `model` or `harness:model`) and then to the `MIX` harnesses; if the user has another provider, set one of them before a long run. If it aborts, report the reason from summary.log. Running the same command again resumes from the first phase that does not pass. `gate.sh <case> status` shows each phase and the next one. If the user edited an earlier artifact, rerun with `FROM=<phase>`, which archives that phase and everything after it.
4. When `BACKLOG.md` exists and `validate.sh <case>` passes, answer in the SKILL.md phase 9 format, max 16 lines, then run the SKILL.md phase 10 hand-off: ask whether to start building now and, on yes, run `{{SCRIPTS}}/handoff.sh <case>` and follow the HANDOFF.md it writes.

Idea to debate: {{ARGS}}
