# install.sh - init, update, uninstall, doctor e models (source de bin/open-debate).
# Requer ROOT, TEMPLATE, SKILL e, de quem chama, PROJECT e FORCE.
# Manifesto: 1 linha "<hash>  <caminho>" por arquivo instalado, relativo a TARGET. O hash ignora a linha
# de modelo, porque `models apply` e a troca manual de modelo nao contam como edicao do usuario.

resolve_target() {
  h_load "$1" || { echo "erro: harness desconhecido: $1 (veja: open-debate harnesses)" >&2; exit 2; }
  if [ "$PROJECT" = "1" ]; then
    if [ "$H_PROJ" = "." ]; then TARGET="$PWD"; base=""; else TARGET="$PWD/$H_PROJ"; base="$H_PROJ/"; fi
    SKILL_DIR="$base$H_SKILLS/$SKILL"
    SCRIPTS="$SKILL_DIR/scripts"
    SCRIPTS_ABS="./$SCRIPTS"
  else
    TARGET="$H_USER"
    abs="$TARGET/$H_SKILLS/$SKILL"
    SCRIPTS_ABS="$abs/scripts"
    case "$abs" in
      "$HOME"/*) SKILL_DIR="~/${abs#"$HOME"/}" ;;
      *) SKILL_DIR="$abs" ;;
    esac
    SCRIPTS="$SKILL_DIR/scripts"
  fi
  MANIFEST="$TARGET/$H_SKILLS/$SKILL/.open-debate-manifest"
  VERSAO="$TARGET/$H_SKILLS/$SKILL/.open-debate-version"
}

# hashes <base>: le caminhos relativos no stdin e imprime "<hash>  <caminho>" ("-" se nao existe), num processo so.
# O hash e o sha256 do arquivo sem a linha de modelo, como `grep -Ev` a imprimia (sempre com \n final): manifestos antigos seguem validos.
# Um perl para a lista inteira: por arquivo, grep | sha256 custava 3 processos e dominava o tempo do init.
hashes() {
  perl -MDigest::SHA -e 1 2>/dev/null || { hashes_lento "$1"; return; }
  perl -MDigest::SHA -e '
    my $b = shift;
    while (my $f = <STDIN>) {
      chomp $f; next if $f eq "";
      if ($f =~ m{(^|/)modelos\.conf$}) { print "config  $f\n"; next }
      my $d = Digest::SHA->new(256);
      if (open(my $h, "<", "$b/$f")) {
        binmode $h;
        while (my $l = <$h>) { next if $l =~ /^(# )?model( =|:) /; $l .= "\n" unless $l =~ /\n$/; $d->add($l) }
        close $h; print $d->hexdigest, "  $f\n";
      } else { print "-  $f\n" }
    }' "$1"
}

# Sem Digest::SHA (perl-base minimo): o mesmo hash, 1 arquivo por vez.
hashes_lento() {
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    case "$f" in */modelos.conf|modelos.conf) printf 'config  %s\n' "$f"; continue ;; esac
    if [ ! -f "$1/$f" ]; then printf -- '-  %s\n' "$f"; continue; fi
    if command -v sha256sum >/dev/null 2>&1; then h="$(grep -Ev '^(# )?model( =|:) ' "$1/$f" | sha256sum | cut -d' ' -f1)"
    elif [ -x /sbin/sha256 ]; then h="$(grep -Ev '^(# )?model( =|:) ' "$1/$f" | /sbin/sha256 -q)"
    else h="$(grep -Ev '^(# )?model( =|:) ' "$1/$f" | shasum -a 256 | cut -d' ' -f1)"; fi
    printf '%s  %s\n' "$h" "$f"
  done
}

sed_esc() { printf '%s' "$1" | sed 's/[\\&#]/\\&/g'; }

