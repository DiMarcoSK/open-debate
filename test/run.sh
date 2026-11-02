#!/bin/sh
# run.sh - dependency-free suite: CLI, installer, gates and the whole protocol with an opencode stub.
# Exits 1 if any test fails.
set -u
export LC_ALL=C

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
CLI="$ROOT/bin/open-debate"
FX="$ROOT/test/fixtures"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
# Hermetic PATH: a real harness installed on the machine must not be detected or called by the suite.
FERR="$WORK/ferramentas"; mkdir -p "$FERR"
for c in jq perl; do ln -s "$(command -v "$c")" "$FERR/$c"; done
export PATH="$ROOT/test/stub:$FERR:/usr/bin:/bin"
export HOME="$WORK/home" XDG_CONFIG_HOME="$WORK/home/.config"
mkdir -p "$HOME"
CFG="$XDG_CONFIG_HOME/opencode"
SK="$CFG/skills/architect-debate"
# Fake CLIs named after each harness: the link name picks the output format.
FAKE="$WORK/fake"; mkdir -p "$FAKE"
for h in claude codex cursor-agent gemini agy omp pi dsh droid copilot qwen cline; do ln -s "$ROOT/test/stub/harness" "$FAKE/$h"; done
TODOS="opencode claude codex cursor gemini agy omp pi dsh droid copilot qwen cline"

PASS=0; FAIL=0
# Registry: `t` runs in sequence (touches HOME or the install), `tp` runs in parallel in a pool of JOBS.
# Each test runs in a subshell with its own WORK, STUB_STATE and stdin; results print in registry order.
# Outside `if`: inside it set -e would be ignored and only the test's last line would count.
# For the same reason, asserts use `nao` (never `! cmd`) and 1 command per line (never `a && b`).
JOBS="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)}"
REG="$WORK/.registro"; : > "$REG"
t() { n_="$1"; shift; printf 's|%s|%s\n' "$n_" "$*" >> "$REG"; }
tp() { n_="$1"; shift; printf 'p|%s|%s\n' "$n_" "$*" >> "$REG"; }
executa() { # executa <dir> <comando...>
  d_="$1"; shift; mkdir -p "$d_"; ini_="$(date +%s)"
  ( WORK="$d_"; export STUB_STATE="$d_/stub-state"; cd "$d_"; set -e; "$@" ) < /dev/null > "$d_.saida" 2>&1
  printf '%s %s\n' "$?" "$(($(date +%s) - ini_))" > "$d_.rc"
}
relata() { # relata <dir> <nome>
  read -r rc_ s_ < "$1.rc"
  [ -z "${TEMPOS:-}" ] || printf '%4ss %s\n' "$s_" "$2" >> "$TEMPOS"
  if [ "$rc_" -eq 0 ]; then PASS=$((PASS + 1)); printf 'ok   %s\n' "$2"
  else FAIL=$((FAIL + 1)); printf 'FAIL %s\n' "$2"; sed 's/^/     /' "$1.saida"; fi
}
nao() { if "$@"; then return 1; fi; }
existe() { for x in "$@"; do [ -e "$x" ] || { echo "missing: $x"; return 1; }; done; }
ausente() { for x in "$@"; do [ ! -e "$x" ] || { echo "left over: $x"; return 1; }; done; }

# --- CLI
versao() { [ "$("$CLI" --version)" = "$(jq -r .version "$ROOT/package.json")" ]; }
ajuda() { "$CLI" --help | grep -q 'open-debate init'; }
desconhecido() { nao "$CLI" foobar; }
symlink() { ln -s "$CLI" "$WORK/od"; "$WORK/od" --version; }
tp "--version reads package.json" versao
tp "--help lists commands" ajuda
tp "unknown command fails" desconhecido
tp "works through a symlink (npm bin)" symlink

# --- package safety
sem_vazamento() {
  grep -rnIE '/Users/|eskudo|apiKey|api_key|sk-[A-Za-z0-9]{20}|\.config/opencode' "$ROOT/template" "$ROOT/lib/install.sh" \
    | grep -v 'XDG_CONFIG_HOME' > "$WORK/vaza" || true
  cat "$WORK/vaza"
  [ ! -s "$WORK/vaza" ]
}
frontmatter_sem_glob_aberto() { nao grep -n '"\*[a-z-]*/scripts' "$ROOT/template/skills/architect-debate/personas/debate.md"; }
tp "template has no local path or secret" sem_vazamento
tp "bash permission does not use a left-open glob" frontmatter_sem_glob_aberto

# --- installer
init_global() {
  "$CLI" init --yes
  existe "$CFG/agents/debate-judge.md" "$CFG/commands/debate.md"
  [ -x "$SK/scripts/gate.sh" ]
  nao grep -rn '{{' "$CFG/agents" "$CFG/commands" "$SK/SKILL.md"
  grep -q '"~/.config/opencode/skills/architect-debate/scripts/\*": allow' "$CFG/agents/debate.md"
  grep -q "\"$SK/scripts/\*\": allow" "$CFG/agents/debate.md"
}
modelos_aplicados() { grep -q '^model: opencode/free-a$' "$CFG/agents/debate-judge.md"; }
idempotente() { "$CLI" init | grep -q '0 new, 0 updated, 0 overwritten'; }
doctor_ok() { "$CLI" doctor; }
t "init installs and renders paths" init_global
t "init swaps a model missing from the catalog" modelos_aplicados
t "init again changes nothing" idempotente
t "doctor passes" doctor_ok

preserva_modelo() {
  sed -i.bak 's/^model: .*/model: opencode\/paid/' "$CFG/agents/debate-arch.md"; rm -f "$CFG/agents/debate-arch.md.bak"
  "$CLI" update
  grep -q '^model: opencode/paid$' "$CFG/agents/debate-arch.md"
}
update_repara_rotacao() {
  sed -i.bak 's/^model: .*/model: opencode\/sumiu/' "$CFG/agents/debate-ux.md"; rm -f "$CFG/agents/debate-ux.md.bak"
  "$CLI" update
  grep -q '^model: opencode/free-' "$CFG/agents/debate-ux.md"
  grep -q '^model: opencode/paid$' "$CFG/agents/debate-arch.md"
}
perfil_misto() {
  nao "$CLI" models profile mixed opencode/missing
  "$CLI" models profile mixed opencode/paid
  grep -q '^model: opencode/paid$' "$CFG/agents/debate-judge.md"
  grep -q '^model: opencode/free-' "$CFG/agents/debate-scout.md"
  "$CLI" models check | grep -q '^profile mixed, strong=opencode/paid$'
  "$CLI" models profile free
  grep -q '^model: opencode/free-' "$CFG/agents/debate-judge.md"
}
protege_edicao() {
  echo extra >> "$CFG/agents/debate-pm.md"
  nao "$CLI" update > "$WORK/u" 2>&1
  grep -q 'agents/debate-pm.md' "$WORK/u"
  grep -q '^extra$' "$CFG/agents/debate-pm.md"
}
force_faz_backup() {
  "$CLI" update --force
  ls "$CFG"/.open-debate-backup-*.tgz >/dev/null
  tar -tzf "$CFG"/.open-debate-backup-*.tgz | grep -q 'agents/debate-pm.md'
  nao grep -q '^extra$' "$CFG/agents/debate-pm.md"
}
preserva_conf() {
  echo 'debate-judge=my/paid-model' >> "$SK/models.conf"
  "$CLI" update
  grep -q '^debate-judge=my/paid-model$' "$SK/models.conf"
}
# A pre-0.5 install kept the profile in modelos.conf with Portuguese keys: update carries it into models.conf.
migra_conf() {
  mv "$SK/models.conf" "$SK/modelos.conf"
  printf 'perfil=misto\nforte=opencode/paid\nreserva=opencode/free-b\n' >> "$SK/modelos.conf"
  "$CLI" update
  ausente "$SK/modelos.conf"
  grep -q '^profile=mixed$' "$SK/models.conf"
  grep -q '^strong=opencode/paid$' "$SK/models.conf"
  grep -q '^spare=opencode/free-b$' "$SK/models.conf"
  grep -q '^debate-judge=my/paid-model$' "$SK/models.conf"
  sed -i.bak -e 's/^profile=mixed$/profile=free/' -e 's/^strong=.*/strong=/' "$SK/models.conf"; rm -f "$SK/models.conf.bak"
}
t "update keeps the chosen model" preserva_modelo
t "update keeps models.conf" preserva_conf
t "update migrates a pre-0.5 modelos.conf" migra_conf
t "update swaps only a model that left the catalog" update_repara_rotacao
t "models profile mixed and free" perfil_misto
t "update refuses to overwrite an edit" protege_edicao
t "update --force makes a backup" force_faz_backup

