#!/bin/sh
# painel.sh <caso> [--grava] [agent...] - monta o painel do caso: assentos base (debate-arch, debate-ux, debate-pm)
# mais os opcionais que o brief aciona em references/painel.conf. Com agents, usa esses e soma a base.
# Imprime o painel na 1a linha e o motivo de cada opcional depois; --grava escreve `painel:` em meta.txt.
set -eu
export LC_ALL=C
CASE_DIR="${1:?uso: painel.sh <caso> [--grava] [agent...]}"
shift
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
TOK="$SCRIPT_DIR/tokens.awk"
. "$SCRIPT_DIR/gates.sh"
[ -f "$CASE_DIR/brief.md" ] || { echo "erro: $CASE_DIR nao e um caso" >&2; exit 2; }
GRAVA=0; PEDIDO=""
for x in "$@"; do
  case "$x" in
    --grava) GRAVA=1 ;;
    debate-*) PEDIDO="$PEDIDO $x" ;;
    *) PEDIDO="$PEDIDO debate-$x" ;;
  esac
done
if [ -n "$PEDIDO" ]; then PAINEL="$(com_base "$PEDIDO")"; else PAINEL="$(escolhe_painel "$CASE_DIR")"; fi
for a in $PAINEL; do
  [ -f "$SCRIPT_DIR/../personas/$a.md" ] || { echo "erro: persona inexistente no painel: $a" >&2; exit 2; }
done
printf 'painel: %s\n' "$PAINEL"
for b in $PAINEL_BASE; do printf '  %s: base, sempre\n' "$b"; done
motivos_painel "$CASE_DIR" | while IFS= read -r x; do
  a="${x%%:*}"
  if no_painel "$a"; then printf '  %s: brief diz "%s"\n' "$a" "${x#*: }"
  else printf '  %s: fora (brief diz "%s", teto %s ou painel pedido)\n' "$a" "${x#*: }" "$PAINEL_TETO"; fi
done
if [ -n "$PEDIDO" ]; then
  for a in $PEDIDO; do case " $PAINEL_BASE " in *" $a "*) ;; *) printf '  %s: pedido\n' "$a" ;; esac; done | sort -u
fi
if [ "$GRAVA" = "1" ]; then
  { grep -v '^painel:' "$CASE_DIR/meta.txt" 2>/dev/null || true; printf 'painel: %s\n' "$PAINEL"; } > "$CASE_DIR/meta.txt.tmp"
  mv "$CASE_DIR/meta.txt.tmp" "$CASE_DIR/meta.txt"
fi
