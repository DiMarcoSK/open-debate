#!/bin/sh
# debate.sh <case-dir> [rounds] - protocolo inteiro: pesquisa, agenda, proposta, ataque, fact-check, replica, juiz, ADRs, SDD, auditoria, specs, backlog.
# Gate reprovado ganha 1 reparo com o motivo (REPAIR=1); reprovou de novo, aborta. Rodar de novo retoma.
# Cada especialista roda como processo isolado no harness escolhido. Modelos free do opencode recusam chamada headless:
# neles use /debate dentro do opencode (modo sessao, subagents).
# Env: HARNESS=opencode, MODEL (vazio = padrao do harness), MODEL_FALLBACK (1x em auth ou limite), RETRIES=2, TIMEOUT=600, MIN_LINES=5,
#      BACKOFF=20 (s, dobra a cada espera), PARALELO=6 (chamadas simultaneas, 0 = sem teto), MAX_CHAMADAS=0 (teto do run, 0 = sem teto),
#      FROM=<fase> (arquiva essa fase e as seguintes em raw/arquivo e refaz),
#      FRESH=0, AGENDA=1, REVIEW=1, RESEARCH=1, FACTCHECK=1, SPECS=1, REPAIR=1,
#      PAINEL="debate-arch debate-ux debate-pm debate-design" (vazio = meta.txt ou escolhido pelo brief; debate-arch, debate-ux e debate-pm sempre entram),
#      MESA="claude codex" (painel distribuido entre harnesses), ROTAS="debate-arch=claude debate-design=codex:gpt-5" (rota por agent),
#      HARNESS_CMD (HARNESS=custom: comando que le $PROMPT e $MODEL e imprime a resposta).
set -eu
export LC_ALL=C

CASE_DIR="${1:?uso: debate.sh <case-dir> [rounds]}"
ROUNDS="${2:-3}"
MODEL="${MODEL:-}"
MODEL_FALLBACK="${MODEL_FALLBACK:-}"
RETRIES="${RETRIES:-2}"
TIMEOUT="${TIMEOUT:-600}"
MIN_LINES="${MIN_LINES:-5}"
BACKOFF="${BACKOFF:-20}"
PARALELO="${PARALELO:-6}"
MAX_CHAMADAS="${MAX_CHAMADAS:-0}"
FROM="${FROM:-}"
FRESH="${FRESH:-0}"
AGENDA="${AGENDA:-1}"
REVIEW="${REVIEW:-1}"
RESEARCH="${RESEARCH:-1}"
FACTCHECK="${FACTCHECK:-1}"
REPAIR="${REPAIR:-1}"
SPECS="${SPECS:-1}"
HARNESS="${HARNESS:-opencode}"
MESA="${MESA:-}"
ROTAS="${ROTAS:-}"

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REF="$SCRIPT_DIR/../references"
TOK="$SCRIPT_DIR/tokens.awk"
. "$SCRIPT_DIR/gates.sh"
. "$SCRIPT_DIR/harness.sh"

# Painel: o pedido, o gravado no caso ou o que o brief aciona em painel.conf. Os assentos base entram sempre.
AUTO=0; [ -n "${PAINEL:-}" ] || grep -q '^painel: ' "$CASE_DIR/meta.txt" 2>/dev/null || AUTO=1
PEDIDO="${PAINEL:-$(painel_do_caso "$CASE_DIR")}"
PAINEL="$(com_base "$PEDIDO")"
SOMADOS=""; for b in $PAINEL_BASE; do case " $PEDIDO " in *" $b "*) ;; *) SOMADOS="$SOMADOS $b" ;; esac; done

case "$ROUNDS" in ''|*[!0-9]*) ROUNDS=3;; esac
[ "$ROUNDS" -gt 3 ] && ROUNDS=3
[ "$ROUNDS" -lt 1 ] && ROUNDS=1

