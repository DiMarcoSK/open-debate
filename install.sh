#!/bin/sh
# install.sh - installs open-debate without npm.
#   curl -fsSL https://raw.githubusercontent.com/DiMarcoSK/open-debate/main/install.sh | sh
# Env: OPEN_DEBATE_REF=stable (tag or branch; stable = the last push to main that passed CI), OPEN_DEBATE_HOME, OPEN_DEBATE_BIN, OPEN_DEBATE_NO_INIT=1.
# Downloads the package to ~/.local/share/open-debate, links the command in ~/.local/bin and installs in the detected harnesses.
# Running it again updates.
set -eu

REPO="DiMarcoSK/open-debate"
REF="${OPEN_DEBATE_REF:-}"
DEST="${OPEN_DEBATE_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/open-debate}"
BIN="${OPEN_DEBATE_BIN:-$HOME/.local/bin}"

erro() { printf 'error: %s\n' "$1" >&2; exit 1; }

dica() {
  if command -v brew >/dev/null 2>&1; then printf 'brew install %s' "$1"
  elif command -v apt-get >/dev/null 2>&1; then printf 'sudo apt-get install %s' "$1"
  elif command -v dnf >/dev/null 2>&1; then printf 'sudo dnf install %s' "$1"
  else printf 'install %s with the system package manager' "$1"; fi
}

case "$(uname -s)" in
  Darwin|Linux) ;;
  *) erro "unsupported system: $(uname -s). On Windows, use WSL." ;;
esac
command -v tar >/dev/null 2>&1 || erro "tar not found"
for c in jq perl; do
  command -v "$c" >/dev/null 2>&1 || erro "$c not found: $(dica "$c")"
done

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
if [ -n "${OPEN_DEBATE_TARBALL:-}" ]; then
  cp "$OPEN_DEBATE_TARBALL" "$tmp/p.tgz"
else
  baixa() { # baixa <url> <out> [header]
    if command -v curl >/dev/null 2>&1; then curl -fsSL ${3:+-H "$3"} "$1" -o "$2"
    elif command -v wget >/dev/null 2>&1; then wget -qO "$2" ${3:+--header="$3"} "$1"
    else erro "curl or wget not found"; fi
  }
  # Pin the sha before downloading: the tarball and the update notice refer to the same commit. Without the stable tag, use main.
  for r in ${REF:-stable main}; do
    if baixa "https://api.github.com/repos/$REPO/commits/$r" "$tmp/sha" 'Accept: application/vnd.github.sha' 2>/dev/null; then REF="$r"; break; fi
  done
  SHA="$(cat "$tmp/sha" 2>/dev/null || true)"
  [ -n "$SHA" ] || erro "ref not found: ${REF:-stable}"
  baixa "https://codeload.github.com/$REPO/tar.gz/$SHA" "$tmp/p.tgz"
fi
mkdir "$tmp/p"
tar -xzf "$tmp/p.tgz" -C "$tmp/p" --strip-components=1
[ -x "$tmp/p/bin/open-debate" ] || erro "invalid package at $REF"

[ -z "${SHA:-}" ] || printf '%s %s\n' "$REF" "$SHA" > "$tmp/p/.open-debate-ref"
existia=0; [ -e "$DEST" ] && existia=1

# Swap only after validating: a failed download does not destroy the installed version.
mkdir -p "$(dirname "$DEST")" "$BIN"
rm -rf "$DEST.antigo"
if [ -e "$DEST" ]; then mv "$DEST" "$DEST.antigo"; fi
mv "$tmp/p" "$DEST"
rm -rf "$DEST.antigo"
ln -sf "$DEST/bin/open-debate" "$BIN/open-debate"
printf 'open-debate %s in %s\n' "$("$BIN/open-debate" --version)" "$DEST"

if [ "${OPEN_DEBATE_NO_INIT:-0}" != "1" ]; then
  # Reinstalling updates what is already installed, keeping models and edits; the 1st time installs in the detected harnesses.
  if [ "$existia" = "1" ]; then "$BIN/open-debate" update || printf 'warning: partial update, see above (open-debate update --force backs up and overwrites)\n' >&2
  else "$BIN/open-debate" init --yes || printf 'warning: no harness configured now. Later run: open-debate init\n' >&2; fi
fi

case ":$PATH:" in
  *":$BIN:"*) ;;
  *) printf '\nAdd to PATH: export PATH="%s:$PATH"\n' "$BIN" ;;
esac
