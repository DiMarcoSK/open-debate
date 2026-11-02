# install.sh - init, update, uninstall, doctor and models (sourced by bin/open-debate).
# Needs ROOT, TEMPLATE, SKILL and, from the caller, PROJECT and FORCE.
# Manifest: 1 line "<hash>  <path>" per installed file, relative to TARGET. The hash ignores the model line,
# because `models apply` and a manual model swap do not count as user edits.

resolve_target() {
  h_load "$1" || { echo "error: unknown harness: $1 (see: open-debate harnesses)" >&2; exit 2; }
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

# hashes <base>: reads relative paths on stdin and prints "<hash>  <path>" ("-" if missing), in a single process.
# The hash is the sha256 of the file without the model line, as `grep -Ev` printed it (always with a final \n): old manifests stay valid.
# models.conf (and modelos.conf, its pre-0.5 name) is config: always "config", never an edit.
# One perl for the whole list: per file, grep | sha256 cost 3 processes and dominated the init time.
hashes() {
  perl -MDigest::SHA -e 1 2>/dev/null || { hashes_lento "$1"; return; }
  perl -MDigest::SHA -e '
    my $b = shift;
    while (my $f = <STDIN>) {
      chomp $f; next if $f eq "";
      if ($f =~ m{(^|/)(models|modelos)\.conf$}) { print "config  $f\n"; next }
      my $d = Digest::SHA->new(256);
      if (open(my $h, "<", "$b/$f")) {
        binmode $h;
        while (my $l = <$h>) { next if $l =~ /^(# )?model( =|:) /; $l .= "\n" unless $l =~ /\n$/; $d->add($l) }
        close $h; print $d->hexdigest, "  $f\n";
      } else { print "-  $f\n" }
    }' "$1"
}

# Without Digest::SHA (minimal perl-base): the same hash, 1 file at a time.
hashes_lento() {
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    case "$f" in */models.conf|models.conf|*/modelos.conf|modelos.conf) printf 'config  %s\n' "$f"; continue ;; esac
    if [ ! -f "$1/$f" ]; then printf -- '-  %s\n' "$f"; continue; fi
    if command -v sha256sum >/dev/null 2>&1; then h="$(grep -Ev '^(# )?model( =|:) ' "$1/$f" | sha256sum | cut -d' ' -f1)"
    elif [ -x /sbin/sha256 ]; then h="$(grep -Ev '^(# )?model( =|:) ' "$1/$f" | /sbin/sha256 -q)"
    else h="$(grep -Ev '^(# )?model( =|:) ' "$1/$f" | shasum -a 256 | cut -d' ' -f1)"; fi
    printf '%s  %s\n' "$h" "$f"
  done
}

sed_esc() { printf '%s' "$1" | sed 's/[\\&#]/\\&/g'; }

# prepara_render <dir>: 1 sed script per harness, instead of escaping the paths for every file.
# Equal patterns become one: a repeated frontmatter key breaks the agent YAML.
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

# render <source>: swaps the placeholders for the install paths.
render() {
  case "$1" in
    */debate.md|*/subagents.md) incluir_delegacao "$1" | sed -f "$RENDER_SED" ;;
    *) sed -f "$RENDER_SED" "$1" ;;
  esac
}

entrada() {
  mkdir -p "$1/$H_SKILLS/debate"
  e="$TEMPLATE/entry/cli.md"; [ "$H_MODE" = "subagents" ] && e="$TEMPLATE/entry/subagents.md"
  args="the text the user wrote after the command"; extra=""
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
description = "Architecture and design debate: from an idea to SDD, ADRs, specs and backlog"
prompt = """Read $SKILL_DIR/../debate/SKILL.md and follow it. Idea to debate: {{args}}"""
EOF
      ;;
  esac
}

