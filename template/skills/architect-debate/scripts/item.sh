#!/bin/sh
# item.sh <case> [Bnn...] - the build context of each backlog item, in build/<Bnn>.md: its line, its card, and only the
# ADR decisions, spec tasks, requirements and SDD sections it traces to. The build agent reads 1 short file per item
# instead of the whole case: an agent given a long plan skips instructions, and every turn resends what it read.
# No id: every item before Post-launch. Extraction follows the ids, with no LLM. Prints 1 line per file with its size.
set -eu
export LC_ALL=C
CASE_DIR="${1:?usage: item.sh <case> [Bnn...]}"; shift
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
C="$(CDPATH= cd -- "$CASE_DIR" && pwd)"
[ -s "$C/BACKLOG.md" ] || { echo "error: $C/BACKLOG.md missing: the backlog phase comes first" >&2; exit 2; }
TSV="$(awk -v mode=tsv -f "$SCRIPT_DIR/backlog.awk" "$C/BACKLOG.md")"
CARDS="$C/BACKLOG-DETAILED.md"
ids="$*"
[ -n "$ids" ] || ids="$(printf '%s\n' "$TSV" | awk -F'\t' '$2 != "Post-launch" { print $1 }')"
mkdir -p "$C/build"

# card <id>: the ### <id> block of BACKLOG-DETAILED.md, without its heading.
card() { [ -s "$CARDS" ] || return 0; awk -v id="$1" '/^### / { on = ($2 == id); next } /^## / { on = 0 } on' "$CARDS"; }

for id in $ids; do
  row="$(printf '%s\n' "$TSV" | awk -F'\t' -v id="$id" '$1 == id')"
  [ -n "$row" ] || { echo "error: $id is not an item of BACKLOG.md" >&2; exit 2; }
  out="$C/build/$id.md"
  cd_="$(card "$id")"
  # Every id the item and its card cite: ADR-NNNN, spec NN:Txxx[,Tyyy | -Tyyy], SDD-n.
  refs="$(printf '%s\n%s\n' "$(printf '%s' "$row" | cut -f6)" "$cd_")"
  {
    printf '%s\n' "$row" | awk -F'\t' '{ printf "# %s - %s\n\n%s, est %s%s\nAcceptance: %s\n", $1, $4, $2, $7, ($11 == "yes" ? ", blocks the next phase" : ""), $5 }'
    deps="$(printf '%s' "$row" | cut -f9)"
    if [ -n "$deps" ]; then
      printf 'Depends on:'
      for d in $deps; do printf ' %s (%s)' "$d" "$(printf '%s\n' "$TSV" | awk -F'\t' -v d="$d" '$1 == d { print $12 }')"; done
      printf '\n'
    fi
    if [ -n "$cd_" ]; then printf '\n## Card\n\n%s\n' "$cd_"; fi

    adrs="$(printf '%s\n' "$refs" | grep -Eo 'ADR-[0-9]+' | sort -u | tr '\n' ' ')"
    if [ -n "$adrs" ]; then
      printf '\n## Decisions it must follow\n\n'
      for a in $adrs; do
        # An appeal may have superseded it: the build follows the ADR in force, at the end of the chain.
        hop=0
        while :; do
          n="$(printf '%04d' "$(printf '%s' "${a#ADR-}" | sed 's/^0*//; s/^$/0/')")"
          f="$(ls "$C"/adr/"$n"-*.md 2>/dev/null | head -1)"
          if [ -z "$f" ]; then printf -- '- %s: not in adr/\n' "$a"; break; fi
          nx="$(sed -n 's/^- Status:.*superseded by \(ADR-[0-9]*\).*/\1/p' "$f" | head -1)"
          hop=$((hop + 1))
          if [ -n "$nx" ] && [ "$hop" -lt 6 ]; then printf -- '- %s: superseded by %s, below\n' "$a" "$nx"; a="$nx"; continue; fi
          awk -f "$SCRIPT_DIR/adr.awk" "$f" | awk -F'\t' '{ printf "- %s %s: \"%s\"%s.%s%s\n", $1, $2, $4, ($6 == "" ? "" : ", because " $6),
            ($7 == "" ? "" : " Accepted cost: " $7 "."), ($10 == "" ? "" : " Check: " $10) }'
          break
        done
      done
    fi

    # spec NN:T001,T003 | spec NN:T001-T004: the tasks, the user stories they serve and those stories' EARS requirements.
    printf '%s\n' "$refs" | grep -Eo 'spec [0-9]{2}:[T0-9,-]+' | sort -u | while read -r _ ref; do
      nn="${ref%%:*}"; ts="${ref#*:}"; d="$(ls -d "$C"/specs/"$nn"-*/ 2>/dev/null | head -1)"
      [ -n "$d" ] || { printf '\n## spec %s: not in specs/\n' "$nn"; continue; }
      printf '\n## spec %s (%s)\n\n' "$nn" "$(basename "$d")"
      awk -v ts="$ts" '
        function num(t) { gsub(/[^0-9]/, "", t); return t + 0 }
        BEGIN { k = split(ts, p, ","); for (i = 1; i <= k; i++) if (p[i] ~ /-/) { split(p[i], r, "-"); lo[i] = num(r[1]); hi[i] = num(r[2]) } else lo[i] = hi[i] = num(p[i]) }
        /^- \[.\] T[0-9]+/ { match($0, /T[0-9]+/); t = num(substr($0, RSTART, RLENGTH))
          for (i = 1; i <= k; i++) if (t >= lo[i] && t <= hi[i]) { print; break } }' "${d}tasks.md" > "$C/build/.tasks"
      cat "$C/build/.tasks"
      for u in $(grep -Eo '\[US[0-9]+\]' "$C/build/.tasks" | tr -d '[]' | sort -u); do
        grep -E "^- ${u}[[:space:]]|\[${u}\]" "${d}spec.md" 2>/dev/null || true
      done
      rm -f "$C/build/.tasks"
    done

    for s in $(printf '%s\n' "$refs" | grep -Eo 'SDD-[0-9]+' | sort -u | sed 's/SDD-//'); do
      [ -s "$C/SDD.md" ] || break
      printf '\n## SDD section %s\n\n' "$s"
      awk -v s="$s" '/^## / { on = (index($0, "## " s) == 1); next } on && NF { print; if (++n == 8) exit }' "$C/SDD.md"
    done

    printf '\n## Rules\n\n'
    [ ! -s "$C/tokens.css" ] || printf -- '- Colors, type and spacing come only from %s/tokens.css.\n' "$C"
    printf -- '- Done when the card'"'"'s Done when and the Definition of Done of BACKLOG.md hold.\n'
    printf -- '- Needs a decision no ADR above covers, or goes against one: stop and ask, or run the appeal (HANDOFF.md).\n'
    printf -- '- Not enough here: open %s/SDD.md, adr/ or specs/, only the part you need.\n' "$C"
  } > "$out"
  printf '%s %s lines\n' "build/$id.md" "$(wc -l < "$out" | tr -d ' ')"
done