desinstala() {
  : > "$CFG/agents/build.md"
  "$CLI" uninstall
  ausente "$SK" "$CFG/commands/debate.md" "$CFG/agents/debate.md"
  existe "$CFG/agents/build.md"
}
adota_instalacao_antiga() {
  mkdir -p "$CFG/agents"; echo antigo > "$CFG/agents/debate-arch.md"
  nao "$CLI" init > "$WORK/a" 2>&1
  grep -q 'nothing was changed' "$WORK/a"
  [ "$(cat "$CFG/agents/debate-arch.md")" = "antigo" ]
  ausente "$SK"
  "$CLI" init --force
  existe "$SK/.open-debate-manifest"
  "$CLI" uninstall --force
  rm -f "$CFG"/.open-debate-backup-*.tgz
}
projeto() {
  mkdir -p "$WORK/proj"; cd "$WORK/proj"
  "$CLI" init --project
  P=.opencode/skills/architect-debate/scripts
  grep -q "\"$P/\*\": allow" .opencode/agents/debate.md
  grep -q "\"\./$P/\*\": allow" .opencode/agents/debate.md
  nao grep -rn "$WORK" .opencode/agents .opencode/skills/architect-debate/SKILL.md
  ausente "$CFG/agents/debate.md"
  "$CLI" uninstall --project
  ausente .opencode/agents/debate.md
}
sem_yaml_duplicado() {
  (
    export XDG_CONFIG_HOME="$WORK/fora-do-home"
    "$CLI" init
    [ "$(grep -c 'scripts/\*": allow' "$XDG_CONFIG_HOME/opencode/agents/debate.md")" = "1" ]
  )
}
t "uninstall removes only what it installed" desinstala
t "init refuses an old install without --force" adota_instalacao_antiga
t "--project uses a relative path" projeto
t "config outside HOME does not duplicate a YAML key" sem_yaml_duplicado

# --- gates
novo_caso() {
  cd "$WORK"
  rm -rf "$WORK/cases"
  CASO="$("$CLI" new "Triagem de alertas" cases)"
  sed -i.bak 's/^\(- [^:]*:\)[[:space:]]*$/\1 preenchido/' "$CASO/brief.md"; rm -f "$CASO/brief.md.bak"
  printf '%s' "$WORK/$CASO"
}
brief_reprova() {
  cd "$WORK"; c="$("$CLI" new "Brief vazio" cases)"
  nao "$CLI" validate "$c" --brief
}
contraste() {
  c="$(novo_caso)"; cp "$FX/proposal-ux.md" "$c/proposals/debate-ux.md"
  "$CLI" gate "$c" proposal debate-ux
  sed 's/^ink #16181D/ink #C8C8C8/' "$FX/proposal-ux.md" > "$c/proposals/debate-ux.md"
  nao "$CLI" gate "$c" proposal debate-ux > "$WORK/g" 2>&1
  grep -q 'ink/paper' "$WORK/g"
  # With an art director on the panel, TOKENS is theirs: the UX proposal does not answer for contrast.
  "$CLI" gate "$c" proposal debate-ux debate-brand > "$WORK/g" 2>&1 || true
  grep -q 'OK proposal proposals/debate-ux.md' "$WORK/g"
}
adr_com_acento() {
  c="$(novo_caso)"
  sed -e 's/### Considered options/### Considered Options/' -e 's/### Decision outcome/### DECISION OUTCOME/' \
      -e 's/### Confirmation/### Confirmation and review/' "$FX/decision.md" > "$c/decision.md"
  "$CLI" gate "$c" decision
  [ "$(ls "$c"/adr/*.md | wc -l | tr -d ' ')" = "3" ]
}
backlog_pos_com_acento() {
  c="$(novo_caso)"; sed 's/^## Post-launch/## Post launch/' "$FX/BACKLOG.md" > "$c/BACKLOG.md"
  "$CLI" backlog "$c" > /dev/null
  [ "$(jq -r '.[-1].phase' "$c/backlog.json")" = "Post-launch" ]
  [ "$(jq -r '.[0].blocks_phase' "$c/backlog.json")" = "true" ]
}
ciclo() {
  c="$(novo_caso)"; sed 's/dep B15, #launch/dep B15 B17, #launch/' "$FX/BACKLOG.md" > "$c/BACKLOG.md"
  nao "$CLI" gate "$c" backlog > "$WORK/g" 2>&1
  grep -q 'cycle' "$WORK/g"
}
tp "empty brief fails" brief_reprova
tp "contrast gate passes and fails" contraste
tp "ADR headings in any case pass and split" adr_com_acento
tp "backlog recognizes Post launch spelled without a hyphen" backlog_pos_com_acento
chaves_no_titulo() {
  c="$(novo_caso)"
  awk '/^- \[ \] B02 / { sub(/B02 /, "B02 Expor /v1/alerts/{id}/decisoes. ") } { print }' "$FX/BACKLOG.md" > "$c/BACKLOG.md"
  grep -q '{id}' "$c/BACKLOG.md"
  "$CLI" gate "$c" backlog
}
tp "backlog fails a dependency cycle" ciclo
tp "backlog accepts braces in the item text" chaves_no_titulo

# Every gate fails what it promises to fail.
caso_completo() {
  c="$(novo_caso)"
  cp "$FX/research.md" "$c/research.md"; cp "$FX/agenda.md" "$c/agenda.md"
  for a in arch ux pm design brand gcp k8s sec aws data ai mobile; do cp "$FX/proposal-$a.md" "$c/proposals/debate-$a.md"; done
  printf '%s' "$c"
}
reprova() { # reprova <motivo> <gate args...>
  mot="$1"; shift
  nao "$CLI" gate "$@" > "$WORK/g" 2>&1
  grep -q -- "$mot" "$WORK/g" || { cat "$WORK/g"; return 1; }
}
citacao_inventada() {
  c="$(caso_completo)"
  sed -e 's/debate-gcp/debate-k8s/g' "$FX/critique.md" > "$c/critiques/debate-arch.md"
  "$CLI" gate "$c" critique debate-arch
  sed -e 's/debate-gcp/debate-k8s/g' -e 's/option A because it costs less/a sentence nobody wrote/' "$FX/critique.md" > "$c/critiques/debate-arch.md"
  reprova 'excerpt not found' "$c" critique debate-arch
}
citacao_folgada() {
  c="$(caso_completo)"
  sed -e 's/debate-gcp/debate-k8s/g' -e 's/"D1: option A because it costs less"/"  d1:   **OPTION A** ... costs less"/' "$FX/critique.md" > "$c/critiques/debate-arch.md"
  "$CLI" gate "$c" critique debate-arch
}
veto_contra_si() {
  c="$(caso_completo)"
  sed 's/debate-gcp/debate-arch/g' "$FX/critique.md" > "$c/critiques/debate-arch.md"
  reprova 'against itself' "$c" critique debate-arch
}
id_inexistente() {
  c="$(caso_completo)"
  echo 'Price in R99.' >> "$c/proposals/debate-gcp.md"
  reprova 'id missing from research.md: R99' "$c" proposal debate-gcp
}
proposta_sem_agenda() {
  c="$(caso_completo)"
  sed '/^D2:/d' "$FX/proposal-gcp.md" > "$c/proposals/debate-gcp.md"
  reprova 'no position on D2' "$c" proposal debate-gcp
}
agenda_dono_fora() {
  c="$(caso_completo)"
  sed 's/debate-ux/debate-mobile/' "$FX/agenda.md" > "$c/agenda.md"
  reprova 'owner outside the panel' "$c" agenda
}
decisao_caso() { c="$(caso_completo)"; printf '%s' "$c"; }
pesos_errados() {
  c="$(decisao_caso)"; sed 's/speed=40/speed=50/' "$FX/decision.md" > "$c/decision.md"
  reprova 'weights sum 110' "$c" decision
}
placar_errado() {
  c="$(decisao_caso)"; sed 's/| 430 |/| 500 |/' "$FX/decision.md" > "$c/decision.md"
  reprova 'Total of Monolith' "$c" decision
}
dn_sem_decisao() {
  c="$(decisao_caso)"; sed -e '/^### D3/d' "$FX/decision.md" > "$c/decision.md"
  reprova 'agenda D3 without a decision' "$c" decision
}
veto_ignorado() {
  c="$(decisao_caso)"; cp "$FX/decision.md" "$c/decision.md"
  for i in 1 2 3 4 5 6 7 8 9 10; do sed 's/debate-gcp/debate-k8s/' "$FX/critique.md" > "$c/critiques/x$i.md"; done
  reprova 'veto(es) ruled out of 10' "$c" decision
}
errado_ignorado() {
  c="$(decisao_caso)"; cp "$FX/decision.md" "$c/decision.md"
  sed 's/confirmed/wrong/' "$FX/research-check.md" > "$c/research-check.md"
  reprova 'wrong claim(s) zeroed out of 1' "$c" decision
}
tokens_divergem() {
  c="$(decisao_caso)"; cp "$FX/SDD.md" "$c/SDD.md"
  { cat "$FX/decision.md"; printf '\n```\n'; sed -n '/^TOKENS/,/^END/p' "$FX/SDD.md" | sed 's/^accent #[0-9A-Fa-f]*/accent #123456/'; printf '```\n'; } > "$c/decision.md"
  reprova 'differ from the decision.md block' "$c" sdd
}
adr_fora_do_sdd() {
  c="$(decisao_caso)"; cp "$FX/SDD.md" "$c/SDD.md"; mkdir -p "$c/adr"; : > "$c/adr/0099-x.md"
  reprova 'ADR-0099 missing from the SDD' "$c" sdd
}
banido_na_proposta() {
  c="$(caso_completo)"; echo 'Background with glassmorphism.' >> "$c/proposals/debate-design.md"
  reprova 'banned visual' "$c" proposal debate-design
}
# Every seat has its role gate: the fixture passes and removing the keyword fails it.
gate_por_papel() {
  c="$(caso_completo)"
  for a in arch ux pm design brand gcp k8s sec aws data ai mobile; do "$CLI" gate "$c" proposal "debate-$a"; done
  for x in 'pm:metric:no metric' 'design:inventory:no screen inventory' 'brand:logo:no logo' 'aws:iam:no IAM' \
           'data:pipeline:no pipeline' 'ai:eval:no eval' 'mobile:offline:no offline' 'ux:wcag:no WCAG plan'; do
    a="${x%%:*}"; r="${x#*:}"; p="${r%%:*}"; mot="${r#*:}"
    grep -iv -- "$p" "$FX/proposal-$a.md" > "$c/proposals/debate-$a.md"
    reprova "$mot" "$c" proposal "debate-$a"
    cp "$FX/proposal-$a.md" "$c/proposals/debate-$a.md"
  done
}
revisao_do_designer() {
  c="$(caso_completo)"; rm -f "$c/agenda.md"
  sed 's/debate-gcp/debate-ux/g' "$FX/critique.md" > "$c/critiques/debate-design.md"
  sed 's/debate-gcp/debate-ux/g' "$FX/critique.md" > "$c/critiques/debate-arch.md"
  sed 's/debate-gcp/debate-design/g' "$FX/critique-ux.md" > "$c/critiques/debate-ux.md"
  "$CLI" gate "$c" critique debate-ux debate-design
  sed 's/debate-gcp/debate-design/g' "$FX/critique.md" > "$c/critiques/debate-ux.md"
  reprova 'Review debate-design' "$c" critique debate-ux debate-design
  "$CLI" gate "$c" critique debate-ux debate-arch
}
brandbook_gate() {
  c="$(decisao_caso)"; cp "$FX/SDD.md" "$c/SDD.md"; cp "$FX/BRANDBOOK.md" "$c/BRANDBOOK.md"
  "$CLI" gate "$c" brand
  sed 's/^accent #[0-9A-Fa-f]*/accent #0A4FEE/' "$FX/BRANDBOOK.md" > "$c/BRANDBOOK.md"
  reprova 'BRANDBOOK TOKENS differ from the SDD' "$c" brand
  sed '/^| queue /d' "$FX/BRANDBOOK.md" > "$c/BRANDBOOK.md"
  reprova 'section 7 without an adapted screen' "$c" brand
}
# The brief answers may be in any language: Portuguese values trigger the same seats as English ones.
brief_escolhe_painel() {
  cd "$WORK"; rm -rf "$WORK/cases"
  c="$("$CLI" new "App de agendamento para clínicas" cases)"
  case "$c" in */app-de-agendamento-para-clinicas) ;; *) echo "slug kept the accent: $c"; return 1 ;; esac
  sed -i.bak -e 's/^\(- [^:]*:\)[[:space:]]*$/\1 preenchido/' \
    -e 's/^- Sensitive data\([^:]*\):.*/- Sensitive data\1: LGPD, dados de saúde/' \
    -e 's/^- Platform\([^:]*\):.*/- Platform\1: aplicativo iOS e Android na AWS/' \
    -e 's/^- Out of scope:.*/- Out of scope: IA e kubernetes/' "$c/brief.md"; rm -f "$c/brief.md.bak"
  "$CLI" panel "$c" > "$WORK/p"
  grep -q '^panel: debate-arch debate-ux debate-pm debate-design debate-sec debate-mobile debate-aws$' "$WORK/p"
  grep -q 'debate-sec: brief says "lgpd"' "$WORK/p"
  nao grep -q 'debate-ai\|debate-k8s\|debate-gcp' "$WORK/p"
  nao grep -q '^panel:' "$c/meta.txt"
  "$CLI" panel "$c" --save brand
  grep -q '^panel: debate-arch debate-ux debate-pm debate-brand$' "$c/meta.txt"
  sed -i.bak 's/^- Sensitive data\([^:]*\):.*/- Sensitive data\1: nenhum dado pessoal/' "$c/brief.md"; rm -f "$c/brief.md.bak"
  "$CLI" panel "$c" | grep -q '^panel: debate-arch debate-ux debate-pm debate-design debate-mobile debate-aws$'
  sed -i.bak 's/^- Sensitive data\([^:]*\):.*/- Sensitive data\1: health records under HIPAA/' "$c/brief.md"; rm -f "$c/brief.md.bak"
  "$CLI" panel "$c" | grep -q 'debate-sec: brief says "health"'
}
tp "role gate on every seat" gate_por_papel
tp "UX reviews the designer in the critique" revisao_do_designer
tp "brandbook with SDD TOKENS and an adapted screen" brandbook_gate
tp "brief picks the panel in any language, base always" brief_escolhe_painel
saida_gigante() {
  c="$(caso_completo)"; i=0; while [ "$i" -lt 90 ]; do echo "linha $i" >> "$c/proposals/debate-gcp.md"; i=$((i + 1)); done
  reprova 'cap 55' "$c" proposal debate-gcp
}
conta_capacidade() {
  c="$(novo_caso)"; sed 's/= 56 working days/= 90 working days/' "$FX/BACKLOG.md" > "$c/BACKLOG.md"
  reprova 'the arithmetic gives 56' "$c" backlog
}
plano_nao_cabe() {
  c="$(novo_caso)"; sed 's/2 x 8 x 5 x 0.7 = 56 working days/1 x 1 x 5 x 0.7 = 3.5 working days/' "$FX/BACKLOG.md" > "$c/BACKLOG.md"
  reprova 'capacity is 3.5' "$c" backlog
}
soma_escrita_errada() {
  c="$(novo_caso)"; sed 's/backlog sums 29/backlog sums 10/' "$FX/BACKLOG.md" > "$c/BACKLOG.md"
  reprova 'the items sum 29' "$c" backlog
}
tarefa_sem_item() {
  c="$(novo_caso)"; cp "$FX/BACKLOG.md" "$c/BACKLOG.md"
  "$CLI" specs "$c" ingestion > /dev/null
  { cat "$FX/tasks.md"; echo '- [ ] T002 [US1] another'; echo '- [ ] T003 [US1] more'; } > "$c/specs/01-ingestion/tasks.md"
  reprova 'T002' "$c" backlog
  sed 's/spec 01:T001/spec 01:T001-T003/' "$FX/BACKLOG.md" > "$c/BACKLOG.md"
  "$CLI" gate "$c" backlog
}
spec_ruim() {
  c="$(novo_caso)"; "$CLI" specs "$c" ingestion > /dev/null
  d="$c/specs/01-ingestion"; cp "$FX/spec.md" "$FX/plan.md" "$FX/tasks.md" "$d"
  mkdir -p "$c/adr"; : > "$c/adr/0001-x.md"
  sed 's/ADR-0001/ADR-0042/' "$FX/spec.md" > "$d/spec.md"
  nao "$CLI" validate "$c" > "$WORK/g" 2>&1
  grep -q 'ADR-0042, which does not exist' "$WORK/g"
  cp "$FX/spec.md" "$d/spec.md"; sed 's/\[US1\] //' "$FX/tasks.md" > "$d/tasks.md"
  nao "$CLI" validate "$c" > "$WORK/g" 2>&1
  grep -q 'US1 has no task' "$WORK/g"
}
tp "critique with an invented quote fails" citacao_inventada
tp "quote tolerates case, spaces and ellipses" citacao_folgada
tp "veto against itself fails" veto_contra_si
tp "missing Rn id fails" id_inexistente
tp "proposal without an agenda position fails" proposta_sem_agenda
tp "agenda with an owner outside the panel fails" agenda_dono_fora
tp "weights not summing 100 fail" pesos_errados
tp "score table with wrong arithmetic fails" placar_errado
tp "Dn without a decision fails" dn_sem_decisao
tp "unruled veto fails" veto_ignorado
tp "wrong claim not zeroed fails" errado_ignorado
tp "SDD TOKENS different from decision.md fail" tokens_divergem
tp "ADR missing from the SDD fails" adr_fora_do_sdd
tp "banned visual fails the proposal" banido_na_proposta
tp "output far over the cap fails" saida_gigante
tp "wrong capacity arithmetic fails" conta_capacidade
tp "plan over capacity fails" plano_nao_cabe
tp "written sum different from the items fails" soma_escrita_errada
tp "task without an item fails, a range covers it" tarefa_sem_item
tp "spec with a missing ADR or a US without a task fails" spec_ruim