command -v jq >/dev/null 2>&1 || { echo "erro: jq nao encontrado no PATH" >&2; exit 2; }
command -v perl >/dev/null 2>&1 || { echo "erro: perl nao encontrado no PATH (usado no timeout)" >&2; exit 2; }
[ -f "$CASE_DIR/constitution.md" ] || { echo "erro: $CASE_DIR/constitution.md ausente, rode new-debate.sh" >&2; exit 2; }
"$SCRIPT_DIR/validate.sh" "$CASE_DIR" --brief >&2 || { echo "erro: brief reprovado, preencha $CASE_DIR/brief.md" >&2; exit 2; }
n=0; for a in $PAINEL; do
  n=$((n + 1))
  [ -f "$SCRIPT_DIR/../personas/$a.md" ] || { echo "erro: persona inexistente no painel: $a" >&2; exit 2; }
done
[ "$n" -ge 2 ] || { echo "erro: PAINEL precisa de 2+ agents" >&2; exit 2; }
case "$FROM" in ''|pesquisa|agenda|proposta|ataque|factcheck|replica|decisao|sdd|marca|specs|backlog) ;;
  *) echo "erro: --from invalido: $FROM (pesquisa agenda proposta ataque factcheck replica decisao sdd marca specs backlog)" >&2; exit 2 ;;
esac

# Mesa: 1 harness por vez ao redor do painel. ROTAS explicitas vencem.
if [ -n "$MESA" ]; then
  set -- $MESA; i=0; n_m="$#"; distrib=""
  for a in $PAINEL; do
    i=$((i + 1)); j=$(( (i - 1) % n_m + 1 )); eval "h=\${$j}"
    distrib="$distrib $a=$h"
  done
  ROTAS="${distrib# } $ROTAS"
fi

# rota <agent>: imprime "<harness> <modelo>"; modelo pode vir vazio.
rota() {
  r=""
  for x in $ROTAS; do case "$x" in "$1="*) r="${x#*=}" ;; esac; done
  [ -n "$r" ] || { printf '%s %s' "$HARNESS" "$MODEL"; return; }
  case "$r" in
    *:*) printf '%s %s' "${r%%:*}" "${r#*:}" ;;
    *) printf '%s ' "$r" ;;
  esac
}

h_existe "$HARNESS"
for x in $ROTAS; do r="${x#*=}"; h_existe "${r%%:*}"; done

# macOS nao tem timeout(1); perl alarm mata a chamada que trava em retry infinito do provider.
TO="perl -e alarm(shift);exec(@ARGV)||die $TIMEOUT"

OUT="$(CDPATH= cd -- "$CASE_DIR" && pwd)"
mkdir -p "$OUT/raw"

# Lock: 2 runs no mesmo caso sobrescrevem saidas um do outro. Trava de run morto e reaproveitada.
LOCK="$OUT/raw/.lock"
if ! mkdir "$LOCK" 2>/dev/null; then
  dono="$(cat "$LOCK/pid" 2>/dev/null || true)"
  if [ -n "$dono" ] && kill -0 "$dono" 2>/dev/null; then echo "erro: caso em execucao pelo processo $dono" >&2; exit 2; fi
  rm -rf "$LOCK"; mkdir "$LOCK"
fi
printf '%s\n' "$$" > "$LOCK/pid"

PIDFILE="$OUT/raw/pids.$$"
FALHAS="$OUT/raw/falhas.$$"
CHAMADAS="$OUT/raw/chamadas.$$"
METRICAS="$OUT/raw/metricas.tsv"
SUMMARY="$OUT/raw/summary.log"
INICIO="$(date +%s)"
: > "$PIDFILE"; : > "$FALHAS"; : > "$CHAMADAS"

