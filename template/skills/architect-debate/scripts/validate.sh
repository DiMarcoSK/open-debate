#!/bin/sh
# validate.sh <case-dir> [--brief] - every gate of the debate. Exits 1 listing file:line: reason. --brief checks only the brief.
set -eu
export LC_ALL=C
CASE_DIR="${1:?usage: validate.sh <case-dir> [--brief]}"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
TOK="$SCRIPT_DIR/tokens.awk"
. "$SCRIPT_DIR/gates.sh"
FAIL=0
say() { printf '%s:%s: %s\n' "$1" "$2" "$3"; FAIL=1; }
gate() { r="$(check "$1" "$2" "$3")"; [ -z "$r" ] || say "$3" 0 "$r"; }
finish() {
  [ "$FAIL" -eq 0 ] && { echo "validate ok: $CASE_DIR"; exit 0; }
  echo "validate failed: $CASE_DIR" >&2; exit 1
}

B="$CASE_DIR/brief.md"
[ -f "$B" ] || { echo "$CASE_DIR: brief.md missing" >&2; exit 2; }
for n in $(awk '/^- [^:]*:[[:space:]]*$/ { print NR }' "$B"); do say "$B" "$n" "empty field in the brief"; done
[ "${2:-}" = "--brief" ] && finish

PANEL="$(case_panel "$CASE_DIR")"

gate research debate-research "$CASE_DIR/research.md"
[ ! -f "$CASE_DIR/agenda.md" ] || gate agenda debate-judge "$CASE_DIR/agenda.md"
for a in $PANEL; do
  gate proposal "$a" "$CASE_DIR/proposals/$a.md"
  [ -f "$CASE_DIR/critiques/$a.md" ] && gate critique "$a" "$CASE_DIR/critiques/$a.md"
done

gate decision debate-judge "$CASE_DIR/decision.md"
if [ -s "$CASE_DIR/decision.md" ] && ! ls "$CASE_DIR"/adr/[0-9]*.md >/dev/null 2>&1; then
  say "$CASE_DIR/adr" 0 "ADRs not split, run debate.sh again"
fi

S="$CASE_DIR/SDD.md"
gate sdd debate-judge "$S"
[ ! -f "$CASE_DIR/audit.md" ] || gate audit debate-auditor "$CASE_DIR/audit.md"
if on_panel debate-brand || [ -f "$CASE_DIR/BRANDBOOK.md" ]; then gate brand debate-brand "$CASE_DIR/BRANDBOOK.md"; fi

for d in "$CASE_DIR"/specs/*/; do
  [ -d "$d" ] || continue
  gate spec - "${d%/}"
  b="${d%/}"; b="${b##*/}"
  [ -f "$CASE_DIR/checklists/requirements-$b.md" ] || say "$CASE_DIR/checklists/requirements-$b.md" 0 "checklist missing"
done

if [ -s "$CASE_DIR/BACKLOG.md" ]; then gate backlog debate-pm "$CASE_DIR/BACKLOG.md"; fi
[ ! -f "$CASE_DIR/backlog/audit.md" ] || gate completeness debate-auditor "$CASE_DIR/backlog/audit.md"
if [ -s "$CASE_DIR/BACKLOG-DETAILED.md" ]; then
  card_groups "$CASE_DIR" > "$CASE_DIR/.groups.tmp"
  while IFS="$(printf '\t')" read -r n ph ids sp; do
    r="$(check_cards "$CASE_DIR/backlog/cards/$n.md" "$ids")"; [ -z "$r" ] || say "$CASE_DIR/backlog/cards/$n.md" 0 "$r"
  done < "$CASE_DIR/.groups.tmp"
  rm -f "$CASE_DIR/.groups.tmp"
fi

grep -rn '\[assumed' "$CASE_DIR" --include='*.md' --exclude='*-template.md' --exclude='debate-rules.md' --exclude='visual-contract.md' --exclude='polish.md' --exclude-dir=raw 2>/dev/null \
  | grep -vi 'owner' | grep -v '`\[assumed' > "$CASE_DIR/.assumed.tmp" || true
if [ -s "$CASE_DIR/.assumed.tmp" ]; then
  while IFS= read -r l; do printf 'assumed-without-owner: %s\n' "$l"; done < "$CASE_DIR/.assumed.tmp"; FAIL=1
fi
rm -f "$CASE_DIR/.assumed.tmp"
finish