# prepara_render <dir>: 1 script de sed por harness, em vez de escapar os caminhos a cada arquivo.
# Patterns iguais viram 1 so: chave repetida no frontmatter quebra o YAML do agent.
prepara_render() {
  RENDER_SED="$1.sed"
  {
    if [ "$SCRIPTS" = "$SCRIPTS_ABS" ]; then printf '/{{SCRIPTS_ABS}}/d\n'
    else printf 's#{{SCRIPTS_ABS}}#%s#g\n' "$(sed_esc "$SCRIPTS_ABS")"; fi
    printf 's#{{SCRIPTS}}#%s#g\n' "$(sed_esc "$SCRIPTS")"
    printf 's#{{SKILL_DIR}}#%s#g\n' "$(sed_esc "$SKILL_DIR")"
    printf 's#{{HARNESS}}#%s#g\n' "$H_ID"
    printf 's#{{HARNESS_NAME}}#%s#g\n' "$(sed_esc "$H_NAME")"
    printf 's#{{DELEGATE}}#%s#g\n' "$(sed_esc "$H_DELEGATE")"
  } > "$RENDER_SED"
}

# render <origem>: troca os placeholders pelos caminhos da instalacao.
render() {
  case "$1" in
    */debate.md|*/subagents.md) incluir_delegacao "$1" | sed -f "$RENDER_SED" ;;
    *) sed -f "$RENDER_SED" "$1" ;;
  esac
}

