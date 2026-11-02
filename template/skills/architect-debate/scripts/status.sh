#!/bin/sh
# status.sh <case> - where the case stands: 1 line per phase, the next one to run, stale outputs and cost so far. Changes nothing.
set -eu
export LC_ALL=C
CASE_DIR="${1:?usage: status.sh <case>}"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
TOK="$SCRIPT_DIR/tokens.awk"
. "$SCRIPT_DIR/gates.sh"
[ -f "$CASE_DIR/brief.md" ] || { echo "error: $CASE_DIR is not a case" >&2; exit 2; }
PANEL="${PANEL:-$(case_panel "$CASE_DIR")}"
if legacy_case "$CASE_DIR"; then echo "warning: $LEGACY_HINT"; fi
NEXT=""
row() {
  printf '%-10s %s\n' "$1" "$2"
  case "$2" in ok*|skipped*|optional*) ;; *) [ -n "$NEXT" ] || NEXT="$1" ;; esac
}
single() {
  if [ ! -s "$3" ]; then row "$1" pending; return 0; fi
  r="$(check "$1" "$2" "$3")"
  if [ -z "$r" ]; then row "$1" ok; else row "$1" "failed: $r"; fi
}
panel_row() {
  ok=0; tot=0; r=""
  for a in $PANEL; do
    tot=$((tot + 1)); x="$(check "$1" "$a" "$CASE_DIR/$2/$a.md")"
    if [ -z "$x" ]; then ok=$((ok + 1)); else r="$r ${a#debate-}"; fi
  done
  if [ "$ok" -eq "$tot" ]; then row "$1" "ok $ok/$tot"
  elif [ "$ok" -eq 0 ]; then row "$1" pending
  else row "$1" "failed $ok/$tot, missing:$r"; fi
}
if "$SCRIPT_DIR/validate.sh" "$CASE_DIR" --brief > /dev/null 2>&1; then row brief ok; else row brief "failed: empty field"; fi
single research debate-research "$CASE_DIR/research.md"
single agenda debate-judge "$CASE_DIR/agenda.md"
panel_row proposal proposals
if [ "$(sed -n 's/^rounds: //p' "$CASE_DIR/meta.txt" 2>/dev/null | tail -1)" = "1" ]; then row critique "skipped, rounds=1"; else panel_row critique critiques; fi
if [ -s "$CASE_DIR/research-check.md" ]; then row factcheck ok; else row factcheck "optional, did not run"; fi
v="$(vetoed "$CASE_DIR")"; f=""
for a in $v; do [ -s "$CASE_DIR/proposals/$a-r2.md" ] || f="$f ${a#debate-}"; done
if [ -z "$f" ]; then row rebuttal ok; else row rebuttal "optional, missing:$f"; fi
single decision debate-judge "$CASE_DIR/decision.md"
single sdd debate-judge "$CASE_DIR/SDD.md"
if [ -s "$CASE_DIR/audit.md" ]; then single audit debate-auditor "$CASE_DIR/audit.md"; else row audit "optional, did not run"; fi
if on_panel debate-brand; then single brand debate-brand "$CASE_DIR/BRANDBOOK.md"; fi
ok=0; tot=0; r=""
for d in "$CASE_DIR"/specs/[0-9]*/; do
  [ -d "$d" ] || continue
  tot=$((tot + 1)); x="$(check spec - "${d%/}")"
  if [ -z "$x" ]; then ok=$((ok + 1)); else d="${d%/}"; r="$r ${d##*/}"; fi
done
if [ "$tot" -eq 0 ]; then row specs pending
elif [ "$ok" -eq "$tot" ]; then row specs "ok $ok/$tot"
else row specs "failed $ok/$tot, missing:$r"; fi
single backlog debate-pm "$CASE_DIR/BACKLOG.md"
if [ -n "$NEXT" ]; then printf 'next: %s\n' "$NEXT"
elif "$SCRIPT_DIR/validate.sh" "$CASE_DIR" > /dev/null 2>&1; then echo 'next: none, case complete'
else echo 'next: no phase left, but validate fails: run open-debate validate'; fi
stale "$CASE_DIR" | sed 's/^/warning: /'
M="$CASE_DIR/raw/metrics.tsv"
if [ -s "$M" ]; then
  awk -F'\t' '{ n++; s += $3; rep += ($1 ~ /repair/); if ($3 > m) { m = $3; q = $1 } } END { printf "cost: %d calls, %d s of model time, %d repair(s); the slowest was %s (%d s)\n", n, s, rep, q, m }' "$M"
fi