# --- the whole protocol with the opencode stub
e2e() {
  c="$(novo_caso)"
  SPECS=0 MODEL=stub/modelo "$CLI" run "$c" 3
  for f in research.md agenda.md proposals/debate-arch.md proposals/debate-ux.md critiques/debate-pm.md research-check.md decision.md \
           adr/0001-use-a-modular-monolith.md SDD.md audit.md style-tile.html tokens.json tokens.css raw/metrics.tsv; do
    [ -s "$c/$f" ] || { echo "missing $f"; return 1; }
  done
  ausente "$c/BACKLOG.md"
  jq -e '.color.paper["$value"].hex == "#F2EFE8" and .motion.easing["$value"] == [0.2,0.8,0.2,1]' "$c/tokens.json"
  "$CLI" specs "$c" ingestion triage report
  for d in "$c"/specs/*/; do cp "$FX/spec.md" "$FX/plan.md" "$FX/tasks.md" "$d"; done
  [ "$(ls "$c"/checklists/ | wc -l | tr -d ' ')" = "3" ]
  SPECS=0 MODEL=stub/modelo "$CLI" run "$c" 3
  [ -s "$c/backlog.csv" ]
  [ -s "$c/backlog-gh.sh" ]
  [ "$(jq length "$c/backlog.json")" = "17" ]
  sh -n "$c/backlog-gh.sh"
  "$CLI" validate "$c"
}
retoma() {
  c="$(novo_caso)"
  SPECS=0 MODEL=stub/modelo "$CLI" run "$c" 1
  log="$WORK/retoma.log"; : > "$log"
  SPECS=0 STUB_LOG="$log" MODEL=stub/modelo "$CLI" run "$c" 1
  nao grep -q 'phase proposal' "$log"
}
reparo() {
  c="$(novo_caso)"; rm -f "$STUB_STATE".*
  SPECS=0 FAIL_ONCE=decision.md MODEL=stub/modelo "$CLI" run "$c" 1
  grep -q 'gate decision ok after repair' "$c/raw/summary.log"
}
sem_instalar() {
  export HOME="$WORK/home-vazio" XDG_CONFIG_HOME="$WORK/home-vazio/.config"; mkdir -p "$HOME"
  c="$(novo_caso)"
  nao "$CLI" run "$c" > "$WORK/r" 2>&1
  grep -q 'open-debate init' "$WORK/r"
}
replica_so_de_vetado() {
  c="$(novo_caso)"
  SPECS=0 MODEL=stub/modelo "$CLI" run "$c" 3
  # The stub always targets the 1st rival: arch vetoes ux and the rest veto arch; pm takes no veto.
  grep -q '^panel: debate-arch debate-ux debate-pm$' "$c/meta.txt"
  existe "$c/proposals/debate-arch-r2.md" "$c/proposals/debate-ux-r2.md"
  ausente "$c/proposals/debate-pm-r2.md"
}
auditoria_corrige() {
  c="$(novo_caso)"
  log="$WORK/aud.log"; : > "$log"
  STUB_LOG="$log" STUB_AUDIT=audit-fix.md SPECS=0 MODEL=stub/modelo "$CLI" run "$c" 1
  grep -q 'phase fix' "$log"
  grep -q '^Verdict: APPLIED' "$c/audit.md"
  : > "$log"
  STUB_LOG="$log" STUB_AUDIT=audit-fix.md SPECS=0 MODEL=stub/modelo "$CLI" run "$c" 1
  nao grep -q 'phase fix' "$log"
}
auditoria_aprova_sem_reemitir() {
  c="$(novo_caso)"
  log="$WORK/aud.log"; : > "$log"
  STUB_LOG="$log" SPECS=0 MODEL=stub/modelo "$CLI" run "$c" 1
  grep -q 'phase audit' "$log"
  nao grep -q 'phase fix' "$log"
}
agenda_pulada_em_caso_antigo() {
  c="$(novo_caso)"
  for a in arch ux pm; do sed '/^D[0-9]:/d' "$FX/proposal-$a.md" > "$c/proposals/debate-$a.md"; done
  SPECS=0 MODEL=stub/modelo "$CLI" run "$c" 1
  grep -q '^skipped' "$c/agenda.md"
}
tarefa_pede_texto() {
  c="$(novo_caso)"
  log="$WORK/txt.log"; : > "$log"
  STUB_LOG="$log" SPECS=0 REVIEW=0 MODEL=stub/modelo "$CLI" run "$c" 1
  n="$(wc -l < "$log" | tr -d ' ')"
  [ "$n" -ge 5 ]
  [ "$(grep -c 'do not write files' "$log")" = "$n" ]
  [ "$(grep -c 'Write it in English' "$log")" = "$n" ]
}
assumido_citado() {
  c="$(novo_caso)"
  echo 'Goal: `[assumed]` premises validated.' >> "$c/idea.md"
  "$CLI" validate "$c" --brief
  grep -q 'assumed' "$c/idea.md"
  cp "$FX/research.md" "$c/research.md"
  nao "$CLI" validate "$c" > "$WORK/g" 2>&1
  nao grep -q 'assumed-without-owner' "$WORK/g"
  echo 'Deadline [assumed] with nobody responsible.' >> "$c/idea.md"
  nao "$CLI" validate "$c" > "$WORK/g" 2>&1
  grep -q 'assumed-without-owner' "$WORK/g"
}
retoma_status() {
  c="$(novo_caso)"
  "$CLI" status "$c" | grep -q '^next: research$'
  SPECS=0 MODEL=stub/modelo "$CLI" run "$c" 1
  "$CLI" status "$c" > "$WORK/s"
  grep -q '^decision *ok' "$WORK/s"
  grep -q '^next: specs$' "$WORK/s"
  grep -q '^cost: ' "$WORK/s"
}
status_lista() {
  cd "$WORK"; rm -rf cases
  "$CLI" new "first idea" cases > /dev/null; "$CLI" new "second idea" cases > /dev/null
  "$CLI" status > "$WORK/s"
  grep -q '^cases/first-idea  *brief$' "$WORK/s"
  grep -q '^cases/second-idea  *brief$' "$WORK/s"
  rm -rf cases; nao "$CLI" status > /dev/null 2>&1
}
caso_legado() {
  c="$(novo_caso)"; mv "$c/debate-rules.md" "$c/regras-debate.md"
  "$CLI" status "$c" | grep -q 'before open-debate 0.5'
  nao env SPECS=0 MODEL=stub/modelo "$CLI" run "$c" 1 > "$WORK/x" 2>&1
  grep -q -- '--from research' "$WORK/x"
  SPECS=0 MODEL=stub/modelo "$CLI" run "$c" 1 --from research
  existe "$c/debate-rules.md"; ausente "$c/regras-debate.md"
}
parse_tolerante() {
  c="$(novo_caso)"; sed 's/^on-accent #FFFFFF/on-accent #FFF/' "$FX/proposal-ux.md" > "$c/proposals/debate-ux.md"
  "$CLI" gate "$c" proposal debate-ux
  sed 's/est S,/est s,/g; s/est M,/est m,/g' "$FX/BACKLOG.md" > "$c/BACKLOG.md"
  "$CLI" gate "$c" backlog
}
defasagem() {
  c="$(novo_caso)"
  SPECS=0 MODEL=stub/modelo "$CLI" run "$c" 1
  touch -t 203001010000 "$c/brief.md"
  "$CLI" status "$c" | grep -q 'brief.md newer than research.md'
  SPECS=0 MODEL=stub/modelo "$CLI" run "$c" 1 > "$WORK/x"
  grep -q 'warning: brief.md newer' "$WORK/x"
}
from_arquiva() {
  c="$(novo_caso)"
  SPECS=0 MODEL=stub/modelo "$CLI" run "$c" 3
  log="$WORK/from.log"; : > "$log"
  FROM=critique STUB_LOG="$log" SPECS=0 MODEL=stub/modelo "$CLI" run "$c" 3
  ls "$c"/raw/archive/*/critiques/debate-arch.md
  ls "$c"/raw/archive/*/decision.md
  nao grep -q 'phase proposal' "$log"
  grep -q 'phase critique' "$log"
  [ -s "$c/decision.md" ]
}
from_invalido() { c="$(novo_caso)"; nao "$CLI" run "$c" --from nada > "$WORK/x" 2>&1; grep -q 'invalid --from' "$WORK/x"; }
sala_cega() {
  c="$(novo_caso)"; cp "$FX/research.md" "$c/research.md"
  cat > "$WORK/espia" <<ESPIA
#!/bin/sh
case "\$PROMPT" in *"phase proposal"*|*"phase critique"*) ;; *) exec $ROOT/test/stub/harness pi "\$PROMPT" ;; esac
{ echo "== \$PWD"; find . -type f | sort; } >> $WORK/espia.log
sleep 1
exec $ROOT/test/stub/harness pi "\$PROMPT"
ESPIA
  : > "$WORK/espia.log"
  HARNESS=custom HARNESS_CMD="exec sh $WORK/espia" SPECS=0 "$CLI" run "$c" --rounds 2
  grep -q 'raw/rooms/proposal-arch' "$WORK/espia.log"
  awk '/^== .*rooms\/proposal/ { f = 1; next } /^== / { f = 0 } f' "$WORK/espia.log" > "$WORK/p.txt"
  grep -q 'brief.md' "$WORK/p.txt"
  nao grep -q 'proposals/\|critiques/' "$WORK/p.txt"
  awk '/^== .*rooms\/critique-arch/ { f = 1; next } /^== / { f = 0 } f' "$WORK/espia.log" > "$WORK/a.txt"
  grep -q 'proposals/debate-ux.md' "$WORK/a.txt"
  nao grep -q 'proposals/debate-arch.md\|critiques/' "$WORK/a.txt"
  ausente "$c/raw/rooms" "$c/raw/.lock"
}
limite_espera() {
  c="$(novo_caso)"
  cat > "$WORK/lim" <<LIM
#!/bin/sh
if [ ! -e $WORK/lim.foi ]; then : > $WORK/lim.foi; echo 'HTTP 429 too many requests' >&2; exit 1; fi
exec $ROOT/test/stub/harness pi "\$PROMPT"
LIM
  HARNESS=custom HARNESS_CMD="exec sh $WORK/lim" BACKOFF=1 SPECS=0 "$CLI" run "$c" --rounds 1
  grep -q 'rate limit in debate-research' "$c/raw/summary.log"
  [ -s "$c/decision.md" ]
}
auth_nao_repete() {
  c="$(novo_caso)"
  cat > "$WORK/aut" <<AUT
#!/bin/sh
echo x >> $WORK/aut.n
echo 'Error: invalid api key' >&2; exit 1
AUT
  : > "$WORK/aut.n"
  nao env HARNESS=custom HARNESS_CMD="exec sh $WORK/aut" RETRIES=3 SPECS=0 "$CLI" run "$c" --rounds 1 > "$WORK/x" 2>&1
  [ "$(wc -l < "$WORK/aut.n" | tr -d ' ')" = "1" ]
  grep -q 'auth or quota' "$c/raw/summary.log"
}
paralelo_limita() {
  c="$(novo_caso)"; cp "$FX/research.md" "$c/research.md"
  cat > "$WORK/par" <<PAR
#!/bin/sh
mkdir -p $WORK/par.d; : > $WORK/par.d/\$\$
n="\$(ls $WORK/par.d | wc -l | tr -d ' ')"; echo "\$n" >> $WORK/par.log
sleep 1
rm -f $WORK/par.d/\$\$
exec $ROOT/test/stub/harness pi "\$PROMPT"
PAR
  : > "$WORK/par.log"
  HARNESS=custom HARNESS_CMD="exec sh $WORK/par" PARALLEL=2 SPECS=0 REVIEW=0 "$CLI" run "$c" --rounds 1
  [ "$(sort -n "$WORK/par.log" | tail -1)" = "2" ]
}
teto_chamadas() {
  c="$(novo_caso)"
  nao env MAX_CALLS=3 SPECS=0 MODEL=stub/modelo "$CLI" run "$c" 1 > "$WORK/x" 2>&1
  grep -q 'MAX_CALLS=3 cap' "$c/raw/summary.log"
}
lock_recusa() {
  c="$(novo_caso)"
  mkdir -p "$c/raw/.lock"; sleep 30 & p=$!
  echo "$p" > "$c/raw/.lock/pid"
  nao env SPECS=0 MODEL=stub/modelo "$CLI" run "$c" 1 > "$WORK/x" 2>&1
  grep -q 'case already running' "$WORK/x"
  kill "$p"
  wait "$p" || true
  SPECS=0 MODEL=stub/modelo "$CLI" run "$c" 1
}
interrompe_mata_filhos() {
  c="$(novo_caso)"
  HARNESS=custom HARNESS_CMD="exec sh -c 'echo \$\$ > $WORK/filho; exec sleep 300'" RESEARCH=0 SPECS=0 "$ROOT/template/skills/architect-debate/scripts/debate.sh" "$c" 1 > "$WORK/x" 2>&1 &
  p=$!
  i=0; while [ ! -s "$WORK/filho" ] && [ "$i" -lt 300 ]; do sleep 0.1; i=$((i + 1)); done
  f="$(cat "$WORK/filho")"
  kill -TERM "$p"
  wait "$p" || true
  i=0; while kill -0 "$f" 2>/dev/null && [ "$i" -lt 30 ]; do sleep 0.1; i=$((i + 1)); done
  nao kill -0 "$f" 2>/dev/null
  ausente "$c/raw/.lock"
}
painel_com_sec() {
  (
    export PATH="$FAKE:$PATH"
    c="$(novo_caso)"
    SPECS=0 REVIEW=0 "$CLI" run "$c" --harness pi --panel arch,design,sec --rounds 2
    [ -s "$c/proposals/debate-sec.md" ]
  )
}
painel_invalido() { c="$(novo_caso)"; nao "$CLI" run "$c" --panel arch,azure > "$WORK/x" 2>&1; grep -q 'unknown persona' "$WORK/x"; }
# Panel with a designer and an art director: UX reviews the screens, the brand closes the brandbook and enters the backlog.
painel_de_marca() {
  (
    export PATH="$FAKE:$PATH"
    c="$(novo_caso)"
    REVIEW=0 "$CLI" run "$c" --harness pi --panel design,brand --rounds 2 > "$WORK/x" 2>&1
    grep -q '^panel: debate-arch debate-ux debate-pm debate-design debate-brand$' "$c/meta.txt"
    grep -q 'base seat added: debate-arch debate-ux debate-pm' "$c/raw/summary.log"
    grep -q '^## Review debate-design' "$c/critiques/debate-ux.md"
    grep -q 'gate brand ok' "$c/raw/summary.log"
    [ -s "$c/BRANDBOOK.md" ]
    "$CLI" status "$c" | grep -q '^brand *ok'
    "$CLI" validate "$c"
    # With a brandbook, the brand tag becomes required in the backlog.
    sed 's/ #brand//' "$FX/BACKLOG.md" > "$c/BACKLOG.md"
    reprova 'brand' "$c" backlog
  )
}
tp "full protocol up to the backlog" e2e
tp "rebuttal only for vetoed agents" replica_so_de_vetado
tp "audit with a defect fixes once" auditoria_corrige
tp "approved audit does not re-emit the SDD" auditoria_aprova_sem_reemitir
tp "old case with proposals goes on without an agenda" agenda_pulada_em_caso_antigo
tp "status shows the next phase" retoma_status
tp "status without a case lists every case" status_lista
tp "legacy Portuguese case is refused until --from research" caso_legado
tp "TOKENS accept short hex and the backlog lowercase estimates" parse_tolerante
tp "every task asks for the content as the answer, in English" tarefa_pede_texto
tp "[assumed] in backticks is not an assumption" assumido_citado
tp "edited input raises a warning" defasagem
tp "--from archives and redoes only from there on" from_arquiva
tp "invalid --from fails early" from_invalido
tp "panel with an unknown persona fails early" painel_invalido
tp "call cap stops the run" teto_chamadas
tp "second run refuses, a dead run's lock does not block" lock_recusa
tp "running again reuses outputs" retoma
tp "failed gate gets 1 repair" reparo
tp "run without install points to init" sem_instalar

# --- harnesses: each fake CLI returns the answer in its real format

instala_todos() {
  (
    export PATH="$FAKE:$PATH"
    "$CLI" harnesses | grep -q 'Antigravity CLI'
    "$CLI" init --all
    for f in .claude/agents/debate-arch.md .claude/skills/debate/SKILL.md .codex/agents/debate-arch.toml .agents/skills/debate/SKILL.md \
             .cursor/agents/debate-judge.md .gemini/agents/debate-pm.md .gemini/commands/debate.toml .gemini/config/skills/debate/SKILL.md \
             .omp/agent/agents/debate-arch.md .pi/agent/skills/debate/SKILL.md .dsh/skills/debate/SKILL.md .factory/droids/debate-scout.md \
             .copilot/agents/debate-arch.agent.md .qwen/agents/debate-k8s.md .qwen/commands/debate.toml .cline/skills/debate/SKILL.md; do
      existe "$HOME/$f"
    done
    ausente "$HOME/.claude/agents/debate.md" "$HOME/.pi/agent/agents"
    nao grep -rn '{{[A-Z_]*}}' "$HOME/.claude" "$HOME/.codex" "$HOME/.agents" "$HOME/.gemini" "$HOME/.omp" "$HOME/.pi" "$HOME/.dsh" "$HOME/.factory" "$HOME/.copilot" "$HOME/.qwen" "$HOME/.cline"
    grep -q '^tools: Read, Glob, Grep, Write, Edit, WebSearch, WebFetch$' "$HOME/.claude/agents/debate-arch.md"
    grep -q '^tools: Read, Glob, Grep, Write, Edit$' "$HOME/.claude/agents/debate-pm.md"
    grep -q '^model: haiku$' "$HOME/.claude/agents/debate-scout.md"
    grep -q '^model: inherit$' "$HOME/.claude/agents/debate-judge.md"
    existe "$HOME/.claude/agents/debate-sec.md" "$HOME/.claude/agents/debate-auditor.md"
    grep -q 'allowed-tools: Bash(~/.claude/skills/architect-debate/scripts/\*)' "$HOME/.claude/skills/debate/SKILL.md"
    grep -q 'ARGUMENTS' "$HOME/.claude/skills/debate/SKILL.md"
    grep -q 'HARNESS=dsh' "$HOME/.dsh/skills/debate/SKILL.md"
    grep -q '{{args}}' "$HOME/.gemini/commands/debate.toml"
    jq -Rs 'length' "$HOME/.codex/agents/debate-arch.toml" > /dev/null
  )
}
toml_valido() {
  f="$HOME/.codex/agents/debate-arch.toml"
  [ "$(sed -n 1p "$f")" = 'name = "debate-arch"' ]
  grep -q '^description = ".*"$' "$f"
  grep -q "^developer_instructions = '''$" "$f"
  [ "$(grep -c "'''" "$f")" = "2" ]
  [ "$(tail -1 "$f")" = "'''" ]
}
update_preserva_modelo_comentado() {
  (
    export PATH="$FAKE:$PATH"
    sed -i.bak 's/^# model = .*/model = "gpt-minha"/' "$HOME/.codex/agents/debate-arch.toml"; rm -f "$HOME/.codex/agents/debate-arch.toml.bak"
    sed -i.bak 's/^# model: .*/model: meu-modelo/' "$HOME/.copilot/agents/debate-pm.agent.md"; rm -f "$HOME/.copilot/agents/debate-pm.agent.md.bak"
    "$CLI" update --harness codex,copilot
    grep -q '^model = "gpt-minha"$' "$HOME/.codex/agents/debate-arch.toml"
    grep -q '^model: meu-modelo$' "$HOME/.copilot/agents/debate-pm.agent.md"
    "$CLI" doctor
  )
}
desinstala_todos() {
  (
    export PATH="$FAKE:$PATH"
    "$CLI" uninstall --all
    ausente "$HOME/.claude/agents/debate-arch.md" "$HOME/.agents/skills" "$HOME/.codex/agents/debate-arch.toml" "$HOME/.gemini/commands/debate.toml" "$HOME/.dsh/skills"
  )
}
projeto_multi() {
  (
    export PATH="$FAKE:$PATH"
    mkdir -p "$WORK/proj2"; cd "$WORK/proj2"
    "$CLI" init --project --harness claude,codex,agy
    existe .claude/agents/debate-arch.md .codex/agents/debate-arch.toml .agents/skills/architect-debate/SKILL.md
    grep -q 'debate-arch' .agents/skills/debate/SKILL.md
    "$CLI" uninstall --project --harness codex
    "$CLI" init --project --harness agy,codex > "$WORK/x" 2>&1
    grep -q 'share .agents/skills' "$WORK/x"
    grep -q 'HARNESS=agy' .agents/skills/debate/SKILL.md
    "$CLI" uninstall --project --harness claude,agy
    ausente .claude .agents
  )
}
harness_nao_detectado() { nao "$CLI" init --harness nada > "$WORK/x" 2>&1; grep -q 'unknown harness' "$WORK/x"; }
nada_detectado() {
  ( export PATH="/usr/bin:/bin" HOME="$WORK/home-vazio" XDG_CONFIG_HOME="$WORK/home-vazio/.config"; mkdir -p "$HOME"; nao "$CLI" init > "$WORK/x" 2>&1 )
  grep -q 'no harness detected' "$WORK/x"
}
t "init --all installs in the 13 harnesses" instala_todos
t "Codex agent is valid TOML" toml_valido
t "update keeps a model on a commented line" update_preserva_modelo_comentado
t "uninstall --all cleans everything" desinstala_todos
t "--project in several harnesses" projeto_multi
t "unknown harness fails" harness_nao_detectado
t "no harness gives guidance" nada_detectado

