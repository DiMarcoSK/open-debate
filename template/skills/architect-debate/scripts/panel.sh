#!/bin/sh
# panel.sh <case> [--save] [agent...] - builds the case panel: base seats (debate-arch, debate-ux, debate-pm)
# plus the optional ones the brief triggers in references/panel.conf. With agents, uses those and adds the base.
# Prints the panel on the 1st line, the reason for each seat after it and how many seats the agenda may still add
# (the judge may seat a catalog seat the brief words missed or a specialist made for the case); --save writes `panel:` to meta.txt.
set -eu
export LC_ALL=C
CASE_DIR="${1:?usage: panel.sh <case> [--save] [agent...]}"
shift
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
TOK="$SCRIPT_DIR/tokens.awk"
. "$SCRIPT_DIR/gates.sh"
[ -f "$CASE_DIR/brief.md" ] || { echo "error: $CASE_DIR is not a case" >&2; exit 2; }
SAVE=0; ASKED=""
for x in "$@"; do
  case "$x" in
    --save) SAVE=1 ;;
    debate-*) ASKED="$ASKED $x" ;;
    *) ASKED="$ASKED debate-$x" ;;
  esac
done
if [ -n "$ASKED" ]; then PANEL="$(with_base "$(no_case_seats "$ASKED")")"; else PANEL="$(pick_panel "$CASE_DIR")"; fi
for a in $PANEL; do
  [ -f "$SCRIPT_DIR/../personas/$a.md" ] || { echo "error: unknown persona on the panel: $a" >&2; exit 2; }
done
SLOTS="$(seat_slots "$PANEL")"
PANEL="$(with_seats "$CASE_DIR" "$PANEL")"
# Saved before printing: a reader that closes the pipe early (| head -1) must not lose the choice.
[ "$SAVE" = "0" ] || save_panel "$CASE_DIR" "$PANEL"
printf 'panel: %s\n' "$PANEL"
for b in $PANEL_BASE; do printf '  %s: base, always\n' "$b"; done
panel_reasons "$CASE_DIR" | while IFS= read -r x; do
  a="${x%%:*}"
  if on_panel "$a"; then printf '  %s: brief says "%s"\n' "$a" "${x#*: }"
  else printf '  %s: out (brief says "%s", cap %s or panel asked for)\n' "$a" "${x#*: }" "$PANEL_CAP"; fi
done
for a in $(agenda_seats "$CASE_DIR"); do if on_panel "$a"; then printf '  %s: seated by the agenda\n' "$a"; fi; done
[ -n "$(agenda_seats "$CASE_DIR")" ] || printf 'seats the agenda may add: %s\n' "$SLOTS"
if [ -n "$ASKED" ]; then
  for a in $ASKED; do case " $PANEL_BASE " in *" $a "*) ;; *) printf '  %s: asked for\n' "$a" ;; esac; done | sort -u
fi
