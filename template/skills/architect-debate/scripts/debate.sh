#!/bin/sh
# debate.sh <case-dir> [rounds] - fases 1-6: pesquisa, proposta, ataque, fact-check, replica, juiz, ADRs, SDD, style tile.
# Gate reprovado ganha 1 reparo com o motivo (REPAIR=1); reprovou de novo, aborta. Rodar de novo retoma.
# Modo CLI: para modelo pago ou proprio (MODEL=<provider>/<modelo>). Modelos free do opencode recusam chamada headless:
# use /debate dentro do opencode (modo sessao, subagents).
# Env: MODEL (vazio = modelo do agent), MODEL_FALLBACK (1x em 401/403/limite free), RETRIES=2, TIMEOUT=600, MIN_LINES=5, FRESH=0, REVIEW=1,
#      RESEARCH=1, FACTCHECK=1, REPAIR=1, PAINEL="debate-arch debate-design debate-gcp debate-k8s".
set -eu
export LC_ALL=C

CASE_DIR="${1:?uso: debate.sh <case-dir> [rounds]}"
ROUNDS="${2:-3}"
MODEL="${MODEL:-}"
MODEL_FALLBACK="${MODEL_FALLBACK:-}"
RETRIES="${RETRIES:-2}"
TIMEOUT="${TIMEOUT:-600}"
MIN_LINES="${MIN_LINES:-5}"
FRESH="${FRESH:-0}"
REVIEW="${REVIEW:-1}"
RESEARCH="${RESEARCH:-1}"
FACTCHECK="${FACTCHECK:-1}"
REPAIR="${REPAIR:-1}"
PAINEL="${PAINEL:-debate-arch debate-design debate-gcp debate-k8s}"

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REF="$SCRIPT_DIR/../references"
TOK="$SCRIPT_DIR/tokens.awk"
. "$SCRIPT_DIR/gates.sh"

case "$ROUNDS" in ''|*[!0-9]*) ROUNDS=3;; esac
[ "$ROUNDS" -gt 3 ] && ROUNDS=3
[ "$ROUNDS" -lt 1 ] && ROUNDS=1

command -v opencode >/dev/null 2>&1 || { echo "erro: opencode nao encontrado no PATH" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "erro: jq nao encontrado no PATH" >&2; exit 2; }
command -v perl >/dev/null 2>&1 || { echo "erro: perl nao encontrado no PATH (usado no timeout)" >&2; exit 2; }
[ -f "$CASE_DIR/constitution.md" ] || { echo "erro: $CASE_DIR/constitution.md ausente, rode new-debate.sh" >&2; exit 2; }
"$SCRIPT_DIR/validate.sh" "$CASE_DIR" --brief >&2 || { echo "erro: brief reprovado, preencha $CASE_DIR/brief.md" >&2; exit 2; }
n=0; for a in $PAINEL; do n=$((n + 1)); done
[ "$n" -ge 2 ] || { echo "erro: PAINEL precisa de 2+ agents" >&2; exit 2; }

# macOS nao tem timeout(1); perl alarm mata a chamada que trava em retry infinito do provider.
TO="perl -e alarm(shift);exec(@ARGV)||die $TIMEOUT"

OUT="$CASE_DIR"
mkdir -p "$OUT/proposals" "$OUT/critiques" "$OUT/raw" "$OUT/adr"
for t in regras-debate.md visual-contract.md research-template.md adr-template.md backlog-template.md lapidacao.md sdd-template.md; do
  [ -f "$OUT/$t" ] || cp "$REF/$t" "$OUT/$t"
done
{ grep -v '^painel:' "$OUT/meta.txt" 2>/dev/null || true; printf 'painel: %s\n' "$PAINEL"; } > "$OUT/meta.txt.tmp"
mv "$OUT/meta.txt.tmp" "$OUT/meta.txt"

PIDFILE="$OUT/raw/pids.$$"
SUMMARY="$OUT/raw/summary.log"
: > "$PIDFILE"
printf '\n== %s rounds=%s painel=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$ROUNDS" "$PAINEL" >> "$SUMMARY"

log() { printf '%s\n' "$*" | tee -a "$SUMMARY"; }
abort() { log "ABORTA: $*"; rm -f "$PIDFILE"; exit 1; }

