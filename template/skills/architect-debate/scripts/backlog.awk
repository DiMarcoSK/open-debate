# backlog.awk - reads BACKLOG.md items in the backlog-template.md format.
# mode=check: prints "FAIL <reason>" per problem, exits 1. Vars: tags, specs, adrs, tasks (space-separated lists; task = NN:Txxx).
# mode=tsv: 1 line per item (id phase epic title acceptance origin est days deps tags blocks status).
# mode=summary: items and days per phase, total and critical path through the dependencies.
function days(e) { return e == "S" ? 1 : e == "M" ? 2.5 : e == "L" ? 4.5 : 0 }
function clean(s) { gsub(/\t/, " ", s); sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
function path(id,  n, i, d, v, best, ds) {
  if (state[id] == 2) return total[id]
  if (state[id] == 1) { cycle[id] = 1; return 0 }
  state[id] = 1; best = 0; prev[id] = ""
  n = split(dep[id], ds, " ")
  for (i = 1; i <= n; i++) { d = ds[i]; if (!(d in phase)) continue; v = path(d); if (v > best) { best = v; prev[id] = d } }
  state[id] = 2; total[id] = best + days(est[id]); return total[id]
}
# Capacity: <devs> x <weeks> x 5 x 0.7 = <N> working days; backlog sums <M> days
/^[^|]*Capacity:/ && cap == "" {
  l = $0; sub(/^.*Capacity:/, "", l)
  if (match(l, /=[[:space:]]*[0-9]+([.,][0-9]+)?/)) {
    x = substr(l, RSTART + 1, RLENGTH - 1); gsub(/[[:space:]]/, "", x); gsub(/,/, ".", x); cap = x + 0
    c = substr(l, 1, RSTART - 1); k = split(c, ws, /[[:space:]]*[xX*][[:space:]]*/); pr = 1; countable = (k >= 3)
    for (i = 1; i <= k; i++) { y = ws[i]; gsub(/[[:space:]]/, "", y); if (y !~ /^[0-9]+([.][0-9]+)?$/) countable = 0; else pr *= y }
    if (countable) capmath = pr
  }
  if (match(l, /sums?[[:space:]]+[0-9]+([.,][0-9]+)?/)) { x = substr(l, RSTART, RLENGTH); gsub(/[^0-9.,]/, "", x); gsub(/,/, ".", x); written = x + 0 }
  next
}
/^##[[:space:]]+Phase[[:space:]]/ { f = $0; sub(/^##[[:space:]]+/, "", f); nf++; pname[nf] = f; next }
/^##[[:space:]]+Post-?[[:space:]]?launch/ { f = "Post-launch"; nf++; pname[nf] = f; next }
/^- \[[ xX]\] B[0-9]+/ {
  l = $0; n++
  match(l, /B[0-9]+/); id = substr(l, RSTART, RLENGTH)
  if (id in phase) dup[id] = 1
  order[n] = id; phase[id] = f; done[id] = (l ~ /^- \[[xX]\]/) ? "done" : "open"
  r = substr(l, RSTART + RLENGTH); blocks[id] = (r ~ /^[[:space:]]*\[P\]/) ? "yes" : "no"; sub(/^[[:space:]]*\[P\][[:space:]]*/, "", r)
  meta = ""; if (match(r, /\{[^{}]*\}[[:space:]]*$/)) { meta = substr(r, RSTART + 1, RLENGTH - 2); r = substr(r, 1, RSTART - 1) substr(r, RSTART + RLENGTH) }
  orig[id] = ""; if (match(r, /\([^()]*(spec|ADR-|SDD)[^()]*\)/)) { orig[id] = substr(r, RSTART + 1, RLENGTH - 2); r = substr(r, 1, RSTART - 1) substr(r, RSTART + RLENGTH) }
  ac[id] = ""; if (match(r, /Acceptance:/)) { ac[id] = clean(substr(r, RSTART + 11)); r = substr(r, 1, RSTART - 1) }
  sub(/\[[^]]*\][[:space:]]*$/, "", ac[id]); tit[id] = clean(r); sub(/\.$/, "", tit[id]); ac[id] = clean(ac[id])
  est[id] = ""; dep[id] = ""; tg[id] = ""; ep[id] = ""; indep = 0
  m = split(meta, w, /[[:space:],]+/)
  for (i = 1; i <= m; i++) {
    if (w[i] == "") continue
    if (w[i] ~ /^E[0-9]+$/) { ep[id] = w[i]; indep = 0 }
    else if (tolower(w[i]) == "est") { est[id] = toupper(w[i + 1]); i++; indep = 0 }
    else if (w[i] == "dep") indep = 1
    else if (w[i] ~ /^#/) { tg[id] = tg[id] " " substr(w[i], 2); used[substr(w[i], 2)] = 1; indep = 0 }
    else if (indep && w[i] ~ /^B[0-9]+$/) dep[id] = dep[id] " " w[i]
  }
  dep[id] = clean(dep[id]); tg[id] = clean(tg[id])
  all = all " " orig[id]
}
END {
  if (mode == "tsv") {
    for (i = 1; i <= n; i++) { id = order[i]
      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", id, phase[id], ep[id], tit[id], ac[id], orig[id], est[id], days(est[id]), dep[id], tg[id], blocks[id], done[id] }
    exit 0
  }
  for (i = 1; i <= n; i++) path(order[i])
  if (mode == "summary") {
    for (i = 1; i <= n; i++) { id = order[i]; qf[phase[id]]++; df[phase[id]] += days(est[id]); tot += days(est[id]); if (done[id] == "done") ok++ }
    for (i = 1; i <= nf; i++) if (qf[pname[i]]) printf "%-48s %3d items %6.1f days\n", substr(pname[i], 1, 48), qf[pname[i]], df[pname[i]]
    printf "Total: %d items, %.1f days of work, %d done\n", n, tot, ok
    end = ""; most = 0; for (i = 1; i <= n; i++) if (total[order[i]] > most) { most = total[order[i]]; end = order[i] }
    c = ""; for (x = end; x != ""; x = prev[x]) c = (c == "" ? x : x " -> " c)
    printf "Critical path (%.1f days): %s\n", most, c
    exit 0
  }
  if (n < 15) { print "FAIL only " n " items, minimum 15"; fail = 1 }
  if (nf < 4) { print "FAIL only " nf " phases, expected foundation, walking skeleton, MVP, polish and launch"; fail = 1 }
  for (id in dup) { print "FAIL duplicate id " id; fail = 1 }
  for (i = 1; i <= n; i++) { id = order[i]
    if (ac[id] == "") { print "FAIL " id " without Acceptance"; fail = 1 }
    if (orig[id] == "") { print "FAIL " id " without a source (spec NN:Txxx, ADR-NNNN or SDD-n)"; fail = 1 }
    if (days(est[id]) == 0) { print "FAIL " id " without est S/M/L"; fail = 1 }
    if (tolower(tit[id]) ~ /^(do|build|create|implement|make) (the )?(backend|frontend|screens?|api)$/) { print "FAIL " id " is not a vertical slice: " tit[id]; fail = 1 }
    k = split(dep[id], ds, " "); for (j = 1; j <= k; j++) {
      if (ds[j] == id) { print "FAIL " id " depends on itself"; fail = 1 }
      else if (!(ds[j] in phase)) { print "FAIL " id " depends on missing " ds[j]; fail = 1 } }
    if (id in cycle) { print "FAIL dependency cycle through " id; fail = 1 }
  }
  k = split(tags, ts, " "); for (j = 1; j <= k; j++) if (!(ts[j] in used)) { print "FAIL polish without item #" ts[j]; fail = 1 }
  k = split(specs, ss, " "); for (j = 1; j <= k; j++) if (all !~ ("spec " ss[j])) { print "FAIL spec " ss[j] " has no backlog item"; fail = 1 }
  k = split(adrs, as, " "); for (j = 1; j <= k; j++) if (all !~ ("ADR-" as[j])) { print "FAIL ADR-" as[j] " has no item (its Confirmation becomes an item)"; fail = 1 }
  # Tasks: `spec 01:T001,T002`, `spec 01:T003-T009` and `spec 02:T001 T004`.
  s = all; gsub(/spec /, "spec_", s); nw = split(s, ws, /[[:space:],;]+/); cur = ""
  for (j = 1; j <= nw; j++) {
    x = ws[j]
    if (x ~ /^spec_[0-9][0-9]:/) { cur = substr(x, 6, 2); x = substr(x, 9) }
    if (cur == "" || x !~ /^T[0-9]+(-T?[0-9]+)?$/) continue
    sub(/^T/, "", x); a = x; b = x
    if (index(x, "-")) { a = substr(x, 1, index(x, "-") - 1); b = substr(x, index(x, "-") + 1); sub(/^T/, "", b) }
    for (y = a + 0; y <= b + 0; y++) covered[cur ":" y] = 1
  }
  k = split(tasks, tf, " ")
  for (j = 1; j <= k; j++) { sp = substr(tf[j], 1, 2); y = substr(tf[j], 5) + 0
    if (!((sp ":" y) in covered)) { qt[sp]++; if (qt[sp] <= 4) miss[sp] = miss[sp] " " substr(tf[j], 4) } }
  for (sp in qt) { print "FAIL spec " sp ": " qt[sp] " task(s) without an item:" miss[sp]; fail = 1 }
  # Capacity: the gate does the arithmetic, not the model. Post-launch stays out.
  for (i = 1; i <= n; i++) if (phase[order[i]] != "Post-launch") plan += days(est[order[i]])
  if (cap == "") { print "FAIL no Capacity math: <devs> x <weeks> x 5 x 0.7 = <N> working days; backlog sums <M> days"; fail = 1 }
  else {
    if (capmath != "" && (capmath - cap > 1 || cap - capmath > 1)) { printf "FAIL capacity written as %s, the arithmetic gives %s\n", cap, capmath; fail = 1 }
    if (plan > cap) { printf "FAIL the plan sums %.1f days and capacity is %s: move items to Post-launch\n", plan, cap; fail = 1 }
    if (written != "" && (written - plan > 1 || plan - written > 1)) { printf "FAIL backlog sum written as %s, the items sum %.1f\n", written, plan; fail = 1 }
  }
  exit fail
}
