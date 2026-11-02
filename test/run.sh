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
# PATH hermetico: um harness real instalado na maquina nao pode ser detectado nem chamado pela suite.
FERR="$WORK/ferramentas"; mkdir -p "$FERR"
for c in jq perl; do ln -s "$(command -v "$c")" "$FERR/$c"; done
export PATH="$ROOT/test/stub:$FERR:/usr/bin:/bin"
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
frontmatter_sem_glob_aberto() { nao grep -n '"\*[a-z-]*/scripts' "$ROOT/template/skills/architect-debate/personas/debate.md"; }
t "template sem caminho local nem segredo" sem_vazamento
t "permissao de bash nao usa glob aberto a esquerda" frontmatter_sem_glob_aberto

# --- instalador
init_global() {
  "$CLI" init --yes
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
chaves_no_titulo() {
  c="$(novo_caso)"
  awk '/^- \[ \] B02 / { sub(/B02 /, "B02 Expor /v1/alerts/{id}/decisoes. ") } { print }' "$FX/BACKLOG.md" > "$c/BACKLOG.md"
  grep -q '{id}' "$c/BACKLOG.md"
  "$CLI" gate "$c" backlog
}
t "backlog reprova ciclo de dependencia" ciclo
t "backlog aceita chaves no texto do item" chaves_no_titulo

# --- protocolo inteiro com opencode stub
e2e() {
  "$CLI" init
  c="$(novo_caso)"
  SPECS=0 MODEL=stub/modelo "$CLI" run "$c" 3
  for f in research.md proposals/debate-arch.md proposals/debate-design-r2.md critiques/debate-k8s.md research-check.md decision.md \
           adr/0001-usar-monolito-modular.md SDD.md style-tile.html tokens.json tokens.css; do
    [ -s "$c/$f" ] || { echo "faltou $f"; return 1; }
  done
  ausente "$c/BACKLOG.md"
  jq -e '.color.papel["$value"].hex == "#F2EFE8" and .motion.easing["$value"] == [0.2,0.8,0.2,1]' "$c/tokens.json"
  "$CLI" specs "$c" ingestao triagem relatorio
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
  nao grep -q 'fase proposta' "$log"
}
reparo() {
  c="$(novo_caso)"; rm -f "$STUB_STATE".*
  SPECS=0 FAIL_ONCE=decision.md MODEL=stub/modelo "$CLI" run "$c" 1
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

# --- harnesses: cada CLI falso devolve a resposta no formato real dele
FAKE="$WORK/fake"; mkdir -p "$FAKE"
for h in claude codex cursor-agent gemini agy omp pi dsh droid copilot qwen cline; do ln -s "$ROOT/test/stub/harness" "$FAKE/$h"; done
TODOS="opencode claude codex cursor gemini agy omp pi dsh droid copilot qwen cline"

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
    grep -q 'dividem .agents/skills' "$WORK/x"
    grep -q 'HARNESS=agy' .agents/skills/debate/SKILL.md
    "$CLI" uninstall --project --harness claude,agy
    ausente .claude .agents
  )
}
harness_nao_detectado() { nao "$CLI" init --harness nada > "$WORK/x" 2>&1; grep -q 'harness desconhecido' "$WORK/x"; }
nada_detectado() {
  ( export PATH="/usr/bin:/bin" HOME="$WORK/home-vazio" XDG_CONFIG_HOME="$WORK/home-vazio/.config"; mkdir -p "$HOME"; nao "$CLI" init > "$WORK/x" 2>&1 )
  grep -q 'nenhum harness detectado' "$WORK/x"
}
t "init --all instala nos 13 harnesses" instala_todos
t "agent do Codex e TOML valido" toml_valido
t "update preserva modelo em linha comentada" update_preserva_modelo_comentado
t "uninstall --all limpa tudo" desinstala_todos
t "--project em varios harnesses" projeto_multi
t "harness desconhecido falha" harness_nao_detectado
t "sem harness orienta" nada_detectado

protocolo_em() {
  (
    export PATH="$FAKE:$PATH"
    "$CLI" init --harness opencode > /dev/null 2>&1 || true
    c="$(novo_caso)"; d="$c"
    REVIEW=0 "$CLI" run "$c" --harness "$1" --rounds 1
    for f in research.md decision.md SDD.md BACKLOG.md backlog.csv specs/01-ingestao/spec.md specs/02-triagem/tasks.md specs/03-relatorio/plan.md; do
      [ -s "$d/$f" ] || { echo "faltou $f"; return 1; }
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
    STUB_LOG="$log" "$CLI" run "$c" --harness claude --mesa codex,gemini --painel arch,design --rounds 1
    grep -q 'codex.*debate-arch\|^codex' "$log"
    grep -q '^gemini' "$log"
    grep -q '^claude' "$log"
    grep -q 'rotas=debate-arch=codex debate-design=gemini' "$c/raw/summary.log"
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
  grep -q 'tempo esgotado em debate-' "$c/raw/summary.log"
}
binario_ausente() {
  c="$(novo_caso)"
  nao "$CLI" run "$c" --harness codex > "$WORK/x" 2>&1
  grep -q 'codex nao encontrado' "$WORK/x"
}
retoma_specs() {
  (
    export PATH="$FAKE:$PATH"
    c="$(novo_caso)"
    "$CLI" run "$c" --harness pi --rounds 1
    echo editado >> "$c/specs/01-ingestao/spec.md"
    "$CLI" run "$c" --harness pi --rounds 1
    grep -q '^editado$' "$c/specs/01-ingestao/spec.md"
  )
}
spec_reparo() {
  (
    export PATH="$FAKE:$PATH"
    c="$(novo_caso)"; rm -f "$STUB_STATE".*
    FAIL_ONCE=spec-bundle.md "$CLI" run "$c" --harness pi --rounds 1
    grep -q 'gate spec reprovado' "$c/raw/summary.log"
    grep -q 'gate specs ok' "$c/raw/summary.log"
  )
}
probe() {
  ( export PATH="$FAKE:$PATH"; for h in claude codex gemini; do "$ROOT/template/skills/architect-debate/scripts/probe.sh" "$h"; done )
}
for h in claude codex cursor gemini agy omp pi dsh droid copilot qwen cline; do t "protocolo completo via $h" protocolo_em "$h"; done
t "mesa distribui o painel entre harnesses" mesa
t "harness custom via HARNESS_CMD" custom
t "timeout diz que foi timeout" tempo_esgotado
t "binario ausente falha cedo" binario_ausente
t "rerun nao sobrescreve spec editada" retoma_specs
t "spec reprovada ganha reparo" spec_reparo
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
t "probe faz chamada pelo adapter" probe
t "adapter grava em arquivo e calcula timeout sob dash" em_dash

# --- instalador de uma linha, sem rede
bootstrap() {
  tar -czf "$WORK/pacote.tgz" -C "$ROOT/.." "$(basename "$ROOT")"
  (
    export OPEN_DEBATE_TARBALL="$WORK/pacote.tgz" OPEN_DEBATE_HOME="$WORK/od-home" OPEN_DEBATE_BIN="$WORK/od-bin"
    sh "$ROOT/install.sh"
    "$WORK/od-bin/open-debate" --version
    sh "$ROOT/install.sh"
  )
  [ "$("$WORK/od-bin/open-debate" --version)" = "$(jq -r .version "$ROOT/package.json")" ]
}
t "install.sh instala e reinstala" bootstrap

printf '\n%s ok, %s falha(s)\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
