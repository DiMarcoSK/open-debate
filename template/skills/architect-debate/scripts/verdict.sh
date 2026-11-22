#!/bin/sh
# verdict.sh <case> [verdict|receipt|quiz|check <answers>] - the debate read by whoever has to act on it, with no LLM.
#   verdict (default)  VERDICT.md: 1 screen for the builder, 1 row per ADR: chosen, over what, its cost, the objection
#                      still standing and when it reopens. Read it instead of the whole case.
#   receipt            RECEIPT.md: 1 page for a non-technical client: what was chosen and why, what it costs, what is
#                      not included and the delivery plan.
#   quiz               teach-back: 1 question per ADR with 2+ options, the options shuffled; the key goes to raw/quiz.key.
#   check 1=b 2=a ...  grades the answers and names the ADRs to review: only the ones missed need reading.
set -eu
export LC_ALL=C
CASE_DIR="${1:?usage: verdict.sh <case> [verdict|receipt|quiz|check <answers>]}"
MODE="${2:-verdict}"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
C="$(CDPATH= cd -- "$CASE_DIR" && pwd)"
ls "$C"/adr/[0-9]*.md > /dev/null 2>&1 || { echo "error: $C/adr/ has no ADR: the decision phase comes first" >&2; exit 2; }
# Only the ADRs in force: one superseded by an appeal stays in adr/ for the record.
ADRS="$(awk -f "$SCRIPT_DIR/adr.awk" "$C"/adr/[0-9]*.md | awk -F'\t' 'tolower($3) !~ /superseded/')"
field() { sed -n "s/^- $1[^:]*:[[:space:]]*//p" "$C/brief.md" 2>/dev/null | head -1; }
plan() { [ ! -s "$C/BACKLOG.md" ] || awk -v mode=summary -f "$SCRIPT_DIR/backlog.awk" "$C/BACKLOG.md"; }
title="$(sed -n '1s/^# *Backlog *-* *//p' "$C/BACKLOG.md" 2>/dev/null)"; title="${title:-$(sed -n 3p "$C/idea.md" 2>/dev/null)}"

case "$MODE" in
  verdict)
    {
      printf '# Verdict - %s\n\n' "$title"
      n="$(printf '%s\n' "$ADRS" | grep -c .)"
      printf '%s decisions. Read this screen, then answer the teach-back (`verdict.sh <case> quiz`): only the ADRs you miss need opening.\n' "$n"
      t="$(plan | sed -n 's/^Total: //p')"; [ -z "$t" ] || printf 'Backlog: %s.\n' "$t"
      printf '\n| ADR | Chosen | Over | Cost | Objection still standing |\n|---|---|---|---|---|\n'
      printf '%s\n' "$ADRS" | awk -F'\t' '{ printf "| %s %s | %s | %s | %s | %s |\n", $1, $2, ($4 == "" ? "-" : $4), ($5 == "" ? "-" : $5), ($7 == "" ? "not recorded" : $7), ($8 == "" ? "none" : $8) }'
    } > "$C/VERDICT.md"
    cat "$C/VERDICT.md" ;;

  receipt)
    {
      printf '# What we will build - %s\n\n' "$title"
      g="$(field Goal)"; w="$(field 'Who uses it')"
      [ -z "$g" ] || printf 'Goal: %s\n' "$g"
      [ -z "$w" ] || printf 'For: %s\n' "$w"
      printf '\n## What we chose, and why\n\n'
      printf '%s\n' "$ADRS" | awk -F'\t' '$4 != "" { r = $5; gsub(/; /, " or ", r); printf "- %s%s", $4, (r == "" ? "" : " instead of " r)
          printf "%s.", ($6 == "" ? "" : ", because " $6)
          printf " What it costs: %s.\n", ($7 == "" ? "nothing recorded" : $7) }'
      printf '\n## Not included\n\n'
      o="$(field 'Out of scope')"; [ -z "$o" ] || printf -- '- %s\n' "$o"
      if [ -s "$C/BACKLOG.md" ]; then
        awk -v mode=tsv -f "$SCRIPT_DIR/backlog.awk" "$C/BACKLOG.md" | awk -F'\t' '$2 == "Post-launch" { printf "- Later, after launch: %s\n", $4 }'
      fi
      p="$(plan)"
      if [ -n "$p" ]; then
        printf '\n## Delivery\n\n'
        printf '%s\n' "$p" | grep -v '^Critical path' | sed 's/^/- /; s/  */ /g'
      fi
      printf '\nEvery line comes from the decision record (adr/) and the backlog of this case; ask for the record behind any of them.\n'
    } > "$C/RECEIPT.md"
    cat "$C/RECEIPT.md" ;;

  quiz)
    mkdir -p "$C/raw"
    # The order comes from the case path: the same case always asks the same quiz, and the chosen one is not always first.
    seed="$(printf '%s' "$C" | cksum | cut -d' ' -f1)"
    printf '%s\n' "$ADRS" | awk -F'\t' -v seed="$seed" -v key="$C/raw/quiz.key" '
      BEGIN { srand(seed); printf "" > key }
      $4 != "" && $5 != "" {
        q++; n = split($5, r, "; "); o[1] = $4; for (i = 1; i <= n; i++) o[i + 1] = r[i]; n++
        for (i = n; i > 1; i--) { j = int(rand() * i) + 1; t = o[i]; o[i] = o[j]; o[j] = t }
        printf "Q%d (%s) %s Which option did the panel choose?\n", q, $1, ($9 == "" ? "" : $9)
        for (i = 1; i <= n; i++) { l = substr("abcdefgh", i, 1); printf "  %s) %s\n", l, o[i]; if (o[i] == $4) a = l }
        printf "%d\t%s\t%s\t%s\t%s\n", q, a, $1, $2, $4 >> key
      }
      END { if (!q) { print "no ADR with 2+ options to ask about" > "/dev/stderr"; exit 2 }
            printf "Answer with: verdict.sh <case> check 1=<letter> 2=<letter> ...\n" }' ;;

  check)
    shift 2
    [ -s "$C/raw/quiz.key" ] || { echo "error: no quiz yet, run: verdict.sh <case> quiz" >&2; exit 2; }
    ans=" $(printf '%s ' "$@" | tr '[:upper:]' '[:lower:]') "
    awk -F'\t' -v ans="$ans" -v dir="$C/adr" '
      { q = $1; k = split(ans, w, " "); got = ""
        for (i = 1; i <= k; i++) if (w[i] ~ ("^" q "[=:)]?[a-h]$")) got = substr(w[i], length(w[i]))
        tot++; if (got == $2) { ok++; next }
        miss = miss sprintf("review %s %s: chosen \"%s\"%s\n", $3, $4, $5, (got == "" ? ", not answered" : "")) }
      END { printf "teach-back: %d/%d\n", ok, tot; printf "%s", miss
            if (ok == tot) print "every decision recalled: build without opening adr/"; exit (ok == tot ? 0 : 1) }' "$C/raw/quiz.key" ;;

  *) echo "error: unknown mode: $MODE (verdict receipt quiz check)" >&2; exit 2 ;;
esac
