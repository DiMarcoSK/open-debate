# Brainstorm: ideas that are not the same for everyone

Ask an assistant to "be creative, think of new features" and two users with different products get much the same list:
an AI assistant, a dashboard, templates, integrations, gamification. `/opd-brainstorm` is built to break that pattern. Its
proposals have to fit the product in front of it, be testable in 2 weeks, and not be the list everyone else gets. This
page covers why the list repeats, what each step does about it, and what was left out.

## Why the ideas repeat

| Finding | Source |
|---|---|
| Writers who took story ideas from an LLM were rated more creative one by one, but their stories were more alike as a group: "individually better off, but collectively a narrower scope of novel content" | Doshi and Hauser, *Science Advances* 10(28), 2024, [doi:10.1126/sciadv.adn5290](https://pubmed.ncbi.nlm.nih.gov/38996021/) |
| Unprompted GPT-4 idea pools were less diverse than human groups; chain-of-thought and persona prompts raised diversity close to human levels | Meincke, Mollick and Terwiesch, "Prompting Diverse Ideas", 2024, [arXiv:2402.01727](https://arxiv.org/abs/2402.01727) |
| An agent that kept generating research ideas reached a plateau: the share of non-duplicates in each new batch fell until almost nothing new came out | Si, Yang and Hashimoto, "Can LLMs Generate Novel Research Ideas?", ICLR 2025, [arXiv:2409.04109](https://arxiv.org/abs/2409.04109) |
| Mode collapse comes from the data: human raters prefer typical text, so aligned models put most of their probability on the typical answer. Asking for several answers with their probabilities raised creative-writing diversity 1.6-2.1x | Zhang et al., "Verbalized Sampling", ICML 2026, [arXiv:2510.01171](https://arxiv.org/abs/2510.01171) |
| In a brainstorm, the first ideas are the most common ones; the original ones come later | Beaty and Silvia, serial order effect, *Psychology of Aesthetics, Creativity, and the Arts*, 2012 |
| Showing designers an example makes them copy its features, its flaws included | Jansson and Smith, "Design fixation", *Design Studies*, 1991 |
| Groups that brainstorm out loud produce fewer ideas than the same people working alone and pooling their lists | Diehl and Stroebe, *Journal of Personality and Social Psychology*, 1987 |
| Problems got solved by people from fields far from the problem's own | Jeppesen and Lakhani, "Marginality and problem-solving effectiveness in broadcast search", *Organization Science*, 2010 |
| People say they want creativity but rate novel ideas lower when they are uncertain | Mueller, Melwani and Goncalo, "The bias against creativity", *Psychological Science*, 2012 |

## What each step does about it

| Step | Mechanism | Answers |
|---|---|---|
| `brainstorm.sh new` | A shell script, not the model, draws the lenses and 1 stimulus per lens from a seed in `/dev/urandom`. The far-analogy lens always sits, and its domain comes from a list of 50. The seed is written to meta.txt, so `SEED=<n>` repeats a draw. | A model asked to "pick at random" makes the same pick for every user |
| ground.md | Before any idea, debate-research reads the product (README, docs, manifests), real users' complaints, 3-5 competitors and the shifts of the last 24 months. Every row has a URL or a `file:` path. | Ideas drawn from the theme words fit any product, so they repeat across products |
| Baseline (Bn) | ground.md lists 6-12 obvious ideas: what the category already ships and what an assistant proposes first. Every idea names the Bn it goes beyond. | Repeating the market or the model's mode |
| Typical, then the tail | Each ideator first writes the 5 ideas it would give first, with its estimate of how often (`p=0.30`), and discards them. It then generates from ideas it would give with p < 0.10. This is verbalized sampling. | Mode collapse, serial order |
| Lenses | Six moves, each from practice or research: far analogy (structure mapping, marginality), inverted assumption (Blue Ocean's eliminate-reduce-raise-create grid, TRIZ), underserved outcome for an extreme user (Jobs to be Done, Outcome-Driven Innovation, IDEO's extreme users), why now, business model shift (Doblin's Ten Types of Innovation), extreme constraint. | One prompt, one angle |
| Blind ideators | 1 call per lens, in parallel. Each sees theme.md and ground.md only, never another lens. Headless runs can put each lens on another model family (`MIX`). | Fixation, production blocking, a single model's taste |
| Anchor (Gn) | Every idea cites a ground.md fact about this product or its users, and the gate fails an id that does not exist. The judge scores `fit` by how much the idea depends on that fact. | Generic ideas |
| novelty.md | A scout searches for each idea: `exists`, `adjacent` or `novel` (nothing found, which does not prove it is new). A proposal built only from ideas that exist scores novelty 0-1, and the gate checks this. | "Innovative" by assumption, the way AI Scientist-style agents check novelty against the literature |
| Scores | Weights for novelty, fit, value and feasibility sum 100, and the gate redoes the arithmetic, as it does in the debate. value needs a quoted pain or a number. | Creative but useless or unbuildable |
| Wildcard and pre-mortem | The judge also names the most novel proposal that scores 3+ on feasibility, even when it loses, and writes how the pick and the wildcard would fail 6 months out (Klein's pre-mortem). | The bias against creativity, optimism |
| First test | Every idea comes with a 2-week experiment and the number that would mean go. | Ideas that cannot be validated |
| Seed | The pick becomes a debate case with its idea, ground and brainstorm attached, ready for `/debate`, where the panel decides how to build it. This follows how companies pass an idea through gates: discovery, then a decision, then a build (Stage-Gate, the Double Diamond). | Ideas that stay in a chat |

## A real run

`/opd-brainstorm Vamos ser criativos, pense em novas features inovadoras para o produto.`, on this repository, headless on
Claude Code (Opus 5.5), 2026-11-22. Lenses drawn: analogy (sourdough starters), constraint (it is a single button),
inversion (turn the output into the input), outcome (someone who must explain the result to a customer).

| Step | Result | Time | Cost |
|---|---|---|---|
| ground | 35 facts (14 from the repo's own files, 8 quoted pains, 5 competitors, 8 shifts), 12 baseline ideas | 200 s | US$ 0.88 |
| ideas | 4/4 lenses, 12 ideas, every gate passed first time | 36-64 s each, in parallel | US$ 0.49 |
| novelty | 1 exists, 9 adjacent, 2 novel | 111 s | US$ 0.57 |
| converge | 9 clusters, 5 proposals; pick P5 (395), wildcard P1 | 77 s | US$ 0.24 |
| total | 7 calls, no repair | 7 min 38 s | US$ 2.19 |

The mode showed up as expected. Working blind, the 4 ideators wrote almost the same Typical list: "lite mode for small
changes" in 4 of 4, a "web viewer" in 3 of 4, "living specs", "cost preview" and "Jira export" in 2 each. All of them
were already in the Baseline (B6, B7, B10, B12, B8). After discarding them, the 12 ideas went elsewhere: critics seeded
with the vetoes that came true in the build, a 30-line context per backlog item extracted by trace id, ADRs inferred
from undocumented code, a client receipt of what was chosen and rejected, and a recall quiz in place of reading 2,500
lines. The novelty check caught the one that already existed: inferred ADRs, done by AgenticAKM, which the judge
dropped.

After this run, 2 changes came from what it showed. Each lens now starts from its own pain of ground.md, because
about half of the 12 ideas had gathered around the loudest one (review load). The proposals also became features of
open-debate itself: the decisions in 1 screen with a teach-back quiz (P5), the build context per item (P3), the build
appeal with lessons for the next debate (P2) and the client receipt (P1, without the GitHub Challenge part, which no
client of a freelancer would use).

## Left out

- Embedding distance between ideas as a gate. It would catch paraphrases that word overlap misses, but it needs a model or an API on every machine. The judge merges duplicates in Clusters, and the Baseline catches the obvious ones.
- More ideas per lens. Si et al. found that over-generating plateaus on duplicates, so more lenses do more than more ideas per lens.
- Letting the model choose the lenses. Its choice would be its mode again. The user can name lenses (`--lenses`), and the seed makes a draw repeatable.