extract_text() {
  jq -r 'select(.type == "text") | .part.text // empty' "$1" > "$2" 2>/dev/null || true
  [ -s "$2" ] && return 0
  jq -r '.text // empty' "$1" > "$2" 2>/dev/null || true
  [ -s "$2" ] && return 0
  jq -r '.. | .text? // empty' "$1" > "$2" 2>/dev/null || true
  [ -s "$2" ]
}

auth_failed() { grep -qi 'FreeTierError\|Free usage limit\|statusCode[^0-9]*40[13]\|unauthorized' "$1" "$1.stderr" 2>/dev/null; }

run_once() {
  agent="$1"; task="$2"; dest="$3"; raw="$4"; model="$5"
  set -- --agent "$agent" --format json --dir "$OUT"
  [ -n "$model" ] && set -- "$@" -m "$model"
  $TO opencode run --print-logs --log-level ERROR "$@" "$task" > "$raw.tmp" 2>"$raw.tmp.stderr" || return 1
  extract_text "$raw.tmp" "$dest.new" || return 1
  [ "$(wc -l < "$dest.new" | tr -d ' ')" -ge "$MIN_LINES" ] || return 1
  mv "$dest.new" "$dest"
  mv "$raw.tmp" "$raw"
}

run_agent() {
  agent="$1"; task="$2"; dest="$3"; raw="$4"
  attempt=1
  while [ "$attempt" -le "$RETRIES" ]; do
    run_once "$agent" "$task" "$dest" "$raw" "$MODEL" && return 0
    if auth_failed "$raw.tmp" && [ -z "$MODEL_FALLBACK" ]; then
      log "limite do plano free em $agent: modelos free so rodam dentro da sessao do opencode (/debate), ou defina MODEL pago/proprio"
      break
    fi
    if auth_failed "$raw.tmp" && [ -n "$MODEL_FALLBACK" ]; then
      log "auth no modelo primario, fallback 1x para $dest"
      run_once "$agent" "$task" "$dest" "$raw" "$MODEL_FALLBACK" && return 0
      break
    fi
    attempt=$((attempt + 1))
  done
  rm -f "$dest.new"
  log "FALHOU $dest apos $RETRIES tentativa(s), ver $raw.tmp.stderr"
  return 1
}

need() { [ "$FRESH" = "1" ] || [ ! -s "$1" ]; }

launch() {
  if [ "${5:-}" = "forca" ] || need "$3"; then
    run_agent "$1" "$2" "$3" "$4" &
    printf '%s %s\n' "$!" "$3" >> "$PIDFILE"
  else
    log "reuso $3"
  fi
}

wait_all() {
  failed=0
  while read -r pid dest; do
    [ -z "$pid" ] && continue
    if wait "$pid"; then log "ok $dest"; else failed=$((failed + 1)); fi
  done < "$PIDFILE"
  : > "$PIDFILE"
  [ "$failed" -eq 0 ] || { log "$1: $failed saida(s) falharam"; return 1; }
}

short() { printf '%s' "${1#debate-}"; }

rivais() {
  s=""
  for r in $PAINEL; do [ "$r" = "$1" ] || s="$s proposals/$r.md"; done
  printf '%s' "${s# }"
}

dest_for() {
  case "$1" in
    proposta) printf '%s' "$OUT/proposals/$2.md" ;;
    ataque) printf '%s' "$OUT/critiques/$2.md" ;;
    replica) printf '%s' "$OUT/proposals/$2-r2.md" ;;
  esac
}

task_for() {
  case "$1" in
    proposta)
      extra=""; [ "$2" = "debate-design" ] && extra=", visual-contract.md"
      printf 'fase proposta: le brief.md, constitution.md, research.md, regras-debate.md%s; responde so no formato de proposta do teu papel' "$extra" ;;
    ataque)
      printf 'fase ataque: le brief.md, research.md, regras-debate.md e as propostas rivais %s; responde so no formato de ataque de regras-debate.md, citando arquivo:linha' "$(rivais "$2")" ;;
    replica)
      printf 'fase replica: le brief.md, research.md, research-check.md, regras-debate.md, proposals/%s.md, os vetos contra %s em critiques/ e as propostas rivais %s; responde so no formato de replica de regras-debate.md' "$2" "$2" "$(rivais "$2")" ;;
  esac
}

