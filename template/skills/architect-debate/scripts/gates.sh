# gates.sh - checagens compartilhadas por debate.sh, gate.sh e validate.sh (source). Requer TOK = caminho de tokens.awk e PAINEL.
# check <fase> <agent> <arquivo> imprime os motivos de reprovacao separados por "; ", ou nada.
# Na fase spec, <arquivo> e o diretorio da spec.

has() { grep -qi -- "$2" "$1" 2>/dev/null; }
# pai <caminho>: o dirname sem processo.
pai() { case "$1" in */*) printf '%s' "${1%/*}" ;; *) printf . ;; esac; }
no_painel() { case " $PAINEL " in *" $1 "*) return 0 ;; esac; return 1; }

# --- painel: assentos base sempre presentes, opcionais escolhidos pelo que o brief diz (references/painel.conf)
PAINEL_BASE="debate-arch debate-ux debate-pm"
PAINEL_TETO=8
AWKS="${TOK%/*}"
CATALOGO="$AWKS/../references/painel.conf"

# O que o brief realmente afirma: valores sem rotulo, sem a linha Fora do escopo e sem negativa; minusculo e sem acento.
texto_brief() {
  { sed -n '/^- Fora do escopo/d; s/^- [^:]*:[[:space:]]*//p' "$1/brief.md" 2>/dev/null; sed 1d "$1/idea.md" 2>/dev/null; } \
    | if perl -MUnicode::Normalize -e 1 2>/dev/null; then perl -CSD -MUnicode::Normalize -ne '$_ = lc NFD($_); s/\pM//g; print'
      else tr '[:upper:]' '[:lower:]'; fi \
    | grep -Ev '^[[:space:]]*(nao|nenhum|nenhuma|sem|n/a)([^a-z]|$)' || true
}

# motivos_painel <caso>: 1 linha "agent: palavra do brief" por assento opcional acionado, na ordem do catalogo.
motivos_painel() {
  tb="$(texto_brief "$1")"
  while IFS='|' read -r ag tipo gat; do
    case "$ag" in ''|'#'*) continue ;; esac
    [ "$tipo" = "opcional" ] || continue
    w="$(printf '%s\n' "$tb" | grep -Eiwo -- "$gat" | head -1 || true)"
    [ -z "$w" ] || printf '%s: %s\n' "$ag" "$w"
  done < "$CATALOGO"
}

# corta_painel <agents>: sem repeticao, no maximo PAINEL_TETO.
corta_painel() {
  cp_out=""; cp_n=0
  for x in $1; do
    case " $cp_out " in *" $x "*) continue ;; esac
    [ "$cp_n" -lt "$PAINEL_TETO" ] || continue
    cp_out="$cp_out $x"; cp_n=$((cp_n + 1))
  done
  printf '%s' "${cp_out# }"
}

# com_base <agents>: assentos base primeiro, depois os demais na ordem dada.
com_base() { corta_painel "$PAINEL_BASE $1"; }

escolhe_painel() { com_base "$(motivos_painel "$1" | cut -d: -f1 | tr '\n' ' ')"; }

# painel_do_caso <caso>: o painel gravado em meta.txt ou, sem ele, o escolhido pelo brief.
painel_do_caso() {
  pc="$(sed -n 's/^painel: //p' "$1/meta.txt" 2>/dev/null | tail -1)"
  [ -n "$pc" ] || pc="$(escolhe_painel "$1")"
  printf '%s' "$pc"
}
pulado() { grep -q '^pulado' "$1" 2>/dev/null; }

tokens_ok() {
  r="$(awk -v modo=contraste -f "$TOK" "$1" 2>&1)" && return 0
  printf '; TOKENS: %s' "$(printf '%s\n' "$r" | grep 'FALHA' | tr '\n' ' ')"
}

