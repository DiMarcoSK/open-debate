# gates.sh - checks shared by debate.sh, gate.sh and validate.sh (sourced). Needs TOK = path of tokens.awk and PANEL.
# check <phase> <agent> <file> prints the failure reasons separated by "; ", or nothing.
# In the spec phase, <file> is the spec directory.

has() { grep -qi -- "$2" "$1" 2>/dev/null; }
# parent <path>: dirname without a process.
parent() { case "$1" in */*) printf '%s' "${1%/*}" ;; *) printf . ;; esac; }
on_panel() { case " $PANEL " in *" $1 "*) return 0 ;; esac; return 1; }

# --- panel: base seats always present, optional ones picked by what the brief says (references/panel.conf)
PANEL_BASE="debate-arch debate-ux debate-pm"
PANEL_CAP=8
AWKS="${TOK%/*}"
CATALOG="$AWKS/../references/panel.conf"

# What the brief actually states: values without labels, without the Out of scope line and without negations;
# lowercase and without accents. The brief may be in any language, so negations cover English and Portuguese.
brief_text() {
  { sed -n '/^- Out of scope/d; /^- Fora do escopo/d; s/^- [^:]*:[[:space:]]*//p' "$1/brief.md" 2>/dev/null; sed 1d "$1/idea.md" 2>/dev/null; } \
    | if perl -MUnicode::Normalize -e 1 2>/dev/null; then perl -CSD -MUnicode::Normalize -ne '$_ = lc NFD($_); s/\pM//g; print'
      else tr '[:upper:]' '[:lower:]'; fi \
    | grep -Ev '^[[:space:]]*(no|none|not|without|n/a|nao|nenhum|nenhuma|sem)([^a-z]|$)' || true
}

# panel_reasons <case>: 1 line "agent: brief word" per optional seat triggered, in catalog order.
panel_reasons() {
  tb="$(brief_text "$1")"
  while IFS='|' read -r ag kind trig; do
    case "$ag" in ''|'#'*) continue ;; esac
    [ "$kind" = "optional" ] || continue
    w="$(printf '%s\n' "$tb" | grep -Eiwo -- "$trig" | head -1 || true)"
    [ -z "$w" ] || printf '%s: %s\n' "$ag" "$w"
  done < "$CATALOG"
}

# cap_panel <agents>: no repeats, at most PANEL_CAP.
cap_panel() {
  cp_out=""; cp_n=0
  for x in $1; do
    case " $cp_out " in *" $x "*) continue ;; esac
    [ "$cp_n" -lt "$PANEL_CAP" ] || continue
    cp_out="$cp_out $x"; cp_n=$((cp_n + 1))
  done
  printf '%s' "${cp_out# }"
}

# with_base <agents>: base seats first, then the rest in the given order.
with_base() { cap_panel "$PANEL_BASE $1"; }

pick_panel() { with_base "$(panel_reasons "$1" | cut -d: -f1 | tr '\n' ' ')"; }

# case_panel <case>: the panel saved in meta.txt or, without it, the one picked by the brief.
case_panel() {
  pc="$(sed -n 's/^panel: //p' "$1/meta.txt" 2>/dev/null | tail -1)"
  [ -n "$pc" ] || pc="$(pick_panel "$1")"
  printf '%s' "$pc"
}
skipped() { grep -q '^skipped' "$1" 2>/dev/null; }
# legacy_case <case>: created before 0.5, with Portuguese templates and headings that the English gates do not read.
legacy_case() { [ -f "$1/regras-debate.md" ] && [ ! -f "$1/debate-rules.md" ]; }
LEGACY_HINT="case created before open-debate 0.5 (Portuguese headings): rerun it with --from research (FROM=research) to redo it in English"


tokens_ok() {
  r="$(awk -v mode=contrast -f "$TOK" "$1" 2>&1)" && return 0
  printf '; TOKENS: %s' "$(printf '%s\n' "$r" | grep 'FAIL' | tr '\n' ' ')"
}

# Cap of non-empty lines per output, the same as the personas. Fails only 50% over: a redo costs more than a few extra lines.
line_cap() {
  case "$1:$2" in
    proposal:debate-arch) printf 85 ;;
    proposal:debate-design) printf 90 ;;
    proposal:debate-ux) printf 80 ;;
    proposal:debate-brand) printf 100 ;;
    proposal:debate-pm) printf 60 ;;
    critique:debate-ux) printf 40 ;;
    proposal:*) printf 55 ;;
    critique:*) printf 25 ;;
    research:*) printf 100 ;;
    agenda:*) printf 20 ;;
    decision:*) printf 150 ;;
    audit:*) printf 25 ;;
    brand:*) printf 120 ;;
    backlog:*) printf 150 ;;
    *) printf 0 ;;
  esac
}