reparo() { printf '%s. CORRECAO: tua saida anterior em %s reprovou no gate: %s. Reemite a saida completa corrigida.' "$1" "${2#"$OUT"/}" "$3"; }

fase_painel() {
  fase="$1"; tag="$2"
  for a in $PAINEL; do launch "$a" "$(task_for "$fase" "$a")" "$(dest_for "$fase" "$a")" "$OUT/raw/$tag-$(short "$a").json"; done
  wait_all "$fase"
}

gate_painel() {
  fase="$1"; tag="$2"; ruins=""
  for a in $PAINEL; do
    d="$(dest_for "$fase" "$a")"; r="$(check "$fase" "$a" "$d")"
    [ -z "$r" ] && continue
    log "gate $fase reprovado em ${d#"$OUT"/}: $r"
    [ "$REPAIR" = "1" ] || return 1
    ruins="$ruins $a"
    launch "$a" "$(reparo "$(task_for "$fase" "$a")" "$d" "$r")" "$d" "$OUT/raw/$tag-$(short "$a")-reparo.json" forca
  done
  [ -z "$ruins" ] && { log "gate $fase ok"; return 0; }
  wait_all "$fase reparo" || true
  ok=0
  for a in $ruins; do
    d="$(dest_for "$fase" "$a")"; r="$(check "$fase" "$a" "$d")"
    [ -z "$r" ] || { log "gate $fase reprovado apos reparo em ${d#"$OUT"/}: $r"; ok=1; }
  done
  [ "$ok" -eq 0 ] && log "gate $fase ok apos reparo"
  return "$ok"
}

gate_one() {
  fase="$1"; agent="$2"; dest="$3"; task="$4"; raw="$5"
  r="$(check "$fase" "$agent" "$dest")"
  [ -z "$r" ] && { log "gate $fase ok"; return 0; }
  log "gate $fase reprovado: $r"
  [ "$REPAIR" = "1" ] || return 1
  run_agent "$agent" "$(reparo "$task" "$dest" "$r")" "$dest" "$raw.reparo" || return 1
  r="$(check "$fase" "$agent" "$dest")"
  [ -z "$r" ] && { log "gate $fase ok apos reparo"; return 0; }
  log "gate $fase reprovado apos reparo: $r"; return 1
}

# fase 1 - pesquisa
if [ "$RESEARCH" = "1" ]; then
  T="modo pesquisa: le brief.md e research-template.md; pesquisa na web e responde so com o research.md completo no template"
  if need "$OUT/research.md" || grep -q '^pulado' "$OUT/research.md"; then
    run_agent debate-research "$T" "$OUT/research.md" "$OUT/raw/f1-research.json" || abort "pesquisa falhou (RESEARCH=0 pula)"
  else log "reuso $OUT/research.md"; fi
  gate_one pesquisa debate-research "$OUT/research.md" "$T" "$OUT/raw/f1-research.json" || abort "gate pesquisa"
else
  [ -s "$OUT/research.md" ] || printf '# Research\n\npulado: RESEARCH=0, numero sem fonte vale como estimativa\n' > "$OUT/research.md"
fi

# fase 2 - proposta cega
fase_painel proposta f2 || abort "fase proposta"
gate_painel proposta f2 || abort "gate proposta"

# fase 3 e 4 - ataque e fact-check
if [ "$ROUNDS" -ge 2 ]; then
  fase_painel ataque f3 || abort "fase ataque"
  gate_painel ataque f3 || abort "gate ataque"
  if [ "$FACTCHECK" = "1" ] && ! grep -q '^pulado' "$OUT/research.md"; then
    if need "$OUT/research-check.md" || grep -q '^pulado\|^falhou' "$OUT/research-check.md"; then
      run_agent debate-research "modo fact-check: le research-template.md (secao Fact-check), proposals/ e critiques/; responde so com a tabela de fact-check" \
        "$OUT/research-check.md" "$OUT/raw/f4-factcheck.json" \
        || printf '# Fact-check\n\nfalhou: ver raw/f4-factcheck.json.tmp.stderr\n' > "$OUT/research-check.md"
    else log "reuso $OUT/research-check.md"; fi
  fi