protocolo_em() {
  (
    export PATH="$FAKE:$PATH"
    c="$(novo_caso)"; d="$c"
    REVIEW=0 "$CLI" run "$c" --harness "$1" --rounds 1
    for f in research.md decision.md SDD.md BACKLOG.md backlog.csv specs/01-ingestion/spec.md specs/02-triage/tasks.md specs/03-report/plan.md; do
      [ -s "$d/$f" ] || { echo "missing $f"; return 1; }
    done
    "$CLI" validate "$c"
    grep -q "^harness: $1$" "$c/meta.txt"
  )
}
mesa() {
  (
    export PATH="$FAKE:$PATH"
    log="$WORK/mesa.log"; : > "$log"
    c="$(novo_caso)"
    STUB_LOG="$log" "$CLI" run "$c" --harness claude --mix codex,gemini --panel arch,design --rounds 1
    grep -q 'codex.*debate-arch\|^codex' "$log"
    grep -q '^gemini' "$log"
    grep -q '^claude' "$log"
    grep -q 'routes=debate-arch=codex debate-ux=gemini debate-pm=codex debate-design=gemini' "$c/raw/summary.log"
  )
}
custom() {
  (
    c="$(novo_caso)"
    HARNESS=custom HARNESS_CMD="exec $ROOT/test/stub/harness pi \"\$PROMPT\"" SPECS=0 "$CLI" run "$c" --rounds 1
    [ -s "$c/decision.md" ]
  )
}
tempo_esgotado() {
  c="$(novo_caso)"
  nao env HARNESS=custom HARNESS_CMD='sleep 5' TIMEOUT=1 RETRIES=1 RESEARCH=0 SPECS=0 "$CLI" run "$c" --rounds 1 > "$WORK/x" 2>&1
  grep -q 'timed out in debate-' "$c/raw/summary.log"
}
binario_ausente() {
  c="$(novo_caso)"
  nao "$CLI" run "$c" --harness codex > "$WORK/x" 2>&1
  grep -q 'codex not found' "$WORK/x"
}
retoma_specs() {
  (
    export PATH="$FAKE:$PATH"
    c="$(novo_caso)"
    "$CLI" run "$c" --harness pi --rounds 1
    echo edited >> "$c/specs/01-ingestion/spec.md"
    "$CLI" run "$c" --harness pi --rounds 1
    grep -q '^edited$' "$c/specs/01-ingestion/spec.md"
  )
}
spec_reparo() {
  (
    export PATH="$FAKE:$PATH"
    c="$(novo_caso)"; rm -f "$STUB_STATE".*
    FAIL_ONCE=spec-bundle.md "$CLI" run "$c" --harness pi --rounds 1
    grep -q 'spec gate failed' "$c/raw/summary.log"
    grep -q 'specs gate ok' "$c/raw/summary.log"
  )
}
probe() {
  ( export PATH="$FAKE:$PATH"; for h in claude codex gemini; do "$ROOT/template/skills/architect-debate/scripts/probe.sh" "$h"; done )
}
for h in claude codex cursor gemini agy omp pi dsh droid copilot qwen cline; do tp "full protocol through $h" protocolo_em "$h"; done
tp "panel with debate-sec" painel_com_sec
tp "panel with a designer and an art director" painel_de_marca
tp "agents run in a room without rival output" sala_cega
tp "429 limit waits and retries" limite_espera
tp "auth failure does not retry" auth_nao_repete
tp "PARALLEL caps simultaneous calls" paralelo_limita
tp "interrupt kills the calls in flight" interrompe_mata_filhos
tp "mix spreads the panel across harnesses" mesa
tp "custom harness through HARNESS_CMD" custom
tp "timeout says it was a timeout" tempo_esgotado
tp "missing binary fails early" binario_ausente
tp "rerun does not overwrite an edited spec" retoma_specs
tp "failed spec gets a repair" spec_reparo
em_dash() {
  [ -x /bin/dash ] || return 0
  S="$ROOT/template/skills/architect-debate/scripts"
  cat > "$WORK/d.sh" <<EOF
SCRIPT_DIR="$S"; TIMEOUT=1; HARNESS_CMD='echo saida'
TO="perl -e alarm(shift);exec(@ARGV)||die 1"
. "$S/harness.sh"
h_run custom debate-pm oi "" "$WORK" "$WORK/d.raw" || exit 9
[ "\$(cat "$WORK/d.raw")" = "saida" ] || exit 8
HARNESS_CMD='sleep 5'; rc=0
h_run custom debate-pm oi "" "$WORK" "$WORK/d.raw" || rc=\$?
[ "\$rc" -eq 142 ] || exit 7
EOF
  /bin/dash "$WORK/d.sh" > "$WORK/d.saida" 2>&1
  [ ! -s "$WORK/d.saida" ]
}
tp "probe calls through the adapter" probe
tp "adapter writes to a file and computes the timeout under dash" em_dash

