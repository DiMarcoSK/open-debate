# placar.awk - confere a conta do juiz em decision.md.
# Pesos: linha `criterio=peso criterio=peso ...`, soma 100, escrita antes do 1o placar.
# Placar: tabela com coluna Total; cada coluna de criterio traz a nota 0-5 da opcao e Total = soma(nota x peso).
# Aceita Total na escala 0-5 (soma / 100). Imprime "FALHA <motivo>" e sai 1.
function trim(s) { gsub(/[*`]/, "", s); sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
function chave(s) { s = tolower(trim(s)); sub(/[[:space:]]*[(=:].*$/, "", s); return s }
function num(s) { s = trim(s); sub(/^[^0-9-]+/, "", s); gsub(/,/, ".", s); if (s !~ /^-?[0-9]+(\.[0-9]+)?/) return "x"; return s + 0 }
!np && /[^[:space:]=|]+=[0-9]+/ && !/^\|/ {
  l = $0
  while (match(l, /[^[:space:],;:|]+=[0-9]+/)) {
    t = substr(l, RSTART, RLENGTH); l = substr(l, RSTART + RLENGTH)
    i = index(t, "="); k = tolower(substr(t, 1, i - 1)); p[k] = substr(t, i + 1) + 0; soma += p[k]; c++
  }
  if (c >= 3) np = 1; else { soma = 0; c = 0; split("", p) }
  next
}
/^\|/ {
  n = split($0, w, "|")
  if (!emt) {
    tot = 0; for (i = 2; i < n; i++) { h[i] = chave(w[i]); if (h[i] == "total") tot = i }
    if (tot) { emt = 1; sep = 1; tabelas++; nome = trim(w[2]) }
    next
  }
  if (sep) { sep = 0; next }
  opc = trim(w[2]); soma_l = 0; soma_c = 0
  for (i = 3; i < n; i++) {
    if (i == tot || h[i] == "") continue
    if (!(h[i] in p)) { sem[h[i]] = 1; continue }
    v = num(w[i])
    if (v == "x") { print "FALHA placar sem nota em " opc "/" h[i]; falha = 1; continue }
    if (v < 0 || v > 5) { print "FALHA nota fora de 0-5 em " opc "/" h[i]; falha = 1 }
    soma_l += v * p[h[i]]; soma_c++
  }
  dec = num(w[tot])
  if (dec == "x") { print "FALHA placar sem Total em " opc; falha = 1 }
  else if (soma_c > 0) {
    d1 = dec - soma_l; if (d1 < 0) d1 = -d1
    d2 = dec - soma_l / 100; if (d2 < 0) d2 = -d2
    if (d1 > 0.51 && d2 > 0.011) { nc++; conta[nc] = sprintf("FALHA Total de %s e %s, a conta da %s", opc, dec, soma_l) }
  }
  next
}
{ emt = 0 }
END {
  if (!np) { print "FALHA sem pesos: 1 linha criterio=peso, 3+ criterios"; falha = 1 }
  else if (soma != 100) { print "FALHA pesos somam " soma ", devem somar 100"; falha = 1 }
  else for (i = 1; i <= nc; i++) { print conta[i]; falha = 1 }
  if (tabelas == 0) { print "FALHA sem placar: 1 tabela com coluna Total por decisao disputada"; falha = 1 }
  for (k in sem) { print "FALHA coluna do placar sem peso: " k; falha = 1 }
  exit falha
}