# Mata a arvore toda: sem job control, chamada em background ignora SIGINT e seguiria gastando apos o Ctrl-C.
mata_arvore() {
  for filho in $(pgrep -P "$1" 2>/dev/null || true); do mata_arvore "$filho"; done
  kill "$1" 2>/dev/null || true
}
interrompe() {
  trap - INT TERM
  [ -z "$FG" ] || mata_arvore "$FG"
  while read -r vp vd; do [ -z "$vp" ] || mata_arvore "$vp"; done < "$PIDFILE"
  printf 'INTERROMPIDO: rodar de novo retoma\n' | tee -a "$SUMMARY"
  exit 130
}
FG=""; MINIMO=""
sai() { rm -rf "$LOCK" "$OUT/raw/salas"; rm -f "$PIDFILE" "$FALHAS" "$CHAMADAS"; }
trap sai EXIT
trap interrompe INT TERM

# arquiva_desde <fase>: move a fase e as seguintes para raw/arquivo/<data>. Nada se apaga, spec editada fica la.
arquiva_desde() {
  a_dest="$OUT/raw/arquivo/$(date -u +%Y%m%dT%H%M%SZ)"; a_on=0
  for g in pesquisa agenda proposta ataque factcheck replica decisao sdd marca specs backlog; do
    [ "$g" = "$1" ] && a_on=1
    [ "$a_on" = "1" ] || continue
    case "$g" in
      pesquisa) l="research.md" ;;
      agenda) l="agenda.md" ;;
      proposta) l="proposals" ;;
      ataque) l="critiques" ;;
      factcheck) l="research-check.md" ;;
      replica) l="$(cd "$OUT" && ls proposals/*-r2.md 2>/dev/null || true)" ;;
      decisao) l="decision.md adr" ;;
      sdd) l="SDD.md auditoria.md style-tile.html tokens.json tokens.css" ;;
      marca) l="BRANDBOOK.md" ;;
      specs) l="specs checklists" ;;
      backlog) l="backlog BACKLOG.md backlog.csv backlog.json backlog-gh.sh" ;;
    esac
    for x in $l; do
      [ -e "$OUT/$x" ] || continue
      mkdir -p "$a_dest/$(pai "$x")"; mv "$OUT/$x" "$a_dest/$x"
    done
  done
  printf 'arquivado em %s, refazendo desde %s\n' "${a_dest#"$OUT"/}" "$1" | tee -a "$SUMMARY"
}
[ -z "$FROM" ] || arquiva_desde "$FROM"

mkdir -p "$OUT/proposals" "$OUT/critiques" "$OUT/adr"
for t in regras-debate.md visual-contract.md research-template.md agenda-template.md adr-template.md backlog-template.md lapidacao.md sdd-template.md spec-template.md plan-template.md tasks-template.md auditoria-template.md brandbook-template.md; do
  [ -f "$OUT/$t" ] || cp "$REF/$t" "$OUT/$t"
done
{ grep -v '^painel:\|^harness:\|^rounds:' "$OUT/meta.txt" 2>/dev/null || true; printf 'painel: %s\nharness: %s\nrounds: %s\n' "$PAINEL" "$HARNESS" "$ROUNDS"; } > "$OUT/meta.txt.tmp"
mv "$OUT/meta.txt.tmp" "$OUT/meta.txt"

printf '\n== %s rounds=%s harness=%s rotas=%s painel=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$ROUNDS" "$HARNESS" "$ROTAS" "$PAINEL" >> "$SUMMARY"

log() { printf '%s\n' "$*" | tee -a "$SUMMARY"; }
abort() { log "ABORTA: $*"; exit 1; }

defasados "$OUT" | while IFS= read -r d; do log "aviso: $d; use --from para refazer o que depende dele"; done
[ -z "$SOMADOS" ] || log "painel: assento base somado:$SOMADOS"
if [ "$AUTO" = "1" ]; then
  motivos_painel "$OUT" | while IFS= read -r x; do
    if no_painel "${x%%:*}"; then log "painel: ${x%%:*} pelo brief (${x#*: })"; fi
  done
