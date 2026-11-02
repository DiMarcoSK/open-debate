#!/bin/sh
# panel.sh <case> [--save] [agent...] - builds the case panel: base seats (debate-arch, debate-ux, debate-pm)
# plus the optional ones the brief triggers in references/panel.conf. With agents, uses those and adds the base.
# Prints the panel on the 1st line and the reason for each optional seat after it; --save writes `panel:` to meta.txt.
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
if [ -n "$ASKED" ]; then PANEL="$(with_base "$ASKED")"; else PANEL="$(pick_panel "$CASE_DIR")"; fi
for a in $PANEL; do
  [ -f "$SCRIPT_DIR/../personas/$a.md" ] || { echo "error: unknown persona on the panel: $a" >&2; exit 2; }
done
printf 'panel: %s\n' "$PANEL"
for b in $PANEL_BASE; do printf '  %s: base, always\n' "$b"; done
panel_reasons "$CASE_DIR" | while IFS= read -r x; do
  a="${x%%:*}"
  if on_panel "$a"; then printf '  %s: brief says "%s"\n' "$a" "${x#*: }"
  else printf '  %s: out (brief says "%s", cap %s or panel asked for)\n' "$a" "${x#*: }" "$PANEL_CAP"; fi
done
if [ -n "$ASKED" ]; then
  for a in $ASKED; do case " $PANEL_BASE " in *" $a "*) ;; *) printf '  %s: asked for\n' "$a" ;; esac; done | sort -u
fi
if [ "$SAVE" = "1" ]; then
  { grep -v '^panel:' "$CASE_DIR/meta.txt" 2>/dev/null || true; printf 'panel: %s\n' "$PANEL"; } > "$CASE_DIR/meta.txt.tmp"
  mv "$CASE_DIR/meta.txt.tmp" "$CASE_DIR/meta.txt"
fi
