#!/bin/sh
# debate.sh <case-dir> [rounds] - the whole protocol: research, agenda, proposal, critique, fact-check, rebuttal, judge, ADRs, SDD, audit, specs, backlog.
# A failed gate gets 1 repair with the reason (REPAIR=1); fails again, aborts. Running again resumes.
# Each specialist runs as an isolated process on the chosen harness. opencode free models refuse headless calls:
# with them use /debate inside opencode (session mode, subagents).
# Every artifact is written in English, whatever the language of the idea and the brief.
# Env: HARNESS=opencode, MODEL (empty = harness default), RETRIES=2, TIMEOUT=600, MIN_LINES=5,
#      MODEL_FALLBACK="model harness:model harness:" (tried in order when a model runs out of quota or keeps hitting the
#      rate limit; then the other MIX harnesses and HARNESS; the run fails only when none is left),
#      BACKOFF=20 (s, doubles on every wait), PARALLEL=6 (simultaneous calls, 0 = no cap), MAX_CALLS=0 (run cap, 0 = no cap),
#      FROM=<phase> (archives that phase and the later ones in raw/archive and redoes them),
#      FRESH=0, AGENDA=1, REVIEW=1, RESEARCH=1, FACTCHECK=1, SPECS=1, REPAIR=1,
#      PANEL="debate-arch debate-ux debate-pm debate-design" (empty = meta.txt or picked by the brief; debate-arch, debate-ux and debate-pm always join),
#      MIX="claude codex" (panel spread across harnesses), ROUTES="debate-arch=claude debate-design=codex:gpt-5" (route per agent),
#      HARNESS_CMD (HARNESS=custom: a command that reads $PROMPT and $MODEL and prints the answer).
set -eu
export LC_ALL=C

CASE_DIR="${1:?usage: debate.sh <case-dir> [rounds]}"
ROUNDS="${2:-3}"
MODEL="${MODEL:-}"
MODEL_FALLBACK="${MODEL_FALLBACK:-}"
RETRIES="${RETRIES:-2}"
TIMEOUT="${TIMEOUT:-600}"
MIN_LINES="${MIN_LINES:-5}"
BACKOFF="${BACKOFF:-20}"
PARALLEL="${PARALLEL:-6}"
MAX_CALLS="${MAX_CALLS:-0}"
FROM="${FROM:-}"
FRESH="${FRESH:-0}"
AGENDA="${AGENDA:-1}"
REVIEW="${REVIEW:-1}"
RESEARCH="${RESEARCH:-1}"
FACTCHECK="${FACTCHECK:-1}"
REPAIR="${REPAIR:-1}"
SPECS="${SPECS:-1}"
HARNESS="${HARNESS:-opencode}"
MIX="${MIX:-}"
ROUTES="${ROUTES:-}"

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REF="$SCRIPT_DIR/../references"
TOK="$SCRIPT_DIR/tokens.awk"
. "$SCRIPT_DIR/gates.sh"
. "$SCRIPT_DIR/harness.sh"

# Panel: the one asked for, the one saved in the case or what the brief triggers in panel.conf. The base seats always join.
AUTO=0; [ -n "${PANEL:-}" ] || grep -q '^panel: ' "$CASE_DIR/meta.txt" 2>/dev/null || AUTO=1
ASKED="${PANEL:-$(case_panel "$CASE_DIR")}"
PANEL="$(with_base "$ASKED")"
ADDED=""; for b in $PANEL_BASE; do case " $ASKED " in *" $b "*) ;; *) ADDED="$ADDED $b" ;; esac; done

case "$ROUNDS" in ''|*[!0-9]*) ROUNDS=3;; esac
[ "$ROUNDS" -gt 3 ] && ROUNDS=3
[ "$ROUNDS" -lt 1 ] && ROUNDS=1

command -v jq >/dev/null 2>&1 || { echo "error: jq not found on PATH" >&2; exit 2; }
command -v perl >/dev/null 2>&1 || { echo "error: perl not found on PATH (used for the timeout)" >&2; exit 2; }
[ -f "$CASE_DIR/constitution.md" ] || { echo "error: $CASE_DIR/constitution.md missing, run new-debate.sh" >&2; exit 2; }
"$SCRIPT_DIR/validate.sh" "$CASE_DIR" --brief >&2 || { echo "error: brief failed, fill $CASE_DIR/brief.md" >&2; exit 2; }
n=0; for a in $PANEL; do
  n=$((n + 1))
  [ -f "$SCRIPT_DIR/../personas/$a.md" ] || { echo "error: unknown persona on the panel: $a" >&2; exit 2; }