size_ok() {
  c="$(line_cap "$1" "$2")"; [ "$c" -gt 0 ] || return 0
  n="$(grep -c . "$3" || true)"
  [ "$n" -le $((c * 3 / 2)) ] || printf '; %s lines, cap %s: cut what does not decide' "$n" "$c"
}

# Rn ids cited that do not exist in research.md: a number with an invented source.
refs_ok() {
  awk -v rs="$2/research.md" '
    BEGIN {
      while ((getline l < rs) > 0) {
        if (l ~ /^skipped/) sk = 1
        if (match(l, /^\|[ *]*R[0-9]+[ *]*\|/)) { x = substr(l, RSTART, RLENGTH); gsub(/[^R0-9]/, "", x); ok[x] = 1; n++ }
      }
      if (sk || !n) exit
    }
    # Rn token bounded by chars outside [A-Za-z0-9_-], as in prose: "R3," and "(R3)" count, "R3a" and "AR3" do not.
    { l = $0; gsub(/[^A-Za-z0-9_-]/, " ", l); k = split(l, w, " ")
      for (i = 1; i <= k; i++) if (w[i] ~ /^R[0-9]+$/ && !(w[i] in ok) && !(w[i] in seen)) { seen[w[i]] = 1; r = r " " w[i] } }
    END { if (r != "") printf "; cites an id missing from research.md:%s", r }' "$1"
}
# missing_d <case> <file>: agenda Dn ids the file does not cite, in a single awk.
missing_d() {
  awk -v ag="$1/agenda.md" '
    BEGIN {
      while ((getline l < ag) > 0) {
        if (l ~ /^skipped/) { n = 0; exit }
        if (match(l, /^\|[ *]*D[0-9]+[ *]*\|/)) { x = substr(l, RSTART, RLENGTH); gsub(/[^D0-9]/, "", x); id[++n] = x }
      }
      if (!n) exit
    }
    { l = $0; gsub(/[^A-Za-z0-9]/, " ", l); k = split(l, w, " "); for (i = 1; i <= k; i++) has[w[i]] = 1 }
    END { for (i = 1; i <= n; i++) if (!(id[i] in has)) printf "%s ", id[i] }' "$2"
}

# missing_sections <file> <n...>: numbers without a "## n" heading.
missing_sections() {
  f_="$1"; shift
  awk -v q="$*" 'BEGIN { k = split(q, s, " ") } /^## / { for (i = 1; i <= k; i++) if (index($0, "## " s[i]) == 1) t[i] = 1 }
    END { for (i = 1; i <= k; i++) if (!(i in t)) printf "; section %s missing", s[i] }' "$f_"
}

# Banned visuals from visual-contract.md: 1 awk for the whole list. A line that only mentions the term to deny or veto it
# does not count; a file with `override` written anywhere is cleared.
banned() {
  awk '
    BEGIN { n = split("purple-blue|purple gradient|glass card|glassmorphism|lorem ipsum|corporate memphis|wall of text|carousel", b, "|") }
    { l = tolower($0) }
    l ~ /override/ { ov = 1 }
    l ~ /no |without|banned|veto|absent|override|avoid|not |forbid|list/ { next }
    { for (i = 1; i <= n; i++) if (!(i in hit) && index(l, b[i])) hit[i] = NR }
    END { if (ov) exit; for (i = 1; i <= n; i++) if (i in hit) printf "; banned visual (%s) on line %s without a written override", b[i], hit[i] }' "$1"
}

