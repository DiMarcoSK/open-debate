#!/bin/sh
# brainstorm.sh - the /opd-brainstorm folder and its headless run (references/brainstorm.md).
#   new "<theme>" [dest-cases]   creates <dest>/brainstorms/<slug>/ and draws the lenses and their stimuli
#   lenses <dir>                 1 line per lens: id, the file it writes and its task, for the host to delegate
#   run <dir>                    ground, ideas (1 blind call per lens, in parallel), novelty, converge, each with its gate
#   seed <dir> <Pn>              creates the debate case from the picked proposal and records the pick
# The draw comes from a seed outside the model: asked to be random, a model gives every user the same pick.
# Env: SEED (repeats a draw), LENSES="analogy outcome" (instead of the draw), NLENSES=4, PRODUCT (the product to read;
#      default the git root of the current folder, `none` without one), HARNESS=opencode, MODEL, MIX="claude codex"
#      (spreads the lenses across harnesses: another model family per lens), RETRIES=2, TIMEOUT=600, REPAIR=1, FRESH=0.
set -eu
export LC_ALL=C
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REF="$SCRIPT_DIR/../references"
TOK="$SCRIPT_DIR/tokens.awk"
PANEL=""
. "$SCRIPT_DIR/gates.sh"
usage() { sed -n '2,6s/^# \{0,1\}//p' "$0" >&2; exit 2; }
CMD="${1:-}"; [ -n "$CMD" ] || usage; shift

# ideate_task <dir> <lens>: the task line of 1 ideator call. After ground.md, each lens also starts from its own pain.
ideate_task() {
  px="$(lens_field "$2" 2)"; pn="$(pain_of "$1" "$2")"
  printf 'phase ideate: lens %s (%s), ids %s1-%s3. Move: %s Stimulus: %s.%s Read theme.md and ground.md only; never open ideas/; reply only with ideas/%s.md in the format of your persona' \
    "$(lens_field "$2" 3)" "$2" "$px" "$px" "$(lens_field "$2" 4)" "$(stimulus_of "$1" "$2")" \
    "${pn:+ Pain: start from $pn, the pain this lens owns (the other lenses own other pains); at least 1 idea anchors on it.}" "$2"
}

case "$CMD" in
  new)
    THEME="${1:?usage: brainstorm.sh new \"<theme>\" [dest-cases]}"; BASE="${2:-cases}"
    SLUG="$("$SCRIPT_DIR/new-debate.sh" --slug "$THEME")"
    OUT="$BASE/brainstorms/$SLUG"; n=2
    while [ -e "$OUT" ]; do OUT="$BASE/brainstorms/$SLUG-$n"; n=$((n + 1)); done
    seed="${SEED:-$(od -An -N4 -tu4 /dev/urandom | tr -d ' ')}"
    case "$seed" in ''|*[!0-9]*) echo "error: SEED must be a number" >&2; exit 2 ;; esac
    product="${PRODUCT:-$(git rev-parse --show-toplevel 2>/dev/null || echo none)}"
    [ "$product" = "none" ] || product="$(CDPATH= cd -- "$product" && pwd)"
    draw="$(awk -F'|' -v seed="$seed" -v want="${LENSES:-}" -v k="${NLENSES:-4}" '
      BEGIN { srand(seed) }
      /^#/ || NF < 5 { next }
      { id[++n] = $1; st[$1] = $5 }
      END {
        if (want != "") m = split(want, pick, " ")
        else {
          # analogy always sits: a far domain is the stimulus least likely to repeat across users.
          pick[1] = "analogy"; m = 1
          for (i = 1; i <= n; i++) if (id[i] != "analogy") o[++no] = id[i]
          for (i = no; i > 1; i--) { j = int(rand() * i) + 1; t = o[i]; o[i] = o[j]; o[j] = t }
          for (i = 1; i <= no && m < k; i++) pick[++m] = o[i]
        }
        for (i = 1; i <= m; i++) {
          if (!(pick[i] in st)) { print "error: unknown lens " pick[i] " (references/lenses.conf)" > "/dev/stderr"; exit 2 }
          c = split(st[pick[i]], s, ";"); printf "lens: %s | %s\n", pick[i], s[int(rand() * c) + 1]
        }
      }' "$LENSES_CONF")"
    mkdir -p "$OUT/ideas" "$OUT/raw"
    for f in ground-template.md brainstorm-template.md debate-rules.md; do cp "$REF/$f" "$OUT/$f"; done
    cat > "$OUT/theme.md" <<EOF