done
[ "$n" -ge 2 ] || { echo "error: PANEL needs 2+ agents" >&2; exit 2; }
PHASES="research agenda proposal critique factcheck rebuttal decision sdd brand specs backlog"
if [ -n "$FROM" ]; then
  case " $PHASES " in *" $FROM "*) ;; *) echo "error: invalid --from: $FROM ($PHASES)" >&2; exit 2 ;; esac
fi
# A legacy case resumed as is would fail every gate on its Portuguese headings; redone from research it works.
if legacy_case "$CASE_DIR"; then
  [ "$FROM" = "research" ] || { echo "error: $LEGACY_HINT" >&2; exit 2; }
  rm -f "$CASE_DIR/regras-debate.md"
fi

# Mix: 1 harness at a time around the panel. Explicit ROUTES win.
if [ -n "$MIX" ]; then
  set -- $MIX; i=0; n_m="$#"; distrib=""
  for a in $PANEL; do
    i=$((i + 1)); j=$(( (i - 1) % n_m + 1 )); eval "h=\${$j}"
    distrib="$distrib $a=$h"
  done
  ROUTES="${distrib# } $ROUTES"
fi

# route <agent>: prints "<harness> <model>"; the model may be empty.
route() {
  r=""
  for x in $ROUTES; do case "$x" in "$1="*) r="${x#*=}" ;; esac; done
  [ -n "$r" ] || { printf '%s %s' "$HARNESS" "$MODEL"; return; }
  case "$r" in
    *:*) printf '%s %s' "${r%%:*}" "${r#*:}" ;;
    *) printf '%s ' "$r" ;;
  esac
}

h_exists "$HARNESS"
for x in $ROUTES; do r="${x#*=}"; h_exists "${r%%:*}"; done
for x in $MODEL_FALLBACK; do case "$x" in *:*) h_exists "${x%%:*}" ;; esac; done

# macOS has no timeout(1); perl alarm kills a call stuck in an endless provider retry.
TO="perl -e alarm(shift);exec(@ARGV)||die $TIMEOUT"

OUT="$(CDPATH= cd -- "$CASE_DIR" && pwd)"
mkdir -p "$OUT/raw"

# Lock: 2 runs on the same case overwrite each other's outputs. A dead run's lock is taken over.
LOCK="$OUT/raw/.lock"
if ! mkdir "$LOCK" 2>/dev/null; then
  owner="$(cat "$LOCK/pid" 2>/dev/null || true)"
  if [ -n "$owner" ] && kill -0 "$owner" 2>/dev/null; then echo "error: case already running in process $owner" >&2; exit 2; fi
  rm -rf "$LOCK"; mkdir "$LOCK"
fi
printf '%s\n' "$$" > "$LOCK/pid"

PIDFILE="$OUT/raw/pids.$$"
FAILS="$OUT/raw/fails.$$"
CALLS="$OUT/raw/calls.$$"
# Routes that ran out of quota in this run, 1 "harness|model" per line: the next calls skip them instead of failing again.
EXHAUSTED="$OUT/raw/exhausted.$$"
METRICS="$OUT/raw/metrics.tsv"
SUMMARY="$OUT/raw/summary.log"
START="$(date +%s)"
: > "$PIDFILE"; : > "$FAILS"; : > "$CALLS"; : > "$EXHAUSTED"

# Kill the whole tree: without job control, a background call ignores SIGINT and would keep spending after Ctrl-C.
kill_tree() {
  for child in $(pgrep -P "$1" 2>/dev/null || true); do kill_tree "$child"; done
  kill "$1" 2>/dev/null || true
}
interrupt() {
  trap - INT TERM
  [ -z "$FG" ] || kill_tree "$FG"
  while read -r vp vd; do [ -z "$vp" ] || kill_tree "$vp"; done < "$PIDFILE"
  printf 'INTERRUPTED: running again resumes\n' | tee -a "$SUMMARY"
  exit 130
}
FG=""; MINIMUM=""
cleanup() { rm -rf "$LOCK" "$OUT/raw/rooms"; rm -f "$PIDFILE" "$FAILS" "$CALLS" "$EXHAUSTED"; }
trap cleanup EXIT
trap interrupt INT TERM