# Panel agents that took a veto: only they need a rebuttal.
vetoed() {
  for x in $PANEL; do
    short="${x#debate-}"
    if cat "$1"/critiques/*.md 2>/dev/null | grep -Eiq "^#+[[:space:]]*veto against[[:space:]\`*]*(debate-)?$short([^a-z0-9-]|\$)"; then printf '%s ' "$x"; fi
  done
}

check_spec() {
  d="${1%/}"; c="${d%/*}"; c="$(parent "$c")"; m=""
  for x in spec plan tasks; do
    [ -s "$d/$x.md" ] || { printf '%s.md missing' "$x"; return 0; }
    if grep -q '<nn>\|<slug>\|<who>\|<event>\|ADR-NNNN' "$d/$x.md"; then printf '%s.md has a placeholder' "$x"; return 0; fi
  done
  grep -q 'ADR-[0-9]' "$d/spec.md" || m="$m; spec cites no ADR"
  if ls "$c"/adr/[0-9]*.md >/dev/null 2>&1; then
    for r in $(grep -Eo 'ADR-[0-9]+' "$d/spec.md" "$d/plan.md" -h | sed 's/ADR-//' | sort -u); do
      x="$(printf '%s' "$r" | sed 's/^0*//')"
      ls "$c/adr/$(printf '%04d' "${x:-0}")"-*.md >/dev/null 2>&1 || m="$m; cites ADR-$r, which does not exist in adr/"
    done
  fi
  grep -q 'THE SYSTEM SHALL' "$d/spec.md" || m="$m; no EARS requirement (THE SYSTEM SHALL)"
  grep -Eq '^- \[.\] T[0-9]+' "$d/tasks.md" || m="$m; tasks without a - [ ] Tnnn line"
  for u in $(sed -n 's/^- \(US[0-9][0-9]*\)[[:space:]].*/\1/p' "$d/spec.md"); do
    grep -q "\[$u\]" "$d/tasks.md" || m="$m; $u has no task"
  done
  printf '%s' "${m#; }"
}

