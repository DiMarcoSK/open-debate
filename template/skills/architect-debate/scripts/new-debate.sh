#!/bin/sh
# new-debate.sh "sua ideia" [dest-cases] - cria cases/<slug>/ com templates.
# Nunca sobrescreve caso existente sem OVERWRITE=1.
set -eu
IDEA="${1:?uso: new-debate.sh \"sua ideia\" [dest-cases]}"
BASE="${2:-cases}"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REF="$SCRIPT_DIR/../references"
TEMPLATES="brief-template.md sdd-template.md constitution-template.md regras-debate.md visual-contract.md research-template.md adr-template.md backlog-template.md lapidacao.md spec-template.md plan-template.md tasks-template.md"
for f in $TEMPLATES; do
  [ -f "$REF/$f" ] || { echo "erro: referencia ausente: $REF/$f" >&2; exit 2; }
done
SLUG="$(printf '%s' "$IDEA" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9][^a-z0-9]*/-/g; s/^-\{1,\}//; s/-\{1,\}$//')"
SLUG="$(printf '%s' "$SLUG" | awk -F- '{out=""; for(i=1;i<=NF && i<=6;i++) out=(out==""?$i:out"-"$i); print out}')"
SLUG="$(printf '%s' "$SLUG" | cut -c1-40 | sed 's/-\{1,\}$//')"
SLUG="${SLUG:-ideia}"
OUT="$BASE/$SLUG"
if [ -e "$OUT" ] && [ "${OVERWRITE:-0}" != "1" ]; then
  n=2
  while [ -e "$BASE/$SLUG-$n" ]; do n=$((n + 1)); done
  OUT="$BASE/$SLUG-$n"
fi
if [ -e "$OUT" ] && [ "${OVERWRITE:-0}" = "1" ]; then rm -rf "$OUT"; fi
mkdir -p "$OUT/proposals" "$OUT/critiques" "$OUT/raw" "$OUT/adr" "$OUT/backlog" "$OUT/specs" "$OUT/checklists"
printf '# Ideia\n\n%s\n' "$IDEA" > "$OUT/idea.md"
cp "$REF/brief-template.md" "$OUT/brief.md"
cp "$REF/constitution-template.md" "$OUT/constitution.md"
for f in sdd-template.md regras-debate.md visual-contract.md research-template.md adr-template.md backlog-template.md lapidacao.md spec-template.md plan-template.md tasks-template.md; do cp "$REF/$f" "$OUT/$f"; done
printf 'ideia: %s\ndata: %s\npainel: %s\n' "$IDEA" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${PAINEL:-debate-arch debate-design debate-gcp debate-k8s}" > "$OUT/meta.txt"
printf '%s\n' "$OUT"