# archive_from <phase>: moves that phase and the later ones to raw/archive/<date>. Nothing is deleted, an edited spec stays there.
archive_from() {
  a_dest="$OUT/raw/archive/$(date -u +%Y%m%dT%H%M%SZ)"; a_on=0
  for g in $PHASES; do
    [ "$g" = "$1" ] && a_on=1
    [ "$a_on" = "1" ] || continue
    case "$g" in
      research) l="research.md" ;;
      agenda) l="agenda.md" ;;
      proposal) l="proposals" ;;
      critique) l="critiques" ;;
      factcheck) l="research-check.md" ;;
      rebuttal) l="$(cd "$OUT" && ls proposals/*-r2.md 2>/dev/null || true)" ;;
      decision) l="decision.md adr" ;;
      sdd) l="SDD.md audit.md style-tile.html tokens.json tokens.css" ;;
      brand) l="BRANDBOOK.md" ;;
      specs) l="specs checklists" ;;
      backlog) l="backlog BACKLOG.md backlog.csv backlog.json backlog-gh.sh" ;;
    esac
    for x in $l; do
      [ -e "$OUT/$x" ] || continue
      mkdir -p "$a_dest/$(parent "$x")"; mv "$OUT/$x" "$a_dest/$x"
    done
  done
  printf 'archived in %s, redoing from %s\n' "${a_dest#"$OUT"/}" "$1" | tee -a "$SUMMARY"
}
[ -z "$FROM" ] || archive_from "$FROM"

mkdir -p "$OUT/proposals" "$OUT/critiques" "$OUT/adr"
for t in debate-rules.md visual-contract.md research-template.md agenda-template.md adr-template.md backlog-template.md polish.md sdd-template.md spec-template.md plan-template.md tasks-template.md audit-template.md brandbook-template.md; do
  [ -f "$OUT/$t" ] || cp "$REF/$t" "$OUT/$t"
done
{ grep -v '^panel:\|^harness:\|^rounds:' "$OUT/meta.txt" 2>/dev/null || true; printf 'panel: %s\nharness: %s\nrounds: %s\n' "$PANEL" "$HARNESS" "$ROUNDS"; } > "$OUT/meta.txt.tmp"
mv "$OUT/meta.txt.tmp" "$OUT/meta.txt"

printf '\n== %s rounds=%s harness=%s routes=%s panel=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$ROUNDS" "$HARNESS" "$ROUTES" "$PANEL" >> "$SUMMARY"

log() { printf '%s\n' "$*" | tee -a "$SUMMARY"; }
abort() { log "ABORT: $*"; exit 1; }

stale "$OUT" | while IFS= read -r d; do log "warning: $d; use --from to redo what depends on it"; done
[ -z "$ADDED" ] || log "panel: base seat added:$ADDED"
if [ "$AUTO" = "1" ]; then
  panel_reasons "$OUT" | while IFS= read -r x; do
    if on_panel "${x%%:*}"; then log "panel: ${x%%:*} from the brief (${x#*: })"; fi
  done
fi
data="$(sed -n 's/^- Sensitive data[^:]*:[[:space:]]*//p' "$OUT/brief.md" | tr '[:upper:]' '[:lower:]')"
if ! on_panel debate-sec && printf '%s' "$data" | grep -Eq 'lgpd|gdpr|ccpa|pci|hipaa|health|saude|personal|pessoa|pii|cpf|ssn|financ' && ! printf '%s' "$data" | grep -Eq '^(no|none|not|without|nao|nenhum|sem) '; then
  log "warning: brief with regulated data and no debate-sec on the panel; consider --panel arch,design,sec"
fi

# The file comes from the returned text. Without this line, the agent tries to write, gets a permission denial and replies with a permission request.
OUTPUT='OUTPUT: in this run you do not write files: do not use Write or Edit. Your whole final answer is the content of the requested file, with no comment before or after and no code fence around it. Write it in English, whatever the language of the brief.'

run_once() {
  agent="$1"; task="$2"; dest="$3"; raw="$4"; h="$5"; m="$6"
  rc=0; h_run "$h" "$agent" "$task. $OUTPUT" "$m" "${ROOM:-$OUT}" "$raw.tmp" || rc=$?
  if [ "$rc" -eq 142 ]; then log "timed out in $agent after ${TIMEOUT}s: raise TIMEOUT and run again"; fi
  [ "$rc" -eq 0 ] || return 1
  h_text "$h" "$raw.tmp" "$dest.new" || return 1
  [ "$(wc -l < "$dest.new" | tr -d ' ')" -ge "${MINIMUM:-$MIN_LINES}" ] || return 1
  mv "$dest.new" "$dest"
  mv "$raw.tmp" "$raw"
}

call_fits() {
  printf 'x\n' >> "$CALLS"
  [ "$MAX_CALLS" -gt 0 ] || return 0
  [ "$(wc -l < "$CALLS" | tr -d ' ')" -le "$MAX_CALLS" ] && return 0
  log "MAX_CALLS=$MAX_CALLS cap reached at $agent"; return 1
}

