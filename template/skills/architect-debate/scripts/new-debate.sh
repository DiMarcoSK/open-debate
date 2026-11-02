#!/bin/sh
# new-debate.sh "your idea" [dest-cases] - creates cases/<slug>/ with the templates. The idea may be in any language.
# Never overwrites an existing case without OVERWRITE=1.
set -eu
IDEA="${1:?usage: new-debate.sh \"your idea\" [dest-cases]}"
BASE="${2:-cases}"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REF="$SCRIPT_DIR/../references"
COPIES="sdd-template.md debate-rules.md visual-contract.md research-template.md adr-template.md agenda-template.md audit-template.md backlog-template.md polish.md spec-template.md plan-template.md tasks-template.md brandbook-template.md"
for f in brief-template.md constitution-template.md $COPIES; do
  [ -f "$REF/$f" ] || { echo "error: missing reference: $REF/$f" >&2; exit 2; }
done
# Slug in ASCII: accents are dropped so "Gestão de clínicas" becomes gestao-de-clinicas, not gest-o-de-cl-nicas.
ascii() {
  if perl -MUnicode::Normalize -e 1 2>/dev/null; then printf '%s' "$1" | perl -CSD -MUnicode::Normalize -pe '$_ = NFD($_); s/\pM//g'
  else printf '%s' "$1"; fi
}
SLUG="$(ascii "$IDEA" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9][^a-z0-9]*/-/g; s/^-\{1,\}//; s/-\{1,\}$//')"
SLUG="$(printf '%s' "$SLUG" | awk -F- '{out=""; for(i=1;i<=NF && i<=6;i++) out=(out==""?$i:out"-"$i); print out}')"
SLUG="$(printf '%s' "$SLUG" | cut -c1-40 | sed 's/-\{1,\}$//')"
SLUG="${SLUG:-idea}"
OUT="$BASE/$SLUG"
if [ -e "$OUT" ] && [ "${OVERWRITE:-0}" != "1" ]; then
  n=2
  while [ -e "$BASE/$SLUG-$n" ]; do n=$((n + 1)); done
  OUT="$BASE/$SLUG-$n"
fi
if [ -e "$OUT" ] && [ "${OVERWRITE:-0}" = "1" ]; then rm -rf "$OUT"; fi
mkdir -p "$OUT/proposals" "$OUT/critiques" "$OUT/raw" "$OUT/adr" "$OUT/backlog" "$OUT/specs" "$OUT/checklists"
printf '# Idea\n\n%s\n' "$IDEA" > "$OUT/idea.md"
cp "$REF/brief-template.md" "$OUT/brief.md"
cp "$REF/constitution-template.md" "$OUT/constitution.md"
for f in $COPIES; do cp "$REF/$f" "$OUT/$f"; done
# Without PANEL, the panel comes from the filled brief (panel.sh), not from here: the brief is still empty.
printf 'idea: %s\ndate: %s\n' "$IDEA" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$OUT/meta.txt"
[ -z "${PANEL:-}" ] || printf 'panel: %s\n' "$PANEL" >> "$OUT/meta.txt"
printf '%s\n' "$OUT"
