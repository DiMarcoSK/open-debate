# render.sh - translates the canonical personas (opencode frontmatter) into each harness's format (sourced).

fm_get() { awk -v k="$2" 'NR == 1 { next } /^---$/ { exit } index($0, k ": ") == 1 { print substr($0, length(k) + 3); exit }' "$1"; }
body_of() { awk 'c >= 2 { print } /^---$/ { c++ }' "$1"; }

# Capabilities read from the permission block; `task:` with a map counts as allowed delegation.
cap() {
  awk -v k="$2" '
    NR == 1 { next } /^---$/ { exit }
    /^permission:/ { p = 1; next }
    p && /^[^ ]/ { p = 0 }
    p && $1 == k ":" { print ($2 == "" ? "allow" : $2); exit }' "$1"
}

PORTAVEL='

Portability: if you cannot delegate to debate-scout here, search and open the sources yourself with your web tools. Write only the file named in `writes:`. Never run shell commands.'

claude_tools() {
  t="Read, Glob, Grep"
  [ "$(cap "$1" edit)" = "allow" ] && t="$t, Write, Edit"
  if [ "$(cap "$1" webfetch)" = "allow" ] || [ "$(cap "$1" task)" = "allow" ]; then t="$t, WebSearch, WebFetch"; fi
  printf '%s' "$t"
}

toml_str() { printf '"%s"' "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')"; }

# render_agent <persona> <dest>: writes the agent in the $H_FMT format.
render_agent() {
  a="$(basename "$1" .md)"; d="$(fm_get "$1" description)"
  case "$H_FMT" in
    codex)
      {
        printf 'name = "%s"\ndescription = %s\n# model = "gpt-..."\n' "$a" "$(toml_str "$d")"
        printf "developer_instructions = '''\n"; body_of "$1"; printf '%s\n' "$PORTAVEL"; printf "'''\n"
      } > "$2"
      return ;;
  esac
  {
    printf -- '---\nname: %s\ndescription: %s\n' "$a" "$d"
    case "$H_FMT" in
      # The scout answers 1 factual question, in waves: a fast model there shortens research without touching the decisions.
      claude)
        m=inherit; [ "$a" = "debate-scout" ] && m=haiku
        printf 'tools: %s\nmodel: %s\n' "$(claude_tools "$1")" "$m" ;;
      cursor|droid|qwen) printf 'model: inherit\n' ;;
      gemini) printf 'model: inherit\ntemperature: %s\nmax_turns: 30\n' "$(fm_get "$1" temperature)" ;;
      copilot) printf '# model: <model>\n' ;;
      omp)
        printf '# model: <model>\n'
        [ "$(cap "$1" task)" = "allow" ] && printf 'spawns: debate-scout\n' ;;
    esac
    printf -- '---\n'; body_of "$1"; printf '%s\n' "$PORTAVEL"
  } > "$2"
}

agent_file() { case "$H_FMT" in codex) printf '%s.toml' "$1" ;; copilot) printf '%s.agent.md' "$1" ;; *) printf '%s.md' "$1" ;; esac; }

# Includes a file in place of a {{DELEGATION}} line or span.
incluir_delegacao() {
  awk -v f="$TEMPLATE/entry/delegation.md" 'index($0, "{{DELEGATION}}") { while ((getline l < f) > 0) print l; close(f); next } { print }' "$1"
}
