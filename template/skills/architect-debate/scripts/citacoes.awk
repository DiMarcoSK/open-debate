# citacoes.awk - prova que cada citacao de um ataque existe no arquivo citado. Var: base (raiz do caso).
# Formato: `- Citacao: "<trecho>" (proposals/<agent>.md:<linha>)`. Trecho com ... vale por partes.
# Compara sem caixa, espacos repetidos, crases, asteriscos e barras de tabela. Imprime "FALHA <motivo>" e sai 1.
function norm(s) {
  s = tolower(s); gsub(/[`*|]/, " ", s); gsub(/[[:space:]]+/, " ", s)
  sub(/^ /, "", s); sub(/ $/, "", s); return s
}
function carrega(p,  l, s) {
  if (p in texto) return texto[p]
  s = ""; existe[p] = 0
  while ((getline l < p) > 0) { s = s " " l; existe[p] = 1 }
  close(p); texto[p] = norm(s); return texto[p]
}
function curta(s) { return length(s) > 50 ? substr(s, 1, 50) "..." : s }
tolower($0) ~ /^#+[[:space:]]*veto contra/ {
  alvo = tolower($0); sub(/^#+[[:space:]]*veto contra[[:space:]]*/, "", alvo); gsub(/[`*:]/, "", alvo); sub(/[[:space:]].*/, "", alvo)
  if (alvo !~ /^debate-/) alvo = "debate-" alvo
  next
}
tolower($0) ~ /cita(cao|ção)/ {
  l = $0; gsub(/“|”/, "\"", l)
  a = index(l, "\""); r = substr(l, a + 1); b = 0
  for (i = length(r); i > 0; i--) if (substr(r, i, 1) == "\"") { b = i; break }
  if (a == 0 || b == 0) { print "FALHA citacao sem aspas: " curta(l); falha = 1; n++; next }
  q = substr(r, 1, b - 1); resto = substr(r, b + 1); n++
  p = ""
  if (match(resto, /[A-Za-z0-9_.\/-]+\.md/)) p = substr(resto, RSTART, RLENGTH)
  if (p == "") p = "proposals/" alvo ".md"
  corpo = carrega(base "/" p)
  if (!existe[base "/" p]) { print "FALHA citacao aponta arquivo inexistente: " p; falha = 1; next }
  gsub(/…/, "...", q)
  k = split(q, partes, /\.\.\.+/)
  for (i = 1; i <= k; i++) {
    t = norm(partes[i])
    if (t != "" && index(corpo, t) == 0) { print "FALHA trecho nao existe em " p ": " curta(t); falha = 1 }
  }
}
END {
  if (n == 0) { print "FALHA sem citacao literal: use - Citacao: \"<trecho>\" (proposals/<agent>.md:<linha>)"; falha = 1 }
  exit falha
}