# stage <dir>: assembles in <dir> everything that goes to TARGET.
stage() {
  prepara_render "$1"
  # Almost nothing has a placeholder: copy the tree at once and render only what needs it.
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

# The model the user chose survives an update, even over a commented `# model` line.
preserva_modelo() {
  linha="$(grep -E '^model( =|:) ' "$1" 2>/dev/null | head -1 || true)"
  [ -n "$linha" ] || return 0
  LINHA="$linha" awk '!f && /^(# )?model( =|:) / { print ENVIRON["LINHA"]; f = 1; next } { print }' "$2" > "$2.new"
  cat "$2.new" > "$2"; rm -f "$2.new"
}

do_install() {
  modo="$1"
  if [ "$modo" = "update" ] && [ ! -f "$MANIFEST" ]; then
    echo "error: nothing installed in $TARGET, run: open-debate init" >&2; return 2
  fi
  [ -f "$MANIFEST" ] && novo=0 || novo=1
  tmp="$(mktemp -d)"; lista="$tmp/.lista"
  stage "$tmp/t"
  # Pre-0.5 installs kept the model profile in modelos.conf: carry it into models.conf before the old file is cleaned up.
  mc="$H_SKILLS/$SKILL/models.conf"
  if [ ! -e "$TARGET/$mc" ] && [ -f "$TARGET/$H_SKILLS/$SKILL/modelos.conf" ]; then
    { sed -n '/^#/p' "$tmp/t/$mc"
      sed -e '/^#/d; s/^perfil=gratis/profile=free/; s/^perfil=misto/profile=mixed/; s/^perfil=forte/profile=strong/' \
          -e 's/^perfil=/profile=/; s/^forte=/strong=/; s/^reserva=/spare=/' "$TARGET/$H_SKILLS/$SKILL/modelos.conf"; } > "$tmp/models.conf"
    mv "$tmp/models.conf" "$tmp/t/$mc"; migrated=1
  else migrated=0; fi
  (cd "$tmp/t" && find . -type f | sed 's#^\./##' | LC_ALL=C sort) > "$lista"

  hashes "$tmp/t" < "$lista" > "$tmp/.novo"
  hashes "$TARGET" < "$lista" > "$tmp/.atual"
  [ -f "$MANIFEST" ] && cp "$MANIFEST" "$tmp/.antigo" || : > "$tmp/.antigo"
  # Per file: missing at the target = new; equal to the template = nothing; equal to the manifest = updated; else, edited by the user.
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
    echo "error: files with their own content in $TARGET, nothing was changed:" >&2
    for f in $conflitos; do echo "  $f" >&2; done
    echo "--force backs them up to $TARGET/.open-debate-backup-*.tgz and overwrites" >&2
    rm -rf "$tmp"; return 1
  fi
  if [ -n "$conflitos" ]; then
    bk="$TARGET/.open-debate-backup-$(date +%Y%m%d-%H%M%S).tgz"
    # shellcheck disable=SC2086
    tar -czf "$bk" -C "$TARGET" $conflitos
    echo "backup: $bk"
  fi

  # files that left the template: remove only the unedited ones
  if [ -f "$MANIFEST" ]; then
    awk '{ print $2 }' "$MANIFEST" | hashes "$TARGET" > "$tmp/.instalado"
    awk -v nov="$tmp/.novo" 'BEGIN { while ((getline l < nov) > 0) { split(l, x, "  "); t[x[2]] = 1 } }
      FNR == NR { h[$2] = $1; next } ($2 in t) || $1 == "-" { next } { print ($1 == h[$2] ? "limpo" : "editado"), $2 }' \
      "$MANIFEST" "$tmp/.instalado" | while read -r st f; do
        if [ "$st" = "limpo" ] || [ "$FORCE" = "1" ]; then rm -f "$TARGET/$f"
        else echo "warning: $f left the template but was edited, kept"; fi
      done
  fi

  # The model the user chose survives: only the files with a model line at the target. The hash ignores that line,
  # so the manifest is the .novo. An existing models.conf is never overwritten; a pre-0.5 modelos.conf is migrated into it.
  man="$tmp/.manifest"; cp "$tmp/.novo" "$man"
  while IFS= read -r f; do
    case "$f" in */models.conf) [ ! -e "$TARGET/$f" ] || rm -f "$tmp/t/$f"; continue ;; esac
  done < "$lista"
  (cd "$TARGET" 2>/dev/null && xargs grep -lE '^model( =|:) ' < "$lista" 2>/dev/null) > "$tmp/.modelos" || true
  while IFS= read -r f; do [ -f "$tmp/t/$f" ] && preserva_modelo "$TARGET/$f" "$tmp/t/$f"; done < "$tmp/.modelos"
  mkdir -p "$TARGET"
  cp -Rp "$tmp/t/." "$TARGET/"
  cp "$man" "$MANIFEST"
  [ "$migrated" = "0" ] || { rm -f "$TARGET/$H_SKILLS/$SKILL/modelos.conf"; echo "migrated modelos.conf to models.conf"; }
  printf '%s\n' "$(version)" > "$VERSAO"
  rm -rf "$tmp"

  echo "open-debate $(version) in $TARGET: $n_add new, $n_upd updated, $(printf '%s' "$conflitos" | wc -w | tr -d ' ') overwritten"
  # A new install writes the profile; an update only swaps a model that left the catalog (free model rotation).
  if [ "$H_ID" = "opencode" ] && command -v opencode >/dev/null 2>&1 && [ -z "$conflitos" ]; then
    action=repair; [ "$novo" = "1" ] && action=apply
    "$TARGET/$H_SKILLS/$SKILL/scripts/models.sh" "$action" > /dev/null || echo "warning: models not applied, run: open-debate models apply"
  fi
  [ "$modo" = "init" ] && printf 'ready in %s: %s\n' "$H_NAME" "$H_INVOKE"
  return 0
}

