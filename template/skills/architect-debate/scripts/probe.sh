#!/bin/sh
# probe.sh <harness> [modelo] - 1 chamada real e barata pelo adapter. Prova login, flags e extracao de texto.
set -eu
H="${1:?uso: probe.sh <harness> [modelo]}"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
TIMEOUT="${TIMEOUT:-120}"
TO="perl -e alarm(shift);exec(@ARGV)||die $TIMEOUT"
. "$SCRIPT_DIR/harness.sh"
h_existe "$H"
D="$(mktemp -d)"; trap 'rm -rf "$D"' EXIT
i="$(date +%s)"
if h_run "$H" debate-pm "Responda apenas a palavra PRONTO. Nao use ferramentas." "${2:-}" "$D" "$D/raw" && h_texto "$H" "$D/raw" "$D/txt" && grep -qi pronto "$D/txt"; then
  printf 'ok    %-9s chamada real em %ss\n' "$H" "$(($(date +%s) - i))"
else
  printf 'FALHA %-9s chamada real: %s\n' "$H" "$(tail -3 "$D/raw.stderr" "$D/raw" 2>/dev/null | tr '\n' ' ' | cut -c1-300)"
  exit 1
fi
