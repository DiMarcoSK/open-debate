# Debate protocol - state and gates

## State

```text
cases/<slug>/
  idea.md  meta.txt  brief.md  constitution.md
  debate-rules.md  visual-contract.md  *-template.md
  research.md                  phase 1, debate-research
  agenda.md                    phase 1b, debate-judge: contested decisions
  proposals/<agent>.md         phase 2
  critiques/<agent>.md         phase 3
  research-check.md            phase 4, fact-check
  proposals/<agent>-r2.md      phase 5
  decision.md  adr/NNNN-*.md   phase 6
  SDD.md  audit.md             phase 6, debate-judge and debate-auditor
  style-tile.html tokens.json tokens.css   generated from the SDD TOKENS (DTCG)
  BRANDBOOK.md                 phase 6d, debate-brand (only with it on the panel)
  specs/<nn>-<slug>/{spec,plan,tasks}.md  checklists/requirements-<nn>-<slug>.md   phase 7
  backlog/design.md  backlog/eng.md   phase 8, drafts per track
  BACKLOG.md  backlog.csv  backlog.json  backlog-gh.sh   phase 8, debate-pm + export
  backlog/audit.md             phase 8b, debate-auditor: completeness from an empty repo to an operated product
  backlog/cards/<nn>.md  BACKLOG-DETAILED.md   phase 8c, debate-arch: 1 card per item, what and how
  raw/   raw json, stderr, summary.log, metrics.tsv, archive/ (outputs replaced by --from)
```

## Gates (gate.sh in session mode, debate.sh in the CLI; fail = 1 repair with the reason, fail again = stop)

| Phase | Gate |
|---|---|
| 0 intake | validate.sh: brief with no empty field |
| 1 research | >= 5 distinct URLs, >= 5 Rn findings with a URL or `unverified`, Gaps section |
| 1b agenda | 3-8 Dn decisions, 2+ options, owner on the panel, driver |
| 2 proposal | concession, position on each Dn, existing Rn ids, line cap; arch: mermaid, ADR, capacity; ux: WCAG, heuristics, usability test, states, banned list, contrast without debate-brand; pm: MVP, metric, assumptions; design: flows, screen inventory, states, banned list; brand: contrast, banned list, voice, logo, platform; gcp and aws: cost, IAM, budget; k8s: cost, rollback; sec: STRIDE, authorization, audit; ai: eval, fallback, cost; data: pipeline, quality, retention, cost; mobile: offline, store, minimum version |
| 3 critique | 1-3 vetoes, none against self, quote found literally in the cited file, existing Rn ids, concession; ux with design on the panel: Review debate-design section |
| 4 fact-check | does not block; a failure becomes a notice in research-check.md |
| 5 rebuttal | only agents that took a veto; does not block; a failure falls back to the r1 proposal |
| 6 decision | weights sum 100, every score adds up, every Dn decided, every veto ruled, every wrong claim zeroed, >= 3 MADR ADRs with Decision outcome, Considered options and Confirmation, index of 3-6 specs, Dissent |
| 6 SDD | sections 0-8, mermaid, TOKENS with contrast and identical to decision.md, every ADR cited, Empty/Loading/Error, banned list, no placeholder |
| 6 audit | Verdict; FIX carries An rows and the judge fixes only what they name; a provider failure does not block |
| 6d brand | only with debate-brand: sections 1-8, TOKENS identical to the SDD and with contrast, logo, voice, 1+ adapted screen, banned list, no placeholder |
| 7 specs | EARS, cited ADR exists, every US has a task, no placeholder, checklist |
| 8 tracks | draft with 8+ items and Acceptance |
| 8 backlog | 15+ items, 4+ phases, every item with Acceptance, source, est S/M/L; deps exist and no cycle; every polish.md tag, spec, task and ADR covered; capacity math adds up and the plan fits; DoD |
| 8b completeness | Verdict; 1 row per completeness.md stage as covered, gap or n/a; covered cites B ids that exist; n/a with a reason; GAPS carries Gn rows and debate-pm adds their items, then the backlog gate runs again |
| 8c cards | every item before Post-launch has a card with What, How in 2+ steps, Files, Done when in Given/When/Then and Test; no placeholder |

## Limits

- rounds 1-3 (1 = proposal only, 2 = +critique and fact-check, 3 = +rebuttal)
- panel of 3-8 agents: debate-arch, debate-ux and debate-pm always; optional seats from the brief (references/panel.conf, `panel.sh`); judge, researcher and auditor sit outside the panel
- resume by default: an existing output is reused; `FRESH=1` redoes everything; `--from <phase>` archives that phase and the later ones in raw/archive and redoes them; `status` shows the next phase and warns when an output is older than its input
- proposal and critique run in a room: a directory with only what the agent may read, no rival output
- provider failed: automatic model fallback, the run fails only when no model is left. Session mode: `models.sh next <case> <agent>` gives the next model (models.conf `fallback`, spare, strong on a paid profile, the free catalog) for the subagent call; with none left, it continues with a panel >= 2. CLI: waits with backoff on a rate limit, then goes through `MODEL_FALLBACK` and the `MIX` harnesses; a route out of quota is skipped for the rest of the run
- `PARALLEL` caps simultaneous calls, `MAX_CALLS` caps the run, 1 run per case (raw/.lock)
- phase 7 in the CLI: 1 call per item of the decision.md index; `SPECS=0` leaves the specs for manual filling
- language: input in any language, every artifact in English