fi
dados="$(sed -n 's/^- Dados sensiveis[^:]*:[[:space:]]*//p' "$OUT/brief.md" | tr '[:upper:]' '[:lower:]')"
if ! printf '%s' " $PAINEL " | grep -q ' debate-sec ' && printf '%s' "$dados" | grep -Eq 'lgpd|gdpr|pci|hipaa|saude|pessoa|cpf|financ' && ! printf '%s' "$dados" | grep -Eq '^(nao|nenhum|sem) '; then
  log "aviso: brief com dado regulado e painel sem debate-sec; considere --painel arch,design,sec"
fi

# Aqui o arquivo sai do texto devolvido. Sem esta linha, o agent tenta gravar, leva permissao negada e responde com um pedido de permissao.
SAIDA='SAIDA: nesta execucao voce nao grava arquivo: nao use Write nem Edit. Tua resposta final inteira e o conteudo do arquivo pedido, sem comentario antes ou depois e sem cerca de codigo em volta.'

run_once() {
  agent="$1"; task="$2"; dest="$3"; raw="$4"; rot="$5"
  h="${rot%% *}"; m="${rot#* }"
  rc=0; h_run "$h" "$agent" "$task. $SAIDA" "$m" "${SALA:-$OUT}" "$raw.tmp" || rc=$?
  if [ "$rc" -eq 142 ]; then log "tempo esgotado em $agent apos ${TIMEOUT}s: aumente TIMEOUT e rode de novo"; fi
  [ "$rc" -eq 0 ] || return 1
  h_texto "$h" "$raw.tmp" "$dest.new" || return 1
  [ "$(wc -l < "$dest.new" | tr -d ' ')" -ge "${MINIMO:-$MIN_LINES}" ] || return 1
  mv "$dest.new" "$dest"
  mv "$raw.tmp" "$raw"
}

cabe_chamada() {
  printf 'x\n' >> "$CHAMADAS"
  [ "$MAX_CHAMADAS" -gt 0 ] || return 0
  [ "$(wc -l < "$CHAMADAS" | tr -d ' ')" -le "$MAX_CHAMADAS" ] && return 0
  log "teto de MAX_CHAMADAS=$MAX_CHAMADAS atingido em $agent"; return 1
}

