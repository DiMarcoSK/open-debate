# Visual contract - checked by validate.sh and rendered by style-tile.sh

## 1. TOKENS block (exact format, 1 key per line, comments only after //; exported as W3C DTCG in tokens.json)

```
TOKENS
paper #F2EFE8        // background of every screen
surface #FFFFFF      // card, table, input
ink #16181D          // primary text
ink-2 #4A4F5A        // secondary text
line #D9D4C7         // borders and dividers
accent #0B5FFF       // primary action and focus only
on-accent #FFFFFF    // text on accent
ok #1F6B3A
warn #9A5B00
crit #A3231B
display Instrument Serif
body Inter
mono JetBrains Mono
scale 1.25 base 16
space 4
radius 6
motion 180ms cubic-bezier(.2,.8,.2,1)
END
```

The values above show the format, they are not a default palette: every project derives its own from the concept.
6-digit hex. Google Fonts only. Optional dark mode: `paper-dark`, `ink-dark`, `accent-dark`.

## 2. Contrast gates (WCAG 2.2, validate.sh computes them)

| Pair | Minimum |
|---|---|
| ink / paper | 7.0 |
| ink / surface | 7.0 |
| ink-2 / paper | 4.5 |
| on-accent / accent | 4.5 |
| accent / paper | 3.0 |
| ok, warn, crit / paper | 4.5 |
| ink-dark / paper-dark | 7.0 (if present) |

## 3. System

Modular type scale (declared ratio), tabular numerals in data, 1 elevation strategy,
motion 120-240 ms only for state changes, with a prefers-reduced-motion fallback.
Visible 2 px focus, 24 px targets (44 px touch), color is never the only signal.

## 4. Copy and states (real text with numbers)

- Empty: what there is (zero), active filters, next step.
- Loading: skeleton with N rows shaped like the content, no lone spinner.
- Error: what happened, why, what to do, user input preserved.
- Success: what changed and where to see it.
- Partial: how much arrived (N of M) and what is missing.

An SDD without the words Empty, Loading and Error fails the gate.

## 5. Banned list (binding veto, override only with the user gain written)

purple-blue gradient, glass cards on a gradient, 3 generic columns with line icons,
lorem ipsum, stock smiles, corporate memphis illustration, emoji as interface icon,
centered wall of text, onboarding carousel, KPI dashboard with no action,
modal for everything, toast as the only error notice, neon on dark without a reason,
warm paper + terracotta palette reused without deriving it from the concept.

## 6. Per spec

Every spec with UI declares in section 6: screens, tokens and components used, written states and the accessibility criterion.
A spec without UI declares `no UI` with the reason in 1 line.
