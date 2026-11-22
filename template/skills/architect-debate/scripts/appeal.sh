#!/bin/sh
# appeal.sh - the build reopens 1 decision instead of retrying blindly or quietly going against it.
#   appeal.sh <case> <Bnn|ADR-NNNN> <evidence-file>   opens appeals/<nn>-adr-<NNNN>/ with the ADR, the items that trace to
#                                                     it and the evidence (a failing test log, a diff, a measurement)
#   appeal.sh <case> apply                            applies the approved ruling of the open appeal: keep, amend the ADR
#                                                     or supersede it, records the lesson and rebuilds build/
# Between the two: debate-arch and debate-pm write their positions (phase appeal, gate.sh <case> appeal), then
# debate-judge rules (phase ruling, gate.sh <case> ruling). The lesson goes to lessons.md next to the case, which the
# next debate in the same folder reads: what broke in this build is evidence there.
set -eu
export LC_ALL=C
CASE_DIR="${1:?usage: appeal.sh <case> <Bnn|ADR-NNNN> <evidence-file> | appeal.sh <case> apply}"
WHAT="${2:?usage: appeal.sh <case> <Bnn|ADR-NNNN> <evidence-file> | appeal.sh <case> apply}"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
TOK="$SCRIPT_DIR/tokens.awk"; PANEL=""
. "$SCRIPT_DIR/gates.sh"
C="$(CDPATH= cd -- "$CASE_DIR" && pwd)"
adr_file() { n="$(printf '%s' "${1#ADR-}" | sed 's/^0*//; s/^$/0/')"; ls "$C"/adr/"$(printf '%04d' "$n")"-*.md 2>/dev/null | head -1; }

if [ "$WHAT" = "apply" ]; then
  A="$(open_appeal "$C")"
  [ -n "$A" ] || { echo "error: no open appeal in $C/appeals" >&2; exit 2; }
  r="$(check ruling debate-judge "$A/ruling.md")"
  [ -z "$r" ] || { echo "error: ruling.md fails its gate: $r" >&2; exit 2; }
  adr="$(sed -n 's/^ADR: //p' "$A/appeal.md" | head -1)"; old="$(adr_file "$adr")"
  ruling="$(sed -n 's/^Ruling:[[:space:]]*//p' "$A/ruling.md" | head -1 | tr '[:upper:]' '[:lower:]' | awk '{ print $1 }')"
  # The ADR block of the ruling, 1 heading level up, as split_adrs writes adr/.
  block() {
    awk 'function level(l) { match(l, /^#+/); return RLENGTH }
      /^#+[[:space:]]*ADR-[0-9]+/ && !on { on = 1; lv = level($0); l = $0; sub(/^#+/, "#", l); print l; next }
      on && /^#/ && level($0) <= lv { exit }
      on { l = $0; if (l ~ /^#/) l = substr(l, lv); print l }' "$A/ruling.md"
  }
  new=""
  case "$ruling" in
    keep) ;;
    amend) block > "$old.new" && mv "$old.new" "$old"; new="$adr" ;;
    supersede)
      id="$(block | sed -n '1s/^# *\(ADR-[0-9]*\).*/\1/p')"
      t="$(block | sed -n '1s/^# *ADR-[0-9]*[[:space:]:.-]*//p' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9][^a-z0-9]*/-/g; s/^-//; s/-$//' | cut -c1-40)"
      f="$C/adr/$(printf '%04d' "$(printf '%s' "${id#ADR-}" | sed 's/^0*//')")-$t.md"
      block > "$f"
      sed "s/^- Status:.*/- Status: superseded by $id/" "$old" > "$old.new" && mv "$old.new" "$old"
      new="$id" ;;
  esac
  lesson="$(sed -n 's/^Lesson:[[:space:]]*//p' "$A/ruling.md" | head -1)"
  item="$(sed -n 's/^Items: //p' "$A/appeal.md" | head -1)"
  # lessons.md lives next to the cases: every case of this folder made afterwards starts with it.
  L="$(dirname "$C")/lessons.md"
  if [ -n "$lesson" ] && [ "$(printf '%s' "$lesson" | tr '[:upper:]' '[:lower:]')" != "none" ]; then
    [ -s "$L" ] || printf '# Lessons from past builds\n\nDecisions that met the code: a proposal that repeats one says why it holds now; a veto may cite a line as evidence.\n\n' > "$L"
    printf -- '- %s %s %s: %s after %s. %s\n' "$(date -u +%Y-%m-%d)" "$(basename "$C")" "$adr" "$ruling${new:+ ($new)}" "${item:-the build}" "$lesson" >> "$L"
  fi
  printf 'Applied: %s %s\n' "$ruling" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$A/appeal.md"
  [ ! -s "$C/BACKLOG.md" ] || "$SCRIPT_DIR/item.sh" "$C" > /dev/null
  printf 'ruling: %s %s%s\n' "$ruling" "$adr" "${new:+, now $new}"
  [ -z "$lesson" ] || printf 'lesson: %s\n' "$L"
  printf 'build/ rebuilt: continue the item with its build/<Bnn>.md\n'
  exit 0
fi

EV="${3:?usage: appeal.sh <case> <Bnn|ADR-NNNN> <evidence-file>}"
[ -s "$EV" ] || { echo "error: evidence $EV missing or empty: save the failing log or the diff to a file" >&2; exit 2; }
[ -z "$(open_appeal "$C")" ] || { echo "error: $(open_appeal "$C") is still open: rule it and run appeal.sh <case> apply" >&2; exit 2; }
items=""
case "$WHAT" in
  ADR-[0-9]*) adr="$WHAT" ;;
  B[0-9]*)
    [ -s "$C/BACKLOG.md" ] || { echo "error: $C/BACKLOG.md missing" >&2; exit 2; }
    items="$WHAT"
    src="$(awk -v mode=tsv -f "$SCRIPT_DIR/backlog.awk" "$C/BACKLOG.md" | awk -F'\t' -v id="$WHAT" '$1 == id { print $6 }')
