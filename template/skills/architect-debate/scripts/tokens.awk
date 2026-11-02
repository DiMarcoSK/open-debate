# tokens.awk - le o 1o bloco TOKENS..FIM do arquivo.
# modo=lista: imprime "chave<TAB>valor". modo=contraste: pares WCAG de visual-contract.md, sai 1 se algum falha.
# Sem bloco: sai 3.
function hx(s,  i, n) { s = tolower(s); n = 0; for (i = 1; i <= length(s); i++) n = n * 16 + index("0123456789abcdef", substr(s, i, 1)) - 1; return n }
function canal(h, i,  v) { v = hx(substr(h, i, 2)) / 255; return v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ^ 2.4 }
function lum(h) { h = substr(h, 2); return 0.2126 * canal(h, 1) + 0.7152 * canal(h, 3) + 0.0722 * canal(h, 5) }
function razao(a, b,  x, y) { x = lum(a) + 0.05; y = lum(b) + 0.05; return x > y ? x / y : y / x }
function par(a, b, m, opcional,  r, ok) {
  if (!(a in t) || !(b in t)) {
    if (opcional) return
    printf "%s/%s ausente FALHA\n", a, b; falha = 1; return
  }
  r = razao(t[a], t[b]); ok = r + 0.005 >= m
  printf "%s/%s %.2f min %.1f %s\n", a, b, r, m, ok ? "OK" : "FALHA"
  if (!ok) falha = 1
}
function ehhex(w) { return w ~ /^#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]$/ }
estado == 0 && /^[[:space:]`>*#|-]*TOKENS[[:space:]`*|:]*$/ { estado = 1; achou = 1; next }
estado == 1 && /^[[:space:]`>*#|-]*FIM[[:space:]`*|]*$/ { estado = 2; next }
estado == 1 {
  l = $0; sub(/\/\/.*/, "", l); gsub(/[|`*]/, " ", l); sub(/^[[:space:]>-]+/, "", l); sub(/[[:space:]]+$/, "", l)
  if (l == "") next
  n = split(l, w, /[[:space:]]+/); temhex = 0
  for (i = 2; i <= n; i++) {
    x = w[i]; sub(/[,;.]$/, "", x)
    if (ehhex(x)) { k = tolower(w[i - 1]); sub(/:$/, "", k); t[k] = toupper(x); temhex = 1 }
  }
  if (temhex) next
  k = tolower(w[1]); sub(/:$/, "", k)
  v = substr(l, length(w[1]) + 1); sub(/^[[:space:]:]+/, "", v)
  if (v != "") txt[k] = v
}
END {
  if (!achou) { print "sem bloco TOKENS..FIM FALHA"; exit 3 }
  if (modo == "lista") {
    for (k in t) printf "%s\t%s\n", k, t[k]
    for (k in txt) printf "%s\t%s\n", k, txt[k]
    exit 0
  }
  par("tinta", "papel", 7.0); par("tinta", "superficie", 7.0, 1); par("tinta-2", "papel", 4.5)
  par("acento-tinta", "acento", 4.5); par("acento", "papel", 3.0)
  par("ok", "papel", 4.5); par("warn", "papel", 4.5); par("crit", "papel", 4.5)
  par("tinta-escuro", "papel-escuro", 7.0, 1)
  if (!("display" in txt)) { print "display ausente FALHA"; falha = 1 }
  if (!("body" in txt)) { print "body ausente FALHA"; falha = 1 }
  exit falha
}
