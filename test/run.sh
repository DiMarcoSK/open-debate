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
# CLIs falsos com o nome de cada harness: o nome do link escolhe o formato de saida.
FAKE="$WORK/fake"; mkdir -p "$FAKE"
for h in claude codex cursor-agent gemini agy omp pi dsh droid copilot qwen cline; do ln -s "$ROOT/test/stub/harness" "$FAKE/$h"; done
TODOS="opencode claude codex cursor gemini agy omp pi dsh droid copilot qwen cline"

PASS=0; FAIL=0
# Registro: `t` roda em sequencia (mexe no HOME ou na instalacao), `tp` roda em paralelo num pool de JOBS.
# Cada teste roda num subshell com WORK, STUB_STATE e stdin proprios; o resultado sai na ordem do registro.
# Fora de `if`: dentro dele o set -e seria ignorado e so a ultima linha do teste contaria.
# Pelo mesmo motivo, asserts usam `nao` (nunca `! cmd`) e 1 comando por linha (nunca `a && b`).
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
existe() { for x in "$@"; do [ -e "$x" ] || { echo "ausente: $x"; return 1; }; done; }
ausente() { for x in "$@"; do [ ! -e "$x" ] || { echo "sobrou: $x"; return 1; }; done; }

# --- CLI
versao() { [ "$("$CLI" --version)" = "$(jq -r .version "$ROOT/package.json")" ]; }
ajuda() { "$CLI" --help | grep -q 'open-debate init'; }
desconhecido() { nao "$CLI" foobar; }
symlink() { ln -s "$CLI" "$WORK/od"; "$WORK/od" --version; }
tp "--version le package.json" versao
tp "--help lista comandos" ajuda
tp "comando desconhecido falha" desconhecido
tp "funciona via symlink (npm bin)" symlink

