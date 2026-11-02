#!/bin/sh
# install.sh - instala o open-debate sem npm.
#   curl -fsSL https://raw.githubusercontent.com/FelipeDiMarco/open-debate/main/install.sh | sh
# Env: OPEN_DEBATE_REF=main (tag ou branch), OPEN_DEBATE_HOME, OPEN_DEBATE_BIN, OPEN_DEBATE_NO_INIT=1.
# Baixa o pacote para ~/.local/share/open-debate, liga o comando em ~/.local/bin e instala nos harnesses detectados.
# Rodar de novo atualiza.
set -eu

REPO="FelipeDiMarco/open-debate"
REF="${OPEN_DEBATE_REF:-main}"
DEST="${OPEN_DEBATE_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/open-debate}"
BIN="${OPEN_DEBATE_BIN:-$HOME/.local/bin}"

erro() { printf 'erro: %s\n' "$1" >&2; exit 1; }

dica() {
  if command -v brew >/dev/null 2>&1; then printf 'brew install %s' "$1"
  elif command -v apt-get >/dev/null 2>&1; then printf 'sudo apt-get install %s' "$1"
  elif command -v dnf >/dev/null 2>&1; then printf 'sudo dnf install %s' "$1"
  else printf 'instale %s pelo gerenciador do sistema' "$1"; fi
}

case "$(uname -s)" in
  Darwin|Linux) ;;
  *) erro "sistema nao suportado: $(uname -s). No Windows, use WSL." ;;
esac
command -v tar >/dev/null 2>&1 || erro "tar nao encontrado"
for c in jq perl; do
  command -v "$c" >/dev/null 2>&1 || erro "$c nao encontrado: $(dica "$c")"
done

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
if [ -n "${OPEN_DEBATE_TARBALL:-}" ]; then
  cp "$OPEN_DEBATE_TARBALL" "$tmp/p.tgz"
else
  url="https://codeload.github.com/$REPO/tar.gz/$REF"
  if command -v curl >/dev/null 2>&1; then curl -fsSL "$url" -o "$tmp/p.tgz"
  elif command -v wget >/dev/null 2>&1; then wget -qO "$tmp/p.tgz" "$url"
  else erro "curl ou wget nao encontrado"; fi
fi
mkdir "$tmp/p"
tar -xzf "$tmp/p.tgz" -C "$tmp/p" --strip-components=1
[ -x "$tmp/p/bin/open-debate" ] || erro "pacote invalido em $REF"

# Troca so depois de validar: falha no download nao destroi a versao instalada.
mkdir -p "$(dirname "$DEST")" "$BIN"
rm -rf "$DEST.antigo"
if [ -e "$DEST" ]; then mv "$DEST" "$DEST.antigo"; fi
mv "$tmp/p" "$DEST"
rm -rf "$DEST.antigo"
ln -sf "$DEST/bin/open-debate" "$BIN/open-debate"
printf 'open-debate %s em %s\n' "$("$BIN/open-debate" --version)" "$DEST"

if [ "${OPEN_DEBATE_NO_INIT:-0}" != "1" ]; then
  "$BIN/open-debate" init --yes || printf 'aviso: nenhum harness configurado agora. Depois rode: open-debate init\n' >&2
fi

case ":$PATH:" in
  *":$BIN:"*) ;;
  *) printf '\nAdicione ao PATH: export PATH="%s:$PATH"\n' "$BIN" ;;
esac
