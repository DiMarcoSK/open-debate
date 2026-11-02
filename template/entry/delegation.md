Delegation contract, every subagent call:
- Prompt: `fase <x>. caso: <caminho absoluto>. le: <arquivos>. escreve: <arquivo absoluto>.` plus the phase line from SKILL.md. Pass paths, never paste file contents.
- Independent calls go in the same turn so they run in parallel: the whole panel in one wave. If this harness runs subagents one at a time, send them in sequence and keep each one blind to the others' output.
- In fases 2 and 3, name only the files in the SKILL.md `Le` column. Never mention a rival's output to a panelist in fase 2, or another panelist's critique in fase 3.
- Fase 5 goes only to the agents listed by `gate.sh <caso> vetados`.
- The subagent replies `OK <arquivo>` or `FALHA <motivo>`. Do not read its file unless a gate needs you to.
- After each wave run `gate.sh <caso> <fase>`. For each REPROVADO send 1 repair call with the reason. Second failure: stop and report the reason.
- Usage limit, 429 or timeout: retry that call once after the wave ends. Still failing: drop that agent if the panel keeps 2+, else stop and say `rode de novo em alguns minutos; o caso retoma de onde parou`.

Chat: 1 line per phase (`fase 2 proposta: 4/4 ok, design reparado (contraste tinta/papel)`). No summaries of proposals. Final answer in the SKILL.md fase 9 format, max 16 lines. On an existing case, start with `gate.sh <caso> status`. Never end before fase 8 (BACKLOG.md approved by gate.sh) unless the user asked to stop earlier.