# --- seguranca do pacote
sem_vazamento() {
  grep -rnIE '/Users/|eskudo|apiKey|api_key|sk-[A-Za-z0-9]{20}|\.config/opencode' "$ROOT/template" "$ROOT/lib/install.sh" \
    | grep -v 'XDG_CONFIG_HOME' > "$WORK/vaza" || true
  cat "$WORK/vaza"
  [ ! -s "$WORK/vaza" ]
}
frontmatter_sem_glob_aberto() { nao grep -n '"\*[a-z-]*/scripts' "$ROOT/template/skills/architect-debate/personas/debate.md"; }
tp "template sem caminho local nem segredo" sem_vazamento
tp "permissao de bash nao usa glob aberto a esquerda" frontmatter_sem_glob_aberto

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
  sed -i.bak 's/^model: .*/model: opencode\/pago/' "$CFG/agents/debate-arch.md"; rm -f "$CFG/agents/debate-arch.md.bak"
  "$CLI" update
  grep -q '^model: opencode/pago$' "$CFG/agents/debate-arch.md"
}
update_repara_rotacao() {
  sed -i.bak 's/^model: .*/model: opencode\/sumiu/' "$CFG/agents/debate-ux.md"; rm -f "$CFG/agents/debate-ux.md.bak"
  "$CLI" update
  grep -q '^model: opencode/gratis-' "$CFG/agents/debate-ux.md"
  grep -q '^model: opencode/pago$' "$CFG/agents/debate-arch.md"
}
perfil_misto() {
  nao "$CLI" models profile misto opencode/inexistente
  "$CLI" models profile misto opencode/pago
  grep -q '^model: opencode/pago$' "$CFG/agents/debate-judge.md"
  grep -q '^model: opencode/gratis-' "$CFG/agents/debate-scout.md"
  "$CLI" models check | grep -q '^perfil misto, forte=opencode/pago$'
  "$CLI" models profile gratis
  grep -q '^model: opencode/gratis-' "$CFG/agents/debate-judge.md"
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
t "update troca so modelo que saiu do catalogo" update_repara_rotacao
t "models profile misto e gratis" perfil_misto
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
  c="$(novo_caso)"; cp "$FX/proposta-ux.md" "$c/proposals/debate-ux.md"
  "$CLI" gate "$c" proposta debate-ux
  sed 's/^tinta #16181D/tinta #C8C8C8/' "$FX/proposta-ux.md" > "$c/proposals/debate-ux.md"
  nao "$CLI" gate "$c" proposta debate-ux > "$WORK/g" 2>&1
  grep -q 'tinta/papel' "$WORK/g"
  # Com diretor de arte no painel, o TOKENS e dele: a proposta de UX nao responde pelo contraste.
  "$CLI" gate "$c" proposta debate-ux debate-brand > "$WORK/g" 2>&1 || true
  grep -q 'OK proposta proposals/debate-ux.md' "$WORK/g"
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
tp "brief vazio reprova" brief_reprova
tp "gate de contraste aprova e reprova" contraste
tp "ADR com acento passa e separa" adr_com_acento
tp "backlog reconhece Pos-lancamento com acento" backlog_pos_com_acento
chaves_no_titulo() {
  c="$(novo_caso)"
  awk '/^- \[ \] B02 / { sub(/B02 /, "B02 Expor /v1/alerts/{id}/decisoes. ") } { print }' "$FX/BACKLOG.md" > "$c/BACKLOG.md"
  grep -q '{id}' "$c/BACKLOG.md"
  "$CLI" gate "$c" backlog
}
tp "backlog reprova ciclo de dependencia" ciclo
tp "backlog aceita chaves no texto do item" chaves_no_titulo

# Cada gate novo reprova o que promete reprovar.
caso_completo() {
  c="$(novo_caso)"
  cp "$FX/research.md" "$c/research.md"; cp "$FX/agenda.md" "$c/agenda.md"
  for a in arch ux pm design brand gcp k8s sec aws data ai mobile; do cp "$FX/proposta-$a.md" "$c/proposals/debate-$a.md"; done
  printf '%s' "$c"
}
reprova() { # reprova <motivo> <gate args...>
  mot="$1"; shift
  nao "$CLI" gate "$@" > "$WORK/g" 2>&1
  grep -q -- "$mot" "$WORK/g" || { cat "$WORK/g"; return 1; }
}
citacao_inventada() {
  c="$(caso_completo)"
  sed -e 's/debate-gcp/debate-k8s/g' "$FX/ataque.md" > "$c/critiques/debate-arch.md"
  "$CLI" gate "$c" ataque debate-arch
  sed -e 's/debate-gcp/debate-k8s/g' -e 's/opcao A porque custa menos/frase que ninguem escreveu/' "$FX/ataque.md" > "$c/critiques/debate-arch.md"
  reprova 'trecho nao existe' "$c" ataque debate-arch
}
citacao_folgada() {
  c="$(caso_completo)"
  sed -e 's/debate-gcp/debate-k8s/g' -e 's/"D1: opcao A porque custa menos"/"  d1:   **OPCAO A** ... custa menos"/' "$FX/ataque.md" > "$c/critiques/debate-arch.md"
  "$CLI" gate "$c" ataque debate-arch
}
veto_contra_si() {
  c="$(caso_completo)"
  sed 's/debate-gcp/debate-arch/g' "$FX/ataque.md" > "$c/critiques/debate-arch.md"
  reprova 'contra si mesmo' "$c" ataque debate-arch
}
id_inexistente() {
  c="$(caso_completo)"
  echo 'Preco em R99.' >> "$c/proposals/debate-gcp.md"
  reprova 'id inexistente em research.md: R99' "$c" proposta debate-gcp
}
proposta_sem_agenda() {
  c="$(caso_completo)"
  sed '/^D2:/d' "$FX/proposta-gcp.md" > "$c/proposals/debate-gcp.md"
  reprova 'sem posicao em D2' "$c" proposta debate-gcp
}
agenda_dono_fora() {
  c="$(caso_completo)"
  sed 's/debate-ux/debate-mobile/' "$FX/agenda.md" > "$c/agenda.md"
  reprova 'dono fora do painel' "$c" agenda
}
decisao_caso() { c="$(caso_completo)"; printf '%s' "$c"; }
pesos_errados() {
  c="$(decisao_caso)"; sed 's/velocidade=40/velocidade=50/' "$FX/decision.md" > "$c/decision.md"
  reprova 'pesos somam 110' "$c" decisao
}
placar_errado() {
  c="$(decisao_caso)"; sed 's/| 430 |/| 500 |/' "$FX/decision.md" > "$c/decision.md"
  reprova 'Total de Monolito' "$c" decisao
}
dn_sem_decisao() {
  c="$(decisao_caso)"; sed -e '/^### D3/d' "$FX/decision.md" > "$c/decision.md"
  reprova 'D3 da agenda sem decisao' "$c" decisao
}
veto_ignorado() {
  c="$(decisao_caso)"; cp "$FX/decision.md" "$c/decision.md"
  for i in 1 2 3 4 5 6 7 8 9 10; do sed 's/debate-gcp/debate-k8s/' "$FX/ataque.md" > "$c/critiques/x$i.md"; done
  reprova 'veto(s) julgado(s) de 10' "$c" decisao
}
errado_ignorado() {
  c="$(decisao_caso)"; cp "$FX/decision.md" "$c/decision.md"
  sed 's/confirmado/errado/' "$FX/research-check.md" > "$c/research-check.md"
  reprova 'errado(s) zerado(s) de 1' "$c" decisao
}
tokens_divergem() {
  c="$(decisao_caso)"; cp "$FX/SDD.md" "$c/SDD.md"
  { cat "$FX/decision.md"; printf '\n```\n'; sed -n '/^TOKENS/,/^FIM/p' "$FX/SDD.md" | sed 's/^acento #[0-9A-Fa-f]*/acento #123456/'; printf '```\n'; } > "$c/decision.md"
  reprova 'difere do bloco de decision.md' "$c" sdd
}
adr_fora_do_sdd() {
  c="$(decisao_caso)"; cp "$FX/SDD.md" "$c/SDD.md"; mkdir -p "$c/adr"; : > "$c/adr/0099-x.md"
  reprova 'ADR-0099 fora do SDD' "$c" sdd
}
banido_na_proposta() {
  c="$(caso_completo)"; echo 'Fundo com glassmorphism.' >> "$c/proposals/debate-design.md"
  reprova 'visual banido' "$c" proposta debate-design
}
# Cada assento tem o seu gate de papel: a fixture passa e tirar a palavra-chave reprova.
gate_por_papel() {
  c="$(caso_completo)"
  for a in arch ux pm design brand gcp k8s sec aws data ai mobile; do "$CLI" gate "$c" proposta "debate-$a"; done
  for x in 'pm:metrica:sem metrica' 'design:inventario:sem inventario' 'brand:logo:sem logo' 'aws:iam:sem IAM' \
           'data:pipeline:sem pipeline' 'ai:eval:sem eval' 'mobile:offline:sem offline' 'ux:wcag:sem plano WCAG'; do
    a="${x%%:*}"; r="${x#*:}"; p="${r%%:*}"; mot="${r#*:}"
    grep -iv -- "$p" "$FX/proposta-$a.md" > "$c/proposals/debate-$a.md"
    reprova "$mot" "$c" proposta "debate-$a"
    cp "$FX/proposta-$a.md" "$c/proposals/debate-$a.md"
  done
}
revisao_do_designer() {
  c="$(caso_completo)"; rm -f "$c/agenda.md"
  sed 's/debate-gcp/debate-ux/g' "$FX/ataque.md" > "$c/critiques/debate-design.md"
  sed 's/debate-gcp/debate-ux/g' "$FX/ataque.md" > "$c/critiques/debate-arch.md"
  sed 's/debate-gcp/debate-design/g' "$FX/ataque-ux.md" > "$c/critiques/debate-ux.md"
  "$CLI" gate "$c" ataque debate-ux debate-design
  sed 's/debate-gcp/debate-design/g' "$FX/ataque.md" > "$c/critiques/debate-ux.md"
  reprova 'Revisao debate-design' "$c" ataque debate-ux debate-design
  "$CLI" gate "$c" ataque debate-ux debate-arch
}
brandbook_gate() {
  c="$(decisao_caso)"; cp "$FX/SDD.md" "$c/SDD.md"; cp "$FX/BRANDBOOK.md" "$c/BRANDBOOK.md"
  "$CLI" gate "$c" marca
  sed 's/^acento #[0-9A-Fa-f]*/acento #0A4FEE/' "$FX/BRANDBOOK.md" > "$c/BRANDBOOK.md"
  reprova 'TOKENS do BRANDBOOK difere do SDD' "$c" marca
  sed '/^| fila /d' "$FX/BRANDBOOK.md" > "$c/BRANDBOOK.md"
  reprova 'secao 7 sem tela adaptada' "$c" marca
}
brief_escolhe_painel() {
  cd "$WORK"; rm -rf "$WORK/cases"
  c="$("$CLI" new "App de agendamento para clinicas" cases)"
  sed -i.bak -e 's/^\(- [^:]*:\)[[:space:]]*$/\1 preenchido/' \
    -e 's/^- Dados sensiveis\([^:]*\):.*/- Dados sensiveis\1: LGPD, dados de saúde/' \
    -e 's/^- Plataforma\([^:]*\):.*/- Plataforma\1: aplicativo iOS e Android na AWS/' \
    -e 's/^- Fora do escopo:.*/- Fora do escopo: IA e kubernetes/' "$c/brief.md"; rm -f "$c/brief.md.bak"
  "$CLI" painel "$c" > "$WORK/p"
  grep -q '^painel: debate-arch debate-ux debate-pm debate-design debate-sec debate-mobile debate-aws$' "$WORK/p"
  grep -q 'debate-sec: brief diz "lgpd"' "$WORK/p"
  nao grep -q 'debate-ai\|debate-k8s\|debate-gcp' "$WORK/p"
  nao grep -q '^painel:' "$c/meta.txt"
  "$CLI" painel "$c" --grava brand
  grep -q '^painel: debate-arch debate-ux debate-pm debate-brand$' "$c/meta.txt"
  sed -i.bak 's/^- Dados sensiveis\([^:]*\):.*/- Dados sensiveis\1: nenhum dado pessoal/' "$c/brief.md"; rm -f "$c/brief.md.bak"
  "$CLI" painel "$c" | grep -q '^painel: debate-arch debate-ux debate-pm debate-design debate-mobile debate-aws$'
}
tp "gate de papel em cada assento" gate_por_papel
tp "UX revisa o designer no ataque" revisao_do_designer
tp "brandbook com TOKENS do SDD e tela adaptada" brandbook_gate
tp "brief escolhe o painel, base sempre" brief_escolhe_painel
saida_gigante() {
  c="$(caso_completo)"; i=0; while [ "$i" -lt 90 ]; do echo "linha $i" >> "$c/proposals/debate-gcp.md"; i=$((i + 1)); done
  reprova 'teto 55' "$c" proposta debate-gcp
}
conta_capacidade() {
  c="$(novo_caso)"; sed 's/= 56 dias/= 90 dias/' "$FX/BACKLOG.md" > "$c/BACKLOG.md"
  reprova 'a conta da 56' "$c" backlog
}
plano_nao_cabe() {
  c="$(novo_caso)"; sed 's/2 x 8 x 5 x 0.7 = 56 dias/1 x 1 x 5 x 0.7 = 3.5 dias/' "$FX/BACKLOG.md" > "$c/BACKLOG.md"
  reprova 'capacidade e 3.5' "$c" backlog
}
soma_escrita_errada() {
  c="$(novo_caso)"; sed 's/backlog soma 29/backlog soma 10/' "$FX/BACKLOG.md" > "$c/BACKLOG.md"
  reprova 'os itens somam 29' "$c" backlog
}
tarefa_sem_item() {
  c="$(novo_caso)"; cp "$FX/BACKLOG.md" "$c/BACKLOG.md"
  "$CLI" specs "$c" ingestao > /dev/null
  { cat "$FX/tasks.md"; echo '- [ ] T002 [US1] outra'; echo '- [ ] T003 [US1] mais'; } > "$c/specs/01-ingestao/tasks.md"
  reprova 'T002' "$c" backlog
  sed 's/spec 01:T001/spec 01:T001-T003/' "$FX/BACKLOG.md" > "$c/BACKLOG.md"
  "$CLI" gate "$c" backlog
}
spec_ruim() {
  c="$(novo_caso)"; "$CLI" specs "$c" ingestao > /dev/null
  d="$c/specs/01-ingestao"; cp "$FX/spec.md" "$FX/plan.md" "$FX/tasks.md" "$d"
  mkdir -p "$c/adr"; : > "$c/adr/0001-x.md"
  sed 's/ADR-0001/ADR-0042/' "$FX/spec.md" > "$d/spec.md"
  nao "$CLI" validate "$c" > "$WORK/g" 2>&1
  grep -q 'ADR-0042, que nao existe' "$WORK/g"
  cp "$FX/spec.md" "$d/spec.md"; sed 's/\[US1\] //' "$FX/tasks.md" > "$d/tasks.md"
  nao "$CLI" validate "$c" > "$WORK/g" 2>&1
  grep -q 'US1 sem task' "$WORK/g"
}
tp "ataque com citacao inventada reprova" citacao_inventada
tp "citacao aceita caixa, espacos e reticencias" citacao_folgada
tp "veto contra si mesmo reprova" veto_contra_si
tp "id Rn inexistente reprova" id_inexistente
tp "proposta sem posicao na agenda reprova" proposta_sem_agenda
tp "agenda com dono fora do painel reprova" agenda_dono_fora
tp "pesos fora de 100 reprovam" pesos_errados
tp "placar com conta errada reprova" placar_errado
tp "Dn sem decisao reprova" dn_sem_decisao
tp "veto nao julgado reprova" veto_ignorado
tp "claim errado nao zerado reprova" errado_ignorado
tp "TOKENS do SDD diferente de decision.md reprova" tokens_divergem
tp "ADR fora do SDD reprova" adr_fora_do_sdd
tp "visual banido reprova na proposta" banido_na_proposta
tp "saida muito acima do teto reprova" saida_gigante
tp "conta de capacidade errada reprova" conta_capacidade
tp "plano acima da capacidade reprova" plano_nao_cabe
tp "soma escrita diferente dos itens reprova" soma_escrita_errada
tp "task sem item reprova, intervalo cobre" tarefa_sem_item
tp "spec com ADR inexistente ou US sem task reprova" spec_ruim

# --- protocolo inteiro com opencode stub
e2e() {
  c="$(novo_caso)"
  SPECS=0 MODEL=stub/modelo "$CLI" run "$c" 3
  for f in research.md agenda.md proposals/debate-arch.md proposals/debate-ux.md critiques/debate-pm.md research-check.md decision.md \
           adr/0001-usar-monolito-modular.md SDD.md auditoria.md style-tile.html tokens.json tokens.css raw/metricas.tsv; do
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
  export HOME="$WORK/home-vazio" XDG_CONFIG_HOME="$WORK/home-vazio/.config"; mkdir -p "$HOME"
  c="$(novo_caso)"
  nao "$CLI" run "$c" > "$WORK/r" 2>&1
  grep -q 'open-debate init' "$WORK/r"
}
replica_so_de_vetado() {
  c="$(novo_caso)"
  SPECS=0 MODEL=stub/modelo "$CLI" run "$c" 3
  # O stub sempre mira o 1o rival: arch veta ux e os demais vetam arch; pm nao leva veto.
  grep -q '^painel: debate-arch debate-ux debate-pm$' "$c/meta.txt"
  existe "$c/proposals/debate-arch-r2.md" "$c/proposals/debate-ux-r2.md"
  ausente "$c/proposals/debate-pm-r2.md"
}
auditoria_corrige() {
  c="$(novo_caso)"
  log="$WORK/aud.log"; : > "$log"
  STUB_LOG="$log" STUB_AUDITORIA=auditoria-corrigir.md SPECS=0 MODEL=stub/modelo "$CLI" run "$c" 1
  grep -q 'fase correcao' "$log"
  grep -q '^Veredito: APLICADO' "$c/auditoria.md"
  : > "$log"
  STUB_LOG="$log" STUB_AUDITORIA=auditoria-corrigir.md SPECS=0 MODEL=stub/modelo "$CLI" run "$c" 1
  nao grep -q 'fase correcao' "$log"
}
auditoria_aprova_sem_reemitir() {
  c="$(novo_caso)"
  log="$WORK/aud.log"; : > "$log"
  STUB_LOG="$log" SPECS=0 MODEL=stub/modelo "$CLI" run "$c" 1
  grep -q 'fase auditoria' "$log"
  nao grep -q 'fase correcao' "$log"
}
agenda_pulada_em_caso_antigo() {
  c="$(novo_caso)"
  for a in arch ux pm; do sed '/^D[0-9]:/d' "$FX/proposta-$a.md" > "$c/proposals/debate-$a.md"; done
  SPECS=0 MODEL=stub/modelo "$CLI" run "$c" 1
  grep -q '^pulado' "$c/agenda.md"
}
tarefa_pede_texto() {
  c="$(novo_caso)"
  log="$WORK/txt.log"; : > "$log"
  STUB_LOG="$log" SPECS=0 REVIEW=0 MODEL=stub/modelo "$CLI" run "$c" 1
  n="$(wc -l < "$log" | tr -d ' ')"
  [ "$n" -ge 5 ]
  [ "$(grep -c 'nao grava arquivo' "$log")" = "$n" ]
}
assumido_citado() {
  c="$(novo_caso)"
  echo 'Meta: premissas `[assumido]` validadas.' >> "$c/idea.md"
  "$CLI" validate "$c" --brief
  grep -q 'assumido' "$c/idea.md"
  cp "$FX/research.md" "$c/research.md"
  nao "$CLI" validate "$c" > "$WORK/g" 2>&1
  nao grep -q 'assumido-sem-dono' "$WORK/g"
  echo 'Prazo [assumido] sem responsavel.' >> "$c/idea.md"
  nao "$CLI" validate "$c" > "$WORK/g" 2>&1
  grep -q 'assumido-sem-dono' "$WORK/g"
}
retoma_status() {
  c="$(novo_caso)"
  "$CLI" status "$c" | grep -q '^proxima: pesquisa$'
  SPECS=0 MODEL=stub/modelo "$CLI" run "$c" 1
  "$CLI" status "$c" > "$WORK/s"
  grep -q '^decisao *ok' "$WORK/s"
  grep -q '^proxima: specs$' "$WORK/s"
  grep -q '^custo: ' "$WORK/s"
}
defasagem() {
  c="$(novo_caso)"
  SPECS=0 MODEL=stub/modelo "$CLI" run "$c" 1
  touch -t 203001010000 "$c/brief.md"
  "$CLI" status "$c" | grep -q 'brief.md mais novo que research.md'
  SPECS=0 MODEL=stub/modelo "$CLI" run "$c" 1 > "$WORK/x"
  grep -q 'aviso: brief.md mais novo' "$WORK/x"
}
from_arquiva() {
  c="$(novo_caso)"
  SPECS=0 MODEL=stub/modelo "$CLI" run "$c" 3
  log="$WORK/from.log"; : > "$log"
  FROM=ataque STUB_LOG="$log" SPECS=0 MODEL=stub/modelo "$CLI" run "$c" 3
  ls "$c"/raw/arquivo/*/critiques/debate-arch.md
  ls "$c"/raw/arquivo/*/decision.md
  nao grep -q 'fase proposta' "$log"
  grep -q 'fase ataque' "$log"
  [ -s "$c/decision.md" ]
}
from_invalido() { c="$(novo_caso)"; nao "$CLI" run "$c" --from nada > "$WORK/x" 2>&1; grep -q 'from invalido' "$WORK/x"; }
sala_cega() {
  c="$(novo_caso)"; cp "$FX/research.md" "$c/research.md"
  cat > "$WORK/espia" <<ESPIA
#!/bin/sh
case "\$PROMPT" in *"fase proposta"*|*"fase ataque"*) ;; *) exec $ROOT/test/stub/harness pi "\$PROMPT" ;; esac
{ echo "== \$PWD"; find . -type f | sort; } >> $WORK/espia.log
sleep 1
exec $ROOT/test/stub/harness pi "\$PROMPT"
ESPIA
  : > "$WORK/espia.log"
  HARNESS=custom HARNESS_CMD="exec sh $WORK/espia" SPECS=0 "$CLI" run "$c" --rounds 2
  grep -q 'raw/salas/proposta-arch' "$WORK/espia.log"
  awk '/^== .*salas\/proposta/ { f = 1; next } /^== / { f = 0 } f' "$WORK/espia.log" > "$WORK/p.txt"
  grep -q 'brief.md' "$WORK/p.txt"
  nao grep -q 'proposals/\|critiques/' "$WORK/p.txt"
  awk '/^== .*salas\/ataque-arch/ { f = 1; next } /^== / { f = 0 } f' "$WORK/espia.log" > "$WORK/a.txt"
  grep -q 'proposals/debate-ux.md' "$WORK/a.txt"
  nao grep -q 'proposals/debate-arch.md\|critiques/' "$WORK/a.txt"
  ausente "$c/raw/salas" "$c/raw/.lock"
}
limite_espera() {
  c="$(novo_caso)"
  cat > "$WORK/lim" <<LIM
#!/bin/sh
if [ ! -e $WORK/lim.foi ]; then : > $WORK/lim.foi; echo 'HTTP 429 too many requests' >&2; exit 1; fi
exec $ROOT/test/stub/harness pi "\$PROMPT"
LIM
  HARNESS=custom HARNESS_CMD="exec sh $WORK/lim" BACKOFF=1 SPECS=0 "$CLI" run "$c" --rounds 1
  grep -q 'limite em debate-research' "$c/raw/summary.log"
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
  grep -q 'auth ou cota' "$c/raw/summary.log"
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
  HARNESS=custom HARNESS_CMD="exec sh $WORK/par" PARALELO=2 SPECS=0 REVIEW=0 "$CLI" run "$c" --rounds 1
  [ "$(sort -n "$WORK/par.log" | tail -1)" = "2" ]
}
teto_chamadas() {
  c="$(novo_caso)"
  nao env MAX_CHAMADAS=3 SPECS=0 MODEL=stub/modelo "$CLI" run "$c" 1 > "$WORK/x" 2>&1
  grep -q 'teto de MAX_CHAMADAS=3' "$c/raw/summary.log"
}
lock_recusa() {
  c="$(novo_caso)"
  mkdir -p "$c/raw/.lock"; sleep 30 & p=$!
  echo "$p" > "$c/raw/.lock/pid"
  nao env SPECS=0 MODEL=stub/modelo "$CLI" run "$c" 1 > "$WORK/x" 2>&1
  grep -q 'caso em execucao' "$WORK/x"
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
    SPECS=0 REVIEW=0 "$CLI" run "$c" --harness pi --painel arch,design,sec --rounds 2
    [ -s "$c/proposals/debate-sec.md" ]
  )
}
painel_invalido() { c="$(novo_caso)"; nao "$CLI" run "$c" --painel arch,azure > "$WORK/x" 2>&1; grep -q 'persona inexistente' "$WORK/x"; }
# Painel com designer e diretor de arte: UX revisa as telas, a marca fecha o brandbook e entra no backlog.
painel_de_marca() {
  (
    export PATH="$FAKE:$PATH"
    c="$(novo_caso)"
    REVIEW=0 "$CLI" run "$c" --harness pi --painel design,brand --rounds 2 > "$WORK/x" 2>&1
    grep -q '^painel: debate-arch debate-ux debate-pm debate-design debate-brand$' "$c/meta.txt"
    grep -q 'assento base somado: debate-arch debate-ux debate-pm' "$c/raw/summary.log"
    grep -q '^## Revisao debate-design' "$c/critiques/debate-ux.md"
    grep -q 'gate marca ok' "$c/raw/summary.log"
    [ -s "$c/BRANDBOOK.md" ]
    "$CLI" status "$c" | grep -q '^marca *ok'
    "$CLI" validate "$c"
    # Com brandbook, a tag marca passa a ser cobrada no backlog.
    sed 's/ #marca//' "$FX/BACKLOG.md" > "$c/BACKLOG.md"
    reprova 'marca' "$c" backlog
  )
}
tp "protocolo completo ate o backlog" e2e
tp "replica so para quem levou veto" replica_so_de_vetado
tp "auditoria com defeito corrige 1 vez" auditoria_corrige
tp "auditoria aprovada nao reemite o SDD" auditoria_aprova_sem_reemitir
tp "caso antigo com propostas segue sem agenda" agenda_pulada_em_caso_antigo
tp "status mostra a proxima fase" retoma_status
tp "toda tarefa pede o conteudo como resposta" tarefa_pede_texto
tp "[assumido] entre crases nao e premissa" assumido_citado
tp "entrada editada gera aviso" defasagem
tp "--from arquiva e refaz so dali em diante" from_arquiva
tp "--from invalido falha cedo" from_invalido
tp "painel com persona inexistente falha cedo" painel_invalido
tp "teto de chamadas interrompe" teto_chamadas
tp "segundo run recusa, lock de run morto nao trava" lock_recusa
tp "rodar de novo reaproveita saidas" retoma
tp "gate reprovado ganha 1 reparo" reparo
tp "run sem instalar orienta init" sem_instalar

