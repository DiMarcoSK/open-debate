#!/bin/sh
# models.sh check|apply|repair|free|profile <free|mixed|strong> [model]|next <case> <agent> [failed-model] - models of the debate agents in opencode.
# Profile (models.conf): free = only zero-cost models (spends 0, shallower opinions); mixed = the `strong` model only on the
# seats that decide (orchestrator, judge, auditor, architecture), the rest free; strong = `strong` everywhere (more tokens).
# check: agent, model and state. apply: writes the profile into the agents. repair: swaps only what left the catalog.
# Rotation: a free model that leaves the catalog becomes the spare and, without one, a distinct free model per agent
# (round-robin), so the panel does not all land on one model and fight over one limit.
# next: session-mode fallback. Records the model that ran out of quota (default: the agent's) in <case>/raw/exhausted-models
# and prints the next one to pass in the subagent call: the `fallback` list, the spare, the strong model on a paid profile,
# then every free model of the catalog, starting at a different one per agent. Exits 1 only when none is left.
set -eu
export LC_ALL=C
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
CONF="$SCRIPT_DIR/../models.conf"
AGENTS="${OPENCODE_AGENTS:-$SCRIPT_DIR/../../../agents}"
DECIDERS="debate debate-judge debate-auditor debate-arch"
command -v opencode >/dev/null 2>&1 || { echo "error: opencode not found" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "error: jq not found" >&2; exit 2; }

CATALOG="$(opencode models --verbose 2>/dev/null || true)"
FREE="$(printf '%s\n' "$CATALOG" | grep -v '^[a-z0-9.-]*/[^ ]*$' \
  | jq -r 'select(.cost.input == 0 and .cost.output == 0 and .capabilities.toolcall and .status != "deprecated") | .providerID + "/" + .id' 2>/dev/null || true)"
ALL="$(printf '%s\n' "$CATALOG" | grep '^[a-z0-9.-]*/[^ ]*$' || true)"
[ -n "$FREE" ] || { echo "error: no free model listed (run: opencode models --refresh)" >&2; exit 2; }
is_free() { printf '%s\n' "$FREE" | grep -qx -- "$1"; }
exists() { is_free "$1" || printf '%s\n' "$ALL" | grep -qx -- "$1"; }
conf() { sed -n "s#^$1=##p" "$CONF" | head -1; }
PROFILE="$(conf profile)"; PROFILE="${PROFILE:-free}"
STRONG="$(conf strong)"

# wanted <agent>: the model the profile asks for the agent.
wanted() {
  case "$PROFILE" in
    strong) printf '%s' "$STRONG"; return ;;
    mixed) case " $DECIDERS " in *" $1 "*) printf '%s' "$STRONG"; return ;; esac ;;
  esac
  conf "$1"
}

# replacement <index>: the free spare or the n-th free model of the catalog, round-robin.
replacement() {
  r="$(conf spare)"
  if [ -n "$r" ] && is_free "$r" && [ "$1" -eq 0 ]; then printf '%s' "$r"; return; fi
  n="$(printf '%s\n' "$FREE" | wc -l | tr -d ' ')"
  printf '%s\n' "$FREE" | sed -n "$(( $1 % n + 1 ))p"
}

write() { # write <mode>: apply rewrites everything; repair only swaps a model that left the catalog.
  i=0
  for f in "$AGENTS"/debate*.md; do
    a="$(basename "$f" .md)"; cur="$(sed -n 's/^model: //p' "$f" | head -1)"
    if [ "$1" = "repair" ]; then
      if exists "$cur"; then continue; fi
      m="$(conf "$a")"
    else
      m="$(wanted "$a")"
    fi
    [ -n "$m" ] || continue
    if ! exists "$m"; then
      s="$(replacement "$i")"; i=$((i + 1))
      printf 'swap  %s: %s -> %s (not in the catalog)\n' "$a" "$m" "$s"; m="$s"
    fi
    sed "s#^model: .*#model: $m#" "$f" > "$f.tmp" && mv "$f.tmp" "$f"
    printf 'ok    %-16s %s\n' "$a" "$m"
  done
}

# next_model <case> <agent> [failed-model]
next_model() {
  f="$AGENTS/$2.md"; [ -f "$f" ] || { echo "error: unknown agent: $2" >&2; exit 2; }
  failed="${3:-$(sed -n 's/^model: //p' "$f" | head -1)}"
  x="$1/raw/exhausted-models"; mkdir -p "$1/raw"
  now="$(date +%s)"
  printf '%s %s\n' "$now" "$failed" >> "$x"
  # Quotas reset: an entry older than 6 h no longer counts.
  gone="$(awk -v t="$((now - 21600))" '$1 >= t { print $2 }' "$x")"
  k="$(ls "$AGENTS"/debate*.md | grep -n "/$2\.md\$" | cut -d: -f1)"
  list="$(conf fallback) $(conf spare)"
  [ "$PROFILE" = "free" ] || list="$list $STRONG"
  list="$list $(printf '%s\n' "$FREE" | awk -v k="${k:-0}" '{ l[NR] = $0 } END { for (j = 0; j < NR; j++) print l[(j + k) % NR + 1] }')"
  for m in $list; do
    if printf '%s\n' "$gone" | grep -qxF -- "$m"; then continue; fi
    exists "$m" || continue
    printf '%s\n' "$m"; return 0
  done
  echo "none left: every model is out of quota; wait for the limit to reset or add a paid one: open-debate models profile mixed <provider/model>" >&2
  exit 1
}

case "${1:-check}" in
  free) printf '%s\n' "$FREE" ;;
  next) next_model "${2:?usage: models.sh next <case> <agent> [failed-model]}" "${3:?usage: models.sh next <case> <agent> [failed-model]}" "${4:-}" ;;
  check)
    rc=0; printf 'profile %s%s\n' "$PROFILE" "${STRONG:+, strong=$STRONG}"
    for f in "$AGENTS"/debate*.md; do
      a="$(basename "$f" .md)"; m="$(sed -n 's/^model: //p' "$f" | head -1)"
      if is_free "$m"; then printf 'ok    %-16s %s\n' "$a" "$m"
      elif exists "$m"; then printf 'paid  %-16s %s\n' "$a" "$m"
      else printf 'GONE  %-16s %s (left the catalog: open-debate models apply)\n' "$a" "$m"; rc=1; fi
    done
    exit "$rc" ;;
  apply) write apply ;;
  repair) write repair ;;
  profile)
    p="${2:-}"; m="${3:-$STRONG}"
    case "$p" in free|mixed|strong) ;; *) echo "usage: models.sh profile free|mixed|strong [provider/model]" >&2; exit 2 ;; esac
    if [ "$p" != "free" ]; then
      [ -n "$m" ] || { echo "error: profile $p needs the strong model, ex: models.sh profile $p anthropic/claude-sonnet-5-5 (list: opencode models)" >&2; exit 2; }
      exists "$m" || { echo "error: $m is not in the opencode catalog (list: opencode models)" >&2; exit 2; }
    fi
    grep -Ev '^(profile|strong)=' "$CONF" > "$CONF.tmp" || true
    { printf 'profile=%s\nstrong=%s\n' "$p" "$m"; cat "$CONF.tmp"; } > "$CONF"; rm -f "$CONF.tmp"
    PROFILE="$p"; STRONG="$m"; write apply ;;
  *) echo "usage: models.sh check|apply|repair|free|profile <free|mixed|strong> [model]|next <case> <agent> [failed-model]" >&2; exit 2 ;;
esac
