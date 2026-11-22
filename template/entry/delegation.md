Delegation contract, every subagent call:
- Prompt: `phase <x>. case: <absolute path>. reads: <files>. writes: <absolute file>. Write in English.` plus the phase line from the protocol. Pass paths, never paste file contents. The subagent opens every file of `reads:` in 1 turn, in parallel, and each once (debate-rules.md, Execution).
- Independent calls go in the same turn so they run in parallel: the whole panel, or every lens, in one wave. If this harness runs subagents one at a time, send them in sequence and keep each one blind to the others' output.
- The subagent replies `OK <file>` or `FAIL <reason>`. Do not read its file unless a gate needs you to.
- After each wave run `gate.sh <case> <phase>`. For each FAILED send 1 repair call with the reason. Second failure: stop and report the reason.
- Model fallback, never a silent drop. Quota or usage limit (`Free usage limit`, `FreeTierError`, `usage limit`, `quota`, 402, 403) or a 429 that persists: in opencode run `{{SCRIPTS}}/models.sh next <case> <agent> [model that failed]`, which prints the next available model, and send the same call again with that model in the subagent tool's `model` parameter (`provider/model`). Fails again: run it again with that model, until the call works or it prints `none left`. In other harnesses, if the delegation tool takes a model, retry with a different one; otherwise retry once after the wave. Timeout: retry once.
- Only when no model is left: drop that agent if the wave keeps 2+, else stop and tell the user the limit and that running again after it resets resumes where it stopped. Name the fallbacks used in the phase line (`phase 2 proposal: 4/4 ok, arch on opencode/big-pickle after quota`).

In /debate (SKILL.md):
- Case seat (`debate-x-<slug>`, seated by the agenda): call the subagent `debate-specialist` and add `seat: debate-x-<slug>. persona: <case>/personas/debate-x-<slug>.md.` to the prompt. `writes:`, gates and `vetoed` use the seat name; for `models.sh next` the agent is `debate-specialist`.
- In phases 2 and 3, name only the files in the SKILL.md `Reads` column. Never mention a rival's output to a panelist in phase 2, or another panelist's critique in phase 3.
- Phase 5 goes only to the agents listed by `gate.sh <case> vetoed`.
- Chat: 1 line per phase, in the user's language (`phase 2 proposal: 4/4 ok, design repaired (ink/paper contrast)`). No summaries of proposals. Final answer in the SKILL.md phase 9 format, max 16 lines. On an existing case, start with `gate.sh <case> status`. Never end before phase 8 (BACKLOG.md, completeness and cards approved by gate.sh) unless the user asked to stop earlier. After the phase 9 answer, run phase 9b (VERDICT.md and the teach-back) and the phase 10 hand-off.
- Build appeal (HANDOFF.md runs `appeal.sh`): debate-arch and debate-pm `phase appeal` in the same turn, then debate-judge `phase ruling`, each with its gate, then `appeal.sh <case> apply`.

In /opd-brainstorm (references/brainstorm.md):
- `case:` is the brainstorm folder. An ideator's prompt carries its lens task line from `brainstorm.sh lenses` literally and `reads: theme.md, ground.md`: never another lens, ideas/ or a rival's output.
- Chat: 1 line per step, in the user's language. The brainstorm ends at the seed; the debate starts only when the user asks for it.
