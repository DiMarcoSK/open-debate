# quotes.awk - proves that every quote in a critique exists in the cited file. Var: base (case root).
# Format: `- Quote: "<excerpt>" (proposals/<agent>.md:<line>)`. An excerpt with ... counts in parts.
# Compares ignoring case, repeated spaces, backticks, asterisks and table bars. Prints "FAIL <reason>" and exits 1.
function norm(s) {
  s = tolower(s); gsub(/[`*|]/, " ", s); gsub(/[[:space:]]+/, " ", s)
  sub(/^ /, "", s); sub(/ $/, "", s); return s
}
function load(p,  l, s) {
  if (p in text) return text[p]
  s = ""; exists[p] = 0
  while ((getline l < p) > 0) { s = s " " l; exists[p] = 1 }
  close(p); text[p] = norm(s); return text[p]
}
function brief(s) { return length(s) > 50 ? substr(s, 1, 50) "..." : s }
tolower($0) ~ /^#+[[:space:]]*veto against/ {
  target = tolower($0); sub(/^#+[[:space:]]*veto against[[:space:]]*/, "", target); gsub(/[`*:]/, "", target); sub(/[[:space:]].*/, "", target)
  if (target !~ /^debate-/) target = "debate-" target
  next
}
tolower($0) ~ /^[-*[:space:]]*quote[*[:space:]]*:/ {
  l = $0; gsub(/“|”/, "\"", l)
  a = index(l, "\""); r = substr(l, a + 1); b = 0
  for (i = length(r); i > 0; i--) if (substr(r, i, 1) == "\"") { b = i; break }
  if (a == 0 || b == 0) { print "FAIL quote without double quotes: " brief(l); fail = 1; n++; next }
  q = substr(r, 1, b - 1); rest = substr(r, b + 1); n++
  p = ""
  if (match(rest, /[A-Za-z0-9_.\/-]+\.md/)) p = substr(rest, RSTART, RLENGTH)
  if (p == "") p = "proposals/" target ".md"
  body = load(base "/" p)
  if (!exists[base "/" p]) { print "FAIL quote points to a missing file: " p; fail = 1; next }
  gsub(/…/, "...", q)
  k = split(q, parts, /\.\.\.+/)
  for (i = 1; i <= k; i++) {
    t = norm(parts[i])
    if (t != "" && index(body, t) == 0) { print "FAIL excerpt not found in " p ": " brief(t); fail = 1 }
  }
}
END {
  if (n == 0) { print "FAIL no literal quote: use - Quote: \"<excerpt>\" (proposals/<agent>.md:<line>)"; fail = 1 }
  exit fail
}