# --- one-line installer, without network
bootstrap() {
  tar -czf "$WORK/pacote.tgz" -C "$ROOT/.." "$(basename "$ROOT")"
  (
    export OPEN_DEBATE_TARBALL="$WORK/pacote.tgz" OPEN_DEBATE_HOME="$WORK/od-home" OPEN_DEBATE_BIN="$WORK/od-bin"
    export HOME="$WORK/home-boot" XDG_CONFIG_HOME="$WORK/home-boot/.config"; mkdir -p "$HOME"
    sh "$ROOT/install.sh"
    "$WORK/od-bin/open-debate" --version
    sh "$ROOT/install.sh"
  )
  [ "$("$WORK/od-bin/open-debate" --version)" = "$(jq -r .version "$ROOT/package.json")" ]
}
tp "install.sh installs and reinstalls" bootstrap
upgrade_sem_ref() { nao "$CLI" upgrade --check 2>/dev/null; }
tp "upgrade refuses an install without install.sh" upgrade_sem_ref

# --- execution. The `t` tests touch the install: they run in order, in a single pool job, with their own HOME.
# The `tp` tests share the main HOME, where opencode is installed once beforehand, and only read it.
"$CLI" init --harness opencode > "$WORK/init-pool" 2>&1 || { cat "$WORK/init-pool"; exit 1; }
cadeia() {
  export HOME="$WORK/home-inst" XDG_CONFIG_HOME="$WORK/home-inst/.config"; mkdir -p "$HOME"
  CFG="$XDG_CONFIG_HOME/opencode"; SK="$CFG/skills/architect-debate"
  k=0
  while IFS='|' read -r tipo nome cmd; do
    k=$((k + 1)); [ "$tipo" = "s" ] || continue
    # shellcheck disable=SC2086
    executa "$WORK/t$k" $cmd
  done < "$REG"
}
cadeia &
: > "$WORK/.pids"; echo "$!" >> "$WORK/.pids"
k=0
while IFS='|' read -r tipo nome cmd; do
  k=$((k + 1)); [ "$tipo" = "p" ] || continue
  # Slot: drop finished jobs from the pool; when full, wait for the oldest.
  while :; do
    vivos=""; nv=0
    for p_ in $(cat "$WORK/.pids"); do if kill -0 "$p_" 2>/dev/null; then vivos="$vivos $p_"; nv=$((nv + 1)); fi; done
    printf '%s\n' $vivos > "$WORK/.pids"
    [ "$nv" -ge "$JOBS" ] || break
    set -- $vivos; wait "$1" 2>/dev/null || true
  done
  # shellcheck disable=SC2086
  executa "$WORK/t$k" $cmd &
  echo "$!" >> "$WORK/.pids"
done < "$REG"
wait
k=0
while IFS='|' read -r tipo nome cmd; do k=$((k + 1)); relata "$WORK/t$k" "$nome"; done < "$REG"

printf '\n%s ok, %s failure(s)\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