# candidates <agent>: "harness|model" per word, in the order they are tried: the agent's route, MODEL_FALLBACK
# (a bare model stays on the route's harness), then the other harnesses of MIX and HARNESS with its MODEL. No repeats.
candidates() {
  r0="$(route "$1")"; h0="${r0%% *}"
  {
    printf '%s|%s\n' "$h0" "${r0#* }"
    for x in $MODEL_FALLBACK; do
      case "$x" in *:*) printf '%s|%s\n' "${x%%:*}" "${x#*:}" ;; *) printf '%s|%s\n' "$h0" "$x" ;; esac
    done
    for x in $MIX; do printf '%s|\n' "$x"; done
    printf '%s|%s\n' "$HARNESS" "$MODEL"
  } | awk '!seen[$0]++'
}

# try_agent: RETRIES attempts per candidate. Quota or login failure: the candidate is marked exhausted for the run
# and the next one takes over at once. A rate limit waits with backoff and, if it persists, moves on too.
# The call fails only when no candidate is left.
try_agent() {
  agent="$1"; task="$2"; dest="$3"; raw="$4"
  tries=0; used=""; tried=""
  for c in $(candidates "$agent"); do
    if grep -qxF -- "$c" "$EXHAUSTED"; then continue; fi
    h="${c%%|*}"; m="${c#*|}"; used="$h${m:+:$m}"
    [ -z "$tried" ] || log "fallback in $agent: trying $used"
    tried="$tried $used"
    n=1
    while [ "$n" -le "$RETRIES" ]; do
      tries=$((tries + 1))
      call_fits || return 1
      run_once "$agent" "$task" "$dest" "$raw" "$h" "$m" && return 0
      if h_auth_failed "$raw.tmp"; then
        printf '%s\n' "$c" >> "$EXHAUSTED"
        log "auth or quota error in $agent on $used: skipped for the rest of the run"
        continue 2
      fi
      if h_limit_failed "$raw.tmp"; then
        if [ "$n" -ge "$RETRIES" ]; then log "rate limit in $agent on $used persists"; continue 2; fi
        # Wait only on what waiting fixes; the jitter spreads calls of the same wave, which hit the limit together.
        e=$((BACKOFF * (1 << (n - 1)) + ($(date +%s) + ${#dest}) % (BACKOFF / 4 + 1)))
        log "rate limit in $agent ($h), retrying in ${e}s"
        sleep "$e"
      fi
      n=$((n + 1))
    done
  done
  rm -f "$dest.new"
  case "$tried" in
    '') log "FAILED $dest: every model is exhausted in this run; set MODEL_FALLBACK or MIX with another provider" ;;
    *) log "FAILED $dest after trying${tried}, see $raw.tmp.stderr" ;;
  esac
  case " $tried " in *" opencode"*) log "hint: opencode free models only run in session (/debate), not headless" ;; esac
  return 1
}

# agent_call <agent> <task> <dest> <raw>: 1 line in raw/metrics.tsv per logical call.
agent_call() {
  t0="$(date +%s)"; rc2=0; tries=0; used=""
  try_agent "$@" || rc2=$?
  b4="${4##*/}"
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "${b4%.json}" "$1" "$(($(date +%s) - t0))" "$tries" "$rc2" "${used%%:*}" >> "$METRICS"
  return "$rc2"
}

# A single-agent call. It runs in the background because the shell only handles signals outside a foreground command:
# with `wait`, an interrupt does not have to wait for the call to finish.
run_agent() {
  agent_call "$@" &
  FG="$!"; rcf=0
  wait "$FG" || rcf=$?
  FG=""
  return "$rcf"
}

need() { [ "$FRESH" = "1" ] || [ ! -s "$1" ]; }

# slot: holds the wave at PARALLEL simultaneous calls, waiting for the oldest to finish.
slot() {
  [ "$PARALLEL" -gt 0 ] || return 0
  while [ "$(wc -l < "$PIDFILE" | tr -d ' ')" -ge "$PARALLEL" ]; do
    read -r vp vd < "$PIDFILE"
    if wait "$vp"; then log "ok $vd"; else printf 'x\n' >> "$FAILS"; fi
    sed 1d "$PIDFILE" > "$PIDFILE.n"; mv "$PIDFILE.n" "$PIDFILE"
  done
}

launch() {
  if [ "${5:-}" = "force" ] || need "$3"; then
    slot
    agent_call "$1" "$2" "$3" "$4" &
    printf '%s %s\n' "$!" "$3" >> "$PIDFILE"
  else
    log "reuse $3"
  fi
}

wait_all() {
  failed="$(wc -l < "$FAILS" | tr -d ' ')"; : > "$FAILS"
  while read -r pid dest; do
    [ -z "$pid" ] && continue
    if wait "$pid"; then log "ok $dest"; else failed=$((failed + 1)); fi
  done < "$PIDFILE"
  : > "$PIDFILE"
  [ "$failed" -eq 0 ] || { log "$1: $failed output(s) failed"; return 1; }
}

short() { printf '%s' "${1#debate-}"; }

rivals() {
  s=""
  for r in $PANEL; do [ "$r" = "$1" ] || s="$s proposals/$r.md"; done
  printf '%s' "${s# }"
}

# room <phase> <agent> [extra]: a directory with only what the agent may read. It holds no rival proposal or critique:
# parallel calls do not leak and one agent's repair does not read another's. Rebuttal and later phases read everything, no room.
room() {
  case "$1" in
    proposal) l="visual-contract.md" ;;
    critique) l="$(rivals "$2")" ;;
    *) return 0 ;;
  esac
  sd="$OUT/raw/rooms/$1-$(short "$2")"; rm -rf "$sd"; mkdir -p "$sd"
  for x in brief.md constitution.md research.md agenda.md debate-rules.md $l ${3:-}; do
    [ -e "$OUT/$x" ] || continue
    mkdir -p "$sd/$(parent "$x")"; cp "$OUT/$x" "$sd/$x"
  done
  printf '%s' "$sd"
}

