#!/bin/sh
# gate.sh <caso> <fase> [agent...] - gate de 1 fase para o orquestrador do modo sessao.
# Fases: brief pesquisa proposta ataque decisao sdd specs trilhas backlog. Imprime OK/REPROVADO por arquivo, sai 1 se algo reprovou.
# decisao aprovada separa os ADRs em adr/; sdd aprovado gera style-tile.html, tokens.json e tokens.css;
# backlog aprovado exporta backlog.csv, backlog.json e backlog-gh.sh.
set -eu
export LC_ALL=C
CASE_DIR="${1:?uso: gate.sh <caso> <fase> [agent...]}"
FASE="${2:?uso: gate.sh <caso> <fase> [agent...]}"
shift 2
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
TOK="$SCRIPT_DIR/tokens.awk"
. "$SCRIPT_DIR/gates.sh"
PAINEL="${*:-$(sed -n 's/^painel: //p' "$CASE_DIR/meta.txt" 2>/dev/null | tail -1)}"
PAINEL="${PAINEL:-debate-arch debate-design debate-gcp debate-k8s}"
FAIL=0
um() {
  r="$(check "$1" "$2" "$3")"
  if [ -z "$r" ]; then printf 'OK %s %s\n' "$1" "${3#"$CASE_DIR"/}"
  else printf 'REPROVADO %s %s %s: %s\n' "$1" "$2" "${3#"$CASE_DIR"/}" "$r"; FAIL=1; fi
}
case "$FASE" in
  brief) "$SCRIPT_DIR/validate.sh" "$CASE_DIR" --brief || FAIL=1 ;;
  pesquisa) um pesquisa debate-research "$CASE_DIR/research.md" ;;
  proposta) for a in $PAINEL; do um proposta "$a" "$CASE_DIR/proposals/$a.md"; done ;;
  ataque) for a in $PAINEL; do um ataque "$a" "$CASE_DIR/critiques/$a.md"; done ;;
  decisao)
    um decisao debate-judge "$CASE_DIR/decision.md"
    [ "$FAIL" -eq 0 ] && printf 'ADRs: %s em adr/\n' "$(split_adrs "$CASE_DIR")" ;;
  sdd)
    um sdd debate-judge "$CASE_DIR/SDD.md"
    [ "$FAIL" -eq 0 ] && "$SCRIPT_DIR/style-tile.sh" "$CASE_DIR" ;;
  specs) "$SCRIPT_DIR/validate.sh" "$CASE_DIR" || FAIL=1 ;;
  trilhas) um trilha debate-design "$CASE_DIR/backlog/design.md"; um trilha debate-arch "$CASE_DIR/backlog/eng.md" ;;
  backlog)
    um backlog debate-pm "$CASE_DIR/BACKLOG.md"
    [ "$FAIL" -eq 0 ] && "$SCRIPT_DIR/backlog-export.sh" "$CASE_DIR" ;;
  *) echo "fase desconhecida: $FASE" >&2; exit 2 ;;
esac
exit "$FAIL"