entrada() {
  mkdir -p "$1/$H_SKILLS/debate"
  e="$TEMPLATE/entry/cli.md"; [ "$H_MODE" = "subagents" ] && e="$TEMPLATE/entry/subagents.md"
  args="o texto que o usuario escreveu depois do comando"; extra=""
  if [ "$H_FMT" = "claude" ]; then
    args='$ARGUMENTS'
    extra="
allowed-tools: Bash($SCRIPTS/*), Bash($SCRIPTS_ABS/*)"
  fi
  render "$e" | EXTRA="$extra" ARGS="$args" awk '
    { i = index($0, "{{FRONTMATTER}}"); if (i) $0 = substr($0, 1, i - 1) ENVIRON["EXTRA"] substr($0, i + 15)
      i = index($0, "{{ARGS}}"); if (i) $0 = substr($0, 1, i - 1) ENVIRON["ARGS"] substr($0, i + 8)
      print }' > "$1/$H_SKILLS/debate/SKILL.md"
  case "$H_FMT" in
    gemini|qwen)
      mkdir -p "$1/$H_CMDS"
      cat > "$1/$H_CMDS/debate.toml" <<EOF
description = "Debate de arquitetura e design: da ideia a SDD, ADRs, specs e backlog"
prompt = """Read $SKILL_DIR/../debate/SKILL.md and follow it. Idea to debate: {{args}}"""
EOF
      ;;
  esac
}

# stage <dir>: monta em <dir> tudo que vai para TARGET.
stage() {
  prepara_render "$1"
  # Quase nada tem placeholder: copia a arvore de uma vez e renderiza so o que precisa.
  mkdir -p "$1/$H_SKILLS"
  cp -Rp "$TEMPLATE/skills/$SKILL" "$1/$H_SKILLS/"
  find "$1/$H_SKILLS/$SKILL" -name .DS_Store -exec rm -f {} +
  (cd "$TEMPLATE/skills/$SKILL" && grep -rl '{{' .) | sed 's#^\./##' | while IFS= read -r f; do
    render "$TEMPLATE/skills/$SKILL/$f" > "$1/$H_SKILLS/$SKILL/$f"
  done
  p="$TEMPLATE/skills/$SKILL/personas"
  case "$H_MODE" in
    native)
      mkdir -p "$1/$H_AGENTS" "$1/$H_CMDS"
      for f in "$p"/debate*.md; do render "$f" > "$1/$H_AGENTS/$(basename "$f")"; done
      render "$TEMPLATE/commands/debate.md" > "$1/$H_CMDS/debate.md" ;;
    *)
      entrada "$1"
      if [ -n "$H_AGENTS" ]; then
        mkdir -p "$1/$H_AGENTS"
        for f in "$p"/debate-*.md; do render_agent "$f" "$1/$H_AGENTS/$(agent_file "$(basename "$f" .md)")"; done
      fi ;;
  esac
}

manifest_hash() {
  [ -f "$MANIFEST" ] || return 0
  awk -v f="$1" '$2 == f { print $1; exit }' "$MANIFEST"
}

# Modelo escolhido pelo usuario sobrevive ao update, inclusive sobre uma linha `# model` comentada.
preserva_modelo() {
  linha="$(grep -E '^model( =|:) ' "$1" 2>/dev/null | head -1 || true)"
  [ -n "$linha" ] || return 0
  LINHA="$linha" awk '!f && /^(# )?model( =|:) / { print ENVIRON["LINHA"]; f = 1; next } { print }' "$2" > "$2.new"
  cat "$2.new" > "$2"; rm -f "$2.new"
}

do_install() {
  modo="$1"
  if [ "$modo" = "update" ] && [ ! -f "$MANIFEST" ]; then
    echo "erro: nada instalado em $TARGET, rode: open-debate init" >&2; return 2
  fi
  [ -f "$MANIFEST" ] && novo=0 || novo=1
  tmp="$(mktemp -d)"; lista="$tmp/.lista"
  stage "$tmp/t"
  (cd "$tmp/t" && find . -type f | sed 's#^\./##' | LC_ALL=C sort) > "$lista"

  hashes "$tmp/t" < "$lista" > "$tmp/.novo"
  hashes "$TARGET" < "$lista" > "$tmp/.atual"
  [ -f "$MANIFEST" ] && cp "$MANIFEST" "$tmp/.antigo" || : > "$tmp/.antigo"
  # Por arquivo: ausente no destino = novo; igual ao template = nada; igual ao manifesto = atualizado; senao, editado pelo usuario.
  awk -v ant="$tmp/.antigo" -v atu="$tmp/.atual" '
    BEGIN { while ((getline l < ant) > 0) { split(l, x, "  "); o[x[2]] = x[1] }
            while ((getline l < atu) > 0) { split(l, x, "  "); c[x[2]] = x[1] } }
    { f = $2; n = $1
      if (c[f] == "-") { print "add", f; next }
      if (c[f] == n) next
      if (c[f] == o[f]) print "upd", f; else print "conf", f }' "$tmp/.novo" > "$tmp/.plano"
  n_add="$(grep -c '^add ' "$tmp/.plano" || true)"; n_upd="$(grep -c '^upd ' "$tmp/.plano" || true)"
  conflitos="$(sed -n 's/^conf //p' "$tmp/.plano" | tr '\n' ' ')"; conflitos="${conflitos% }"

  if [ -n "$conflitos" ] && [ "$FORCE" != "1" ]; then
    echo "erro: arquivos com conteudo proprio em $TARGET, nada foi alterado:" >&2
    for f in $conflitos; do echo "  $f" >&2; done
    echo "--force faz backup deles em $TARGET/.open-debate-backup-*.tgz e sobrescreve" >&2
    rm -rf "$tmp"; return 1
  fi
  if [ -n "$conflitos" ]; then
    bk="$TARGET/.open-debate-backup-$(date +%Y%m%d-%H%M%S).tgz"
    # shellcheck disable=SC2086
    tar -czf "$bk" -C "$TARGET" $conflitos
    echo "backup: $bk"
  fi

  # arquivos que sairam do template: remove so os nao editados
  if [ -f "$MANIFEST" ]; then
    awk '{ print $2 }' "$MANIFEST" | hashes "$TARGET" > "$tmp/.instalado"
    awk -v nov="$tmp/.novo" 'BEGIN { while ((getline l < nov) > 0) { split(l, x, "  "); t[x[2]] = 1 } }
      FNR == NR { h[$2] = $1; next } ($2 in t) || $1 == "-" { next } { print ($1 == h[$2] ? "limpo" : "editado"), $2 }' \
      "$MANIFEST" "$tmp/.instalado" | while read -r st f; do
        if [ "$st" = "limpo" ] || [ "$FORCE" = "1" ]; then rm -f "$TARGET/$f"
        else echo "aviso: $f saiu do template mas foi editado, mantido"; fi
      done
  fi

  # Modelo escolhido pelo usuario sobrevive: so os arquivos com linha model no destino. O hash ignora essa linha,
  # entao o manifesto e o .novo. modelos.conf existente nunca e sobrescrito.
  man="$tmp/.manifest"; cp "$tmp/.novo" "$man"
  while IFS= read -r f; do
    case "$f" in */modelos.conf) [ ! -e "$TARGET/$f" ] || rm -f "$tmp/t/$f"; continue ;; esac
  done < "$lista"
  (cd "$TARGET" 2>/dev/null && xargs grep -lE '^model( =|:) ' < "$lista" 2>/dev/null) > "$tmp/.modelos" || true
  while IFS= read -r f; do [ -f "$tmp/t/$f" ] && preserva_modelo "$TARGET/$f" "$tmp/t/$f"; done < "$tmp/.modelos"
  mkdir -p "$TARGET"
  cp -Rp "$tmp/t/." "$TARGET/"
  cp "$man" "$MANIFEST"
  printf '%s\n' "$(version)" > "$VERSAO"
  rm -rf "$tmp"

  echo "open-debate $(version) em $TARGET: $n_add novo(s), $n_upd atualizado(s), $(printf '%s' "$conflitos" | wc -w | tr -d ' ') sobrescrito(s)"
  # Instalacao nova grava o perfil; update so troca o modelo que saiu do catalogo (rotacao dos gratuitos).
  if [ "$H_ID" = "opencode" ] && command -v opencode >/dev/null 2>&1 && [ -z "$conflitos" ]; then
    acao=reparar; [ "$novo" = "1" ] && acao=aplicar
    "$TARGET/$H_SKILLS/$SKILL/scripts/modelos.sh" "$acao" > /dev/null || echo "aviso: modelos nao aplicados, rode: open-debate models apply"
  fi
  [ "$modo" = "init" ] && printf 'pronto em %s: %s\n' "$H_NAME" "$H_INVOKE"
  return 0
}

