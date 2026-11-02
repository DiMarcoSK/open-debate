# tokens.awk - reads the 1st TOKENS..END block of the file.
# mode=list: prints "key<TAB>value". mode=contrast: the WCAG pairs of visual-contract.md, exits 1 if any fails.
# No block: exits 3.
function hx(s,  i, n) { s = tolower(s); n = 0; for (i = 1; i <= length(s); i++) n = n * 16 + index("0123456789abcdef", substr(s, i, 1)) - 1; return n }
function chan(h, i,  v) { v = hx(substr(h, i, 2)) / 255; return v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ^ 2.4 }
function lum(h) { h = substr(h, 2); return 0.2126 * chan(h, 1) + 0.7152 * chan(h, 3) + 0.0722 * chan(h, 5) }
function ratio(a, b,  x, y) { x = lum(a) + 0.05; y = lum(b) + 0.05; return x > y ? x / y : y / x }
function pair(a, b, m, optional,  r, ok) {
  if (!(a in t) || !(b in t)) {
    if (optional) return
    printf "%s/%s missing FAIL\n", a, b; fail = 1; return
  }
  r = ratio(t[a], t[b]); ok = r + 0.005 >= m
  printf "%s/%s %.2f min %.1f %s\n", a, b, r, m, ok ? "OK" : "FAIL"
  if (!ok) fail = 1
}
function ishex(w) { return w ~ /^#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]$/ }
state == 0 && /^[[:space:]`>*#|-]*TOKENS[[:space:]`*|:]*$/ { state = 1; found = 1; next }
state == 1 && /^[[:space:]`>*#|-]*END[[:space:]`*|]*$/ { state = 2; next }
state == 1 {
  l = $0; sub(/\/\/.*/, "", l); gsub(/[|`*]/, " ", l); sub(/^[[:space:]>-]+/, "", l); sub(/[[:space:]]+$/, "", l)
  if (l == "") next
  n = split(l, w, /[[:space:]]+/); hashex = 0
  for (i = 2; i <= n; i++) {
    x = w[i]; sub(/[,;.]$/, "", x)
    if (ishex(x)) { k = tolower(w[i - 1]); sub(/:$/, "", k); t[k] = toupper(x); hashex = 1 }
  }
  if (hashex) next
  k = tolower(w[1]); sub(/:$/, "", k)
  v = substr(l, length(w[1]) + 1); sub(/^[[:space:]:]+/, "", v)
  if (v != "") txt[k] = v
}
END {
  if (!found) { print "no TOKENS..END block FAIL"; exit 3 }
  if (mode == "list") {
    for (k in t) printf "%s\t%s\n", k, t[k]
    for (k in txt) printf "%s\t%s\n", k, txt[k]
    exit 0
  }
  pair("ink", "paper", 7.0); pair("ink", "surface", 7.0, 1); pair("ink-2", "paper", 4.5)
  pair("on-accent", "accent", 4.5); pair("accent", "paper", 3.0)
  pair("ok", "paper", 4.5); pair("warn", "paper", 4.5); pair("crit", "paper", 4.5)
  pair("ink-dark", "paper-dark", 7.0, 1)
  if (!("display" in txt)) { print "display missing FAIL"; fail = 1 }
  if (!("body" in txt)) { print "body missing FAIL"; fail = 1 }
  exit fail
}