# Teto de linhas nao vazias de cada saida, o mesmo das personas. Reprova so com folga de 50%: refazer custa mais que sobrar um pouco.
teto() {
  case "$1:$2" in
    proposta:debate-arch) printf 85 ;;
    proposta:debate-design) printf 90 ;;
    proposta:debate-ux) printf 80 ;;
    proposta:debate-brand) printf 100 ;;
    proposta:debate-pm) printf 60 ;;
    ataque:debate-ux) printf 40 ;;
    proposta:*) printf 55 ;;
    ataque:*) printf 25 ;;
    pesquisa:*) printf 100 ;;
    agenda:*) printf 20 ;;
    decisao:*) printf 150 ;;
    auditoria:*) printf 25 ;;
    marca:*) printf 120 ;;
    backlog:*) printf 150 ;;
    *) printf 0 ;;
  esac
}

tamanho_ok() {
  c="$(teto "$1" "$2")"; [ "$c" -gt 0 ] || return 0
  n="$(grep -c . "$3" || true)"
  [ "$n" -le $((c * 3 / 2)) ] || printf '; %s linhas, teto %s: corte o que nao decide' "$n" "$c"
}

# Ids Rn citados que nao existem em research.md: numero com fonte inventada.
refs_ok() {
  awk -v rs="$2/research.md" '
    BEGIN {
      while ((getline l < rs) > 0) {
        if (l ~ /^pulado/) pul = 1
        if (match(l, /^\|[ *]*R[0-9]+[ *]*\|/)) { x = substr(l, RSTART, RLENGTH); gsub(/[^R0-9]/, "", x); ok[x] = 1; n++ }
      }
      if (pul || !n) exit
    }
    # Token Rn com fronteira fora de [A-Za-z0-9_-], como no texto: "R3," e "(R3)" contam, "R3a" e "AR3" nao.
    { l = $0; gsub(/[^A-Za-z0-9_-]/, " ", l); k = split(l, w, " ")
      for (i = 1; i <= k; i++) if (w[i] ~ /^R[0-9]+$/ && !(w[i] in ok) && !(w[i] in vis)) { vis[w[i]] = 1; r = r " " w[i] } }
    END { if (r != "") printf "; cita id inexistente em research.md:%s", r }' "$1"
}
# faltam_d <caso> <arquivo>: ids Dn da agenda que o arquivo nao cita, num awk so.
faltam_d() {
  awk -v ag="$1/agenda.md" '
    BEGIN {
      while ((getline l < ag) > 0) {
        if (l ~ /^pulado/) { n = 0; exit }
        if (match(l, /^\|[ *]*D[0-9]+[ *]*\|/)) { x = substr(l, RSTART, RLENGTH); gsub(/[^D0-9]/, "", x); id[++n] = x }
      }
      if (!n) exit
    }
    { l = $0; gsub(/[^A-Za-z0-9]/, " ", l); k = split(l, w, " "); for (i = 1; i <= k; i++) tem[w[i]] = 1 }
    END { for (i = 1; i <= n; i++) if (!(id[i] in tem)) printf "%s ", id[i] }' "$2"
}

# secoes_faltando <arquivo> <n...>: numeros sem cabecalho "## n".
secoes_faltando() {
  f_="$1"; shift
  awk -v q="$*" 'BEGIN { k = split(q, s, " ") } /^## / { for (i = 1; i <= k; i++) if (index($0, "## " s[i]) == 1) t[i] = 1 }
    END { for (i = 1; i <= k; i++) if (!(i in t)) printf "; secao %s ausente", s[i] }' "$f_"
}

# Visual banido de visual-contract.md: 1 awk para a lista toda. Linha que so menciona o termo para negar ou vetar nao conta;
# o arquivo com `override` escrito em qualquer lugar fica liberado.
banidos() {
  awk '
    BEGIN { n = split("roxo-azul|gradiente roxo|glass card|glassmorphism|lorem ipsum|corporate memphis|parede de texto|carousel|carrossel", b, "|") }
    { l = tolower($0) }
    l ~ /override/ { ov = 1 }
    l ~ /sem |banid|veto|ausente|override|evit|nao |proib|lista/ { next }
    { for (i = 1; i <= n; i++) if (!(i in hit) && index(l, b[i])) hit[i] = NR }
    END { if (ov) exit; for (i = 1; i <= n; i++) if (i in hit) printf "; visual banido (%s) na linha %s sem override escrito", b[i], hit[i] }' "$1"
}

