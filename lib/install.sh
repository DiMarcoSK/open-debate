# install.sh - init, update, uninstall, doctor e models (source de bin/open-debate).
# Requer ROOT, TEMPLATE, SKILL e, de quem chama, PROJECT e FORCE.
# Manifesto: 1 linha "<hash>  <caminho>" por arquivo instalado. O hash ignora a linha `model:`,
# porque `models apply` e a troca manual de modelo nao contam como edicao do usuario.

resolve_target() {
  if [ "$PROJECT" = "1" ]; then
    TARGET="$PWD/.opencode"
    SCRIPTS=".opencode/$SKILL/scripts"
    SCRIPTS_ABS="./$SCRIPTS"
  else
    TARGET="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
    SCRIPTS_ABS="$TARGET/$SKILL/scripts"
    case "$SCRIPTS_ABS" in
      "$HOME"/*) SCRIPTS="~/${SCRIPTS_ABS#"$HOME"/}" ;;
      *) SCRIPTS="$SCRIPTS_ABS" ;;
    esac
  fi
  MANIFEST="$TARGET/$SKILL/.open-debate-manifest"
}

sha() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum | cut -d' ' -f1
  else shasum -a 256 | cut -d' ' -f1; fi
}

# modelos.conf e configuracao do usuario: instalado 1 vez, nunca conta como edicao nem e sobrescrito.
hash_file() {
  case "$1" in
    */modelos.conf) echo config ;;
    *) grep -v '^model: ' "$1" | sha ;;
  esac
}

sed_esc() { printf '%s' "$1" | sed 's/[\\&#]/\\&/g'; }

# render <origem>: troca os placeholders pelos caminhos da instalacao. Patterns iguais viram 1 so,
# chave repetida no frontmatter quebra o YAML do agent.
render() {
  if [ "$SCRIPTS" = "$SCRIPTS_ABS" ]; then
    sed -e '/{{SCRIPTS_ABS}}/d' -e "s#{{SCRIPTS}}#$(sed_esc "$SCRIPTS")#g" "$1"
  else
    sed -e "s#{{SCRIPTS}}#$(sed_esc "$SCRIPTS")#g" -e "s#{{SCRIPTS_ABS}}#$(sed_esc "$SCRIPTS_ABS")#g" "$1"
  fi
}

template_files() { (cd "$TEMPLATE" && find . -type f ! -name .DS_Store | sed 's#^\./##' | LC_ALL=C sort); }

manifest_hash() {
  [ -f "$MANIFEST" ] || return 0
  awk -v f="$1" '$2 == f { print $1; exit }' "$MANIFEST"
}

do_install() {
  modo="$1"
  if [ "$modo" = "update" ] && [ ! -f "$MANIFEST" ]; then
    echo "erro: nada instalado em $TARGET, rode: open-debate init" >&2; exit 2
  fi
  [ -f "$MANIFEST" ] && novo=0 || novo=1
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT

  conflitos=""; n_add=0; n_upd=0
  for f in $(template_files); do
    mkdir -p "$tmp/$(dirname "$f")"
    render "$TEMPLATE/$f" > "$tmp/$f"
    [ -x "$TEMPLATE/$f" ] && chmod +x "$tmp/$f"
    d="$TARGET/$f"
    if [ ! -e "$d" ]; then n_add=$((n_add + 1)); continue; fi
    cur="$(hash_file "$d")"; new="$(hash_file "$tmp/$f")"
    [ "$cur" = "$new" ] && continue
    old="$(manifest_hash "$f")"
    if [ "$cur" = "$old" ]; then n_upd=$((n_upd + 1)); else conflitos="$conflitos $f"; fi
  done

  if [ -n "$conflitos" ] && [ "$FORCE" != "1" ]; then
    echo "erro: arquivos com conteudo proprio em $TARGET, nada foi alterado:" >&2
    for f in $conflitos; do echo "  $f" >&2; done
    echo "--force faz backup deles em $TARGET/.open-debate-backup-*.tgz e sobrescreve" >&2
    exit 1
  fi
  if [ -n "$conflitos" ]; then
    bk="$TARGET/.open-debate-backup-$(date +%Y%m%d-%H%M%S).tgz"
    # shellcheck disable=SC2086
    tar -czf "$bk" -C "$TARGET" $conflitos
    echo "backup: $bk"
  fi

  # arquivos que sairam do template: remove so os nao editados
  if [ -f "$MANIFEST" ]; then
    while read -r h f; do
      [ -e "$TARGET/$f" ] && [ ! -e "$tmp/$f" ] || continue
      if [ "$(hash_file "$TARGET/$f")" = "$h" ] || [ "$FORCE" = "1" ]; then rm -f "$TARGET/$f"
      else echo "aviso: $f saiu do template mas foi editado, mantido"; fi
    done < "$MANIFEST"
  fi

  man="$tmp/.manifest"; : > "$man"
  for f in $(template_files); do
    d="$TARGET/$f"; mkdir -p "$(dirname "$d")"
    case "$f" in */modelos.conf) if [ -e "$d" ]; then printf 'config  %s\n' "$f" >> "$man"; continue; fi ;; esac
    # modelo escolhido pelo usuario sobrevive ao update
    m=""; [ -f "$d" ] && m="$(sed -n 's/^model: //p' "$d" | head -1)"
    if [ -n "$m" ]; then sed "s#^model: .*#model: $(sed_esc "$m")#" "$tmp/$f" > "$tmp/$f.new"; cat "$tmp/$f.new" > "$tmp/$f"; rm -f "$tmp/$f.new"; fi
    printf '%s  %s\n' "$(hash_file "$tmp/$f")" "$f" >> "$man"
    cp -p "$tmp/$f" "$d"
  done
  cp "$man" "$MANIFEST"
  printf '%s\n' "$(version)" > "$TARGET/$SKILL/.open-debate-version"

  echo "open-debate $(version) em $TARGET: $n_add novo(s), $n_upd atualizado(s), $(printf '%s' "$conflitos" | wc -w | tr -d ' ') sobrescrito(s)"
  if command -v opencode >/dev/null 2>&1 && [ "$novo" = "1" ] && [ -z "$conflitos" ]; then
    "$TARGET/$SKILL/scripts/modelos.sh" aplicar || echo "aviso: modelos nao aplicados, rode: open-debate models apply"
  fi
  [ "$modo" = "init" ] && echo 'pronto: abra o opencode e rode /debate <sua ideia>'
  return 0
}