check() {
  phase="$1"; a="$2"; f="$3"; m=""
  [ "$phase" = "spec" ] && { check_spec "$f"; return 0; }
  if [ ! -s "$f" ]; then printf 'output missing or empty'; return 0; fi
  case "$phase" in
    proposal|critique) c="$(parent "$(parent "$f")")" ;;
    *) c="$(parent "$f")" ;;
  esac
  m="$(size_ok "$phase" "$a" "$f")"
  case "$phase" in
    research)
      if skipped "$f"; then return 0; fi
      u="$(grep -Eo 'https?://[^] )|>"]+' "$f" | sort -u | wc -l | tr -d ' ')"
      [ "$u" -ge 5 ] || m="$m; $u distinct URL(s), minimum 5"
      n="$(grep -cE '^\|[ *]*R[0-9]+[ *]*\|' "$f" || true)"
      [ "$n" -ge 5 ] || m="$m; $n finding(s) in the table, minimum 5"
      s="$(grep -E '^\|[ *]*R[0-9]+[ *]*\|' "$f" | grep -Evi 'https?://|unverified' | sed 's/^|[ *]*\(R[0-9]*\).*/\1/' | tr '\n' ' ' || true)"
      [ -z "$s" ] || m="$m; finding with neither URL nor unverified: $s"
      has "$f" 'gaps' || m="$m; no Gaps section" ;;
    agenda)
      if skipped "$f"; then return 0; fi
      n="$(grep -cE '^\|[ *]*D[0-9]+[ *]*\|' "$f" || true)"
      { [ "$n" -ge 3 ] && [ "$n" -le 8 ]; } || m="$m; $n decision(s), expected 3-8 rows | Dn | ..."
      r="$(awk -F'|' -v panel=" $PANEL " '
        /^\|[ *]*D[0-9]+[ *]*\|/ {
          id = $2; o = $4; owner = $5; drv = $6; gsub(/[ *]/, "", id); gsub(/[ *`]/, "", owner); gsub(/ /, "", drv)
          if (o !~ / \/ /) print id " without 2+ options separated by / "
          if (index(panel, " " owner " ") == 0) print id " with an owner outside the panel: " owner
          if (drv == "") print id " without a driver"
        }' "$f")"
      [ -z "$r" ] || m="$m; $(printf '%s' "$r" | tr '\n' ';' | sed 's/;/; /g')" ;;
    proposal)
      has "$f" 'concession' || m="$m; no concession"
      for d in $(missing_d "$c" "$f"); do m="$m; no position on $d"; done
      m="$m$(refs_ok "$f" "$c")"
      case "$a" in
        debate-arch)
          grep -q 'mermaid' "$f" || m="$m; no C4 in a mermaid block"
          grep -q 'ADR' "$f" || m="$m; no proposed ADRs"
          has "$f" 'capacity' || m="$m; no capacity math" ;;
        debate-design)
          has "$f" 'flow' || m="$m; no flows"
          has "$f" 'inventory' || m="$m; no screen inventory"
          m="$m$(banned "$f")"
          for s in Empty Loading Error; do has "$f" "$s" || m="$m; no $s state written"; done ;;
        debate-ux)
          has "$f" 'wcag' || m="$m; no WCAG plan"
          has "$f" 'nielsen\|heuristic' || m="$m; no heuristics"
          has "$f" 'usability' || m="$m; no usability test"
          on_panel debate-brand || m="$m$(tokens_ok "$f")"
          m="$m$(banned "$f")"
          for s in Empty Loading Error; do has "$f" "$s" || m="$m; no $s state written"; done ;;
        debate-brand)
          m="$m$(tokens_ok "$f")"
          m="$m$(banned "$f")"
          has "$f" 'voice' || m="$m; no voice and tone"
          has "$f" 'logo' || m="$m; no logo"
          has "$f" 'positioning\|platform' || m="$m; no brand platform" ;;
        debate-pm)
          has "$f" 'mvp' || m="$m; no MVP cut"
          has "$f" 'metric' || m="$m; no metric"
          has "$f" 'assumption\|premise' || m="$m; no assumptions to validate" ;;
        debate-aws|debate-gcp)
          has "$f" 'cost' || m="$m; no cost"
          has "$f" 'iam' || m="$m; no IAM"
          has "$f" 'budget\|alert' || m="$m; no budget alert" ;;
        debate-data)
          has "$f" 'pipeline' || m="$m; no pipeline"
          has "$f" 'quality' || m="$m; no quality tests"
          has "$f" 'retention' || m="$m; no retention"
          has "$f" 'cost' || m="$m; no cost" ;;
        debate-ai)
          has "$f" 'eval' || m="$m; no eval"
          has "$f" 'fallback' || m="$m; no fallback"
          has "$f" 'cost' || m="$m; no cost" ;;
        debate-mobile)
          has "$f" 'offline' || m="$m; no offline"
          has "$f" 'store' || m="$m; no store"
          has "$f" 'minimum version\|rollout' || m="$m; no update policy" ;;
        debate-k8s)
          has "$f" 'rollback' || m="$m; no rollback"
          has "$f" 'cost' || m="$m; no cost" ;;
        debate-sec)
          has "$f" 'stride' || m="$m; no STRIDE"
          has "$f" 'authz\|authoriz' || m="$m; no authorization model"
          has "$f" 'audit' || m="$m; no audit trail" ;;
      esac ;;
    critique)
      n="$(grep -cEi '^#+[[:space:]]*veto against' "$f" || true)"
      { [ "$n" -ge 1 ] && [ "$n" -le 3 ]; } || m="$m; $n veto(es), expected 1-3 headings ### Veto against <agent>"
      has "$f" 'concession' || m="$m; no concession"
      if grep -Eiq "^#+[[:space:]]*veto against[[:space:]\`*]*(debate-)?${a#debate-}([^a-z0-9-]|\$)" "$f"; then m="$m; veto against itself"; fi
      r="$(awk -v base="$c" -f "$AWKS/quotes.awk" "$f" 2>&1)" \
        || m="$m; $(printf '%s\n' "$r" | sed 's/^FAIL //' | head -4 | tr '\n' ';' | sed 's/;$//; s/;/; /g')"
      if [ "$a" = "debate-ux" ] && on_panel debate-design; then
        grep -Eiq '^#+[[:space:]]*review[[:space:]]+(of[[:space:]]+)?(debate-)?design' "$f" || m="$m; no ## Review debate-design section"
      fi
      m="$m$(refs_ok "$f" "$c")" ;;
    decision)
      n="$(grep -cE '^#+[[:space:]]*ADR-[0-9]+' "$f" || true)"
      [ "$n" -ge 3 ] || m="$m; $n ADR(s), minimum 3 with a ## ADR-NNNN heading"
      i="$(awk '
        function level(l) { match(l, /^#+/); return RLENGTH }
        function close_adr() { if (h != "" && !(d && al && c)) print h }
        /^#+[[:space:]]*ADR-[0-9]/ { close_adr(); h = $0; lv = level($0); d = al = c = 0; next }
        /^#/ && h != "" && level($0) <= lv { close_adr(); h = "" }
        h != "" && tolower($0) ~ /outcome|decision:|chosen:/ { d = 1 }
        h != "" && tolower($0) ~ /options|alternativ/ { al = 1 }
        h != "" && tolower($0) ~ /confirmation/ { c = 1 }
        END { close_adr() }' "$f")"
      [ -z "$i" ] || m="$m; ADR without Decision outcome, Considered options or Confirmation (MADR): $(printf '%s' "$i" | tr '\n' ' ')"
      s="$(grep -c '`[0-9][0-9] [a-z0-9]' "$f" || true)"
      { [ "$s" -ge 3 ] && [ "$s" -le 6 ]; } || m="$m; spec index with $s line(s), expected 3-6 as \`NN slug\`"
      has "$f" 'dissent' || m="$m; no Dissent"
      r="$(awk -f "$AWKS/scores.awk" "$f" 2>&1)" \
        || m="$m; $(printf '%s\n' "$r" | sed 's/^FAIL //' | head -6 | tr '\n' ';' | sed 's/;$//; s/;/; /g')"
      for d in $(missing_d "$c" "$f"); do m="$m; agenda $d without a decision"; done
      m="$m$(refs_ok "$f" "$c")"
      v="$(cat "$c"/critiques/*.md 2>/dev/null | grep -cEi '^#+[[:space:]]*veto against' || true)"
      e="$(grep -cEi '\|[[:space:]]*wrong[[:space:]]*\|' "$c/research-check.md" 2>/dev/null || true)"
      e="${e:-0}"
      sec="$(awk 'tolower($0) ~ /^#+[[:space:]]*([0-9]+[.)]?[[:space:]]*)?vetoes/ { on = 1; next } /^## / { on = 0 } on' "$f")"
      nv="$(printf '%s\n' "$sec" | grep -cEi 'upheld|rejected' || true)"
      [ "$nv" -ge "$v" ] || m="$m; $nv veto(es) ruled out of $v: Vetoes section with 1 upheld|rejected row per veto"
      ne="$(printf '%s\n' "$sec" | grep -ci 'wrong' || true)"
      [ "$ne" -ge "$e" ] || m="$m; $ne wrong claim(s) zeroed out of $e from the fact-check: 1 row per claim in the Vetoes section" ;;
    audit)
      grep -Eq '^Verdict: (APPROVED|FIX|APPLIED)' "$f" || m="$m; no Verdict: APPROVED|FIX line"
      if grep -q '^Verdict: FIX' "$f"; then
        grep -Eq '^\|[ *]*A[0-9]+[ *]*\|' "$f" || m="$m; FIX without a | An | ... row"
      fi ;;
    brand)
      m="$m$(missing_sections "$f" 1 2 3 4 5 6 7 8)"
      m="$m$(tokens_ok "$f")"
      m="$m$(banned "$f")"
      has "$f" 'logo' || m="$m; no logo"
      has "$f" 'voice' || m="$m; no voice"
      n="$(awk '/^## 7/ { on = 1; next } /^## / { on = 0 } on && /^\|/ && !/^\|[ :-]*\|[ :|-]*$/ { n++ } END { print n + 0 }' "$f")"
      [ "$n" -ge 2 ] || m="$m; section 7 without an adapted screen: table | Screen | ... with 1+ row"
      if grep -q '<product name>\|<screen>' "$f" || grep -qw -e TODO -e TBD "$f"; then m="$m; placeholder in the text"; fi
      if [ -s "$c/SDD.md" ] && awk -v mode=list -f "$TOK" "$c/SDD.md" > /dev/null 2>&1; then
        o="$(awk -v mode=list -f "$TOK" "$c/SDD.md" | sort)"; d="$(awk -v mode=list -f "$TOK" "$f" 2>/dev/null | sort)"
        [ "$o" = "$d" ] || m="$m; BRANDBOOK TOKENS differ from the SDD: copy them literally"
      fi ;;
    track)
      has "$f" 'Acceptance' || m="$m; items without Acceptance"
      [ "$(grep -c '^- ' "$f")" -ge 8 ] || m="$m; fewer than 8 items" ;;
    backlog)
      t="$(sed -n 's/^| \([a-z-]*\) | .*/\1/p' "$c/polish.md" 2>/dev/null | grep -v '^tag$' | tr '\n' ' ')"
      # The brand tag only counts with a brandbook: without an art director on the panel there is no brand to apply.
      [ -s "$c/BRANDBOOK.md" ] || t="$(printf '%s' "$t" | tr ' ' '\n' | grep -vx 'brand' | tr '\n' ' ')"
      sp="$(ls -d "$c"/specs/[0-9][0-9]-*/ 2>/dev/null | sed 's#.*/\([0-9][0-9]\)-[^/]*/$#\1#' | tr '\n' ' ')"
      ad="$(ls "$c"/adr/[0-9]*.md 2>/dev/null | sed 's#.*/\([0-9]\{4\}\)-.*#\1#' | tr '\n' ' ')"
      ta=""
      for d in "$c"/specs/[0-9][0-9]-*/; do
        [ -f "${d}tasks.md" ] || continue
        b="${d%/}"; b="${b##*/}"
        for x in $(sed -n 's/^- \[.\] \(T[0-9][0-9]*\).*/\1/p' "${d}tasks.md"); do ta="$ta ${b%%-*}:$x"; done
      done
      r="$(awk -v mode=check -v tags="$t" -v specs="$sp" -v adrs="$ad" -v tasks="$ta" -f "$AWKS/backlog.awk" "$f" 2>&1)" \
        || m="$m; $(printf '%s\n' "$r" | sed 's/^FAIL //' | head -12 | tr '\n' ';' | sed 's/;$//; s/;/; /g')"
      has "$f" 'Definition of Done' || m="$m; no Definition of Done" ;;
    sdd)
      m="$m$(missing_sections "$f" 0 1 2 3 4 5 6 7 8)"
      grep -q 'mermaid' "$f" || m="$m; section 4 without a mermaid block"
      m="$m$(tokens_ok "$f")"
      m="$m$(banned "$f")"
      for s in Empty Loading Error; do has "$f" "$s" || m="$m; no $s state"; done
      if grep -qw -e TODO -e TBD "$f" || has "$f" 'to be defined' || grep -q '<product name>\|<metaphor>' "$f"; then
        m="$m; placeholder in the text"
      fi
      for x in "$c"/adr/[0-9]*.md; do
        [ -f "$x" ] || continue
        id="${x##*/}"; id="${id%"${id#????}"}"
        grep -q "ADR-$id" "$f" || m="$m; ADR-$id missing from the SDD"
      done
      if awk -v mode=list -f "$TOK" "$c/decision.md" > /dev/null 2>&1; then
        o="$(awk -v mode=list -f "$TOK" "$c/decision.md" | sort)"; d="$(awk -v mode=list -f "$TOK" "$f" 2>/dev/null | sort)"
        [ "$o" = "$d" ] || m="$m; SDD TOKENS differ from the decision.md block: copy them literally"
      fi ;;
  esac
  printf '%s' "${m#; }"
}