dest_for() {
  case "$1" in
    proposal) printf '%s' "$OUT/proposals/$2.md" ;;
    critique) printf '%s' "$OUT/critiques/$2.md" ;;
    rebuttal) printf '%s' "$OUT/proposals/$2-r2.md" ;;
  esac
}

task_for() {
  case "$1" in
    proposal)
      extra=""; case "$2" in debate-design|debate-ux|debate-brand) extra=", visual-contract.md" ;; esac
      printf 'phase proposal: read brief.md, constitution.md, research.md, agenda.md, debate-rules.md%s; reply only in your role'"'"'s proposal format, with the Positions section covering every Dn of agenda.md' "$extra" ;;
    critique)
      printf 'phase critique: read brief.md, research.md, agenda.md, debate-rules.md and the rival proposals %s; reply only in the critique format of debate-rules.md, copying the quote literally from the file, with file:line' "$(rivals "$2")" ;;
    rebuttal)
      printf 'phase rebuttal: read brief.md, research.md, research-check.md, debate-rules.md, proposals/%s.md, the vetoes against %s in critiques/ and the rival proposals %s; reply only in the rebuttal format of debate-rules.md' "$2" "$2" "$(rivals "$2")" ;;
  esac
}

repair() { printf '%s. FIX: your previous output in %s failed the gate: %s. Re-emit the full corrected output.' "$1" "${2#"$OUT"/}" "$3"; }

panel_phase() {
  phase="$1"; tag="$2"; who="${3:-$PANEL}"
  for a in $who; do
    ROOM="$(room "$phase" "$a")"
    launch "$a" "$(task_for "$phase" "$a")" "$(dest_for "$phase" "$a")" "$OUT/raw/$tag-$(short "$a").json"
  done
  ROOM=""
  wait_all "$phase"
}

