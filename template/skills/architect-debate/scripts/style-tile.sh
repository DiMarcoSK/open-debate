#!/bin/sh
# style-tile.sh <case-dir> [fonte.md] - gera <case-dir>/style-tile.html do bloco TOKENS
# (SDD.md, senao decision.md, senao proposta de design): cores com contraste, escala de tipo, componentes e estados.
# Exporta tambem tokens.json (W3C DTCG 2025.10) e tokens.css (custom properties).
set -eu
export LC_ALL=C
CASE_DIR="${1:?uso: style-tile.sh <case-dir> [fonte.md]}"
SRC="${2:-}"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
TOK="$SCRIPT_DIR/tokens.awk"

if [ -z "$SRC" ]; then
  for c in SDD.md decision.md proposals/debate-design-r2.md proposals/debate-design.md; do
    if [ -s "$CASE_DIR/$c" ] && awk -v modo=lista -f "$TOK" "$CASE_DIR/$c" >/dev/null 2>&1; then SRC="$CASE_DIR/$c"; break; fi
  done
fi
[ -n "$SRC" ] || { echo "erro: nenhum bloco TOKENS em $CASE_DIR" >&2; exit 2; }

LISTA="$(awk -v modo=lista -f "$TOK" "$SRC")"
get() { printf '%s\n' "$LISTA" | awk -F'\t' -v k="$1" '$1 == k { print $2; exit }'; }
cor() {
  v="$(get "$1")"
  case "$v" in \#[0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F]) printf '%s' "$v" ;; *) printf '%s' "$2" ;; esac
}
limpa() { printf '%s' "$1" | tr -cd 'A-Za-z0-9 .,()-'; }
esc() { printf '%s' "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/\*\*//g; s/`//g'; }
fam() { v="$(limpa "$(get "$1")")"; printf '%s' "${v:-$2}"; }
url() { printf '%s' "$1" | sed 's/ /+/g'; }
texto() {
  l="$(grep -m1 "$1[*]*:" "$SRC" 2>/dev/null | sed "s/.*$1[*]*:[[:space:]]*//" || true)"
  esc "${l:-nao escrito em ${SRC##*/}}"
}

PAPEL="$(cor papel '#F4F4F5')"; SUP="$(cor superficie "$PAPEL")"; TINTA="$(cor tinta '#18181B')"
TINTA2="$(cor tinta-2 "$TINTA")"; LINHA="$(cor linha '#D4D4D8')"; ACENTO="$(cor acento '#1D4ED8')"
ACT="$(cor acento-tinta '#FFFFFF')"; OK="$(cor ok '#166534')"; WARN="$(cor warn '#B45309')"; CRIT="$(cor crit '#991B1B')"
DISPLAY="$(fam display 'Fraunces')"; BODY="$(fam body 'Inter')"; MONO="$(fam mono 'JetBrains Mono')"
ESCALA="$(limpa "$(get escala)")"
RATIO="$(printf '%s' "$ESCALA" | awk '{ r = $1 + 0; print (r > 1 && r < 2) ? r : 1.25 }')"
BASE="$(printf '%s' "$ESCALA" | awk '{ b = 16; for (i = 1; i < NF; i++) if ($i == "base") b = $(i + 1) + 0; print (b >= 12 && b <= 22) ? b : 16 }')"
ESPACO="$(get espaco | tr -cd '0-9')"; ESPACO="${ESPACO:-4}"
RAIO="$(get raio | tr -cd '0-9')"; RAIO="${RAIO:-4}"
MOV="$(limpa "$(get movimento)")"; MOV="${MOV:-180ms ease}"
NOME="$(esc "$(sed -n '1s/^#[[:space:]]*\(SDD[[:space:]]*-[[:space:]]*\)\{0,1\}//p' "$CASE_DIR/SDD.md" 2>/dev/null)")"
NOME="${NOME:-$(esc "$(sed -n '3p' "$CASE_DIR/idea.md" 2>/dev/null)")}"
CONCEITO="$(texto Conceito)"
TAM() { awk -v b="$BASE" -v r="$RATIO" -v n="$1" 'BEGIN { printf "%.0f", b * r ^ n }'; }
H1="$(TAM 4)"; H2="$(TAM 2)"; H3="$(TAM 1)"; CAP="$(TAM -1)"

CONTRASTE="$(awk -v modo=contraste -f "$TOK" "$SRC" 2>/dev/null | awk '
  { st = ($NF == "OK") ? "ok" : "crit"; v = ($2 == "ausente") ? "-" : $2; m = ($3 == "min") ? $4 : "-"
    printf "<tr><td>%s</td><td class=num>%s</td><td class=num>%s</td><td><span class=\"tag %s\">%s</span></td></tr>\n", $1, v, m, st, $NF }' || true)"

SW=""
for k in papel superficie tinta tinta-2 linha acento acento-tinta ok warn crit; do
  h="$(cor "$k" '')"; [ -n "$h" ] || continue
  SW="$SW<figure class=sw><div style=\"background:$h\"></div><figcaption><b>$k</b><code>$h</code></figcaption></figure>"
done

cat > "$CASE_DIR/style-tile.html" <<HTML
<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Style tile ${NOME}</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=$(url "$DISPLAY")&display=swap">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=$(url "$BODY")&display=swap">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=$(url "$BODY"):wght@400;600&display=swap">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=$(url "$MONO")&display=swap">
<style>
:root{--papel:$PAPEL;--sup:$SUP;--tinta:$TINTA;--tinta2:$TINTA2;--linha:$LINHA;--acento:$ACENTO;--act:$ACT;
--ok:$OK;--warn:$WARN;--crit:$CRIT;--e:${ESPACO}px;--r:${RAIO}px;--mov:$MOV;
--fd:"$DISPLAY",Georgia,serif;--fb:"$BODY",system-ui,sans-serif;--fm:"$MONO",ui-monospace,monospace}
*{box-sizing:border-box}
body{margin:0;background:var(--papel);color:var(--tinta);font:${BASE}px/1.5 var(--fb)}
main{max-width:1120px;margin:0 auto;padding:calc(var(--e)*12) 16px}
header{border-bottom:2px solid var(--tinta);padding-bottom:calc(var(--e)*6);margin-bottom:calc(var(--e)*10)}
.kicker,.cap,figcaption code,th{font:500 ${CAP}px/1.4 var(--fm);letter-spacing:.06em;text-transform:uppercase;color:var(--tinta2)}
h1{font:${H1}px/1.02 var(--fd);margin:calc(var(--e)*3) 0;letter-spacing:-.02em;overflow-wrap:anywhere}
h2{font:${H2}px/1.15 var(--fd);margin:0 0 calc(var(--e)*4)}
h3{font:600 ${H3}px/1.3 var(--fb);margin:0 0 calc(var(--e)*2)}
section{margin:0 0 calc(var(--e)*14)}
.grid{display:grid;gap:calc(var(--e)*4);grid-template-columns:repeat(auto-fill,minmax(150px,1fr))}
.sw{margin:0;background:var(--sup);border:1px solid var(--linha);border-radius:var(--r);overflow:hidden}
.sw div{height:88px;border-bottom:1px solid var(--linha)}
.sw figcaption{padding:calc(var(--e)*3);display:flex;flex-direction:column;gap:var(--e)}
.esc p{margin:0 0 calc(var(--e)*3);display:flex;gap:calc(var(--e)*4);align-items:baseline}
.esc .cap{min-width:92px}
.duas{display:grid;gap:calc(var(--e)*8);grid-template-columns:repeat(auto-fit,minmax(300px,1fr))}
.card{background:var(--sup);border:1px solid var(--linha);border-radius:var(--r);padding:calc(var(--e)*6)}
button{font:600 ${BASE}px/1 var(--fb);padding:calc(var(--e)*3) calc(var(--e)*5);min-height:44px;border-radius:var(--r);cursor:pointer;
  border:1px solid var(--tinta);background:transparent;color:var(--tinta);transition:transform var(--mov),background var(--mov)}
button.p{background:var(--acento);border-color:var(--acento);color:var(--act)}
button:hover{transform:translateY(-1px)}
:focus-visible{outline:2px solid var(--acento);outline-offset:2px}
label{display:block;margin:calc(var(--e)*5) 0 var(--e)}
input{width:100%;font:${BASE}px var(--fb);padding:calc(var(--e)*3);border:1px solid var(--linha);border-radius:var(--r);background:var(--papel);color:var(--tinta)}
.fila{display:flex;gap:calc(var(--e)*3);flex-wrap:wrap;margin-top:calc(var(--e)*5)}
.tab{overflow-x:auto}
table{width:100%;border-collapse:collapse;background:var(--sup);border:1px solid var(--linha)}
th,td{text-align:left;padding:calc(var(--e)*3) calc(var(--e)*4);border-bottom:1px solid var(--linha)}
.num{font-variant-numeric:tabular-nums;font-family:var(--fm)}
.tag{font:600 ${CAP}px/1 var(--fm);text-transform:uppercase;padding:var(--e) calc(var(--e)*2);border:1px solid currentColor;border-radius:var(--r)}
.tag.ok{color:var(--ok)}.tag.warn{color:var(--warn)}.tag.crit{color:var(--crit)}
.estado{border-left:4px solid var(--linha)}
.estado.erro{border-left-color:var(--crit)}.estado.ok{border-left-color:var(--ok)}.estado.parcial{border-left-color:var(--warn)}
.sk{height:14px;border-radius:var(--r);margin:calc(var(--e)*2) 0;background:linear-gradient(90deg,var(--linha),var(--papel),var(--linha));background-size:200% 100%;animation:sk 1.4s linear infinite}
@keyframes sk{to{background-position:-200% 0}}
.esp div{height:12px;background:var(--acento);margin:calc(var(--e)*2) 0;border-radius:2px}
footer{border-top:1px solid var(--linha);padding-top:calc(var(--e)*4)}
@media (prefers-reduced-motion:reduce){*{animation:none!important;transition:none!important}}
</style>
</head>
<body>
<main>
<header>
  <div class="kicker">Style tile, gerado de ${SRC##*/}</div>
  <h1>${NOME:-Direcao visual}</h1>
  <p>${CONCEITO}</p>
</header>

<section>
  <h2>Cor</h2>
  <div class="grid">$SW</div>
</section>

<section class="duas">
  <div>
    <h2>Contraste</h2>
    <div class="tab"><table><thead><tr><th>Par</th><th>Razao</th><th>Minimo</th><th>Gate</th></tr></thead><tbody>
$CONTRASTE
    </tbody></table></div>
  </div>
  <div class="esc">
    <h2>Tipo</h2>
    <p><span class="cap">H1 ${H1}px</span><span style="font:${H1}px/1 var(--fd)">Aa</span></p>
    <p><span class="cap">H2 ${H2}px</span><span style="font:${H2}px/1.1 var(--fd)">$(esc "$DISPLAY")</span></p>
    <p><span class="cap">H3 ${H3}px</span><span style="font:600 ${H3}px var(--fb)">$(esc "$BODY") semibold</span></p>
    <p><span class="cap">Body ${BASE}px</span><span>12 alertas novos desde 09:40, 3 com prazo hoje.</span></p>
    <p><span class="cap">Mono ${CAP}px</span><span class="num">1.234.567 | 08:41:07</span></p>
    <p class="cap">escala ${RATIO}, espaco ${ESPACO}px, raio ${RAIO}px, movimento $(esc "$MOV")</p>
  </div>
</section>

<section class="duas">
  <div class="card">
    <h3>Componentes</h3>
    <label for="q">Buscar</label>
    <input id="q" placeholder="dominio, CNPJ ou id">
    <div class="fila"><button class="p">Acao primaria</button><button>Secundaria</button></div>
  </div>
  <div class="tab">
    <table>
      <thead><tr><th>Item</th><th>Valor</th><th>Estado</th></tr></thead>
      <tbody>
        <tr><td>Fila de entrada</td><td class="num">1.204</td><td><span class="tag ok">ok</span></td></tr>
        <tr><td>Tempo de resposta p95</td><td class="num">412 ms</td><td><span class="tag warn">atencao</span></td></tr>
        <tr><td>Falhas na ultima hora</td><td class="num">37</td><td><span class="tag crit">critico</span></td></tr>
      </tbody>
    </table>
  </div>
</section>

<section>
  <h2>Estados</h2>
  <div class="grid" style="grid-template-columns:repeat(auto-fit,minmax(260px,1fr))">
    <div class="card estado"><div class="cap">Vazio</div><p>$(texto Vazio)</p></div>
    <div class="card estado"><div class="cap">Loading</div><div class="sk"></div><div class="sk" style="width:80%"></div><div class="sk" style="width:60%"></div><p>$(texto Loading)</p></div>
    <div class="card estado erro"><div class="cap">Erro</div><p>$(texto Erro)</p></div>
    <div class="card estado ok"><div class="cap">Sucesso</div><p>$(texto Sucesso)</p></div>
    <div class="card estado parcial"><div class="cap">Parcial</div><p>$(texto Parcial)</p></div>
  </div>
</section>

<section class="esp">
  <h2>Espaco</h2>
  <div style="width:calc(var(--e)*2)"></div><div style="width:calc(var(--e)*4)"></div><div style="width:calc(var(--e)*8)"></div><div style="width:calc(var(--e)*16)"></div><div style="width:calc(var(--e)*32)"></div>
</section>

<footer class="cap">Fonte: ${SRC#"$CASE_DIR"/}. Regenerar: style-tile.sh ${CASE_DIR}</footer>
</main>
</body>
</html>
HTML
DUR="$(printf '%s' "$MOV" | awk '{ d = $1 + 0; print (d > 0 && d < 2000) ? d : 180 }')"
BEZ="$(printf '%s' "$MOV" | sed -n 's/.*cubic-bezier(\([-0-9., ]*\)).*/\1/p' | tr -d ' ')"
case "$(printf '%s' "$BEZ" | tr ',' '\n' | grep -c .)" in 4) ;; *) BEZ="0.2,0.8,0.2,1" ;; esac
jq -n --arg papel "$PAPEL" --arg sup "$SUP" --arg tinta "$TINTA" --arg tinta2 "$TINTA2" --arg linha "$LINHA" \
  --arg acento "$ACENTO" --arg act "$ACT" --arg ok "$OK" --arg warn "$WARN" --arg crit "$CRIT" \
  --arg fd "$DISPLAY" --arg fb "$BODY" --arg fm "$MONO" \
  --argjson h1 "$H1" --argjson h2 "$H2" --argjson h3 "$H3" --argjson base "$BASE" --argjson cap "$CAP" \
  --argjson esp "$ESPACO" --argjson raio "$RAIO" --argjson dur "$DUR" --argjson bez "[$BEZ]" '
  def cor($h): { "$type": "color", "$value": { colorSpace: "srgb", hex: $h,
    components: [ ($h[1:3], $h[3:5], $h[5:7]) | ascii_downcase | explode | (.[0] as $a | .[1] as $b |
      ((if $a > 96 then $a - 87 else $a - 48 end) * 16 + (if $b > 96 then $b - 87 else $b - 48 end)) / 255 * 1000 | round / 1000) ] } };
  def px($n): { "$type": "dimension", "$value": { value: $n, unit: "px" } };
  def fonte($f; $g): { "$type": "fontFamily", "$value": [ $f, $g ] };
  { color: { papel: cor($papel), superficie: cor($sup), tinta: cor($tinta), "tinta-2": cor($tinta2), linha: cor($linha),
      acento: cor($acento), "acento-tinta": cor($act), ok: cor($ok), warn: cor($warn), crit: cor($crit) },
    font: { family: { display: fonte($fd; "serif"), body: fonte($fb; "sans-serif"), mono: fonte($fm; "monospace") },
      size: { h1: px($h1), h2: px($h2), h3: px($h3), body: px($base), caption: px($cap) } },
    space: { base: px($esp) }, radius: { base: px($raio) },
    motion: { duration: { "$type": "duration", "$value": { value: $dur, unit: "ms" } },
      easing: { "$type": "cubicBezier", "$value": $bez } } }' > "$CASE_DIR/tokens.json"
cat > "$CASE_DIR/tokens.css" <<CSS
/* gerado por style-tile.sh de ${SRC#"$CASE_DIR"/}; fonte de verdade: tokens.json (DTCG) */
:root {
  --color-papel: $PAPEL; --color-superficie: $SUP; --color-tinta: $TINTA; --color-tinta-2: $TINTA2; --color-linha: $LINHA;
  --color-acento: $ACENTO; --color-acento-tinta: $ACT; --color-ok: $OK; --color-warn: $WARN; --color-crit: $CRIT;
  --font-display: "$DISPLAY", serif; --font-body: "$BODY", sans-serif; --font-mono: "$MONO", monospace;
  --font-size-h1: ${H1}px; --font-size-h2: ${H2}px; --font-size-h3: ${H3}px; --font-size-body: ${BASE}px; --font-size-caption: ${CAP}px;
  --space-base: ${ESPACO}px; --radius-base: ${RAIO}px; --motion-duration: ${DUR}ms; --motion-easing: cubic-bezier($BEZ);
}
CSS
printf '%s\n' "$CASE_DIR/style-tile.html" "$CASE_DIR/tokens.json" "$CASE_DIR/tokens.css"
