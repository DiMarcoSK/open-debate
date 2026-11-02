#!/bin/sh
# modelos.sh check|aplicar|livres - modelos dos agents do debate contra os gratuitos do opencode.
# check: mostra agent, modelo e se esta disponivel e gratis. aplicar: grava modelos.conf nos agents,
# trocando indisponivel pela reserva e, sem reserva, pelo 1o gratuito. livres: lista os gratuitos.
set -eu
export LC_ALL=C
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
CONF="$SCRIPT_DIR/../modelos.conf"
AGENTS="${OPENCODE_AGENTS:-$SCRIPT_DIR/../../../agents}"
command -v opencode >/dev/null 2>&1 || { echo "erro: opencode nao encontrado" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "erro: jq nao encontrado" >&2; exit 2; }

LIVRES="$(opencode models opencode --verbose 2>/dev/null | grep -v '^[a-z0-9.-]*/[^ ]*$' \
  | jq -r 'select(.cost.input == 0 and .cost.output == 0 and .capabilities.toolcall and .status != "deprecated") | .providerID + "/" + .id' 2>/dev/null || true)"
[ -n "$LIVRES" ] || { echo "erro: nenhum modelo gratuito listado (rode: opencode models --refresh)" >&2; exit 2; }
livre() { printf '%s\n' "$LIVRES" | grep -qx -- "$1"; }
conf() { sed -n "s/^$1=//p" "$CONF" | head -1; }

case "${1:-check}" in
  livres) printf '%s\n' "$LIVRES" ;;
  check)
    rc=0
    for f in "$AGENTS"/debate*.md; do
      a="$(basename "$f" .md)"; m="$(sed -n 's/^model: //p' "$f" | head -1)"
      if livre "$m"; then printf 'ok    %-16s %s\n' "$a" "$m"; else printf 'FORA  %-16s %s (indisponivel ou pago)\n' "$a" "$m"; rc=1; fi
    done
    exit "$rc" ;;
  aplicar)
    reserva="$(conf reserva)"; primeiro="$(printf '%s\n' "$LIVRES" | head -1)"
    for f in "$AGENTS"/debate*.md; do
      a="$(basename "$f" .md)"; m="$(conf "$a")"; [ -n "$m" ] || continue
      if ! livre "$m"; then
        if [ -n "$reserva" ] && livre "$reserva"; then m="$reserva"; else m="$primeiro"; fi
        printf 'troca %s: %s -> %s\n' "$a" "$(conf "$a")" "$m"
      fi
      sed "s#^model: .*#model: $m#" "$f" > "$f.tmp" && mv "$f.tmp" "$f"
      printf 'ok    %-16s %s\n' "$a" "$m"
    done ;;
  *) echo "uso: modelos.sh check|aplicar|livres" >&2; exit 2 ;;
esac