panel_gate() {
  phase="$1"; tag="$2"; bad=""
  for a in $PANEL; do
    d="$(dest_for "$phase" "$a")"; r="$(check "$phase" "$a" "$d")"
    [ -z "$r" ] && continue
    log "gate $phase failed on ${d#"$OUT"/}: $r"
    [ "$REPAIR" = "1" ] || return 1
    bad="$bad $a"
    ROOM="$(room "$phase" "$a" "${d#"$OUT"/}")"
    launch "$a" "$(repair "$(task_for "$phase" "$a")" "$d" "$r")" "$d" "$OUT/raw/$tag-$(short "$a")-repair.json" force
  done
  ROOM=""
  [ -z "$bad" ] && { log "gate $phase ok"; return 0; }
  wait_all "$phase repair" || true
  ok=0
  for a in $bad; do
    d="$(dest_for "$phase" "$a")"; r="$(check "$phase" "$a" "$d")"
    [ -z "$r" ] || { log "gate $phase failed after repair on ${d#"$OUT"/}: $r"; ok=1; }
  done
  [ "$ok" -eq 0 ] && log "gate $phase ok after repair"
  return "$ok"
}

gate_one() {
  phase="$1"; agent="$2"; dest="$3"; task="$4"; raw="$5"
  r="$(check "$phase" "$agent" "$dest")"
  [ -z "$r" ] && { log "gate $phase ok"; return 0; }
  log "gate $phase failed: $r"
  [ "$REPAIR" = "1" ] || return 1
  run_agent "$agent" "$(repair "$task" "$dest" "$r")" "$dest" "$raw.repair" || return 1
  r="$(check "$phase" "$agent" "$dest")"
  [ -z "$r" ] && { log "gate $phase ok after repair"; return 0; }
  log "gate $phase failed after repair: $r"; return 1
}

# phase 1 - research
if [ "$RESEARCH" = "1" ]; then
  T="phase research: read brief.md and research-template.md; research the web and reply only with the full research.md in the template"
  if need "$OUT/research.md" || grep -q '^skipped' "$OUT/research.md"; then
    run_agent debate-research "$T" "$OUT/research.md" "$OUT/raw/f1-research.json" || abort "research failed (RESEARCH=0 skips it)"
  else log "reuse $OUT/research.md"; fi
  gate_one research debate-research "$OUT/research.md" "$T" "$OUT/raw/f1-research.json" || abort "research gate"
else
  [ -s "$OUT/research.md" ] || printf '# Research\n\nskipped: RESEARCH=0, a number without a source counts as an estimate\n' > "$OUT/research.md"
fi

# phase 1b - agenda: the contested decisions, before any proposal. An older case with proposals already done goes without it.
if [ "$AGENDA" != "1" ]; then
  [ -s "$OUT/agenda.md" ] || printf '# Agenda\n\nskipped: AGENDA=0\n' > "$OUT/agenda.md"
elif [ "$FRESH" != "1" ] && [ ! -s "$OUT/agenda.md" ] && [ -s "$OUT/proposals/$(set -- $PANEL; printf '%s' "$1").md" ]; then
  printf '# Agenda\n\nskipped: case older than the agenda\n' > "$OUT/agenda.md"
else
  T="phase agenda: read brief.md, constitution.md, research.md, agenda-template.md and debate-rules.md; panel: $PANEL; reply only with agenda.md"
  if need "$OUT/agenda.md"; then
    run_agent debate-judge "$T" "$OUT/agenda.md" "$OUT/raw/f1b-agenda.json" || abort "agenda failed (AGENDA=0 skips it)"
  else log "reuse $OUT/agenda.md"; fi
  gate_one agenda debate-judge "$OUT/agenda.md" "$T" "$OUT/raw/f1b-agenda.json" || abort "agenda gate"
fi

# phase 2 - blind proposal
panel_phase proposal f2 || abort "proposal phase"
panel_gate proposal f2 || abort "proposal gate"

# phases 3 and 4 - critique and fact-check
if [ "$ROUNDS" -ge 2 ]; then
  panel_phase critique f3 || abort "critique phase"
  panel_gate critique f3 || abort "critique gate"
  if [ "$FACTCHECK" = "1" ] && ! grep -q '^skipped' "$OUT/research.md"; then
    if need "$OUT/research-check.md" || grep -q '^skipped\|^failed' "$OUT/research-check.md"; then
      run_agent debate-research "phase fact-check: read research-template.md (Fact-check section), proposals/ and critiques/; reply only with the fact-check table" \
        "$OUT/research-check.md" "$OUT/raw/f4-factcheck.json" \
        || printf '# Fact-check\n\nfailed: see raw/f4-factcheck.json.tmp.stderr\n' > "$OUT/research-check.md"
    else log "reuse $OUT/research-check.md"; fi
  fi
fi
[ -s "$OUT/research-check.md" ] || printf '# Fact-check\n\nskipped: rounds=%s FACTCHECK=%s\n' "$ROUNDS" "$FACTCHECK" > "$OUT/research-check.md"

# phase 5 - rebuttal
if [ "$ROUNDS" -ge 3 ]; then
  # Without a veto against it, there is nothing to rebut: the r1 proposal stands and the call is saved.
  v="$(vetoed "$OUT")"
  if [ -n "$v" ]; then
    panel_phase rebuttal f5 "$v" || log "partial rebuttal, the judge uses r1 where it is missing"
    for a in $v; do
      d="$(dest_for rebuttal "$a")"
      if [ -s "$d" ] && ! { has "$d" 'accepted' && has "$d" 'rebutted'; }; then log "warning: rebuttal from $a without Accepted or Rebutted"; fi
    done
  else log "no veto against the panel, rebuttal skipped"; fi
fi

# phase 6 - judge, ADRs, SDD
T="phase decision: read brief.md, constitution.md, research.md, research-check.md, agenda.md, debate-rules.md, adr-template.md, proposals/ (prefer *-r2) and critiques/; reply only with decision.md"
if need "$OUT/decision.md"; then
  run_agent debate-judge "$T" "$OUT/decision.md" "$OUT/raw/f6-decision.json" || abort "judge decision"
else log "reuse $OUT/decision.md"; fi
gate_one decision debate-judge "$OUT/decision.md" "$T" "$OUT/raw/f6-decision.json" || abort "decision gate"
log "ADRs: $(split_adrs "$OUT") in adr/"

T="phase sdd: read brief.md, constitution.md, research.md, decision.md, adr/, sdd-template.md and visual-contract.md; reply only with the full SDD.md"
if need "$OUT/SDD.md"; then
  run_agent debate-judge "$T" "$OUT/SDD.md" "$OUT/raw/f6-sdd.json" || abort "judge SDD"
else log "reuse $OUT/SDD.md"; fi
gate_one sdd debate-judge "$OUT/SDD.md" "$T" "$OUT/raw/f6-sdd.json" || abort "SDD gate"

# Independent audit: the author does not catch their own omissions. Short output, and the SDD is re-emitted only on a defect.
if [ "$REVIEW" = "1" ]; then
  TA="phase audit: read SDD.md, brief.md, constitution.md, decision.md, adr/, research-check.md and audit-template.md; reply only with audit.md"
  # An approved audit is short on purpose.
  MINIMUM=1
  if need "$OUT/audit.md"; then
    if ! run_agent debate-auditor "$TA" "$OUT/audit.md" "$OUT/raw/f6-audit.json"; then
      log "audit failed, the SDD goes on without an audit"
    fi
  else log "reuse $OUT/audit.md"; fi
  if [ -s "$OUT/audit.md" ]; then
    gate_one audit debate-auditor "$OUT/audit.md" "$TA" "$OUT/raw/f6-audit.json" || abort "audit gate"
    MINIMUM=""
    if grep -q '^Verdict: FIX' "$OUT/audit.md"; then
      log "audit: $(grep -cE '^\|[ *]*A[0-9]+[ *]*\|' "$OUT/audit.md") defect(s), fixing the SDD"
      TC="phase fix: read audit.md, SDD.md, brief.md, decision.md and adr/; apply every An row and reply only with the full corrected SDD.md"
      run_agent debate-judge "$TC" "$OUT/SDD.md" "$OUT/raw/f6-sdd-fix.json" || abort "SDD fix"
      gate_one sdd debate-judge "$OUT/SDD.md" "$TC" "$OUT/raw/f6-sdd-fix.json" || abort "SDD gate after audit"
      sed 's/^Verdict: FIX/Verdict: APPLIED/' "$OUT/audit.md" > "$OUT/audit.md.n"; mv "$OUT/audit.md.n" "$OUT/audit.md"
    fi
  fi
  MINIMUM=""
fi

if "$SCRIPT_DIR/style-tile.sh" "$OUT" >> "$SUMMARY" 2>&1; then log "style tile: $OUT/style-tile.html"
else log "style tile failed, see $SUMMARY"; fi

# phase 6d - brand: the art director closes the brandbook and adapts the SDD screens to the brand. Only with debate-brand on the panel.
if on_panel debate-brand; then
  reads_b="brief.md, SDD.md, decision.md, brandbook-template.md, visual-contract.md"
  for x in proposals/debate-brand-r2.md proposals/debate-brand.md proposals/debate-design.md critiques/debate-ux.md; do
    [ -s "$OUT/$x" ] && reads_b="$reads_b, $x"
  done
  T="phase brand: read $reads_b; reply only with the full BRANDBOOK.md"
  if need "$OUT/BRANDBOOK.md"; then
    run_agent debate-brand "$T" "$OUT/BRANDBOOK.md" "$OUT/raw/f6-brand.json" || abort "brand"
  else log "reuse $OUT/BRANDBOOK.md"; fi
  gate_one brand debate-brand "$OUT/BRANDBOOK.md" "$T" "$OUT/raw/f6-brand.json" || abort "brand gate"
fi

# phase 7 - specs: 1 call per item of the decision.md index, in parallel
spec_pending() { [ ! -s "$1/spec.md" ] || grep -q '<nn>\|<slug>\|<who>' "$1/spec.md"; }
spec_task() {
  printf 'phase spec: write spec, plan and tasks for spec %s; read brief.md, SDD.md, decision.md, adr/, visual-contract.md, spec-template.md, plan-template.md and tasks-template.md; reply only with the 3 files, each opened by the line <!-- file: name -->' "${1##*/}"
}
spec_split() {
  awk -v d="$1" '
    /^<!-- file: (spec|plan|tasks)\.md -->[[:space:]]*$/ { if (f != "") close(f); n = $3; f = d "/" n; printf "" > f; next }
    f != "" { print > f }' "$2"
}
if [ "$SPECS" = "1" ]; then
  if ! ls -d "$OUT"/specs/[0-9]*/ >/dev/null 2>&1; then
    slugs="$(sed -n 's/^.*`[0-9][0-9] \([a-z0-9-]*\)`.*$/\1/p' "$OUT/decision.md")"
    # shellcheck disable=SC2086
    "$SCRIPT_DIR/make-specs.sh" "$OUT" $slugs >> "$SUMMARY"
  fi
  for d in "$OUT"/specs/[0-9]*/; do
    d="${d%/}"; b="${d##*/}"
    spec_pending "$d" && launch debate-arch "$(spec_task "$d")" "$OUT/raw/f7-$b.md" "$OUT/raw/f7-$b.json" force
  done
  wait_all "specs phase" || abort "specs phase"
  for d in "$OUT"/specs/[0-9]*/; do
    d="${d%/}"; b="${d##*/}"
    if spec_pending "$d" && [ -s "$OUT/raw/f7-$b.md" ]; then spec_split "$d" "$OUT/raw/f7-$b.md"; fi
    r="$(check spec - "$d")"
    [ -z "$r" ] && continue
    log "spec gate failed on $b: $r"
    [ "$REPAIR" = "1" ] || abort "specs gate"
    run_agent debate-arch "$(repair "$(spec_task "$d")" "raw/f7-$b.md" "$r")" "$OUT/raw/f7-$b.md" "$OUT/raw/f7-$b-repair.json" || abort "repair of spec $b"
    spec_split "$d" "$OUT/raw/f7-$b.md"
    r="$(check spec - "$d")"
    [ -z "$r" ] || abort "spec gate after repair on $b: $r"
  done
  log "specs gate ok"
fi

# phase 8 - backlog, only with filled specs
SPECS_OK=0
if ls "$OUT"/specs/[0-9]*/spec.md >/dev/null 2>&1 && ! grep -l '<nn>\|<slug>\|<who>' "$OUT"/specs/*/spec.md >/dev/null 2>&1; then SPECS_OK=1; fi
if [ "$SPECS_OK" = "1" ]; then
  mkdir -p "$OUT/backlog"
  READS="read SDD.md, adr/, specs/, polish.md and backlog-template.md"
  BB=""; [ -s "$OUT/BRANDBOOK.md" ] && BB=" and BRANDBOOK.md"
  launch debate-ux "phase backlog-design: $READS$BB; reply only with the draft items" "$OUT/backlog/design.md" "$OUT/raw/f8-design.json"
  launch debate-arch "phase backlog-eng: $READS; reply only with the draft items" "$OUT/backlog/eng.md" "$OUT/raw/f8-eng.json"
  wait_all "tracks phase" || abort "tracks phase"
  T="phase backlog: read brief.md, SDD.md, decision.md, adr/, specs/*/tasks.md, backlog/design.md, backlog/eng.md$BB, polish.md and backlog-template.md; reply only with BACKLOG.md"
  if need "$OUT/BACKLOG.md"; then run_agent debate-pm "$T" "$OUT/BACKLOG.md" "$OUT/raw/f8-backlog.json" || abort "pm backlog"; else log "reuse $OUT/BACKLOG.md"; fi
  gate_one backlog debate-pm "$OUT/BACKLOG.md" "$T" "$OUT/raw/f8-backlog.json" || abort "backlog gate"
  "$SCRIPT_DIR/backlog-export.sh" "$OUT" | tee -a "$SUMMARY"
fi

metrics() {
  [ -s "$METRICS" ] || return 0
  awk -F'\t' -v wall="$(($(date +%s) - START))" '
    { n++; s += $3; rep += ($1 ~ /repair/); ret += ($4 > 1 ? $4 - 1 : 0); if ($3 > m) { m = $3; q = $1 } }
    END { printf "time: %d s in this run; case history: %d calls, %d s of model time, %d repair(s), %d retry(ies); the slowest was %s (%d s)\n", wall, n, s, rep, ret, q, m }' "$METRICS"
}
log "$(metrics)"
log "debate ok: decision.md, adr/, SDD.md, style-tile.html$([ -s "$OUT/BRANDBOOK.md" ] && printf ', BRANDBOOK.md') in $OUT"
if [ "$SPECS_OK" = "1" ]; then log "backlog ok: BACKLOG.md, backlog.csv, backlog.json, backlog-gh.sh"
else log "next: fill the specs (make-specs.sh, with SPECS=0) and run debate.sh again for phase 8 (backlog)"; fi