tenta_agent() {
  agent="$1"; task="$2"; dest="$3"; raw="$4"
  rot="$(rota "$agent")"
  tentativas=1
  while [ "$tentativas" -le "$RETRIES" ]; do
    cabe_chamada || return 1
    run_once "$agent" "$task" "$dest" "$raw" "$rot" && return 0
    if h_auth_falhou "$raw.tmp"; then
      if [ -z "$MODEL_FALLBACK" ]; then
        log "auth ou cota em $agent (${rot%% *}): confira o login; no opencode, modelos free so rodam na sessao (/debate)"
        break
      fi
      log "auth ou cota no modelo primario, fallback 1x para $dest"
      cabe_chamada || return 1
      run_once "$agent" "$task" "$dest" "$raw" "${rot%% *} $MODEL_FALLBACK" && return 0
      break
    fi
    # Espera so o que uma espera resolve; o jitter separa chamadas da mesma leva, que batem no limite juntas.
    if [ "$tentativas" -lt "$RETRIES" ] && h_limite_falhou "$raw.tmp"; then
      e=$((BACKOFF * (1 << (tentativas - 1)) + ($(date +%s) + ${#dest}) % (BACKOFF / 4 + 1)))
      log "limite em $agent (${rot%% *}), nova tentativa em ${e}s"
      sleep "$e"
    fi
    tentativas=$((tentativas + 1))
  done
  rm -f "$dest.new"
  log "FALHOU $dest apos $RETRIES tentativa(s), ver $raw.tmp.stderr"
  return 1
}

# agente <agent> <tarefa> <destino> <bruto>: 1 linha em raw/metricas.tsv por chamada logica.
agente() {
  t0="$(date +%s)"; rc2=0; tentativas=0
  tenta_agent "$@" || rc2=$?
  b4="${4##*/}"; r4="$(rota "$1")"
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "${b4%.json}" "$1" "$(($(date +%s) - t0))" "$tentativas" "$rc2" "${r4%% *}" >> "$METRICAS"
  return "$rc2"
}

# Chamada de 1 agent so. Roda em background porque o shell so atende sinal fora de comando em primeiro plano:
# com `wait`, interromper nao precisa esperar a chamada acabar.
run_agent() {
  agente "$@" &
  FG="$!"; rcf=0
  wait "$FG" || rcf=$?
  FG=""
  return "$rcf"
}

need() { [ "$FRESH" = "1" ] || [ ! -s "$1" ]; }

# vaga: segura a leva em PARALELO chamadas simultaneas, esperando a mais antiga terminar.
vaga() {
  [ "$PARALELO" -gt 0 ] || return 0
  while [ "$(wc -l < "$PIDFILE" | tr -d ' ')" -ge "$PARALELO" ]; do
    read -r vp vd < "$PIDFILE"
    if wait "$vp"; then log "ok $vd"; else printf 'x\n' >> "$FALHAS"; fi
    sed 1d "$PIDFILE" > "$PIDFILE.n"; mv "$PIDFILE.n" "$PIDFILE"
  done
}

launch() {
  if [ "${5:-}" = "forca" ] || need "$3"; then
    vaga
    agente "$1" "$2" "$3" "$4" &
    printf '%s %s\n' "$!" "$3" >> "$PIDFILE"
  else
    log "reuso $3"
  fi
}

wait_all() {
  failed="$(wc -l < "$FALHAS" | tr -d ' ')"; : > "$FALHAS"
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

# sala <fase> <agent> [extra]: diretorio com so o que o agent pode ler. Fora dele nao ha proposta nem critica de rival:
# paralelo nao vaza e o reparo de um nao le o outro. Replica e seguintes leem tudo, sem sala.
sala() {
  case "$1" in
    proposta) l="visual-contract.md" ;;
    ataque) l="$(rivais "$2")" ;;
    *) return 0 ;;
  esac
  sd="$OUT/raw/salas/$1-$(short "$2")"; rm -rf "$sd"; mkdir -p "$sd"
  for x in brief.md constitution.md research.md agenda.md regras-debate.md $l ${3:-}; do
    [ -e "$OUT/$x" ] || continue
    mkdir -p "$sd/$(pai "$x")"; cp "$OUT/$x" "$sd/$x"
  done
  printf '%s' "$sd"
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
      extra=""; case "$2" in debate-design|debate-ux|debate-brand) extra=", visual-contract.md" ;; esac
      printf 'fase proposta: le brief.md, constitution.md, research.md, agenda.md, regras-debate.md%s; responde so no formato de proposta do teu papel, com a secao Posicoes cobrindo cada Dn de agenda.md' "$extra" ;;
    ataque)
      printf 'fase ataque: le brief.md, research.md, agenda.md, regras-debate.md e as propostas rivais %s; responde so no formato de ataque de regras-debate.md, copiando a citacao literal do arquivo, com arquivo:linha' "$(rivais "$2")" ;;
    replica)
      printf 'fase replica: le brief.md, research.md, research-check.md, regras-debate.md, proposals/%s.md, os vetos contra %s em critiques/ e as propostas rivais %s; responde so no formato de replica de regras-debate.md' "$2" "$2" "$(rivais "$2")" ;;
  esac
}

reparo() { printf '%s. CORRECAO: tua saida anterior em %s reprovou no gate: %s. Reemite a saida completa corrigida.' "$1" "${2#"$OUT"/}" "$3"; }

