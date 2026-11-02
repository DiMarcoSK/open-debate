# scores.awk - checks the judge's arithmetic in decision.md.
# Weights: a line `criterion=weight criterion=weight ...`, summing 100, written before the 1st score table.
# Score table: a table with a Total column; each criterion column holds the option's 0-5 score and Total = sum(score x weight).
# Accepts Total on the 0-5 scale (sum / 100). Prints "FAIL <reason>" and exits 1.
function trim(s) { gsub(/[*`]/, "", s); sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
function key(s) { s = tolower(trim(s)); sub(/[[:space:]]*[(=:].*$/, "", s); return s }
function num(s) { s = trim(s); sub(/^[^0-9-]+/, "", s); gsub(/,/, ".", s); if (s !~ /^-?[0-9]+(\.[0-9]+)?/) return "x"; return s + 0 }
!np && /[^[:space:]=|]+=[0-9]+/ && !/^\|/ {
  l = $0
  while (match(l, /[^[:space:],;:|]+=[0-9]+/)) {
    t = substr(l, RSTART, RLENGTH); l = substr(l, RSTART + RLENGTH)
    i = index(t, "="); k = tolower(substr(t, 1, i - 1)); w[k] = substr(t, i + 1) + 0; sum += w[k]; c++
  }
  if (c >= 3) np = 1; else { sum = 0; c = 0; split("", w) }
  next
}
/^\|/ {
  n = split($0, col, "|")
  if (!intable) {
    tot = 0; for (i = 2; i < n; i++) { h[i] = key(col[i]); if (h[i] == "total") tot = i }
    if (tot) { intable = 1; sep = 1; tables++ }
    next
  }
  if (sep) { sep = 0; next }
  opt = trim(col[2]); row = 0; cnt = 0
  for (i = 3; i < n; i++) {
    if (i == tot || h[i] == "") continue
    if (!(h[i] in w)) { noweight[h[i]] = 1; continue }
    v = num(col[i])
    if (v == "x") { print "FAIL score table without a score at " opt "/" h[i]; fail = 1; continue }
    if (v < 0 || v > 5) { print "FAIL score outside 0-5 at " opt "/" h[i]; fail = 1 }
    row += v * w[h[i]]; cnt++
  }
  dec = num(col[tot])
  if (dec == "x") { print "FAIL score table without a Total at " opt; fail = 1 }
  else if (cnt > 0) {
    d1 = dec - row; if (d1 < 0) d1 = -d1
    d2 = dec - row / 100; if (d2 < 0) d2 = -d2
    if (d1 > 0.51 && d2 > 0.011) { nc++; math[nc] = sprintf("FAIL Total of %s is %s, the arithmetic gives %s", opt, dec, row) }
  }
  next
}
{ intable = 0 }
END {
  if (!np) { print "FAIL no weights: 1 line criterion=weight, 3+ criteria"; fail = 1 }
  else if (sum != 100) { print "FAIL weights sum " sum ", they must sum 100"; fail = 1 }
  else for (i = 1; i <= nc; i++) { print math[i]; fail = 1 }
  if (tables == 0) { print "FAIL no score table: 1 table with a Total column per contested decision"; fail = 1 }
  for (k in noweight) { print "FAIL score column without a weight: " k; fail = 1 }
  exit fail
}