# Agents do painel que levaram veto: so eles precisam de replica.
vetados() {
  for x in $PAINEL; do
    curto="${x#debate-}"
    if cat "$1"/critiques/*.md 2>/dev/null | grep -Eiq "^#+[[:space:]]*veto contra[[:space:]\`*]*(debate-)?$curto([^a-z0-9-]|\$)"; then printf '%s ' "$x"; fi
  done
}

check_spec() {
  d="${1%/}"; c="${d%/*}"; c="$(pai "$c")"; m=""
  for x in spec plan tasks; do
    [ -s "$d/$x.md" ] || { printf '%s.md ausente' "$x"; return 0; }
    if grep -q '<nn>\|<slug>\|<quem>\|<evento>\|ADR-NNNN' "$d/$x.md"; then printf '%s.md com placeholder' "$x"; return 0; fi
  done
  grep -q 'ADR-[0-9]' "$d/spec.md" || m="$m; spec sem ADR citado"
  if ls "$c"/adr/[0-9]*.md >/dev/null 2>&1; then
    for r in $(grep -Eo 'ADR-[0-9]+' "$d/spec.md" "$d/plan.md" -h | sed 's/ADR-//' | sort -u); do
      x="$(printf '%s' "$r" | sed 's/^0*//')"
      ls "$c/adr/$(printf '%04d' "${x:-0}")"-*.md >/dev/null 2>&1 || m="$m; cita ADR-$r, que nao existe em adr/"
    done
  fi
  grep -q 'O SISTEMA DEVE' "$d/spec.md" || m="$m; sem requisito EARS (O SISTEMA DEVE)"
  grep -Eq '^- \[.\] T[0-9]+' "$d/tasks.md" || m="$m; tasks sem linha - [ ] Tnnn"
  for u in $(sed -n 's/^- \(US[0-9][0-9]*\)[[:space:]].*/\1/p' "$d/spec.md"); do
    grep -q "\[$u\]" "$d/tasks.md" || m="$m; $u sem task"
  done
  printf '%s' "${m#; }"
}