fase_painel() {
  fase="$1"; tag="$2"; quem="${3:-$PAINEL}"
  for a in $quem; do
    SALA="$(sala "$fase" "$a")"
    launch "$a" "$(task_for "$fase" "$a")" "$(dest_for "$fase" "$a")" "$OUT/raw/$tag-$(short "$a").json"
  done
  SALA=""
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
    SALA="$(sala "$fase" "$a" "${d#"$OUT"/}")"
    launch "$a" "$(reparo "$(task_for "$fase" "$a")" "$d" "$r")" "$d" "$OUT/raw/$tag-$(short "$a")-reparo.json" forca
  done
  SALA=""
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

# fase 1b - agenda: as decisoes em disputa, antes de qualquer proposta. Caso antigo com propostas prontas segue sem.
if [ "$AGENDA" != "1" ]; then
  [ -s "$OUT/agenda.md" ] || printf '# Agenda\n\npulado: AGENDA=0\n' > "$OUT/agenda.md"
elif [ "$FRESH" != "1" ] && [ ! -s "$OUT/agenda.md" ] && [ -s "$OUT/proposals/$(set -- $PAINEL; printf '%s' "$1").md" ]; then
  printf '# Agenda\n\npulado: caso anterior a agenda\n' > "$OUT/agenda.md"
else
  T="fase agenda: le brief.md, constitution.md, research.md, agenda-template.md e regras-debate.md; painel: $PAINEL; responde so com o agenda.md"
  if need "$OUT/agenda.md"; then
    run_agent debate-judge "$T" "$OUT/agenda.md" "$OUT/raw/f1b-agenda.json" || abort "agenda falhou (AGENDA=0 pula)"
  else log "reuso $OUT/agenda.md"; fi
  gate_one agenda debate-judge "$OUT/agenda.md" "$T" "$OUT/raw/f1b-agenda.json" || abort "gate agenda"
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
  # Sem veto contra si, nao ha o que replicar: a proposta r1 segue valendo e a chamada se economiza.
  v="$(vetados "$OUT")"
  if [ -n "$v" ]; then
    fase_painel replica f5 "$v" || log "replica parcial, juiz usa r1 onde faltar"
    for a in $v; do
      d="$(dest_for replica "$a")"
      if [ -s "$d" ] && ! { has "$d" 'aceito' && has "$d" 'refuto'; }; then log "aviso: replica de $a sem Aceito ou Refuto"; fi
    done
  else log "sem veto contra o painel, replica pulada"; fi
fi

# fase 6 - juiz, ADRs, SDD
T="fase decisao: le brief.md, constitution.md, research.md, research-check.md, agenda.md, regras-debate.md, adr-template.md, proposals/ (prefere *-r2) e critiques/; responde so com o decision.md"
if need "$OUT/decision.md"; then
  run_agent debate-judge "$T" "$OUT/decision.md" "$OUT/raw/f6-decision.json" || abort "juiz decision"
else log "reuso $OUT/decision.md"; fi
gate_one decisao debate-judge "$OUT/decision.md" "$T" "$OUT/raw/f6-decision.json" || abort "gate decisao"
log "ADRs: $(split_adrs "$OUT") em adr/"

T="fase sdd: le brief.md, constitution.md, research.md, decision.md, adr/, sdd-template.md e visual-contract.md; responde so com o SDD.md completo"
if need "$OUT/SDD.md"; then
  run_agent debate-judge "$T" "$OUT/SDD.md" "$OUT/raw/f6-sdd.json" || abort "juiz SDD"
else log "reuso $OUT/SDD.md"; fi
gate_one sdd debate-judge "$OUT/SDD.md" "$T" "$OUT/raw/f6-sdd.json" || abort "gate SDD"

# Auditoria independente: quem escreveu nao se corrige sozinho. Saida curta, e o SDD so e reemitido se houver defeito.
if [ "$REVIEW" = "1" ]; then
  TA="fase auditoria: le SDD.md, brief.md, constitution.md, decision.md, adr/, research-check.md e auditoria-template.md; responde so com o auditoria.md"
  # Auditoria aprovada e curta de proposito.
  MINIMO=1
  if need "$OUT/auditoria.md"; then
    if ! run_agent debate-auditor "$TA" "$OUT/auditoria.md" "$OUT/raw/f6-auditoria.json"; then
      log "auditoria falhou, SDD segue sem auditoria"
    fi
  else log "reuso $OUT/auditoria.md"; fi
  if [ -s "$OUT/auditoria.md" ]; then
    gate_one auditoria debate-auditor "$OUT/auditoria.md" "$TA" "$OUT/raw/f6-auditoria.json" || abort "gate auditoria"
    MINIMO=""
    if grep -q '^Veredito: CORRIGIR' "$OUT/auditoria.md"; then
      log "auditoria: $(grep -cE '^\|[ *]*A[0-9]+[ *]*\|' "$OUT/auditoria.md") defeito(s), corrigindo o SDD"
      TC="fase correcao: le auditoria.md, SDD.md, brief.md, decision.md e adr/; aplica cada linha An e responde so com o SDD.md completo corrigido"
      run_agent debate-judge "$TC" "$OUT/SDD.md" "$OUT/raw/f6-sdd-correcao.json" || abort "correcao do SDD"
      gate_one sdd debate-judge "$OUT/SDD.md" "$TC" "$OUT/raw/f6-sdd-correcao.json" || abort "gate SDD apos auditoria"
      sed 's/^Veredito: CORRIGIR/Veredito: APLICADO/' "$OUT/auditoria.md" > "$OUT/auditoria.md.n"; mv "$OUT/auditoria.md.n" "$OUT/auditoria.md"
    fi
  fi
  MINIMO=""
fi

if "$SCRIPT_DIR/style-tile.sh" "$OUT" >> "$SUMMARY" 2>&1; then log "style tile: $OUT/style-tile.html"
else log "style tile falhou, ver $SUMMARY"; fi

# fase 6d - marca: o diretor de arte fecha o brandbook e adapta as telas do SDD a marca. So com debate-brand no painel.
if no_painel debate-brand; then
  le_m="brief.md, SDD.md, decision.md, brandbook-template.md, visual-contract.md"
  for x in proposals/debate-brand-r2.md proposals/debate-brand.md proposals/debate-design.md critiques/debate-ux.md; do
    [ -s "$OUT/$x" ] && le_m="$le_m, $x"
  done
  T="fase marca: le $le_m; responde so com o BRANDBOOK.md completo"
  if need "$OUT/BRANDBOOK.md"; then
    run_agent debate-brand "$T" "$OUT/BRANDBOOK.md" "$OUT/raw/f6-marca.json" || abort "marca"
  else log "reuso $OUT/BRANDBOOK.md"; fi
  gate_one marca debate-brand "$OUT/BRANDBOOK.md" "$T" "$OUT/raw/f6-marca.json" || abort "gate marca"
fi

# fase 7 - specs: 1 chamada por item do indice de decision.md, em paralelo
spec_pendente() { [ ! -s "$1/spec.md" ] || grep -q '<nn>\|<slug>\|<quem>' "$1/spec.md"; }
spec_tarefa() {
  printf 'fase spec: gera spec, plan e tasks da spec %s; le brief.md, SDD.md, decision.md, adr/, visual-contract.md, spec-template.md, plan-template.md e tasks-template.md; responde so com os 3 arquivos, cada um aberto pela linha <!-- arquivo: nome -->' "${1##*/}"
}
spec_separa() {
  awk -v d="$1" '
    /^<!-- arquivo: (spec|plan|tasks)\.md -->[[:space:]]*$/ { if (f != "") close(f); n = $3; f = d "/" n; printf "" > f; next }
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
    spec_pendente "$d" && launch debate-arch "$(spec_tarefa "$d")" "$OUT/raw/f7-$b.md" "$OUT/raw/f7-$b.json" forca
  done
  wait_all "fase specs" || abort "fase specs"
  for d in "$OUT"/specs/[0-9]*/; do
    d="${d%/}"; b="${d##*/}"
    if spec_pendente "$d" && [ -s "$OUT/raw/f7-$b.md" ]; then spec_separa "$d" "$OUT/raw/f7-$b.md"; fi
    r="$(check spec - "$d")"
    [ -z "$r" ] && continue
    log "gate spec reprovado em $b: $r"
    [ "$REPAIR" = "1" ] || abort "gate specs"
    run_agent debate-arch "$(reparo "$(spec_tarefa "$d")" "raw/f7-$b.md" "$r")" "$OUT/raw/f7-$b.md" "$OUT/raw/f7-$b-reparo.json" || abort "reparo da spec $b"
    spec_separa "$d" "$OUT/raw/f7-$b.md"
    r="$(check spec - "$d")"
    [ -z "$r" ] || abort "gate spec apos reparo em $b: $r"
  done
  log "gate specs ok"
fi

# fase 8 - backlog, so com specs preenchidas
SPECS_OK=0
if ls "$OUT"/specs/[0-9]*/spec.md >/dev/null 2>&1 && ! grep -l '<nn>\|<slug>\|<quem>' "$OUT"/specs/*/spec.md >/dev/null 2>&1; then SPECS_OK=1; fi
if [ "$SPECS_OK" = "1" ]; then
  mkdir -p "$OUT/backlog"
  LE="le SDD.md, adr/, specs/, lapidacao.md e backlog-template.md"
  BB=""; [ -s "$OUT/BRANDBOOK.md" ] && BB=" e BRANDBOOK.md"
  launch debate-ux "fase backlog-design: $LE$BB; responde so com o rascunho de itens" "$OUT/backlog/design.md" "$OUT/raw/f8-design.json"
  launch debate-arch "fase backlog-eng: $LE; responde so com o rascunho de itens" "$OUT/backlog/eng.md" "$OUT/raw/f8-eng.json"
  wait_all "fase trilhas" || abort "fase trilhas"
  T="fase backlog: le brief.md, SDD.md, decision.md, adr/, specs/*/tasks.md, backlog/design.md, backlog/eng.md$BB, lapidacao.md e backlog-template.md; responde so com o BACKLOG.md"
  if need "$OUT/BACKLOG.md"; then run_agent debate-pm "$T" "$OUT/BACKLOG.md" "$OUT/raw/f8-backlog.json" || abort "pm backlog"; else log "reuso $OUT/BACKLOG.md"; fi
  gate_one backlog debate-pm "$OUT/BACKLOG.md" "$T" "$OUT/raw/f8-backlog.json" || abort "gate backlog"
  "$SCRIPT_DIR/backlog-export.sh" "$OUT" | tee -a "$SUMMARY"
fi

metricas() {
  [ -s "$METRICAS" ] || return 0
  awk -F'\t' -v parede="$(($(date +%s) - INICIO))" '
    { n++; s += $3; rep += ($1 ~ /reparo/); ret += ($4 > 1 ? $4 - 1 : 0); if ($3 > m) { m = $3; q = $1 } }
    END { printf "tempo: %d s neste run; historico do caso: %d chamadas, %d s de modelo, %d reparo(s), %d retentativa(s); a mais lenta foi %s (%d s)\n", parede, n, s, rep, ret, q, m }' "$METRICAS"
}
log "$(metricas)"
log "debate ok: decision.md, adr/, SDD.md, style-tile.html$([ -s "$OUT/BRANDBOOK.md" ] && printf ', BRANDBOOK.md') em $OUT"
if [ "$SPECS_OK" = "1" ]; then log "backlog ok: BACKLOG.md, backlog.csv, backlog.json, backlog-gh.sh"
else log "proximo: preencher as specs (make-specs.sh, com SPECS=0) e rodar debate.sh de novo para a fase 8 (backlog)"; fi