$(awk -v id="$WHAT" '/^### / { on = ($2 == id); next } on' "$C/BACKLOG-DETAILED.md" 2>/dev/null)"
    a="$(printf '%s\n' "$src" | grep -Eo 'ADR-[0-9]+' | sort -u)"
    case "$(printf '%s\n' "$a" | grep -c .)" in
      0) echo "error: $WHAT cites no ADR: name it, appeal.sh <case> ADR-NNNN <evidence>" >&2; exit 2 ;;
      1) adr="$a" ;;
      *) echo "error: $WHAT cites $(printf '%s' "$a" | tr '\n' ' ')- name the one the evidence breaks: appeal.sh <case> ADR-NNNN <evidence>" >&2; exit 2 ;;
    esac ;;
  *) echo "error: $WHAT is neither Bnn nor ADR-NNNN" >&2; exit 2 ;;
esac
f="$(adr_file "$adr")"; [ -n "$f" ] || { echo "error: $adr is not in $C/adr/" >&2; exit 2; }
[ -n "$items" ] || items="$(awk -v mode=tsv -f "$SCRIPT_DIR/backlog.awk" "$C/BACKLOG.md" 2>/dev/null | awk -F'\t' -v a="$adr" 'index($6, a) { printf "%s ", $1 }')"
n=1; while ls -d "$C"/appeals/"$(printf '%02d' "$n")"-* > /dev/null 2>&1; do n=$((n + 1)); done
A="$C/appeals/$(printf '%02d' "$n")-$(printf '%s' "$adr" | tr '[:upper:]' '[:lower:]')"
mkdir -p "$A"
cp "$EV" "$A/evidence.txt"
nx=1; for x in "$C"/adr/[0-9]*.md; do v="$(basename "$x" | cut -c1-4 | sed 's/^0*//')"; [ "${v:-0}" -lt "$nx" ] || nx=$((v + 1)); done
{
  printf '# Appeal - %s\n\n' "$adr"
  printf 'ADR: %s\nFile: %s\nItems: %s\nEvidence: %s\nNext free ADR number: ADR-%04d\n\n' "$adr" "adr/$(basename "$f")" "${items:-none}" "${A#"$C"/}/evidence.txt" "$nx"
  printf 'The build met this decision and the evidence says it may not hold. Re-decide only this ADR: keep it (the code is wrong), amend it (same number, the decision changes) or supersede it (a new ADR replaces it).\n\n## The ADR\n\n'
  cat "$f"
} > "$A/appeal.md"
R="${A#"$C"/}"
printf 'appeal: %s\n' "$R"
printf '1. In parallel, debate-arch and debate-pm, phase appeal: reads %s/appeal.md, %s/evidence.txt, debate-rules.md; writes %s/<agent>.md. Then gate.sh <case> appeal\n' "$R" "$R" "$R"
printf '2. debate-judge, phase ruling: reads %s/appeal.md, %s/evidence.txt, %s/debate-arch.md, %s/debate-pm.md, adr-template.md; writes %s/ruling.md. Then gate.sh <case> ruling\n' "$R" "$R" "$R" "$R" "$R"
printf '3. appeal.sh <case> apply\n'
