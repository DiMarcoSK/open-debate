# gates.sh - checagens compartilhadas por debate.sh e validate.sh (source). Requer TOK = caminho de tokens.awk.
# check <fase> <agent> <arquivo> imprime os motivos de reprovacao separados por "; ", ou nada.

has() { grep -qi -- "$2" "$1" 2>/dev/null; }

tokens_ok() {
  r="$(awk -v modo=contraste -f "$TOK" "$1" 2>&1)" && return 0
  printf '; TOKENS: %s' "$(printf '%s\n' "$r" | grep 'FALHA' | tr '\n' ' ')"
}

check() {
  fase="$1"; a="$2"; f="$3"; m=""
  if [ ! -s "$f" ]; then printf 'saida ausente ou vazia'; return 0; fi
  case "$fase" in
    pesquisa)
      if grep -q '^pulado' "$f"; then return 0; fi
      u="$(grep -Eo 'https?://[^] )|>"]+' "$f" | sort -u | wc -l | tr -d ' ')"
      [ "$u" -ge 5 ] || m="$m; $u URL(s) distinta(s), minimo 5"
      has "$f" 'lacuna' || m="$m; sem secao Lacunas" ;;
    proposta)
      has "$f" 'concess' || m="$m; sem concessao"
      case "$a" in
        debate-arch)
          grep -q 'mermaid' "$f" || m="$m; sem C4 em bloco mermaid"
          grep -q 'ADR' "$f" || m="$m; sem ADRs propostos" ;;
        debate-design)
          m="$m$(tokens_ok "$f")"
          for s in Vazio Loading Erro; do has "$f" "$s" || m="$m; sem estado $s escrito"; done ;;
      esac ;;
    ataque)
      has "$f" 'veto' || m="$m; sem veto"
      has "$f" 'concess' || m="$m; sem concessao"
      grep -q '"' "$f" || m="$m; sem citacao literal entre aspas" ;;
    decisao)
      n="$(grep -cE '^#+[[:space:]]*ADR-[0-9]+' "$f" || true)"
      [ "$n" -ge 3 ] || m="$m; $n ADR(s), minimo 3 com cabecalho ## ADR-NNNN"
      i="$(awk '
        function nivel(l) { match(l, /^#+/); return RLENGTH }
        function fecha() { if (h != "" && !(d && al && c)) print h }
        /^#+[[:space:]]*ADR-[0-9]/ { fecha(); h = $0; lv = nivel($0); d = al = c = 0; next }
        /^#/ && h != "" && nivel($0) <= lv { fecha(); h = "" }
        h != "" && tolower($0) ~ /resultado|decisao:|decisão:/ { d = 1 }
        h != "" && tolower($0) ~ /opcoes|opções|alternativ/ { al = 1 }
        h != "" && tolower($0) ~ /confirmac|confirmaç/ { c = 1 }
        END { fecha() }' "$f")"
      [ -z "$i" ] || m="$m; ADR sem Resultado, Opcoes ou Confirmacao (MADR): $(printf '%s' "$i" | tr '\n' ' ')"
      s="$(grep -c '`[0-9][0-9] [a-z0-9]' "$f" || true)"
      { [ "$s" -ge 3 ] && [ "$s" -le 6 ]; } || m="$m; indice de specs com $s linha(s), esperado 3-6 como \`NN slug\`"
      has "$f" 'dissenso' || m="$m; sem Dissenso" ;;
    trilha)
      has "$f" 'Aceite' || m="$m; itens sem Aceite"
      [ "$(grep -c '^- ' "$f")" -ge 8 ] || m="$m; menos de 8 itens" ;;
    backlog)
      t="$(sed -n 's/^| \([a-z-]*\) | .*/\1/p' "$(dirname "$f")/lapidacao.md" 2>/dev/null | grep -v '^tag$' | tr '\n' ' ')"
      sp="$(ls -d "$(dirname "$f")"/specs/[0-9][0-9]-*/ 2>/dev/null | sed 's#.*/\([0-9][0-9]\)-[^/]*/$#\1#' | tr '\n' ' ')"
      ad="$(ls "$(dirname "$f")"/adr/[0-9]*.md 2>/dev/null | sed 's#.*/\([0-9]\{4\}\)-.*#\1#' | tr '\n' ' ')"
      r="$(awk -v modo=check -v tags="$t" -v specs="$sp" -v adrs="$ad" -f "$(dirname "$TOK")/backlog.awk" "$f" 2>&1)" \
        || m="$m; $(printf '%s\n' "$r" | sed 's/^FALHA //' | head -12 | tr '\n' ';' | sed 's/;$//; s/;/; /g')"
      has "$f" 'Definition of Done' || m="$m; sem Definition of Done"
      has "$f" 'Capacidade' || m="$m; sem conta de capacidade" ;;
    sdd)
      for s in 0 1 2 3 4 5 6 7 8; do grep -q "^## $s" "$f" || m="$m; secao $s ausente"; done
      grep -q 'mermaid' "$f" || m="$m; secao 4 sem bloco mermaid"
      m="$m$(tokens_ok "$f")"
      for s in Vazio Loading Erro; do has "$f" "$s" || m="$m; sem estado $s"; done
      if grep -qw -e TODO -e TBD "$f" || has "$f" 'a definir' || grep -q '<nome do produto>\|<metafora>' "$f"; then
        m="$m; placeholder no texto"
      fi ;;
  esac
  printf '%s' "${m#; }"
}

# split_adrs <caso> - separa cada ADR de decision.md em adr/NNNN-slug.md (MADR, 1 arquivo por decisao).
split_adrs() {
  mkdir -p "$1/adr"; rm -f "$1"/adr/[0-9]*.md
  awk -v dir="$1/adr" '
    function nivel(l) { match(l, /^#+/); return RLENGTH }
    /^#+[[:space:]]*ADR-[0-9]+/ {
      if (f != "") close(f)
      lv = nivel($0); h = $0; sub(/^#+[[:space:]]*ADR-/, "", h); num = h; sub(/[^0-9].*/, "", num)
      t = h; sub(/^[0-9]+[[:space:]:.-]*/, "", t); s = tolower(t); gsub(/[^a-z0-9]+/, "-", s); gsub(/^-+|-+$/, "", s)
      f = sprintf("%s/%04d-%s.md", dir, num + 0, substr(s, 1, 40))
      l = $0; sub(/^#+/, "#", l); print l > f; next
    }
    /^#/ && f != "" && nivel($0) <= lv { close(f); f = ""; next }
    f != "" { l = $0; if (l ~ /^#/) l = substr(l, lv); print l > f }' "$1/decision.md"
  ls "$1"/adr/[0-9]*.md 2>/dev/null | wc -l | tr -d ' '
}
