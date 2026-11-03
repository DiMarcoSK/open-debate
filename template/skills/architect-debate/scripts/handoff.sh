#!/bin/sh
# handoff.sh <case> [agent] - after the debate, from specification to building. Writes <case>/HANDOFF.md, the build loop
# over BACKLOG.md and its cards. Inside an opencode session (OPENCODE_SESSION_ID set by opencode's shell tool), it switches
# the session to the build agent (default build) and queues the kickoff, so building starts when the debate turn ends.
# Prints the next item and "agent: switched <agent>, kickoff queued", "agent: switched <agent>" or "agent: manual".
set -eu
export LC_ALL=C
CASE_DIR="${1:?usage: handoff.sh <case> [agent]}"
AGENT="${2:-build}"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
B="$CASE_DIR/BACKLOG.md"
[ -s "$B" ] || { echo "error: $B missing: the backlog phase comes first" >&2; exit 2; }
CASE="$(CDPATH= cd -- "$CASE_DIR" && pwd)"
title="$(sed -n '1s/^# *Backlog *-* *//p' "$B")"; title="${title:-the product}"
next="$(awk -v mode=tsv -f "$SCRIPT_DIR/backlog.awk" "$B" | awk -F'\t' '$12 == "open" && $2 != "Post-launch" { print $1 " " $4; exit }')"
path="$(awk -v mode=summary -f "$SCRIPT_DIR/backlog.awk" "$B" | sed -n 's/^Critical path/Critical path/p')"
opt() { [ ! -e "$CASE/$1" ] || printf -- '- %s: %s\n' "$1" "$2"; }

{
  printf '# Hand-off - %s\n\n' "$title"
  printf 'The debate is over; this file turns the case into working software. Code goes in the project, outside the case folder: the case is the specification.\n\n'
  printf 'Case: %s\n' "$CASE"
  printf 'Next item: %s\n' "${next:-none open, the backlog is done}"
  [ -z "$path" ] || printf '%s\n' "$path"
  printf '\n## Read first\n\n'
  printf -- '- brief.md, SDD.md and adr/: what is being built and the decisions already made\n'
  printf -- '- BACKLOG.md: order, estimates, dependencies and the Definition of Done\n'
  opt BACKLOG-DETAILED.md 'the card of each item: what to build and how'
  opt specs 'requirements, plan and tasks per feature'
  opt tokens.css 'the only source of color, type and spacing in the code'
  opt BRANDBOOK.md 'logo, voice and every key screen adapted to the brand'
  cat <<'EOF'

## Loop, 1 item at a time

1. Take the first open item of BACKLOG.md (`- [ ]`) whose dependencies are all done (`- [x]`).
2. Read its card and the spec tasks it cites. Build only what the item says.
3. Write the card's Test with the code; run it and the existing suite until they pass.
4. Check the card's Done when and the Definition of Done of BACKLOG.md.
5. Mark the item `- [x]` and append `[verified YYYY-MM-DD: <how it was checked>]`.
6. Commit with the message `<Bnn> <item title>`.

At the end of each phase of BACKLOG.md, stop and show what its Demo line promises.

## Stop and ask when

- the item needs a decision no ADR covers, or goes against an ADR
- the card is wrong or incomplete: fix the card after the answer, then the code
- a step needs credentials, payment or access you do not have
EOF
} > "$CASE/HANDOFF.md"

printf 'HANDOFF.md: %s\n' "$CASE/HANDOFF.md"
printf 'next: %s\n' "${next:-none}"

# opencode 2.x keeps the agent per session on its server: switching there is what Tab does in the TUI.
state=manual
if [ -n "${OPENCODE_SESSION_ID:-}" ] && command -v opencode >/dev/null 2>&1; then
  if opencode api session.switchAgent --param "sessionID=$OPENCODE_SESSION_ID" --data "{\"agent\":\"$AGENT\"}" > /dev/null 2>&1; then
    state="switched $AGENT"
    kick="Build $title from the debate case: read $CASE/HANDOFF.md and follow it, starting at ${next:-the first open item}."
    body="$(jq -cn --arg t "$kick" '{text: $t, delivery: "queue"}' 2>/dev/null || true)"
    if [ -n "$body" ] && opencode api session.prompt --param "sessionID=$OPENCODE_SESSION_ID" --data "$body" > /dev/null 2>&1; then
      state="$state, kickoff queued"
    fi
  fi
fi
printf 'agent: %s\n' "$state"