# --- harnesses: cada CLI falso devolve a resposta no formato real dele

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
    grep -q 'rotas=debate-arch=codex debate-ux=gemini debate-pm=codex debate-design=gemini' "$c/raw/summary.log"
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
for h in claude codex cursor gemini agy omp pi dsh droid copilot qwen cline; do tp "protocolo completo via $h" protocolo_em "$h"; done
tp "painel com debate-sec" painel_com_sec
tp "painel com designer e diretor de arte" painel_de_marca
tp "agents rodam em sala sem saida de rival" sala_cega
tp "limite 429 espera e tenta de novo" limite_espera
tp "auth falha nao repete" auth_nao_repete
tp "PARALELO limita chamadas simultaneas" paralelo_limita
tp "interrupcao mata as chamadas em andamento" interrompe_mata_filhos
tp "mesa distribui o painel entre harnesses" mesa
tp "harness custom via HARNESS_CMD" custom
tp "timeout diz que foi timeout" tempo_esgotado
tp "binario ausente falha cedo" binario_ausente
tp "rerun nao sobrescreve spec editada" retoma_specs
tp "spec reprovada ganha reparo" spec_reparo
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
tp "probe faz chamada pelo adapter" probe
tp "adapter grava em arquivo e calcula timeout sob dash" em_dash

# --- instalador de uma linha, sem rede
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
tp "install.sh instala e reinstala" bootstrap
upgrade_sem_ref() { nao "$CLI" upgrade --check 2>/dev/null; }
tp "upgrade recusa instalacao sem install.sh" upgrade_sem_ref

# --- execucao. Os testes `t` mexem na instalacao: rodam em ordem, num job so do pool, com HOME proprio.
# Os `tp` dividem o HOME principal, onde o opencode e instalado 1 vez antes, e so o leem.
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
  # Vaga: tira do pool quem ja terminou; cheio, espera o mais antigo.
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

printf '\n%s ok, %s falha(s)\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
