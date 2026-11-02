#!/bin/sh
# run.sh - suite sem dependencias: CLI, instalador, gates e o protocolo inteiro com opencode stub.
# Sai 1 se algum teste falhar.
set -u
export LC_ALL=C

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
CLI="$ROOT/bin/open-debate"
FX="$ROOT/test/fixtures"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export PATH="$ROOT/test/stub:$PATH"
export HOME="$WORK/home" XDG_CONFIG_HOME="$WORK/home/.config"
mkdir -p "$HOME"
CFG="$XDG_CONFIG_HOME/opencode"
SK="$CFG/skills/architect-debate"
export STUB_STATE="$WORK/stub-state"

PASS=0; FAIL=0
# Fora de `if`: dentro dele o set -e seria ignorado e so a ultima linha do teste contaria.
# Pelo mesmo motivo, asserts usam `nao` (nunca `! cmd`) e 1 comando por linha (nunca `a && b`).
t() {
  nome="$1"; shift
  ( set -e; "$@" ) > "$WORK/saida" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then PASS=$((PASS + 1)); printf 'ok   %s\n' "$nome"
  else FAIL=$((FAIL + 1)); printf 'FAIL %s\n' "$nome"; sed 's/^/     /' "$WORK/saida"; fi
}
nao() { if "$@"; then return 1; fi; }
existe() { for x in "$@"; do [ -e "$x" ] || { echo "ausente: $x"; return 1; }; done; }
ausente() { for x in "$@"; do [ ! -e "$x" ] || { echo "sobrou: $x"; return 1; }; done; }

# --- CLI
versao() { [ "$("$CLI" --version)" = "$(jq -r .version "$ROOT/package.json")" ]; }
ajuda() { "$CLI" --help | grep -q 'open-debate init'; }
desconhecido() { nao "$CLI" foobar; }
symlink() { ln -s "$CLI" "$WORK/od"; "$WORK/od" --version; }
t "--version le package.json" versao
t "--help lista comandos" ajuda
t "comando desconhecido falha" desconhecido
t "funciona via symlink (npm bin)" symlink

# --- seguranca do pacote
sem_vazamento() {
  grep -rnIE '/Users/|eskudo|apiKey|api_key|sk-[A-Za-z0-9]{20}|\.config/opencode' "$ROOT/template" "$ROOT/lib/install.sh" \
    | grep -v 'XDG_CONFIG_HOME' > "$WORK/vaza" || true
  cat "$WORK/vaza"
  [ ! -s "$WORK/vaza" ]
}
frontmatter_sem_glob_aberto() { nao grep -n '"\*[a-z-]*/scripts' "$ROOT/template/agents/debate.md"; }
t "template sem caminho local nem segredo" sem_vazamento
t "permissao de bash nao usa glob aberto a esquerda" frontmatter_sem_glob_aberto

# --- instalador
init_global() {
  "$CLI" init
  existe "$CFG/agents/debate-judge.md" "$CFG/commands/debate.md"
  [ -x "$SK/scripts/gate.sh" ]
  nao grep -rn '{{' "$CFG/agents" "$CFG/commands" "$SK/SKILL.md"
  grep -q '"~/.config/opencode/skills/architect-debate/scripts/\*": allow' "$CFG/agents/debate.md"
  grep -q "\"$SK/scripts/\*\": allow" "$CFG/agents/debate.md"
}
modelos_aplicados() { grep -q '^model: opencode/gratis-a$' "$CFG/agents/debate-judge.md"; }
idempotente() { "$CLI" init | grep -q '0 novo(s), 0 atualizado(s), 0 sobrescrito(s)'; }
doctor_ok() { "$CLI" doctor; }
t "init instala e renderiza caminhos" init_global
t "init troca modelo fora do catalogo" modelos_aplicados
t "init de novo nao muda nada" idempotente
t "doctor passa" doctor_ok

preserva_modelo() {
  sed -i.bak 's/^model: .*/model: meu\/modelo-pago/' "$CFG/agents/debate-arch.md"; rm -f "$CFG/agents/debate-arch.md.bak"
  "$CLI" update
  grep -q '^model: meu/modelo-pago$' "$CFG/agents/debate-arch.md"
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
  echo 'debate-judge=meu/modelo-pago' >> "$SK/modelos.conf"
  "$CLI" update
  grep -q '^debate-judge=meu/modelo-pago$' "$SK/modelos.conf"
}
t "update preserva modelo escolhido" preserva_modelo
t "update preserva modelos.conf" preserva_conf
t "update recusa sobrescrever edicao" protege_edicao
t "update --force faz backup" force_faz_backup

