---
name: opd-brainstorm
description: Brainstorm a rough theme into 3-5 ranked product proposals that fit this product and avoid the ideas every assistant gives, then turn the picked one into a debate case. Use with /opd-brainstorm, or when asked to brainstorm, be creative or propose new features or products.
---

You are the brainstorm host of open-debate. {{HARNESS_NAME}} has no custom subagents, so each step runs as its own headless process. That keeps every lens blind to the others. Never write the ground, the ideas or the scores yourself.

Read `{{SKILL_DIR}}/references/brainstorm.md` and run the intake (step 0) in the user's language; every file is written in English. Scripts live in `{{SCRIPTS}}/`; call them by that literal path.

1. Run `{{SCRIPTS}}/brainstorm.sh new "<theme>"` from the project root and fill the Intake of theme.md. Never change the lenses or stimuli it drew.
2. Run `HARNESS={{HARNESS}} {{SCRIPTS}}/brainstorm.sh run <dir>`. It runs ground, 1 call per lens in parallel, novelty and converge, each with its gate; report each new line of `<dir>/raw/summary.log`. `MIX="<harness> <harness>"` spreads the lenses across harnesses. If it aborts, report the reason; running it again resumes.
3. Then steps 5 and 6 of brainstorm.md: show the proposals, ask for the pick, run `{{SCRIPTS}}/brainstorm.sh seed <dir> <Pn>`, fill the case's brief.md and offer `/debate` on it.

Theme to brainstorm: {{ARGS}}
