# backlog.awk - le itens de BACKLOG.md no formato de backlog-template.md.
# modo=check: imprime "FALHA <motivo>" por problema, sai 1. Vars: tags, specs, adrs, tarefas (listas separadas por espaco; tarefa = NN:Txxx).
# modo=tsv: 1 linha por item (id fase epico titulo aceite origem est dias deps tags bloqueia status).
# modo=resumo: itens e dias por fase, total e caminho critico pelas dependencias.
function dias(e) { return e == "P" ? 1 : e == "M" ? 2.5 : e == "G" ? 4.5 : 0 }
function limpa(s) { gsub(/\t/, " ", s); sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
function caminho(id,  n, i, d, v, melhor, ds) {
  if (estado[id] == 2) return total[id]
  if (estado[id] == 1) { ciclo[id] = 1; return 0 }
  estado[id] = 1; melhor = 0; prev[id] = ""
  n = split(dep[id], ds, " ")
  for (i = 1; i <= n; i++) { d = ds[i]; if (!(d in fase)) continue; v = caminho(d); if (v > melhor) { melhor = v; prev[id] = d } }
  estado[id] = 2; total[id] = melhor + dias(est[id]); return total[id]
}
# Capacidade: <devs> x <semanas> x 5 x 0.7 = <N> dias uteis; backlog soma <M> dias
/^[^|]*Capacidade:/ && cap == "" {
  l = $0; sub(/^.*Capacidade:/, "", l)
  if (match(l, /=[[:space:]]*[0-9]+([.,][0-9]+)?/)) {
    x = substr(l, RSTART + 1, RLENGTH - 1); gsub(/[[:space:]]/, "", x); gsub(/,/, ".", x); cap = x + 0
    c = substr(l, 1, RSTART - 1); k = split(c, ws, /[[:space:]]*[xX*][[:space:]]*/); pr = 1; contavel = (k >= 3)
    for (i = 1; i <= k; i++) { y = ws[i]; gsub(/[[:space:]]/, "", y); if (y !~ /^[0-9]+([.][0-9]+)?$/) contavel = 0; else pr *= y }
    if (contavel) capconta = pr
  }
  if (match(l, /soma[[:space:]]*[0-9]+([.,][0-9]+)?/)) { x = substr(l, RSTART + 4, RLENGTH - 4); gsub(/[[:space:]]/, "", x); gsub(/,/, ".", x); soma = x + 0 }
  next
}
/^##[[:space:]]+Fase[[:space:]]/ { f = $0; sub(/^##[[:space:]]+/, "", f); nf++; nomef[nf] = f; next }
/^##[[:space:]]+P(o|ó)s/ { f = "Pos-lancamento"; nf++; nomef[nf] = f; next }
/^- \[[ xX]\] B[0-9]+/ {
  l = $0; n++
  match(l, /B[0-9]+/); id = substr(l, RSTART, RLENGTH)
  if (id in fase) dup[id] = 1
  ordem[n] = id; fase[id] = f; feito[id] = (l ~ /^- \[[xX]\]/) ? "feito" : "aberto"
  r = substr(l, RSTART + RLENGTH); bloq[id] = (r ~ /^[[:space:]]*\[P\]/) ? "sim" : "nao"; sub(/^[[:space:]]*\[P\][[:space:]]*/, "", r)
  meta = ""; if (match(r, /\{[^{}]*\}[[:space:]]*$/)) { meta = substr(r, RSTART + 1, RLENGTH - 2); r = substr(r, 1, RSTART - 1) substr(r, RSTART + RLENGTH) }
  orig[id] = ""; if (match(r, /\([^()]*(spec|ADR-|SDD)[^()]*\)/)) { orig[id] = substr(r, RSTART + 1, RLENGTH - 2); r = substr(r, 1, RSTART - 1) substr(r, RSTART + RLENGTH) }
  ac[id] = ""; if (match(r, /Aceite:/)) { ac[id] = limpa(substr(r, RSTART + 7)); r = substr(r, 1, RSTART - 1) }
  sub(/\[[^]]*\][[:space:]]*$/, "", ac[id]); tit[id] = limpa(r); sub(/\.$/, "", tit[id]); ac[id] = limpa(ac[id])
  est[id] = ""; dep[id] = ""; tg[id] = ""; ep[id] = ""; emdep = 0
  m = split(meta, w, /[[:space:],]+/)
  for (i = 1; i <= m; i++) {
    if (w[i] == "") continue
    if (w[i] ~ /^E[0-9]+$/) { ep[id] = w[i]; emdep = 0 }
    else if (w[i] == "est") { est[id] = w[i + 1]; i++; emdep = 0 }
    else if (w[i] == "dep") emdep = 1
    else if (w[i] ~ /^#/) { tg[id] = tg[id] " " substr(w[i], 2); usada[substr(w[i], 2)] = 1; emdep = 0 }
    else if (emdep && w[i] ~ /^B[0-9]+$/) dep[id] = dep[id] " " w[i]
  }
  dep[id] = limpa(dep[id]); tg[id] = limpa(tg[id])
  todo = todo " " orig[id]
}
END {
  if (modo == "tsv") {
    for (i = 1; i <= n; i++) { id = ordem[i]
      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", id, fase[id], ep[id], tit[id], ac[id], orig[id], est[id], dias(est[id]), dep[id], tg[id], bloq[id], feito[id] }
    exit 0
  }
  for (i = 1; i <= n; i++) caminho(ordem[i])
  if (modo == "resumo") {
    for (i = 1; i <= n; i++) { id = ordem[i]; qf[fase[id]]++; df[fase[id]] += dias(est[id]); tot += dias(est[id]); if (feito[id] == "feito") ok++ }
    for (i = 1; i <= nf; i++) if (qf[nomef[i]]) printf "%-48s %3d itens %6.1f dias\n", substr(nomef[i], 1, 48), qf[nomef[i]], df[nomef[i]]
    printf "Total: %d itens, %.1f dias de trabalho, %d feitos\n", n, tot, ok
    fim = ""; maior = 0; for (i = 1; i <= n; i++) if (total[ordem[i]] > maior) { maior = total[ordem[i]]; fim = ordem[i] }
    c = ""; for (x = fim; x != ""; x = prev[x]) c = (c == "" ? x : x " -> " c)
    printf "Caminho critico (%.1f dias): %s\n", maior, c
    exit 0
  }
  if (n < 15) { print "FALHA so " n " itens, minimo 15"; falha = 1 }
  if (nf < 4) { print "FALHA so " nf " fases, esperado fundacao, esqueleto, MVP, lapidacao e lancamento"; falha = 1 }
  for (id in dup) { print "FALHA id duplicado " id; falha = 1 }
  for (i = 1; i <= n; i++) { id = ordem[i]
    if (ac[id] == "") { print "FALHA " id " sem Aceite"; falha = 1 }
    if (orig[id] == "") { print "FALHA " id " sem origem (spec NN:Txxx, ADR-NNNN ou SDD-n)"; falha = 1 }
    if (dias(est[id]) == 0) { print "FALHA " id " sem est P/M/G"; falha = 1 }
    if (tit[id] ~ /^(fazer|criar|implementar) (o |a )?(backend|frontend|telas?|api)$/) { print "FALHA " id " nao e fatia vertical: " tit[id]; falha = 1 }
    k = split(dep[id], ds, " "); for (j = 1; j <= k; j++) {
      if (ds[j] == id) { print "FALHA " id " depende de si"; falha = 1 }
      else if (!(ds[j] in fase)) { print "FALHA " id " depende de " ds[j] " inexistente"; falha = 1 } }
    if (id in ciclo) { print "FALHA ciclo de dependencia passando por " id; falha = 1 }
  }
  k = split(tags, ts, " "); for (j = 1; j <= k; j++) if (!(ts[j] in usada)) { print "FALHA lapidacao sem item #" ts[j]; falha = 1 }
  k = split(specs, ss, " "); for (j = 1; j <= k; j++) if (todo !~ ("spec " ss[j])) { print "FALHA spec " ss[j] " sem item no backlog"; falha = 1 }
  k = split(adrs, as, " "); for (j = 1; j <= k; j++) if (todo !~ ("ADR-" as[j])) { print "FALHA ADR-" as[j] " sem item (Confirmacao vira item)"; falha = 1 }
  # Tarefas: `spec 01:T001,T002`, `spec 01:T003-T009` e `spec 02:T001 T004`.
  s = todo; gsub(/spec /, "spec_", s); nw = split(s, ws, /[[:space:],;]+/); cur = ""
  for (j = 1; j <= nw; j++) {
    x = ws[j]
    if (x ~ /^spec_[0-9][0-9]:/) { cur = substr(x, 6, 2); x = substr(x, 9) }
    if (cur == "" || x !~ /^T[0-9]+(-T?[0-9]+)?$/) continue
    sub(/^T/, "", x); a = x; b = x
    if (index(x, "-")) { a = substr(x, 1, index(x, "-") - 1); b = substr(x, index(x, "-") + 1); sub(/^T/, "", b) }
    for (y = a + 0; y <= b + 0; y++) coberta[cur ":" y] = 1
  }
  k = split(tarefas, tf, " ")
  for (j = 1; j <= k; j++) { sp = substr(tf[j], 1, 2); y = substr(tf[j], 5) + 0
    if (!((sp ":" y) in coberta)) { qt[sp]++; if (qt[sp] <= 4) lista[sp] = lista[sp] " " substr(tf[j], 4) } }
  for (sp in qt) { print "FALHA spec " sp ": " qt[sp] " tarefa(s) sem item:" lista[sp]; falha = 1 }
  # Capacidade: a conta e do gate, nao do modelo. Pos-lancamento fica fora.
  for (i = 1; i <= n; i++) if (fase[ordem[i]] != "Pos-lancamento") plano += dias(est[ordem[i]])
  if (cap == "") { print "FALHA sem conta de Capacidade: <devs> x <semanas> x 5 x 0.7 = <N> dias uteis; backlog soma <M> dias"; falha = 1 }
  else {
    if (capconta != "" && (capconta - cap > 1 || cap - capconta > 1)) { printf "FALHA capacidade escrita %s, a conta da %s\n", cap, capconta; falha = 1 }
    if (plano > cap) { printf "FALHA plano soma %.1f dias e a capacidade e %s: mova itens para Pos-lancamento\n", plano, cap; falha = 1 }
    if (soma != "" && (soma - plano > 1 || plano - soma > 1)) { printf "FALHA backlog soma escrito %s, os itens somam %.1f\n", soma, plano; falha = 1 }
  }
  exit falha
}
