#!/bin/sh
# gate.sh <case> <phase> [agent...] - the gate of 1 phase, for the session mode orchestrator.
# Phases: brief research agenda proposal critique decision sdd audit brand specs tracks backlog completeness cards. Prints OK/FAILED per file, exits 1 if anything failed.
# status prints the state of each phase and the next one; vetoed lists who needs a rebuttal.
# An approved decision splits the ADRs into adr/; an approved sdd generates style-tile.html, tokens.json and tokens.css;
# an approved backlog exports backlog.csv, backlog.json and backlog-gh.sh; card-groups lists the groups of the cards phase,
# and approved cards are merged into BACKLOG-DETAILED.md and exported again.
set -eu
export LC_ALL=C
CASE_DIR="${1:?usage: gate.sh <case> <phase> [agent...]}"
PHASE="${2:?usage: gate.sh <case> <phase> [agent...]}"
shift 2
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
TOK="$SCRIPT_DIR/tokens.awk"
. "$SCRIPT_DIR/gates.sh"
PANEL="${*:-$(case_panel "$CASE_DIR")}"
FAIL=0
one() {
  r="$(check "$1" "$2" "$3")"
  if [ -z "$r" ]; then printf 'OK %s %s\n' "$1" "${3#"$CASE_DIR"/}"
  else printf 'FAILED %s %s %s: %s\n' "$1" "$2" "${3#"$CASE_DIR"/}" "$r"; FAIL=1; fi
}
case "$PHASE" in
  brief) "$SCRIPT_DIR/validate.sh" "$CASE_DIR" --brief || FAIL=1 ;;
  research) one research debate-research "$CASE_DIR/research.md" ;;
  agenda) one agenda debate-judge "$CASE_DIR/agenda.md" ;;
  proposal) for a in $PANEL; do one proposal "$a" "$CASE_DIR/proposals/$a.md"; done ;;
  critique) for a in $PANEL; do one critique "$a" "$CASE_DIR/critiques/$a.md"; done ;;
  decision)
    one decision debate-judge "$CASE_DIR/decision.md"
    [ "$FAIL" -eq 0 ] && printf 'ADRs: %s in adr/\n' "$(split_adrs "$CASE_DIR")" ;;
  sdd)
    one sdd debate-judge "$CASE_DIR/SDD.md"
    [ "$FAIL" -eq 0 ] && "$SCRIPT_DIR/style-tile.sh" "$CASE_DIR" ;;
  audit) one audit debate-auditor "$CASE_DIR/audit.md" ;;
  brand) one brand debate-brand "$CASE_DIR/BRANDBOOK.md" ;;
  specs) "$SCRIPT_DIR/validate.sh" "$CASE_DIR" || FAIL=1 ;;
  vetoed) vetoed "$CASE_DIR"; echo ;;
  status) exec "$SCRIPT_DIR/status.sh" "$CASE_DIR" ;;
  tracks) one track debate-ux "$CASE_DIR/backlog/design.md"; one track debate-arch "$CASE_DIR/backlog/eng.md" ;;
  backlog)
    one backlog debate-pm "$CASE_DIR/BACKLOG.md"
    [ "$FAIL" -eq 0 ] && "$SCRIPT_DIR/backlog-export.sh" "$CASE_DIR" ;;
  completeness) one completeness debate-auditor "$CASE_DIR/backlog/audit.md" ;;
  card-groups) card_groups "$CASE_DIR" | awk -F'\t' '{ printf "%s | %s | %s | %s\n", $1, $2, $3, $4 }' ;;
  cards)
    [ -s "$CASE_DIR/BACKLOG.md" ] || { echo "FAILED cards: BACKLOG.md missing"; exit 1; }
    card_groups "$CASE_DIR" > "$CASE_DIR/.groups.tmp"
    while IFS="$(printf '\t')" read -r n ph ids sp; do
      r="$(check_cards "$CASE_DIR/backlog/cards/$n.md" "$ids")"
      if [ -z "$r" ]; then printf 'OK cards backlog/cards/%s.md\n' "$n"
      else printf 'FAILED cards debate-arch backlog/cards/%s.md: %s\n' "$n" "$r"; FAIL=1; fi
    done < "$CASE_DIR/.groups.tmp"
    rm -f "$CASE_DIR/.groups.tmp"
    if [ "$FAIL" -eq 0 ]; then
      merge_cards "$CASE_DIR"; "$SCRIPT_DIR/backlog-export.sh" "$CASE_DIR" > /dev/null
      printf 'BACKLOG-DETAILED.md: %s card(s)\n' "$(grep -c '^### B' "$CASE_DIR/BACKLOG-DETAILED.md")"
    fi ;;
  *) echo "unknown phase: $PHASE (brief research agenda proposal critique decision sdd audit brand specs tracks backlog completeness card-groups cards vetoed status)" >&2; exit 2 ;;
esac
exit "$FAIL"
