#!/bin/sh
# modelos.sh check|aplicar|reparar|livres|perfil <gratis|misto|forte> [modelo] - modelos dos agents do debate no opencode.
# Perfil (modelos.conf): gratis = so modelos de custo 0 (gasta 0, opiniao mais rasa); misto = o modelo `forte` so nos
# assentos que decidem (orquestrador, juiz, auditor, arquitetura), o resto gratis; forte = `forte` em todos (mais tokens).
# check: agent, modelo e estado. aplicar: grava o perfil nos agents. reparar: troca so o que saiu do catalogo.
# Rotacao: modelo gratis que some do catalogo vira a reserva e, sem ela, um gratis distinto por agent (round-robin),
# para o painel nao cair todo no mesmo modelo e disputar o mesmo limite.
set -eu
export LC_ALL=C
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
CONF="$SCRIPT_DIR/../modelos.conf"
AGENTS="${OPENCODE_AGENTS:-$SCRIPT_DIR/../../../agents}"
DECISORES="debate debate-judge debate-auditor debate-arch"
command -v opencode >/dev/null 2>&1 || { echo "erro: opencode nao encontrado" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "erro: jq nao encontrado" >&2; exit 2; }

CATALOGO="$(opencode models --verbose 2>/dev/null || true)"
LIVRES="$(printf '%s\n' "$CATALOGO" | grep -v '^[a-z0-9.-]*/[^ ]*$' \
  | jq -r 'select(.cost.input == 0 and .cost.output == 0 and .capabilities.toolcall and .status != "deprecated") | .providerID + "/" + .id' 2>/dev/null || true)"
TODOS="$(printf '%s\n' "$CATALOGO" | grep '^[a-z0-9.-]*/[^ ]*$' || true)"
[ -n "$LIVRES" ] || { echo "erro: nenhum modelo gratuito listado (rode: opencode models --refresh)" >&2; exit 2; }
livre() { printf '%s\n' "$LIVRES" | grep -qx -- "$1"; }
existe() { livre "$1" || printf '%s\n' "$TODOS" | grep -qx -- "$1"; }
conf() { sed -n "s#^$1=##p" "$CONF" | head -1; }
PERFIL="$(conf perfil)"; PERFIL="${PERFIL:-gratis}"
FORTE="$(conf forte)"

# desejado <agent>: modelo que o perfil pede para o agent.
desejado() {
  case "$PERFIL" in
    forte) printf '%s' "$FORTE"; return ;;
    misto) case " $DECISORES " in *" $1 "*) printf '%s' "$FORTE"; return ;; esac ;;
  esac
  conf "$1"
}

# substituto <indice>: reserva gratis ou o n-esimo gratis do catalogo, em rodizio.
substituto() {
  r="$(conf reserva)"
  if [ -n "$r" ] && livre "$r" && [ "$1" -eq 0 ]; then printf '%s' "$r"; return; fi
  n="$(printf '%s\n' "$LIVRES" | wc -l | tr -d ' ')"
  printf '%s\n' "$LIVRES" | sed -n "$(( $1 % n + 1 ))p"
}

grava() { # grava <modo>: aplicar reescreve tudo; reparar so troca o modelo que saiu do catalogo.
  i=0
  for f in "$AGENTS"/debate*.md; do
    a="$(basename "$f" .md)"; atual="$(sed -n 's/^model: //p' "$f" | head -1)"
    if [ "$1" = "reparar" ]; then
      if existe "$atual"; then continue; fi
      m="$(conf "$a")"
    else
      m="$(desejado "$a")"
    fi
    [ -n "$m" ] || continue
    if ! existe "$m"; then
      s="$(substituto "$i")"; i=$((i + 1))
      printf 'troca %s: %s -> %s (fora do catalogo)\n' "$a" "$m" "$s"; m="$s"
    fi
    sed "s#^model: .*#model: $m#" "$f" > "$f.tmp" && mv "$f.tmp" "$f"
    printf 'ok    %-16s %s\n' "$a" "$m"
  done
}

case "${1:-check}" in
  livres) printf '%s\n' "$LIVRES" ;;
  check)
    rc=0; printf 'perfil %s%s\n' "$PERFIL" "${FORTE:+, forte=$FORTE}"
    for f in "$AGENTS"/debate*.md; do
      a="$(basename "$f" .md)"; m="$(sed -n 's/^model: //p' "$f" | head -1)"
      if livre "$m"; then printf 'ok    %-16s %s\n' "$a" "$m"
      elif existe "$m"; then printf 'pago  %-16s %s\n' "$a" "$m"
      else printf 'FORA  %-16s %s (saiu do catalogo: open-debate models apply)\n' "$a" "$m"; rc=1; fi
    done
    exit "$rc" ;;
  aplicar) grava aplicar ;;
  reparar) grava reparar ;;
  perfil)
    p="${2:-}"; m="${3:-$FORTE}"
    case "$p" in gratis|misto|forte) ;; *) echo "uso: modelos.sh perfil gratis|misto|forte [provider/modelo]" >&2; exit 2 ;; esac
    if [ "$p" != "gratis" ]; then
      [ -n "$m" ] || { echo "erro: perfil $p pede o modelo forte, ex: modelos.sh perfil $p anthropic/claude-sonnet-5-5 (lista: opencode models)" >&2; exit 2; }
      existe "$m" || { echo "erro: $m nao esta no catalogo do opencode (lista: opencode models)" >&2; exit 2; }
    fi
    grep -Ev '^(perfil|forte)=' "$CONF" > "$CONF.tmp" || true
    { printf 'perfil=%s\nforte=%s\n' "$p" "$m"; cat "$CONF.tmp"; } > "$CONF"; rm -f "$CONF.tmp"
    PERFIL="$p"; FORTE="$m"; grava aplicar ;;
  *) echo "uso: modelos.sh check|aplicar|reparar|livres|perfil <gratis|misto|forte> [modelo]" >&2; exit 2 ;;
esac