do_uninstall() {
  [ -f "$MANIFEST" ] || { echo "erro: nada instalado em $TARGET" >&2; return 2; }
  mantidos=0; dirs=""
  tmpu="$(mktemp)"
  awk '{ print $2 }' "$MANIFEST" | hashes "$TARGET" | awk 'FNR == NR { h[$2] = $1; next } { print $1, $2, h[$2] }' "$MANIFEST" - > "$tmpu"
  while read -r a f h; do
    [ "$a" != "-" ] || continue
    if [ "$a" = "$h" ] || [ "$FORCE" = "1" ]; then rm -f "$TARGET/$f"; case "$f" in */*) dirs="$dirs ${f%/*}" ;; *) dirs="$dirs ." ;; esac
    else echo "mantido, editado: $f"; mantidos=$((mantidos + 1)); fi
  done < "$tmpu"
  rm -f "$tmpu"
  if [ "$mantidos" -eq 0 ]; then
    rm -f "$MANIFEST" "$VERSAO"
    find "$TARGET/$H_SKILLS/$SKILL" -depth -type d -empty -exec rmdir {} \; 2>/dev/null || true
    for d in $dirs; do
      while [ "$d" != "." ] && rmdir "$TARGET/$d" 2>/dev/null; do d="$(dirname "$d")"; done
    done
    if [ "$PROJECT" = "1" ] && [ "$TARGET" != "$PWD" ]; then rmdir "$TARGET" 2>/dev/null || true; fi
    echo "removido de $TARGET"
  else
    echo "$mantidos arquivo(s) editado(s) mantidos; --force remove tudo" >&2; return 1
  fi
}

dica_dep() {
  if command -v brew >/dev/null 2>&1; then printf 'brew install %s' "$1"
  elif command -v apt-get >/dev/null 2>&1; then printf 'sudo apt-get install %s' "$1"
  elif command -v dnf >/dev/null 2>&1; then printf 'sudo dnf install %s' "$1"
  else printf 'instale %s' "$1"; fi
}

doctor_harness() {
  edit=0; falta=0
  r="$(awk '{ print $2 }' "$MANIFEST" | hashes "$TARGET" | awk 'FNR == NR { h[$2] = $1; next }
    $1 == "-" { print "FALTA " $2; next } $1 != h[$2] { e++ } END { print "EDIT " e + 0 }' "$MANIFEST" -)"
  printf '%s\n' "$r" | grep '^FALTA ' && falta=1
  edit="$(printf '%s\n' "$r" | sed -n 's/^EDIT //p')"
  printf 'ok    %-9s instalado em %s (versao %s, chame com %s)\n' "$H_ID" "$TARGET" "$(cat "$VERSAO" 2>/dev/null || echo '?')" "$H_INVOKE"
  [ "$edit" -eq 0 ] || printf 'aviso %-9s %s arquivo(s) editado(s), update nao os sobrescreve\n' "$H_ID" "$edit"
  [ "$(cat "$VERSAO" 2>/dev/null)" = "$(version)" ] || printf 'aviso %-9s versao instalada difere do pacote %s, rode: open-debate update\n' "$H_ID" "$(version)"
  rc2="$falta"
  if [ "$H_ID" = "opencode" ] && command -v opencode >/dev/null 2>&1; then "$TARGET/$H_SKILLS/$SKILL/scripts/modelos.sh" check || rc2=1; fi
  return "$rc2"
}

do_doctor() {
  rc=0; inst=0
  for c in jq awk perl; do
    if command -v "$c" >/dev/null 2>&1; then printf 'ok    %s\n' "$c"
    else printf 'FALTA %s: %s\n' "$c" "$(dica_dep "$c")"; rc=1; fi
  done
  for h in $1; do
    resolve_target "$h"
    if [ -f "$MANIFEST" ]; then
      inst=$((inst + 1)); doctor_harness || rc=1
      h_bin >/dev/null || printf 'aviso %-9s instalado, mas o binario nao esta no PATH\n' "$h"
    elif h_bin >/dev/null; then printf 'livre %-9s detectado, sem instalar: open-debate init --harness %s\n' "$h" "$h"
    fi
  done
  if [ "$inst" -eq 0 ]; then echo 'FALTA nenhuma instalacao, rode: open-debate init'; rc=1; fi
  return "$rc"
}

do_models() {
  resolve_target opencode
  [ -f "$MANIFEST" ] || { echo "erro: models so se aplica ao opencode, e nada esta instalado em $TARGET" >&2; exit 2; }
  m="$TARGET/$H_SKILLS/$SKILL/scripts/modelos.sh"
  case "${1:-check}" in
    check|livres) exec "$m" "$1" ;;
    free) exec "$m" livres ;;
    apply) exec "$m" aplicar ;;
    profile) shift; exec "$m" perfil "$@" ;;
    *) echo "uso: open-debate models check|apply|free|profile <gratis|misto|forte> [provider/modelo]" >&2; exit 2 ;;
  esac
}

do_harnesses() {
  printf '%-9s %-20s %-9s %-10s %-10s %s\n' ID HARNESS DETECTADO INSTALADO MODO CHAMADA
  for h in $HARNESSES; do
    resolve_target "$h"
    d=nao; if h_detected; then d=sim; fi
    i=nao; if [ -f "$MANIFEST" ]; then i=sim; fi
    printf '%-9s %-20s %-9s %-10s %-10s %s\n' "$h" "$H_NAME" "$d" "$i" "$H_MODE" "$H_INVOKE"
  done
  echo
  echo 'Modos: native e subagents rodam o painel como subagents na sessao; cli roda cada especialista como processo headless.'
  echo 'Qualquer CLI com modo headless tambem serve: HARNESS=custom HARNESS_CMD="meu-cli --print \"\$PROMPT\"" open-debate run <caso>'
}