desinstala() {
  : > "$CFG/agents/build.md"
  "$CLI" uninstall
  ausente "$SK" "$CFG/commands/debate.md" "$CFG/agents/debate.md"
  existe "$CFG/agents/build.md"
}
adota_instalacao_antiga() {
  mkdir -p "$CFG/agents"; echo antigo > "$CFG/agents/debate-arch.md"
  nao "$CLI" init > "$WORK/a" 2>&1
  grep -q 'nada foi alterado' "$WORK/a"
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
t "uninstall remove so o que instalou" desinstala
t "init recusa instalacao antiga sem --force" adota_instalacao_antiga
t "--project usa caminho relativo" projeto
t "config fora do HOME nao duplica chave YAML" sem_yaml_duplicado

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
  c="$(novo_caso)"; cp "$FX/proposta-design.md" "$c/proposals/debate-design.md"
  "$CLI" gate "$c" proposta debate-design
  sed 's/^tinta #16181D/tinta #C8C8C8/' "$FX/proposta-design.md" > "$c/proposals/debate-design.md"
  nao "$CLI" gate "$c" proposta debate-design > "$WORK/g" 2>&1
  grep -q 'tinta/papel' "$WORK/g"
}
adr_com_acento() {
  c="$(novo_caso)"
  sed -e 's/### Opcoes consideradas/### Opções consideradas/' -e 's/### Resultado da decisao/### Resultado da decisão/' \
      -e 's/### Confirmacao/### Confirmação/' "$FX/decision.md" > "$c/decision.md"
  "$CLI" gate "$c" decisao
  [ "$(ls "$c"/adr/*.md | wc -l | tr -d ' ')" = "3" ]
}
backlog_pos_com_acento() {
  c="$(novo_caso)"; cp "$FX/BACKLOG.md" "$c/BACKLOG.md"
  "$CLI" backlog "$c" > /dev/null
  [ "$(jq -r '.[-1].fase' "$c/backlog.json")" = "Pos-lancamento" ]
}
ciclo() {
  c="$(novo_caso)"; sed 's/dep B15, #lancamento/dep B15 B17, #lancamento/' "$FX/BACKLOG.md" > "$c/BACKLOG.md"
  nao "$CLI" gate "$c" backlog > "$WORK/g" 2>&1
  grep -q 'ciclo' "$WORK/g"
}
t "brief vazio reprova" brief_reprova
t "gate de contraste aprova e reprova" contraste
t "ADR com acento passa e separa" adr_com_acento
t "backlog reconhece Pos-lancamento com acento" backlog_pos_com_acento
t "backlog reprova ciclo de dependencia" ciclo

# --- protocolo inteiro com opencode stub
e2e() {
  "$CLI" init
  c="$(novo_caso)"
  MODEL=stub/modelo "$CLI" run "$c" 3
  for f in research.md proposals/debate-arch.md proposals/debate-design-r2.md critiques/debate-k8s.md research-check.md decision.md \
           adr/0001-usar-monolito-modular.md SDD.md style-tile.html tokens.json tokens.css; do
    [ -s "$c/$f" ] || { echo "faltou $f"; return 1; }
  done
  ausente "$c/BACKLOG.md"
  jq -e '.color.papel["$value"].hex == "#F2EFE8" and .motion.easing["$value"] == [0.2,0.8,0.2,1]' "$c/tokens.json"
  "$CLI" specs "$c" ingestao triagem relatorio
  for d in "$c"/specs/*/; do cp "$FX/spec.md" "$FX/plan.md" "$FX/tasks.md" "$d"; done
  [ "$(ls "$c"/checklists/ | wc -l | tr -d ' ')" = "3" ]
  MODEL=stub/modelo "$CLI" run "$c" 3
  [ -s "$c/backlog.csv" ]
  [ -s "$c/backlog-gh.sh" ]
  [ "$(jq length "$c/backlog.json")" = "17" ]
  sh -n "$c/backlog-gh.sh"
  "$CLI" validate "$c"
}
retoma() {
  c="$(novo_caso)"
  MODEL=stub/modelo "$CLI" run "$c" 1
  log="$WORK/retoma.log"; : > "$log"
  STUB_LOG="$log" MODEL=stub/modelo "$CLI" run "$c" 1
  nao grep -q 'fase proposta' "$log"
}
reparo() {
  c="$(novo_caso)"; rm -f "$STUB_STATE".*
  FAIL_ONCE=decision.md MODEL=stub/modelo "$CLI" run "$c" 1
  grep -q 'gate decisao ok apos reparo' "$c/raw/summary.log"
}
sem_instalar() {
  "$CLI" uninstall --force
  c="$(novo_caso)"
  nao "$CLI" run "$c" > "$WORK/r" 2>&1
  grep -q 'open-debate init' "$WORK/r"
}
t "protocolo completo ate o backlog" e2e
t "rodar de novo reaproveita saidas" retoma
t "gate reprovado ganha 1 reparo" reparo
t "run sem instalar orienta init" sem_instalar

printf '\n%s ok, %s falha(s)\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