do_uninstall() {
  [ -f "$MANIFEST" ] || { echo "erro: nada instalado em $TARGET" >&2; exit 2; }
  mantidos=0
  while read -r h f; do
    [ -e "$TARGET/$f" ] || continue
    if [ "$(hash_file "$TARGET/$f")" = "$h" ] || [ "$FORCE" = "1" ]; then rm -f "$TARGET/$f"
    else echo "mantido, editado: $f"; mantidos=$((mantidos + 1)); fi
  done < "$MANIFEST"
  if [ "$mantidos" -eq 0 ]; then
    rm -f "$MANIFEST" "$TARGET/$SKILL/.open-debate-version"
    find "$TARGET/$SKILL" -depth -type d -empty -exec rmdir {} \; 2>/dev/null || true
    rmdir "$TARGET/skills" "$TARGET/agents" "$TARGET/commands" 2>/dev/null || true
    echo "removido de $TARGET"
  else
    echo "$mantidos arquivo(s) editado(s) mantidos; --force remove tudo" >&2; exit 1
  fi
}

do_doctor() {
  rc=0
  for c in opencode jq awk perl; do
    if command -v "$c" >/dev/null 2>&1; then printf 'ok    %s\n' "$c"
    else printf 'FALTA %s\n' "$c"; rc=1; fi
  done
  if [ -f "$MANIFEST" ]; then
    printf 'ok    instalado em %s (versao %s, pacote %s)\n' "$TARGET" "$(cat "$TARGET/$SKILL/.open-debate-version" 2>/dev/null || echo '?')" "$(version)"
    edit=0
    while read -r h f; do
      if [ ! -e "$TARGET/$f" ]; then printf 'FALTA %s\n' "$f"; rc=1
      elif [ "$(hash_file "$TARGET/$f")" != "$h" ]; then edit=$((edit + 1)); fi
    done < "$MANIFEST"
    [ "$edit" -eq 0 ] || printf 'aviso %s arquivo(s) editado(s), update nao os sobrescreve\n' "$edit"
    if command -v opencode >/dev/null 2>&1; then "$TARGET/$SKILL/scripts/modelos.sh" check || rc=1; fi
  else
    printf 'FALTA instalacao em %s, rode: open-debate init\n' "$TARGET"; rc=1
  fi
  return "$rc"
}

do_models() {
  [ -f "$MANIFEST" ] || { echo "erro: nada instalado em $TARGET, rode: open-debate init" >&2; exit 2; }
  case "$1" in
    check|livres) exec "$TARGET/$SKILL/scripts/modelos.sh" "$1" ;;
    free) exec "$TARGET/$SKILL/scripts/modelos.sh" livres ;;
    apply) exec "$TARGET/$SKILL/scripts/modelos.sh" aplicar ;;
    *) echo "uso: open-debate models check|apply|free" >&2; exit 2 ;;
  esac
}
