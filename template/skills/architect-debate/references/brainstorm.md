# Brainstorm protocol (/opd-brainstorm)

From a rough theme ("let's be creative, new features for the product") to 3-5 proposals that fit this product, can be
tested in 2 weeks and are not what every other user gets. One of them becomes a debate case: the debate assumes 1 idea,
the brainstorm finds which one is worth it.

Why it is built this way (sources in docs/brainstorm.md): a model asked for ideas returns its most typical ones, and
returns them to everyone, so the ideas converge across users. The protocol answers each cause:

| Cause of same-y ideas | Answer here |
|---|---|
| The model's "random" is the same for everyone | `brainstorm.sh new` draws the lenses and stimuli with a seed outside the model |
| Ideas come from the theme words, not from the product | ground.md: the product's own files, real users' pains, the market; every idea cites a Gn fact |
| The first ideas are the most typical (mode collapse) | ground.md Baseline lists the obvious; each ideator writes its own Typical first and discards it, and every idea names the Bn it goes beyond |
| Every lens anchors on the loudest pain | after ground.md, each lens starts from a different Users and pains fact, turned by the seed; 1 of its ideas must anchor on it |
| Seeing others' ideas fixates the group | 1 ideator per lens, blind, in parallel, in a different model when the harness allows |
| "Novel" by assumption | novelty.md: a scout searches for each idea; `exists` caps its novelty score at 1 |
| Judges mark the unfamiliar down | the Wildcard keeps the most novel proposal that is still feasible |
| Creative but unbuildable | fit and feasibility weigh in the scores; every idea has a 2-week first test with a go number |

Language: talk to the user in their language; every file is written in English.

## Flow

`$S` is the scripts folder. A step ending in a gate runs `$S/gate.sh <dir> <phase>`: a FAILED line gets 1 repair call
with the reason; failing again, stop and report.

0. Intake. Before asking, read the project (README, docs, manifests) when there is one: never ask what the repo answers.
   Then 1 round of up to 3 questions, each with a default: who has the problem, what they do today, the hard constraint
   (deadline, cost ceiling or platform). No answer: assume and mark `[assumed, owner <name>, <week>]`.
   Run `$S/brainstorm.sh new "<theme, the user's words>"` from the project root (dest defaults to `cases`; the product
   read is the git root, `PRODUCT=none` for a new product). It prints the folder and the lenses drawn. Fill the Intake of
   theme.md in English. Never pick or change the lenses or stimuli yourself: the draw is the point. The user may name
   lenses with `--lenses analogy,outcome` (`LENSES="analogy outcome"`).
1. Ground: debate-research, `phase ground`, `project: <path in theme.md, or none>`, reads theme.md and
   ground-template.md, writes ground.md. Gate `ground`.
2. Ideas: after ground.md passes, `$S/brainstorm.sh lenses <dir>` prints 1 line per lens: the file it writes and its task, with the pain it starts from. 1 debate-ideator call
   per lens, all in the same turn, each with its task line literally, `reads: theme.md, ground.md` and nothing else:
   never name ideas/ or another lens in a prompt. Gate `ideas`.
3. Novelty: debate-research, `phase novelty`, reads ideas/, writes novelty.md (1 debate-scout per idea). Gate `novelty`.
4. Converge: debate-judge, `phase converge`, reads theme.md, ground.md, ideas/, novelty.md and brainstorm-template.md,
   writes brainstorm.md. Gate `converge`.
5. Pick: show the proposals table and the recommendation, max 12 lines (below), then ask which one goes to the debate,
   with the harness's question tool when it has one: the pick as the default, the wildcard, the others, `Not now`.
   `Not now` ends with the folder path.
6. Seed: `$S/brainstorm.sh seed <dir> <Pn>` (`PICKED_BY=default` when the user took the default) creates the debate
   case, writes the proposal into its idea.md, copies brainstorm.md and ground.md into it, fills the brief fields the
   proposal answers (goal, who uses it, the first test's go number as the metric, the intake's hard constraint) and
   records the pick. Fill the rest of brief.md in English from ground.md and the intake where they answer it (the rest
   stays for the debate intake), run `$S/gate.sh <case> brief`, and offer `/debate` on that case: its intake asks only what the
   brief still lacks.

Headless (harnesses without subagents, CI): after the intake, `HARNESS=<id> $S/brainstorm.sh run <dir>` runs steps 1-4
with every gate and 1 repair each, each lens in its own process that sees only theme.md and ground.md. `MIX="claude
codex"` spreads the lenses across harnesses, so each lens runs on another model family. Running it again resumes.

## State

```text
cases/brainstorms/<slug>/
  theme.md  meta.txt (theme, seed, lenses and stimuli drawn, product path)
  ground-template.md  brainstorm-template.md  debate-rules.md
  ground.md            1, debate-research: Gn facts, Bn baseline
  ideas/<lens>.md      2, debate-ideator, 1 per lens, blind
  novelty.md           3, debate-research + debate-scout
  brainstorm.md        4, debate-judge; Picked filled by brainstorm.sh seed
  raw/                 headless runs: raw output, summary.log, metrics.tsv (seconds and tokens per call)
```

## Gates

| Phase | Gate |
|---|---|
| ground | 10+ Gn facts, each with a URL, `file:` or `unverified`; 5+ distinct URLs; 6-12 Bn baseline ideas; Gaps |
| ideas | per lens: 1+ idea anchored on the lens's pain (`brainstorm.sh lenses` names it); 3 ideas `### <prefix>n`, each with Pitch, For, Mechanism, Anchor (an existing Gn), Stimulus, Beyond (an existing Bn), Why now and First test with `go if`; a Typical section with 3+ `p=` lines |
| novelty | 1 row per idea of ideas/; verdict exists, adjacent or novel; exists and adjacent with a URL, novel with a URL or `searched:` |
| converge | 3-5 proposals, each From existing idea ids; weights with novelty, fit, value and feasibility summing 100; every Total adds up; a proposal whose ideas all exist scores novelty 0-1; Pick names the top Total, or writes `override` and why; Wildcard scores feasibility 3+, or is `same as the pick`; Pre-mortem; Would change the pick |

## Lenses (references/lenses.conf)

| Lens | Move | From |
|---|---|---|
| analogy (always) | transfer the structure of a mechanism from a far domain | far analogies, marginality in broadcast search |
| inversion | invert an assumption the whole category shares | Blue Ocean ERRC, TRIZ inversion |
| outcome | design for an extreme user's most underserved outcome | Jobs to be Done, Outcome-Driven Innovation, extreme users |
| enabler | build what a recent shift made viable | "why now" |
| model | change how value is captured, not the feature | Ten Types of Innovation |
| constraint | solve the core job under an extreme constraint | constraints as a creativity driver |

## Output in chat

1 line per step (`ideas: 4/4 ok, lenses analogy (harbor pilots), outcome (a team of 500), ...`). At the pick, max 12
lines: the proposals table (ID, name, pitch, Total, novelty verdict), the pick with its reason, the wildcard, and what
would change the pick.