fi
[ -s "$OUT/research-check.md" ] || printf '# Fact-check\n\npulado: rounds=%s FACTCHECK=%s\n' "$ROUNDS" "$FACTCHECK" > "$OUT/research-check.md"

# fase 5 - replica
if [ "$ROUNDS" -ge 3 ]; then
  fase_painel replica f5 || log "replica parcial, juiz usa r1 onde faltar"
fi

# fase 6 - juiz, ADRs, SDD
T="fase decisao: le brief.md, constitution.md, research.md, research-check.md, regras-debate.md, adr-template.md, proposals/ (prefere *-r2) e critiques/; responde so com o decision.md"
if need "$OUT/decision.md"; then
  run_agent debate-judge "$T" "$OUT/decision.md" "$OUT/raw/f6-decision.json" || abort "juiz decision"
else log "reuso $OUT/decision.md"; fi
gate_one decisao debate-judge "$OUT/decision.md" "$T" "$OUT/raw/f6-decision.json" || abort "gate decisao"
log "ADRs: $(split_adrs "$OUT") em adr/"

T="fase sdd: le brief.md, constitution.md, research.md, decision.md, adr/, sdd-template.md e visual-contract.md; responde so com o SDD.md completo"
if need "$OUT/SDD.md"; then
  run_agent debate-judge "$T" "$OUT/SDD.md" "$OUT/raw/f6-sdd.json" || abort "juiz SDD"
  if [ "$REVIEW" = "1" ]; then
    run_agent debate-judge "fase revisao: rele SDD.md contra brief.md, constitution.md, decision.md e adr/; responde so com o SDD.md completo corrigido" \
      "$OUT/SDD.md" "$OUT/raw/f6-sdd-review.json" || log "revisao do SDD falhou, mantendo a versao anterior"
  fi
else log "reuso $OUT/SDD.md"; fi
gate_one sdd debate-judge "$OUT/SDD.md" "$T" "$OUT/raw/f6-sdd.json" || abort "gate SDD"

if "$SCRIPT_DIR/style-tile.sh" "$OUT" >> "$SUMMARY" 2>&1; then log "style tile: $OUT/style-tile.html"
else log "style tile falhou, ver $SUMMARY"; fi

# fase 8 - backlog, so com specs preenchidas
SPECS_OK=0
if ls "$OUT"/specs/[0-9]*/spec.md >/dev/null 2>&1 && ! grep -l '<nn>\|<slug>\|<quem>' "$OUT"/specs/*/spec.md >/dev/null 2>&1; then SPECS_OK=1; fi
if [ "$SPECS_OK" = "1" ]; then
  mkdir -p "$OUT/backlog"
  LE="le SDD.md, adr/, specs/, lapidacao.md e backlog-template.md"
  launch debate-design "fase backlog-design: $LE; responde so com o rascunho de itens" "$OUT/backlog/design.md" "$OUT/raw/f8-design.json"
  launch debate-arch "fase backlog-eng: $LE; responde so com o rascunho de itens" "$OUT/backlog/eng.md" "$OUT/raw/f8-eng.json"
  wait_all "fase trilhas" || abort "fase trilhas"
  T="fase backlog: le brief.md, SDD.md, decision.md, adr/, specs/*/tasks.md, backlog/design.md, backlog/eng.md, lapidacao.md e backlog-template.md; responde so com o BACKLOG.md"
  if need "$OUT/BACKLOG.md"; then run_agent debate-pm "$T" "$OUT/BACKLOG.md" "$OUT/raw/f8-backlog.json" || abort "pm backlog"; else log "reuso $OUT/BACKLOG.md"; fi
  gate_one backlog debate-pm "$OUT/BACKLOG.md" "$T" "$OUT/raw/f8-backlog.json" || abort "gate backlog"
  "$SCRIPT_DIR/backlog-export.sh" "$OUT" | tee -a "$SUMMARY"
fi

rm -f "$PIDFILE"
log "debate ok: decision.md, adr/, SDD.md, style-tile.html em $OUT"
if [ "$SPECS_OK" = "1" ]; then log "backlog ok: BACKLOG.md, backlog.csv, backlog.json, backlog-gh.sh"
else log "proximo: make-specs.sh $OUT <slugs do indice de decision.md>, preencher specs e rodar debate.sh de novo para a fase 8 (backlog)"; fi
