#!/bin/sh
# probe.sh <harness> [model] - 1 real, cheap call through the adapter. Proves login, flags and text extraction.
set -eu
H="${1:?usage: probe.sh <harness> [model]}"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
TIMEOUT="${TIMEOUT:-120}"
TO="perl -e alarm(shift);exec(@ARGV)||die $TIMEOUT"
. "$SCRIPT_DIR/harness.sh"
h_exists "$H"
D="$(mktemp -d)"; trap 'rm -rf "$D"' EXIT
i="$(date +%s)"
if h_run "$H" debate-pm "Reply with the single word READY. Do not use tools." "${2:-}" "$D" "$D/raw" && h_text "$H" "$D/raw" "$D/txt" && grep -qi ready "$D/txt"; then
  printf 'ok    %-9s real call in %ss\n' "$H" "$(($(date +%s) - i))"
else
  printf 'FAIL  %-9s real call: %s\n' "$H" "$(tail -3 "$D/raw.stderr" "$D/raw" 2>/dev/null | tr '\n' ' ' | cut -c1-300)"
  exit 1
fi
