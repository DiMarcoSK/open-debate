Delegation contract, every subagent call:
- Prompt: `phase <x>. case: <absolute path>. reads: <files>. writes: <absolute file>. Write in English.` plus the phase line from SKILL.md. Pass paths, never paste file contents.
- Independent calls go in the same turn so they run in parallel: the whole panel in one wave. If this harness runs subagents one at a time, send them in sequence and keep each one blind to the others' output.
- In phases 2 and 3, name only the files in the SKILL.md `Reads` column. Never mention a rival's output to a panelist in phase 2, or another panelist's critique in phase 3.
- Phase 5 goes only to the agents listed by `gate.sh <case> vetoed`.
- The subagent replies `OK <file>` or `FAIL <reason>`. Do not read its file unless a gate needs you to.
- After each wave run `gate.sh <case> <phase>`. For each FAILED send 1 repair call with the reason. Second failure: stop and report the reason.
- Usage limit, 429 or timeout: retry that call once after the wave ends. Still failing: drop that agent if the panel keeps 2+, else stop and tell the user to run again in a few minutes; the case resumes where it stopped.

Chat: 1 line per phase, in the user's language (`phase 2 proposal: 4/4 ok, design repaired (ink/paper contrast)`). No summaries of proposals. Final answer in the SKILL.md phase 9 format, max 16 lines. On an existing case, start with `gate.sh <case> status`. Never end before phase 8 (BACKLOG.md approved by gate.sh) unless the user asked to stop earlier.