do_uninstall() {
  [ -f "$MANIFEST" ] || { echo "error: nothing installed in $TARGET" >&2; return 2; }
  mantidos=0; dirs=""
  tmpu="$(mktemp)"
  awk '{ print $2 }' "$MANIFEST" | hashes "$TARGET" | awk 'FNR == NR { h[$2] = $1; next } { print $1, $2, h[$2] }' "$MANIFEST" - > "$tmpu"
  while read -r a f h; do
    [ "$a" != "-" ] || continue
    if [ "$a" = "$h" ] || [ "$FORCE" = "1" ]; then rm -f "$TARGET/$f"; case "$f" in */*) dirs="$dirs ${f%/*}" ;; *) dirs="$dirs ." ;; esac
    else echo "kept, edited: $f"; mantidos=$((mantidos + 1)); fi
  done < "$tmpu"
  rm -f "$tmpu"
  if [ "$mantidos" -eq 0 ]; then
    rm -f "$MANIFEST" "$VERSAO"
    find "$TARGET/$H_SKILLS/$SKILL" -depth -type d -empty -exec rmdir {} \; 2>/dev/null || true
    for d in $dirs; do
      while [ "$d" != "." ] && rmdir "$TARGET/$d" 2>/dev/null; do d="$(dirname "$d")"; done
    done
    if [ "$PROJECT" = "1" ] && [ "$TARGET" != "$PWD" ]; then rmdir "$TARGET" 2>/dev/null || true; fi
    echo "removed from $TARGET"
  else
    echo "$mantidos edited file(s) kept; --force removes everything" >&2; return 1
  fi
}

dica_dep() {
  if command -v brew >/dev/null 2>&1; then printf 'brew install %s' "$1"
  elif command -v apt-get >/dev/null 2>&1; then printf 'sudo apt-get install %s' "$1"
  elif command -v dnf >/dev/null 2>&1; then printf 'sudo dnf install %s' "$1"
  else printf 'install %s' "$1"; fi
}

doctor_harness() {
  edit=0; falta=0
  r="$(awk '{ print $2 }' "$MANIFEST" | hashes "$TARGET" | awk 'FNR == NR { h[$2] = $1; next }
    $1 == "-" { print "MISSING " $2; next } $1 != h[$2] { e++ } END { print "EDIT " e + 0 }' "$MANIFEST" -)"
  printf '%s\n' "$r" | grep '^MISSING ' && falta=1
  edit="$(printf '%s\n' "$r" | sed -n 's/^EDIT //p')"
  printf 'ok    %-9s installed in %s (version %s, call it with %s)\n' "$H_ID" "$TARGET" "$(cat "$VERSAO" 2>/dev/null || echo '?')" "$H_INVOKE"
  [ "$edit" -eq 0 ] || printf 'warn  %-9s %s edited file(s), update does not overwrite them\n' "$H_ID" "$edit"
  [ "$(cat "$VERSAO" 2>/dev/null)" = "$(version)" ] || printf 'warn  %-9s installed version differs from the package %s, run: open-debate update\n' "$H_ID" "$(version)"
  rc2="$falta"
  if [ "$H_ID" = "opencode" ] && command -v opencode >/dev/null 2>&1; then "$TARGET/$H_SKILLS/$SKILL/scripts/models.sh" check || rc2=1; fi
  return "$rc2"
}

do_doctor() {
  rc=0; inst=0
  for c in jq awk perl; do
    if command -v "$c" >/dev/null 2>&1; then printf 'ok    %s\n' "$c"
    else printf 'MISSING %s: %s\n' "$c" "$(dica_dep "$c")"; rc=1; fi
  done
  for h in $1; do
    resolve_target "$h"
    if [ -f "$MANIFEST" ]; then
      inst=$((inst + 1)); doctor_harness || rc=1
      h_bin >/dev/null || printf 'warn  %-9s installed, but the binary is not on PATH\n' "$h"
    elif h_bin >/dev/null; then printf 'free  %-9s detected, not installed: open-debate init --harness %s\n' "$h" "$h"
    fi
  done
  if [ "$inst" -eq 0 ]; then echo 'MISSING no install, run: open-debate init'; rc=1; fi
  return "$rc"
}

do_models() {
  resolve_target opencode
  [ -f "$MANIFEST" ] || { echo "error: models only applies to opencode, and nothing is installed in $TARGET" >&2; exit 2; }
  m="$TARGET/$H_SKILLS/$SKILL/scripts/models.sh"
  case "${1:-check}" in
    check|free|apply|repair) exec "$m" "$1" ;;
    profile) shift; exec "$m" profile "$@" ;;
    *) echo "usage: open-debate models check|apply|repair|free|profile <free|mixed|strong> [provider/model]" >&2; exit 2 ;;
  esac
}

do_harnesses() {
  printf '%-9s %-20s %-9s %-10s %-10s %s\n' ID HARNESS DETECTED INSTALLED MODE INVOKE
  for h in $HARNESSES; do
    resolve_target "$h"
    d=no; if h_detected; then d=yes; fi
    i=no; if [ -f "$MANIFEST" ]; then i=yes; fi
    printf '%-9s %-20s %-9s %-10s %-10s %s\n' "$h" "$H_NAME" "$d" "$i" "$H_MODE" "$H_INVOKE"
  done
  echo
  echo 'Modes: native and subagents run the panel as subagents in the session; cli runs each specialist as a headless process.'
  echo 'Any CLI with a headless mode works too: HARNESS=custom HARNESS_CMD="my-cli --print \"\$PROMPT\"" open-debate run <case>'
}
