#!/bin/sh
# validate.sh <case-dir> [--brief] - gates do debate. Sai 1 listando arquivo:linha: motivo. --brief so checa o brief.
set -eu
export LC_ALL=C
CASE_DIR="${1:?uso: validate.sh <case-dir> [--brief]}"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
TOK="$SCRIPT_DIR/tokens.awk"
. "$SCRIPT_DIR/gates.sh"
FAIL=0
say() { printf '%s:%s: %s\n' "$1" "$2" "$3"; FAIL=1; }
gate() { r="$(check "$1" "$2" "$3")"; [ -z "$r" ] || say "$3" 0 "$r"; }
fim() {
  [ "$FAIL" -eq 0 ] && { echo "validate ok: $CASE_DIR"; exit 0; }
  echo "validate reprovado: $CASE_DIR" >&2; exit 1
}

B="$CASE_DIR/brief.md"
[ -f "$B" ] || { echo "$CASE_DIR: brief.md ausente" >&2; exit 2; }
for n in $(awk '/^- [^:]*:[[:space:]]*$/ { print NR }' "$B"); do say "$B" "$n" "campo vazio no brief"; done
[ "${2:-}" = "--brief" ] && fim

PAINEL="$(sed -n 's/^painel: //p' "$CASE_DIR/meta.txt" 2>/dev/null | tail -1)"
PAINEL="${PAINEL:-debate-arch debate-design debate-gcp debate-k8s}"

gate pesquisa debate-research "$CASE_DIR/research.md"
[ ! -f "$CASE_DIR/agenda.md" ] || gate agenda debate-judge "$CASE_DIR/agenda.md"
for a in $PAINEL; do
  gate proposta "$a" "$CASE_DIR/proposals/$a.md"
  [ -f "$CASE_DIR/critiques/$a.md" ] && gate ataque "$a" "$CASE_DIR/critiques/$a.md"
done

gate decisao debate-judge "$CASE_DIR/decision.md"
if [ -s "$CASE_DIR/decision.md" ] && ! ls "$CASE_DIR"/adr/[0-9]*.md >/dev/null 2>&1; then
  say "$CASE_DIR/adr" 0 "ADRs nao separados, rode debate.sh de novo"
fi

S="$CASE_DIR/SDD.md"
gate sdd debate-judge "$S"
[ ! -f "$CASE_DIR/auditoria.md" ] || gate auditoria debate-auditor "$CASE_DIR/auditoria.md"

for d in "$CASE_DIR"/specs/*/; do
  [ -d "$d" ] || continue
  gate spec - "${d%/}"
  b="$(basename "$d")"
  [ -f "$CASE_DIR/checklists/requirements-$b.md" ] || say "$CASE_DIR/checklists/requirements-$b.md" 0 "checklist ausente"
done

if [ -s "$CASE_DIR/BACKLOG.md" ]; then gate backlog debate-pm "$CASE_DIR/BACKLOG.md"; fi

grep -rn '\[assumido' "$CASE_DIR" --include='*.md' --exclude='*-template.md' --exclude='regras-debate.md' --exclude='visual-contract.md' --exclude='lapidacao.md' --exclude-dir=raw 2>/dev/null \
  | grep -vi 'dono' | grep -v '`\[assumido' > "$CASE_DIR/.assumido.tmp" || true
if [ -s "$CASE_DIR/.assumido.tmp" ]; then
  while IFS= read -r l; do printf 'assumido-sem-dono: %s\n' "$l"; done < "$CASE_DIR/.assumido.tmp"; FAIL=1
fi
rm -f "$CASE_DIR/.assumido.tmp"
fim
