#!/bin/sh
# make-specs.sh <case-dir> <slug1> [slug2...] - cria specs/<nn>-<slug>/ a partir dos templates.
# Idempotente: slug existente e pulado. NN = max existente + 1.
set -eu
CASE_DIR="${1:?uso: make-specs.sh <case-dir> <slug1> [slug2...]}"
shift
[ "$#" -ge 1 ] || { echo "erro: informe ao menos 1 slug" >&2; exit 2; }
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REF="$SCRIPT_DIR/../references"
for f in spec-template.md plan-template.md tasks-template.md checklist-template.md; do
  [ -f "$REF/$f" ] || { echo "erro: referencia ausente: $REF/$f" >&2; exit 2; }
done
mkdir -p "$CASE_DIR/specs" "$CASE_DIR/checklists"
clean() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9][^a-z0-9]*/-/g; s/^-\{1,\}//; s/-\{1,\}$//' | cut -c1-40; }
max_n() {
  m=0
  for d in "$CASE_DIR/specs"/*/; do
    [ -d "$d" ] || continue
    b="$(basename "$d")"
    n="$(printf '%s' "$b" | sed 's/^\([0-9][0-9]\)-.*/\1/')"
    case "$n" in ''|*[!0-9]*) continue;; esac
    n="$(printf '%s' "$n" | sed 's/^0*//')"; [ -z "$n" ] && n=0
    [ "$n" -gt "$m" ] && m="$n"
  done
  printf '%s' "$m"
}
N="$(max_n)"
for raw in "$@"; do
  slug="$(clean "$raw")"
  [ -n "$slug" ] || { echo "erro: slug invalido: $raw" >&2; exit 2; }
  if ls -d "$CASE_DIR/specs/"*-"$slug" >/dev/null 2>&1; then
    echo "pulo $slug: ja existe em $CASE_DIR/specs"
    continue
  fi
  N=$((N + 1)); NN="$(printf '%02d' "$N")"; D="$CASE_DIR/specs/$NN-$slug"
  mkdir -p "$D"
  cp "$REF/spec-template.md" "$D/spec.md"
  cp "$REF/plan-template.md" "$D/plan.md"
  cp "$REF/tasks-template.md" "$D/tasks.md"
  cp "$REF/checklist-template.md" "$CASE_DIR/checklists/requirements-$NN-$slug.md"
  printf '%s\n' "$D"
done