check() {
  fase="$1"; a="$2"; f="$3"; m=""
  [ "$fase" = "spec" ] && { check_spec "$f"; return 0; }
  if [ ! -s "$f" ]; then printf 'saida ausente ou vazia'; return 0; fi
  case "$fase" in
    proposta|ataque) c="$(pai "$(pai "$f")")" ;;
    *) c="$(pai "$f")" ;;
  esac
  m="$(tamanho_ok "$fase" "$a" "$f")"
  case "$fase" in
    pesquisa)
      if pulado "$f"; then return 0; fi
      u="$(grep -Eo 'https?://[^] )|>"]+' "$f" | sort -u | wc -l | tr -d ' ')"
      [ "$u" -ge 5 ] || m="$m; $u URL(s) distinta(s), minimo 5"
      n="$(grep -cE '^\|[ *]*R[0-9]+[ *]*\|' "$f" || true)"
      [ "$n" -ge 5 ] || m="$m; $n achado(s) na tabela, minimo 5"
      s="$(grep -E '^\|[ *]*R[0-9]+[ *]*\|' "$f" | grep -Evi 'https?://|nao verificado' | sed 's/^|[ *]*\(R[0-9]*\).*/\1/' | tr '\n' ' ' || true)"
      [ -z "$s" ] || m="$m; achado sem URL nem nao verificado: $s"
      has "$f" 'lacuna' || m="$m; sem secao Lacunas" ;;
    agenda)
      if pulado "$f"; then return 0; fi
      n="$(grep -cE '^\|[ *]*D[0-9]+[ *]*\|' "$f" || true)"
      { [ "$n" -ge 3 ] && [ "$n" -le 8 ]; } || m="$m; $n decisao(oes), esperado 3-8 linhas | Dn | ..."
      r="$(awk -F'|' -v painel=" $PAINEL " '
        /^\|[ *]*D[0-9]+[ *]*\|/ {
          id = $2; o = $4; dono = $5; drv = $6; gsub(/[ *]/, "", id); gsub(/[ *`]/, "", dono); gsub(/ /, "", drv)
          if (o !~ / \/ /) print id " sem 2+ opcoes separadas por / "
          if (index(painel, " " dono " ") == 0) print id " com dono fora do painel: " dono
          if (drv == "") print id " sem driver"
        }' "$f")"
      [ -z "$r" ] || m="$m; $(printf '%s' "$r" | tr '\n' ';' | sed 's/;/; /g')" ;;
    proposta)
      has "$f" 'concess' || m="$m; sem concessao"
      for d in $(faltam_d "$c" "$f"); do m="$m; sem posicao em $d"; done
      m="$m$(refs_ok "$f" "$c")"
      case "$a" in
        debate-arch)
          grep -q 'mermaid' "$f" || m="$m; sem C4 em bloco mermaid"
          grep -q 'ADR' "$f" || m="$m; sem ADRs propostos"
          has "$f" 'capacidade' || m="$m; sem conta de capacidade" ;;
        debate-design)
          has "$f" 'fluxo' || m="$m; sem fluxos"
          has "$f" 'inventario' || m="$m; sem inventario de telas"
          m="$m$(banidos "$f")"
          for s in Vazio Loading Erro; do has "$f" "$s" || m="$m; sem estado $s escrito"; done ;;
        debate-ux)
          has "$f" 'wcag' || m="$m; sem plano WCAG"
          has "$f" 'nielsen\|heuristica' || m="$m; sem heuristicas"
          has "$f" 'usabilidade' || m="$m; sem teste de usabilidade"
          no_painel debate-brand || m="$m$(tokens_ok "$f")"
          m="$m$(banidos "$f")"
          for s in Vazio Loading Erro; do has "$f" "$s" || m="$m; sem estado $s escrito"; done ;;
        debate-brand)
          m="$m$(tokens_ok "$f")"
          m="$m$(banidos "$f")"
          has "$f" 'voz' || m="$m; sem voz e tom"
          has "$f" 'logo' || m="$m; sem logo"
          has "$f" 'posicionamento\|plataforma' || m="$m; sem plataforma de marca" ;;
        debate-pm)
          has "$f" 'mvp' || m="$m; sem corte de MVP"
          has "$f" 'metrica' || m="$m; sem metrica"
          has "$f" 'premissa' || m="$m; sem premissas a validar" ;;
        debate-aws)
          has "$f" 'custo' || m="$m; sem custo"
          has "$f" 'iam' || m="$m; sem IAM"
          has "$f" 'budget\|alerta' || m="$m; sem alerta de budget" ;;
        debate-data)
          has "$f" 'pipeline' || m="$m; sem pipeline"
          has "$f" 'qualidade' || m="$m; sem testes de qualidade"
          has "$f" 'retencao' || m="$m; sem retencao"
          has "$f" 'custo' || m="$m; sem custo" ;;
        debate-ai)
          has "$f" 'eval' || m="$m; sem eval"
          has "$f" 'fallback' || m="$m; sem fallback"
          has "$f" 'custo' || m="$m; sem custo" ;;
        debate-mobile)
          has "$f" 'offline' || m="$m; sem offline"
          has "$f" 'loja\|store' || m="$m; sem loja"
          has "$f" 'versao minima\|rollout' || m="$m; sem politica de atualizacao" ;;
        debate-gcp)
          has "$f" 'custo' || m="$m; sem custo"
          has "$f" 'iam' || m="$m; sem IAM"
          has "$f" 'budget\|alerta' || m="$m; sem alerta de budget" ;;
        debate-k8s)
          has "$f" 'rollback' || m="$m; sem rollback"
          has "$f" 'custo' || m="$m; sem custo" ;;
        debate-sec)
          has "$f" 'stride' || m="$m; sem STRIDE"
          has "$f" 'authz\|autoriza' || m="$m; sem modelo de autorizacao"
          has "$f" 'audit' || m="$m; sem trilha de auditoria" ;;
      esac ;;
    ataque)
      n="$(grep -cEi '^#+[[:space:]]*veto contra' "$f" || true)"
      { [ "$n" -ge 1 ] && [ "$n" -le 3 ]; } || m="$m; $n veto(s), esperado 1-3 cabecalhos ### Veto contra <agent>"
      has "$f" 'concess' || m="$m; sem concessao"
      if grep -Eiq "^#+[[:space:]]*veto contra[[:space:]\`*]*(debate-)?${a#debate-}([^a-z0-9-]|\$)" "$f"; then m="$m; veto contra si mesmo"; fi
      r="$(awk -v base="$c" -f "$AWKS/citacoes.awk" "$f" 2>&1)" \
        || m="$m; $(printf '%s\n' "$r" | sed 's/^FALHA //' | head -4 | tr '\n' ';' | sed 's/;$//; s/;/; /g')"
      if [ "$a" = "debate-ux" ] && no_painel debate-design; then
        grep -Eiq '^#+[[:space:]]*revis(ao|ão)[[:space:]]+(de[[:space:]]+)?(debate-)?design' "$f" || m="$m; sem secao ## Revisao debate-design"
      fi
      m="$m$(refs_ok "$f" "$c")" ;;
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
      has "$f" 'dissenso' || m="$m; sem Dissenso"
      r="$(awk -f "$AWKS/placar.awk" "$f" 2>&1)" \
        || m="$m; $(printf '%s\n' "$r" | sed 's/^FALHA //' | head -6 | tr '\n' ';' | sed 's/;$//; s/;/; /g')"
      for d in $(faltam_d "$c" "$f"); do m="$m; $d da agenda sem decisao"; done
      m="$m$(refs_ok "$f" "$c")"
      v="$(cat "$c"/critiques/*.md 2>/dev/null | grep -cEi '^#+[[:space:]]*veto contra' || true)"
      e="$(grep -cEi '\|[[:space:]]*errado[[:space:]]*\|' "$c/research-check.md" 2>/dev/null || true)"
      e="${e:-0}"
      sec="$(awk 'tolower($0) ~ /^#+[[:space:]]*([0-9]+[.)]?[[:space:]]*)?vetos/ { on = 1; next } /^## / { on = 0 } on' "$f")"
      nv="$(printf '%s\n' "$sec" | grep -cEi 'mantido|rejeitado' || true)"
      [ "$nv" -ge "$v" ] || m="$m; $nv veto(s) julgado(s) de $v: secao Vetos com 1 linha mantido|rejeitado por veto"
      ne="$(printf '%s\n' "$sec" | grep -ci 'errado' || true)"
      [ "$ne" -ge "$e" ] || m="$m; $ne claim(s) errado(s) zerado(s) de $e do fact-check: 1 linha por claim na secao Vetos" ;;
    auditoria)
      grep -Eq '^Veredito: (APROVADO|CORRIGIR|APLICADO)' "$f" || m="$m; sem linha Veredito: APROVADO|CORRIGIR"
      if grep -q '^Veredito: CORRIGIR' "$f"; then
        grep -Eq '^\|[ *]*A[0-9]+[ *]*\|' "$f" || m="$m; CORRIGIR sem linha | An | ..."
      fi ;;
    marca)
      m="$m$(secoes_faltando "$f" 1 2 3 4 5 6 7 8)"
      m="$m$(tokens_ok "$f")"
      m="$m$(banidos "$f")"
      has "$f" 'logo' || m="$m; sem logo"
      has "$f" 'voz' || m="$m; sem voz"
      n="$(awk '/^## 7/ { on = 1; next } /^## / { on = 0 } on && /^\|/ && !/^\|[ :-]*\|[ :|-]*$/ { n++ } END { print n + 0 }' "$f")"
      [ "$n" -ge 2 ] || m="$m; secao 7 sem tela adaptada: tabela | Tela | ... com 1+ linha"
      if grep -q '<nome do produto>\|<tela>' "$f" || grep -qw -e TODO -e TBD "$f"; then m="$m; placeholder no texto"; fi
      if [ -s "$c/SDD.md" ] && awk -v modo=lista -f "$TOK" "$c/SDD.md" > /dev/null 2>&1; then
        o="$(awk -v modo=lista -f "$TOK" "$c/SDD.md" | sort)"; d="$(awk -v modo=lista -f "$TOK" "$f" 2>/dev/null | sort)"
        [ "$o" = "$d" ] || m="$m; TOKENS do BRANDBOOK difere do SDD: copie literal"
      fi ;;
    trilha)
      has "$f" 'Aceite' || m="$m; itens sem Aceite"
      [ "$(grep -c '^- ' "$f")" -ge 8 ] || m="$m; menos de 8 itens" ;;
    backlog)
      t="$(sed -n 's/^| \([a-z-]*\) | .*/\1/p' "$c/lapidacao.md" 2>/dev/null | grep -v '^tag$' | tr '\n' ' ')"
      # Tag de marca so vale com brandbook: sem diretor de arte no painel, nao ha marca para aplicar.
      [ -s "$c/BRANDBOOK.md" ] || t="$(printf '%s' "$t" | tr ' ' '\n' | grep -vx 'marca' | tr '\n' ' ')"
      sp="$(ls -d "$c"/specs/[0-9][0-9]-*/ 2>/dev/null | sed 's#.*/\([0-9][0-9]\)-[^/]*/$#\1#' | tr '\n' ' ')"
      ad="$(ls "$c"/adr/[0-9]*.md 2>/dev/null | sed 's#.*/\([0-9]\{4\}\)-.*#\1#' | tr '\n' ' ')"
      ta=""
      for d in "$c"/specs/[0-9][0-9]-*/; do
        [ -f "${d}tasks.md" ] || continue
        b="${d%/}"; b="${b##*/}"
        for x in $(sed -n 's/^- \[.\] \(T[0-9][0-9]*\).*/\1/p' "${d}tasks.md"); do ta="$ta ${b%%-*}:$x"; done
      done
      r="$(awk -v modo=check -v tags="$t" -v specs="$sp" -v adrs="$ad" -v tarefas="$ta" -f "$AWKS/backlog.awk" "$f" 2>&1)" \
        || m="$m; $(printf '%s\n' "$r" | sed 's/^FALHA //' | head -12 | tr '\n' ';' | sed 's/;$//; s/;/; /g')"
      has "$f" 'Definition of Done' || m="$m; sem Definition of Done" ;;
    sdd)
      m="$m$(secoes_faltando "$f" 0 1 2 3 4 5 6 7 8)"
      grep -q 'mermaid' "$f" || m="$m; secao 4 sem bloco mermaid"
      m="$m$(tokens_ok "$f")"
      m="$m$(banidos "$f")"
      for s in Vazio Loading Erro; do has "$f" "$s" || m="$m; sem estado $s"; done
      if grep -qw -e TODO -e TBD "$f" || has "$f" 'a definir' || grep -q '<nome do produto>\|<metafora>' "$f"; then
        m="$m; placeholder no texto"
      fi
      for x in "$c"/adr/[0-9]*.md; do
        [ -f "$x" ] || continue
        id="${x##*/}"; id="${id%"${id#????}"}"
        grep -q "ADR-$id" "$f" || m="$m; ADR-$id fora do SDD"
      done
      if awk -v modo=lista -f "$TOK" "$c/decision.md" > /dev/null 2>&1; then
        o="$(awk -v modo=lista -f "$TOK" "$c/decision.md" | sort)"; d="$(awk -v modo=lista -f "$TOK" "$f" 2>/dev/null | sort)"
        [ "$o" = "$d" ] || m="$m; TOKENS do SDD difere do bloco de decision.md: copie literal"
      fi ;;
  esac
  printf '%s' "${m#; }"
}

# Saida mais antiga que a entrada dela: alguem editou o caso e o resto nao acompanhou.
defasados() {
  ant=""
  for x in brief.md research.md agenda.md decision.md SDD.md BACKLOG.md; do
    [ -s "$1/$x" ] || continue
    if [ -n "$ant" ] && [ "$1/$ant" -nt "$1/$x" ]; then printf '%s mais novo que %s\n' "$ant" "$x"; fi
    ant="$x"
  done
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