# An output older than its input: someone edited the case and the rest did not follow.
stale() {
  prev=""
  for x in brief.md research.md agenda.md decision.md SDD.md BACKLOG.md; do
    [ -s "$1/$x" ] || continue
    if [ -n "$prev" ] && [ "$1/$prev" -nt "$1/$x" ]; then printf '%s newer than %s\n' "$prev" "$x"; fi
    prev="$x"
  done
}

# split_adrs <case> - splits each ADR of decision.md into adr/NNNN-slug.md (MADR, 1 file per decision).
split_adrs() {
  mkdir -p "$1/adr"; rm -f "$1"/adr/[0-9]*.md
  awk -v dir="$1/adr" '
    function level(l) { match(l, /^#+/); return RLENGTH }
    /^#+[[:space:]]*ADR-[0-9]+/ {
      if (f != "") close(f)
      lv = level($0); h = $0; sub(/^#+[[:space:]]*ADR-/, "", h); num = h; sub(/[^0-9].*/, "", num)
      t = h; sub(/^[0-9]+[[:space:]:.-]*/, "", t); s = tolower(t); gsub(/[^a-z0-9]+/, "-", s); gsub(/^-+|-+$/, "", s)
      f = sprintf("%s/%04d-%s.md", dir, num + 0, substr(s, 1, 40))
      l = $0; sub(/^#+/, "#", l); print l > f; next
    }
    /^#/ && f != "" && level($0) <= lv { close(f); f = ""; next }
    f != "" { l = $0; if (l ~ /^#/) l = substr(l, lv); print l > f }' "$1/decision.md"
  ls "$1"/adr/[0-9]*.md 2>/dev/null | wc -l | tr -d ' '
}
