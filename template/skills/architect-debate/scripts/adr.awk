# adr.awk - reads MADR files (adr/NNNN-*.md, or the ADR blocks of decision.md), whatever the heading level.
# 1 line per ADR: id, title, status, chosen, the other options (separated by "; "), because, bad, dissent, context,
# confirmation, separated by tabs. A field the ADR lacks is empty.
function clean(s) { gsub(/\t/, " ", s); gsub(/[*`]/, "", s); sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
function flush(   i, o, r) {
  if (id == "") return
  r = ""
  for (i = 1; i <= no; i++) { o = opt[i]; if (o != chosen) r = r (r == "" ? "" : "; ") o }
  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", id, title, status, chosen, r, because, bad, dissent, ctx, conf
  id = ""
}
/^#+[[:space:]]*ADR-[0-9]+/ {
  flush()
  h = $0; sub(/^#+[[:space:]]*/, "", h); match(h, /^ADR-[0-9]+/); id = substr(h, 1, RLENGTH)
  title = clean(substr(h, RLENGTH + 1)); sub(/^[:.-][[:space:]]*/, "", title)
  status = chosen = because = bad = dissent = ctx = conf = ""; no = 0; sec = ""; next
}
id != "" && /^#/ { s = tolower($0); sub(/^#+[[:space:]]*/, "", s); sec = s
  if (s !~ /^(context|considered|decision|consequences|dissent|confirmation|pros|decision drivers)/) { if (s ~ /^[0-9]/) { flush(); next } }
  next }
id == "" { next }
/^- Status:/ { status = clean(substr($0, 11)); next }
sec ~ /^context/ && ctx == "" && NF { ctx = clean($0); next }
sec ~ /^considered/ && /^- / { opt[++no] = clean(substr($0, 3)); next }
sec ~ /^decision outcome/ && /Chosen:/ {
  l = $0; sub(/^.*Chosen:[[:space:]]*/, "", l)
  if (match(l, /^"[^"]*"/)) { chosen = substr(l, 2, RLENGTH - 2); l = substr(l, RLENGTH + 1) }
  else { chosen = l; sub(/,.*/, "", chosen) }
  chosen = clean(chosen); sub(/^[,[:space:]]*(because[[:space:]]*)?/, "", l); because = clean(l); sub(/\.$/, "", because); next
}
sec ~ /^consequences/ && /^- Bad:/ && bad == "" { bad = clean(substr($0, 7)); next }
sec ~ /^confirmation/ && conf == "" && NF { conf = clean($0); next }
sec ~ /^dissent/ && dissent == "" && NF { dissent = clean($0); if (tolower(dissent) ~ /^none\.?$/) dissent = "none"; next }
END { flush() }
