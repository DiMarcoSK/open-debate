#!/bin/sh
# style-tile.sh <case-dir> [source.md] - generates <case-dir>/style-tile.html from the TOKENS block
# (SDD.md, else decision.md, else the debate-brand or debate-ux proposal): colors with contrast, type scale, components and states.
# Also exports tokens.json (W3C DTCG 2025.10) and tokens.css (custom properties).
set -eu
export LC_ALL=C
CASE_DIR="${1:?usage: style-tile.sh <case-dir> [source.md]}"
SRC="${2:-}"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
TOK="$SCRIPT_DIR/tokens.awk"

if [ -z "$SRC" ]; then
  for c in SDD.md decision.md proposals/debate-brand-r2.md proposals/debate-brand.md proposals/debate-ux-r2.md proposals/debate-ux.md; do
    if [ -s "$CASE_DIR/$c" ] && awk -v mode=list -f "$TOK" "$CASE_DIR/$c" >/dev/null 2>&1; then SRC="$CASE_DIR/$c"; break; fi
  done
fi
[ -n "$SRC" ] || { echo "error: no TOKENS block in $CASE_DIR" >&2; exit 2; }

LISTA="$(awk -v mode=list -f "$TOK" "$SRC")"
TAB="$(printf '\t')"
# get <key>: builtins only, no process per key.
get() {
  while IFS="$TAB" read -r g_k g_v; do
    if [ "$g_k" = "$1" ]; then printf '%s' "$g_v"; return 0; fi
  done <<EOF_LISTA
$LISTA
EOF_LISTA
}
color() {
  v="$(get "$1")"
  case "$v" in \#[0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F]) printf '%s' "$v" ;; *) printf '%s' "$2" ;; esac
}
clean() { printf '%s' "$1" | tr -cd 'A-Za-z0-9 .,()-'; }
esc() { printf '%s' "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/\*\*//g; s/`//g'; }
family() { v="$(clean "$(get "$1")")"; printf '%s' "${v:-$2}"; }
url() { printf '%s' "$1" | sed 's/ /+/g'; }
text() {
  l="$(grep -m1 "$1[*]*:" "$SRC" 2>/dev/null | sed "s/.*$1[*]*:[[:space:]]*//" || true)"
  esc "${l:-not written in ${SRC##*/}}"
}

PAPER="$(color paper '#F4F4F5')"; SUP="$(color surface "$PAPER")"; INK="$(color ink '#18181B')"
INK2="$(color ink-2 "$INK")"; LINE="$(color line '#D4D4D8')"; ACCENT="$(color accent '#1D4ED8')"
ACT="$(color on-accent '#FFFFFF')"; OK="$(color ok '#166534')"; WARN="$(color warn '#B45309')"; CRIT="$(color crit '#991B1B')"
DISPLAY="$(family display 'Fraunces')"; BODY="$(family body 'Inter')"; MONO="$(family mono 'JetBrains Mono')"
SCALE="$(clean "$(get scale)")"
RATIO="$(printf '%s' "$SCALE" | awk '{ r = $1 + 0; print (r > 1 && r < 2) ? r : 1.25 }')"
BASE="$(printf '%s' "$SCALE" | awk '{ b = 16; for (i = 1; i < NF; i++) if ($i == "base") b = $(i + 1) + 0; print (b >= 12 && b <= 22) ? b : 16 }')"
SPACE="$(get space | tr -cd '0-9')"; SPACE="${SPACE:-4}"
RADIUS="$(get radius | tr -cd '0-9')"; RADIUS="${RADIUS:-4}"
MOV="$(clean "$(get motion)")"; MOV="${MOV:-180ms ease}"
NAME="$(esc "$(sed -n '1s/^#[[:space:]]*\(SDD[[:space:]]*-[[:space:]]*\)\{0,1\}//p' "$CASE_DIR/SDD.md" 2>/dev/null)")"
NAME="${NAME:-$(esc "$(sed -n '3p' "$CASE_DIR/idea.md" 2>/dev/null)")}"
CONCEPT="$(text Concept)"
SIZE() { awk -v b="$BASE" -v r="$RATIO" -v n="$1" 'BEGIN { printf "%.0f", b * r ^ n }'; }
H1="$(SIZE 4)"; H2="$(SIZE 2)"; H3="$(SIZE 1)"; CAP="$(SIZE -1)"

CONTRAST="$(awk -v mode=contrast -f "$TOK" "$SRC" 2>/dev/null | awk '
  { st = ($NF == "OK") ? "ok" : "crit"; v = ($2 == "missing") ? "-" : $2; m = ($3 == "min") ? $4 : "-"
    printf "<tr><td>%s</td><td class=num>%s</td><td class=num>%s</td><td><span class=\"tag %s\">%s</span></td></tr>\n", $1, v, m, st, $NF }' || true)"

SW=""
for k in paper surface ink ink-2 line accent on-accent ok warn crit; do
  h="$(color "$k" '')"; [ -n "$h" ] || continue
  SW="$SW<figure class=sw><div style=\"background:$h\"></div><figcaption><b>$k</b><code>$h</code></figcaption></figure>"
done

cat > "$CASE_DIR/style-tile.html" <<HTML
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Style tile ${NAME}</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=$(url "$DISPLAY")&display=swap">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=$(url "$BODY")&display=swap">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=$(url "$BODY"):wght@400;600&display=swap">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=$(url "$MONO")&display=swap">
<style>
:root{--paper:$PAPER;--sup:$SUP;--ink:$INK;--ink2:$INK2;--line:$LINE;--accent:$ACCENT;--act:$ACT;
--ok:$OK;--warn:$WARN;--crit:$CRIT;--e:${SPACE}px;--r:${RADIUS}px;--mov:$MOV;
--fd:"$DISPLAY",Georgia,serif;--fb:"$BODY",system-ui,sans-serif;--fm:"$MONO",ui-monospace,monospace}
*{box-sizing:border-box}
body{margin:0;background:var(--paper);color:var(--ink);font:${BASE}px/1.5 var(--fb)}
main{max-width:1120px;margin:0 auto;padding:calc(var(--e)*12) 16px}
header{border-bottom:2px solid var(--ink);padding-bottom:calc(var(--e)*6);margin-bottom:calc(var(--e)*10)}
.kicker,.cap,figcaption code,th{font:500 ${CAP}px/1.4 var(--fm);letter-spacing:.06em;text-transform:uppercase;color:var(--ink2)}
h1{font:${H1}px/1.02 var(--fd);margin:calc(var(--e)*3) 0;letter-spacing:-.02em;overflow-wrap:anywhere}
h2{font:${H2}px/1.15 var(--fd);margin:0 0 calc(var(--e)*4)}
h3{font:600 ${H3}px/1.3 var(--fb);margin:0 0 calc(var(--e)*2)}
section{margin:0 0 calc(var(--e)*14)}
.grid{display:grid;gap:calc(var(--e)*4);grid-template-columns:repeat(auto-fill,minmax(150px,1fr))}
.sw{margin:0;background:var(--sup);border:1px solid var(--line);border-radius:var(--r);overflow:hidden}
.sw div{height:88px;border-bottom:1px solid var(--line)}
.sw figcaption{padding:calc(var(--e)*3);display:flex;flex-direction:column;gap:var(--e)}
.scale p{margin:0 0 calc(var(--e)*3);display:flex;gap:calc(var(--e)*4);align-items:baseline}
.scale .cap{min-width:92px}
.two{display:grid;gap:calc(var(--e)*8);grid-template-columns:repeat(auto-fit,minmax(300px,1fr))}
.card{background:var(--sup);border:1px solid var(--line);border-radius:var(--r);padding:calc(var(--e)*6)}
button{font:600 ${BASE}px/1 var(--fb);padding:calc(var(--e)*3) calc(var(--e)*5);min-height:44px;border-radius:var(--r);cursor:pointer;
  border:1px solid var(--ink);background:transparent;color:var(--ink);transition:transform var(--mov),background var(--mov)}
button.p{background:var(--accent);border-color:var(--accent);color:var(--act)}
button:hover{transform:translateY(-1px)}
:focus-visible{outline:2px solid var(--accent);outline-offset:2px}
label{display:block;margin:calc(var(--e)*5) 0 var(--e)}
input{width:100%;font:${BASE}px var(--fb);padding:calc(var(--e)*3);border:1px solid var(--line);border-radius:var(--r);background:var(--paper);color:var(--ink)}
.row{display:flex;gap:calc(var(--e)*3);flex-wrap:wrap;margin-top:calc(var(--e)*5)}
.tab{overflow-x:auto}
table{width:100%;border-collapse:collapse;background:var(--sup);border:1px solid var(--line)}
th,td{text-align:left;padding:calc(var(--e)*3) calc(var(--e)*4);border-bottom:1px solid var(--line)}
.num{font-variant-numeric:tabular-nums;font-family:var(--fm)}
.tag{font:600 ${CAP}px/1 var(--fm);text-transform:uppercase;padding:var(--e) calc(var(--e)*2);border:1px solid currentColor;border-radius:var(--r)}
.tag.ok{color:var(--ok)}.tag.warn{color:var(--warn)}.tag.crit{color:var(--crit)}
.state{border-left:4px solid var(--line)}
.state.error{border-left-color:var(--crit)}.state.ok{border-left-color:var(--ok)}.state.partial{border-left-color:var(--warn)}
.sk{height:14px;border-radius:var(--r);margin:calc(var(--e)*2) 0;background:linear-gradient(90deg,var(--line),var(--paper),var(--line));background-size:200% 100%;animation:sk 1.4s linear infinite}
@keyframes sk{to{background-position:-200% 0}}
.space div{height:12px;background:var(--accent);margin:calc(var(--e)*2) 0;border-radius:2px}
footer{border-top:1px solid var(--line);padding-top:calc(var(--e)*4)}
@media (prefers-reduced-motion:reduce){*{animation:none!important;transition:none!important}}
</style>
</head>
<body>
<main>
<header>
  <div class="kicker">Style tile, generated from ${SRC##*/}</div>
  <h1>${NAME:-Visual direction}</h1>
  <p>${CONCEPT}</p>
</header>

<section>
  <h2>Color</h2>
  <div class="grid">$SW</div>
</section>

<section class="two">
  <div>
    <h2>Contrast</h2>
    <div class="tab"><table><thead><tr><th>Pair</th><th>Ratio</th><th>Minimum</th><th>Gate</th></tr></thead><tbody>
$CONTRAST
    </tbody></table></div>
  </div>
  <div class="scale">
    <h2>Type</h2>
    <p><span class="cap">H1 ${H1}px</span><span style="font:${H1}px/1 var(--fd)">Aa</span></p>
    <p><span class="cap">H2 ${H2}px</span><span style="font:${H2}px/1.1 var(--fd)">$(esc "$DISPLAY")</span></p>
    <p><span class="cap">H3 ${H3}px</span><span style="font:600 ${H3}px var(--fb)">$(esc "$BODY") semibold</span></p>
    <p><span class="cap">Body ${BASE}px</span><span>12 new alerts since 09:40, 3 due today.</span></p>
    <p><span class="cap">Mono ${CAP}px</span><span class="num">1,234,567 | 08:41:07</span></p>
    <p class="cap">scale ${RATIO}, space ${SPACE}px, radius ${RADIUS}px, motion $(esc "$MOV")</p>
  </div>
</section>

<section class="two">
  <div class="card">
    <h3>Components</h3>
    <label for="q">Search</label>
    <input id="q" placeholder="domain, company or id">
    <div class="row"><button class="p">Primary action</button><button>Secondary</button></div>
  </div>
  <div class="tab">
    <table>
      <thead><tr><th>Item</th><th>Value</th><th>State</th></tr></thead>
      <tbody>
        <tr><td>Inbound queue</td><td class="num">1,204</td><td><span class="tag ok">ok</span></td></tr>
        <tr><td>Response time p95</td><td class="num">412 ms</td><td><span class="tag warn">warning</span></td></tr>
        <tr><td>Failures in the last hour</td><td class="num">37</td><td><span class="tag crit">critical</span></td></tr>
      </tbody>
    </table>
  </div>
</section>

<section>
  <h2>States</h2>
  <div class="grid" style="grid-template-columns:repeat(auto-fit,minmax(260px,1fr))">
    <div class="card state"><div class="cap">Empty</div><p>$(text Empty)</p></div>
    <div class="card state"><div class="cap">Loading</div><div class="sk"></div><div class="sk" style="width:80%"></div><div class="sk" style="width:60%"></div><p>$(text Loading)</p></div>
    <div class="card state error"><div class="cap">Error</div><p>$(text Error)</p></div>
    <div class="card state ok"><div class="cap">Success</div><p>$(text Success)</p></div>
    <div class="card state partial"><div class="cap">Partial</div><p>$(text Partial)</p></div>
  </div>
</section>

<section class="space">
  <h2>Space</h2>
  <div style="width:calc(var(--e)*2)"></div><div style="width:calc(var(--e)*4)"></div><div style="width:calc(var(--e)*8)"></div><div style="width:calc(var(--e)*16)"></div><div style="width:calc(var(--e)*32)"></div>
</section>

<footer class="cap">Source: ${SRC#"$CASE_DIR"/}. Regenerate: style-tile.sh ${CASE_DIR}</footer>
</main>
</body>
</html>
HTML
DUR="$(printf '%s' "$MOV" | awk '{ d = $1 + 0; print (d > 0 && d < 2000) ? d : 180 }')"
BEZ="$(printf '%s' "$MOV" | sed -n 's/.*cubic-bezier(\([-0-9., ]*\)).*/\1/p' | tr -d ' ')"
case "$(printf '%s' "$BEZ" | tr ',' '\n' | grep -c .)" in 4) ;; *) BEZ="0.2,0.8,0.2,1" ;; esac
jq -n --arg paper "$PAPER" --arg sup "$SUP" --arg ink "$INK" --arg ink2 "$INK2" --arg line "$LINE" \
  --arg accent "$ACCENT" --arg act "$ACT" --arg ok "$OK" --arg warn "$WARN" --arg crit "$CRIT" \
  --arg fd "$DISPLAY" --arg fb "$BODY" --arg fm "$MONO" \
  --argjson h1 "$H1" --argjson h2 "$H2" --argjson h3 "$H3" --argjson base "$BASE" --argjson cap "$CAP" \
  --argjson esp "$SPACE" --argjson raio "$RADIUS" --argjson dur "$DUR" --argjson bez "[$BEZ]" '
  def color($h): { "$type": "color", "$value": { colorSpace: "srgb", hex: $h,
    components: [ ($h[1:3], $h[3:5], $h[5:7]) | ascii_downcase | explode | (.[0] as $a | .[1] as $b |
      ((if $a > 96 then $a - 87 else $a - 48 end) * 16 + (if $b > 96 then $b - 87 else $b - 48 end)) / 255 * 1000 | round / 1000) ] } };
  def px($n): { "$type": "dimension", "$value": { value: $n, unit: "px" } };
  def font($f; $g): { "$type": "fontFamily", "$value": [ $f, $g ] };
  { color: { paper: color($paper), surface: color($sup), ink: color($ink), "ink-2": color($ink2), line: color($line),
      accent: color($accent), "on-accent": color($act), ok: color($ok), warn: color($warn), crit: color($crit) },
    font: { family: { display: font($fd; "serif"), body: font($fb; "sans-serif"), mono: font($fm; "monospace") },
      size: { h1: px($h1), h2: px($h2), h3: px($h3), body: px($base), caption: px($cap) } },
    space: { base: px($esp) }, radius: { base: px($raio) },
    motion: { duration: { "$type": "duration", "$value": { value: $dur, unit: "ms" } },
      easing: { "$type": "cubicBezier", "$value": $bez } } }' > "$CASE_DIR/tokens.json"
cat > "$CASE_DIR/tokens.css" <<CSS
/* generated by style-tile.sh from ${SRC#"$CASE_DIR"/}; source of truth: tokens.json (DTCG) */
:root {
  --color-paper: $PAPER; --color-surface: $SUP; --color-ink: $INK; --color-ink-2: $INK2; --color-line: $LINE;
  --color-accent: $ACCENT; --color-on-accent: $ACT; --color-ok: $OK; --color-warn: $WARN; --color-crit: $CRIT;
  --font-display: "$DISPLAY", serif; --font-body: "$BODY", sans-serif; --font-mono: "$MONO", monospace;
  --font-size-h1: ${H1}px; --font-size-h2: ${H2}px; --font-size-h3: ${H3}px; --font-size-body: ${BASE}px; --font-size-caption: ${CAP}px;
  --space-base: ${SPACE}px; --radius-base: ${RADIUS}px; --motion-duration: ${DUR}ms; --motion-easing: cubic-bezier($BEZ);
}
CSS
printf '%s\n' "$CASE_DIR/style-tile.html" "$CASE_DIR/tokens.json" "$CASE_DIR/tokens.css"
