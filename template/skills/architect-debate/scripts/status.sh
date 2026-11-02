#!/bin/sh
# status.sh <caso> - onde o caso esta: 1 linha por fase, a proxima a rodar, defasagens e custo ate aqui. Nao muda nada.
set -eu
export LC_ALL=C
CASE_DIR="${1:?uso: status.sh <caso>}"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
TOK="$SCRIPT_DIR/tokens.awk"
. "$SCRIPT_DIR/gates.sh"
[ -f "$CASE_DIR/brief.md" ] || { echo "erro: $CASE_DIR nao e um caso" >&2; exit 2; }
PAINEL="${PAINEL:-$(painel_do_caso "$CASE_DIR")}"
PROX=""
linha() {
  printf '%-10s %s\n' "$1" "$2"
  case "$2" in ok*|pulado*|opcional*) ;; *) [ -n "$PROX" ] || PROX="$1" ;; esac
}
fase1() {
  if [ ! -s "$3" ]; then linha "$1" pendente; return 0; fi
  r="$(check "$1" "$2" "$3")"
  if [ -z "$r" ]; then linha "$1" ok; else linha "$1" "reprovado: $r"; fi
}
painel() {
  ok=0; tot=0; r=""
  for a in $PAINEL; do
    tot=$((tot + 1)); x="$(check "$1" "$a" "$CASE_DIR/$2/$a.md")"
    if [ -z "$x" ]; then ok=$((ok + 1)); else r="$r ${a#debate-}"; fi
  done
  if [ "$ok" -eq "$tot" ]; then linha "$1" "ok $ok/$tot"
  elif [ "$ok" -eq 0 ]; then linha "$1" pendente
  else linha "$1" "reprovado $ok/$tot, falta:$r"; fi
}
if "$SCRIPT_DIR/validate.sh" "$CASE_DIR" --brief > /dev/null 2>&1; then linha brief ok; else linha brief "reprovado: campo vazio"; fi
fase1 pesquisa debate-research "$CASE_DIR/research.md"
fase1 agenda debate-judge "$CASE_DIR/agenda.md"
painel proposta proposals
if [ "$(sed -n 's/^rounds: //p' "$CASE_DIR/meta.txt" 2>/dev/null | tail -1)" = "1" ]; then linha ataque "pulado, rounds=1"; else painel ataque critiques; fi
if [ -s "$CASE_DIR/research-check.md" ]; then linha factcheck ok; else linha factcheck "opcional, nao rodou"; fi
v="$(vetados "$CASE_DIR")"; f=""
for a in $v; do [ -s "$CASE_DIR/proposals/$a-r2.md" ] || f="$f ${a#debate-}"; done
if [ -z "$f" ]; then linha replica ok; else linha replica "opcional, falta:$f"; fi
fase1 decisao debate-judge "$CASE_DIR/decision.md"
fase1 sdd debate-judge "$CASE_DIR/SDD.md"
if [ -s "$CASE_DIR/auditoria.md" ]; then fase1 auditoria debate-auditor "$CASE_DIR/auditoria.md"; else linha auditoria "opcional, nao rodou"; fi
if no_painel debate-brand; then fase1 marca debate-brand "$CASE_DIR/BRANDBOOK.md"; fi
ok=0; tot=0; r=""
for d in "$CASE_DIR"/specs/[0-9]*/; do
  [ -d "$d" ] || continue
  tot=$((tot + 1)); x="$(check spec - "${d%/}")"
  if [ -z "$x" ]; then ok=$((ok + 1)); else d="${d%/}"; r="$r ${d##*/}"; fi
done
if [ "$tot" -eq 0 ]; then linha specs pendente
elif [ "$ok" -eq "$tot" ]; then linha specs "ok $ok/$tot"
else linha specs "reprovado $ok/$tot, falta:$r"; fi
fase1 backlog debate-pm "$CASE_DIR/BACKLOG.md"
if [ -n "$PROX" ]; then printf 'proxima: %s\n' "$PROX"
elif "$SCRIPT_DIR/validate.sh" "$CASE_DIR" > /dev/null 2>&1; then echo 'proxima: nenhuma, caso completo'
else echo 'proxima: nenhuma fase, mas validate reprova: rode open-debate validate'; fi
defasados "$CASE_DIR" | sed 's/^/aviso: /'
M="$CASE_DIR/raw/metricas.tsv"
if [ -s "$M" ]; then
  awk -F'\t' '{ n++; s += $3; rep += ($1 ~ /reparo/); if ($3 > m) { m = $3; q = $1 } } END { printf "custo: %d chamadas, %d s de modelo, %d reparo(s); a mais lenta foi %s (%d s)\n", n, s, rep, q, m }' "$M"
fi