# Theme

$THEME

## Intake

- Who has the problem:
- What they do today:
- Hard constraint (deadline, cost ceiling or platform):
- Product: $product
EOF
    printf 'theme: %s\ndate: %s\ncases: %s\nproduct: %s\nseed: %s\n%s\n' \
      "$THEME" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$BASE" "$product" "$seed" "$draw" > "$OUT/meta.txt"
    printf '%s\n%s\n' "$OUT" "$draw" ;;

  lenses)
    B="${1:?usage: brainstorm.sh lenses <dir>}"
    [ -n "$(lenses_of "$B")" ] || { echo "error: $B has no lens in meta.txt, run brainstorm.sh new" >&2; exit 2; }
    for l in $(lenses_of "$B"); do printf '%s | writes ideas/%s.md | %s\n' "$l" "$l" "$(ideate_task "$B" "$l")"; done ;;

  run)
    B="${1:?usage: brainstorm.sh run <dir>}"
    [ -n "$(lenses_of "$B")" ] || { echo "error: $B has no lens in meta.txt, run brainstorm.sh new" >&2; exit 2; }
    command -v jq >/dev/null 2>&1 || { echo "error: jq not found on PATH" >&2; exit 2; }
    command -v perl >/dev/null 2>&1 || { echo "error: perl not found on PATH (used for the timeout)" >&2; exit 2; }
    HARNESS="${HARNESS:-opencode}"; MODEL="${MODEL:-}"; MIX="${MIX:-}"
    RETRIES="${RETRIES:-2}"; TIMEOUT="${TIMEOUT:-600}"; REPAIR="${REPAIR:-1}"; FRESH="${FRESH:-0}"
    . "$SCRIPT_DIR/harness.sh"
    h_exists "$HARNESS"; for x in $MIX; do h_exists "$x"; done
    TO="perl -e alarm(shift);exec(@ARGV)||die $TIMEOUT"
    OUT="$(CDPATH= cd -- "$B" && pwd)"
    SUMMARY="$OUT/raw/summary.log"; mkdir -p "$OUT/raw/rooms"
    log() { printf '%s\n' "$*" | tee -a "$SUMMARY"; }
    project="$(sed -n 's/^product: //p' "$OUT/meta.txt" | tail -1)"
    [ -d "$project" ] || project=none

    # inline <file...>: the case files of a call inside its prompt, so it spends no turn opening them.
    inline() {
      printf '## Case files\n\nThese files are inlined as they are now: do not open them again.\n'
      for x in "$@"; do [ -f "$OUT/$x" ] || continue; printf '\n<file path="%s">\n' "$x"; cat "$OUT/$x"; printf '</file>\n'; done
      printf '\n'
    }
    # call <agent> <task> <dest> <dir> <harness> <model> <file...>: runs in <dir> with the files inlined, RETRIES
    # attempts; the answer becomes <dest>.
    call() {
      ag="$1"; tk="$2"; de="$3"; dr="$4"; hn="$5"; mn="$6"; shift 6
      raw="$OUT/raw/$(basename "$de" .md)-$ag.json"; i=1
      while [ "$i" -le "$RETRIES" ]; do
        t0="$(date +%s)"
        if h_run "$hn" "$ag" "$tk. $OUTPUT" "$mn" "$dr" "$raw" "$(inline "$@")" && h_text "$hn" "$raw" "$de.new" \
          && [ "$(wc -l < "$de.new" | tr -d ' ')" -ge 5 ]; then
          mv "$de.new" "$de"
          # 1 line per call in raw/metrics.tsv, as debate.sh: name, agent, seconds, input and output tokens (- when unknown).
          tk_="$(h_tokens "$hn" "$raw")"
          printf '%s\t%s\t%s\t%s\t%s\n' "${de#"$OUT"/}" "$ag" "$(($(date +%s) - t0))" "${tk_% *}" "${tk_#* }" | sed 's/\t\t/\t-\t/; s/\t$/\t-/' >> "$OUT/raw/metrics.tsv"
          return 0
        fi
        i=$((i + 1))
      done
      rm -f "$de.new"; log "FAILED ${de#"$OUT"/} on $hn after $RETRIES attempt(s), see $raw.stderr"; return 1
    }
    # step <phase> <agent> <task> <dest> <dir> <harness> <model> <file...>: the call, its gate and 1 repair, which
    # gets its own previous output.
    step() {
      ph="$1"; ag="$2"; tk="$3"; de="$4"; shift 4
      if [ "$FRESH" = "1" ] || [ ! -s "$de" ]; then call "$ag" "$tk" "$de" "$@" || return 1
      else log "reuse ${de#"$OUT"/}"; fi
      r="$(check "$ph" "$ag" "$de")"; [ -n "$r" ] || { log "ok ${de#"$OUT"/}"; return 0; }
      log "gate $ph failed on ${de#"$OUT"/}: $r"
      [ "$REPAIR" = "1" ] || return 1
      call "$ag" "$tk. FIX: your previous output, ${de#"$OUT"/}, failed the gate: $r. Re-emit the full corrected output" "$de" "$@" "${de#"$OUT"/}" || return 1
      r="$(check "$ph" "$ag" "$de")"; [ -n "$r" ] || { log "ok ${de#"$OUT"/} after repair"; return 0; }
      log "gate $ph failed after repair on ${de#"$OUT"/}: $r"; return 1
    }

    # 1 ground: the product's own facts, real pains, the market and the obvious ideas. It runs in the product's folder,
    # so the researcher reads the code and docs there.
    if [ "$project" = "none" ]; then dr="$OUT"; pj="none, there is no product yet"; else dr="$project"; pj="the current folder, read its README, docs and manifests"; fi
    step ground debate-research "phase ground: read theme.md and ground-template.md; project: $pj; search the web; reply only with ground.md" \
      "$OUT/ground.md" "$dr" "$HARNESS" "$MODEL" theme.md ground-template.md debate-rules.md || { log "ABORT: ground"; exit 1; }

    # 2 ideas: 1 call per lens, in parallel, each in a room with only theme.md and ground.md: no ideator sees another.
    set -- $MIX; nm="$#"; i=0; pids=""
    for l in $(lenses_of "$OUT"); do
      i=$((i + 1)); hn="$HARNESS"; mn="$MODEL"
      if [ "$nm" -gt 0 ]; then j=$(( (i - 1) % nm + 1 )); eval "hn=\${$j}"; mn=""; fi
      rm_="$OUT/raw/rooms/ideas-$l"; rm -rf "$rm_"; mkdir -p "$rm_"
      cp "$OUT/theme.md" "$OUT/ground.md" "$OUT/debate-rules.md" "$rm_/"
      log "lens $l on $hn${mn:+:$mn}: $(stimulus_of "$OUT" "$l")"
      step ideas debate-ideator "$(ideate_task "$OUT" "$l")" "$OUT/ideas/$l.md" "$rm_" "$hn" "$mn" theme.md ground.md debate-rules.md &
      pids="$pids $!"
    done
    bad=0; for p in $pids; do wait "$p" || bad=$((bad + 1)); done
    [ "$bad" -eq 0 ] || { log "ABORT: $bad lens(es) failed; running again resumes"; exit 1; }

    # 3 novelty: what already exists, per idea. 4 converge: merge, score, pick, wildcard.
    step novelty debate-research "phase novelty: read ideas/; reply only with novelty.md" \
      "$OUT/novelty.md" "$OUT" "$HARNESS" "$MODEL" $(cd "$OUT" && ls ideas/*.md) || { log "ABORT: novelty"; exit 1; }
    step converge debate-judge "phase converge: read theme.md, ground.md, ideas/, novelty.md and brainstorm-template.md; reply only with brainstorm.md" \
      "$OUT/brainstorm.md" "$OUT" "$HARNESS" "$MODEL" theme.md ground.md $(cd "$OUT" && ls ideas/*.md) novelty.md brainstorm-template.md debate-rules.md \
      || { log "ABORT: converge"; exit 1; }
    rm -rf "$OUT/raw/rooms"
    log "brainstorm ok: $(sed -n 's/^Pick: //p' "$OUT/brainstorm.md" | head -1)"
    [ ! -s "$OUT/raw/metrics.tsv" ] || log "$(awk -F'\t' '{ n++; s += $3; if ($4 != "-") { i += $4; o += $5; k++ } }
      END { printf "cost: %d calls, %d s of model time", n, s; if (k) printf ", %d tokens in and %d out on %d of them", i, o, k }' "$OUT/raw/metrics.tsv")" ;;

  seed)
    B="${1:?usage: brainstorm.sh seed <dir> <Pn>}"; P="${2:?usage: brainstorm.sh seed <dir> <Pn>}"
    r="$(check converge debate-judge "$B/brainstorm.md")"
    [ -z "$r" ] || { echo "error: brainstorm.md fails its gate: $r" >&2; exit 2; }
    row="$(awk -F'|' -v p="$P" '
      function trim(x) { gsub(/[*`]/, "", x); sub(/^[[:space:]]+/, "", x); sub(/[[:space:]]+$/, "", x); return x }
      /^## / { on = (tolower($0) ~ /proposals/); next }
      on && /^\|/ && !h { for (i = 2; i < NF; i++) c[tolower(trim($i))] = i; h = 1; next }
      on && trim($2) == p { printf "%s\t%s\t%s\t%s\t%s\n", trim($c["name"]), trim($c["pitch"]), trim($c["from"]), trim($c["for"]), trim($c["first test"]); exit }' "$B/brainstorm.md")"
    [ -n "$row" ] || { echo "error: $P is not a proposal of $B/brainstorm.md" >&2; exit 2; }
    IFS="$(printf '\t')" read -r name pitch from for test <<EOF
$row
EOF
    base="$(sed -n 's/^cases: //p' "$B/meta.txt" | tail -1)"
    case_="$("$SCRIPT_DIR/new-debate.sh" "$name: $pitch" "${base:-cases}")"
    printf '\nFrom the brainstorm %s, %s (ideas %s):\n- For: %s\n- First test: %s\n' "$B" "$P" "$from" "$for" "$test" >> "$case_/idea.md"
    cp "$B/ground.md" "$case_/ground.md"
    # The brief fields the proposal and the intake already answer; the debate intake asks only for the rest.
    hard="$(sed -n 's/^- Hard constraint[^:]*:[[:space:]]*//p' "$B/theme.md" | head -1)"
    goal="$(printf '%s' "$test" | sed -n 's/.*[Gg]o if //p')"
    awk -v g="$name: $pitch" -v w="$for" -v m="$goal" -v c="$hard" '
      function put(v) { if (v != "" && $0 ~ /:[[:space:]]*$/) { sub(/[[:space:]]*$/, " " v) } print }
      /^- Goal/ { put(g); next } /^- Who uses it/ { put(w); next }
      /^- 90-day success metric/ { put(m == "" ? "" : "first test: go if " m); next } /^- Fixed constraints/ { put(c); next }
      { print }' "$case_/brief.md" > "$case_/brief.md.new" && mv "$case_/brief.md.new" "$case_/brief.md"
    awk -v line="$P, by ${PICKED_BY:-user}; case: $case_" '/^## Picked/ { print; print ""; print line; skip = 1; next } !skip' "$B/brainstorm.md" > "$B/brainstorm.md.new"
    mv "$B/brainstorm.md.new" "$B/brainstorm.md"
    cp "$B/brainstorm.md" "$case_/brainstorm.md"
    printf '%s\n' "$case_" ;;

  *) usage ;;
esac
