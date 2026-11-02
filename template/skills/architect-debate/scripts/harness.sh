# harness.sh - headless call of each harness (sourced by debate.sh and probe.sh). Needs TO, SCRIPT_DIR.
# Every harness gets the persona inside the prompt, so nothing needs to be installed in it.
# Outside opencode the call is read-only: debate.sh writes the file, from the returned text.

h_binary() {
  case "$1" in
    cursor) if command -v cursor-agent >/dev/null 2>&1; then printf cursor-agent; else printf agent; fi ;;
    custom) printf sh ;;
    opencode|claude|codex|gemini|agy|omp|pi|dsh|droid|copilot|qwen|cline) printf '%s' "$1" ;;
    *) return 1 ;;
  esac
}

h_exists() {
  b="$(h_binary "$1")" || { echo "error: unknown harness: $1" >&2; return 2; }
  command -v "$b" >/dev/null 2>&1 || { echo "error: $b not found on PATH" >&2; return 2; }
  if [ "$1" = "custom" ] && [ -z "${HARNESS_CMD:-}" ]; then echo "error: HARNESS=custom needs HARNESS_CMD" >&2; return 2; fi
}

persona() { awk 'c >= 2 { print } /^---$/ { c++ }' "$SCRIPT_DIR/../personas/$1.md"; }

h_prompt() { printf '%s\n\n## Task\n\n%s\n' "$(persona "$1")" "$2"; }

# h_call: the call itself. stdin closed, because several CLIs wait for piped input and hang.
h_call() {
  (
    cd "$di"
    case "$h" in
      opencode)
        set -- --agent "$ag" --format json --dir "$di"
        [ -z "$mo" ] || set -- "$@" -m "$mo"
        exec $TO opencode run --print-logs --log-level ERROR "$@" "$ta" ;;
      claude)
        set -- --output-format json --allowedTools "Read,Glob,Grep,WebSearch,WebFetch"
        [ -z "$mo" ] || set -- "$@" --model "$mo"
        exec $TO claude -p "$ta" "$@" ;;
      codex)
        set -- --skip-git-repo-check --sandbox read-only -c web_search=live -o "$ra.fim"
        [ -z "$mo" ] || set -- "$@" -m "$mo"
        exec $TO codex exec "$@" "$ta" ;;
      cursor)
        set -- -p --output-format json
        [ -z "$mo" ] || set -- "$@" --model "$mo"
        exec $TO "$(h_binary cursor)" "$@" "$ta" ;;
      gemini)
        set -- --output-format json --approval-mode plan
        [ -z "$mo" ] || set -- "$@" -m "$mo"
        exec $TO gemini "$@" -p "$ta" ;;
      agy)
        set -- --output-format json --print-timeout "${TIMEOUT}s"
        [ -z "$mo" ] || set -- "$@" --model "$mo"
        exec $TO agy "$@" -p "$ta" ;;
      omp)
        set -- -p --no-session --tools read,grep,glob,web_search
        [ -z "$mo" ] || set -- "$@" --model "$mo"
        exec $TO omp "$@" "$ta" ;;
      pi)
        set -- -p --no-session
        [ -z "$mo" ] || set -- "$@" --model "$mo"
        exec $TO pi "$@" "$ta" ;;
      dsh) exec $TO dsh --profile headless --approval-policy never "$ta" ;;
      droid)
        set -- -o json --cwd "$di"
        [ -z "$mo" ] || set -- "$@" -m "$mo"
        exec $TO droid exec "$@" "$ta" ;;
      copilot)
        set -- -s --allow-tool read --allow-tool url
        [ -z "$mo" ] || set -- "$@" --model "$mo"
        exec $TO copilot "$@" -p "$ta" ;;
      qwen)
        set -- -o json --approval-mode plan
        [ -z "$mo" ] || set -- "$@" -m "$mo"
        exec $TO qwen "$@" -p "$ta" ;;
      cline)
        set -- -p -c "$di"
        [ -z "$mo" ] || set -- "$@" -m "$mo"
        exec $TO cline "$@" "$ta" ;;
      custom) PROMPT="$ta" MODEL="$mo" exec $TO sh -c "$HARNESS_CMD" ;;
      *) echo "unknown harness: $h" >&2; exit 2 ;;
    esac
  ) < /dev/null > "$ra" 2> "$ra.stderr"
}

# h_run <harness> <agent> <task> <model> <dir> <raw-output>; stderr goes to <raw-output>.stderr
# The call lives in its own function: in dash, redirecting a group around the subshell drops the inner redirections.
# The 2>/dev/null here silences the shell notice when the TIMEOUT alarm kills the call.
h_run() {
  h="$1"; ag="$2"; ta="$3"; mo="$4"; di="$5"; ra="$6"
  [ "$h" = "opencode" ] || ta="$(h_prompt "$ag" "$ta")"
  h_call 2>/dev/null
}

# h_text <harness> <raw-output> <dest>: extracts the final answer.
h_text() {
  case "$1" in
    opencode)
      jq -r 'select(.type == "text") | .part.text // empty' "$2" > "$3" 2>/dev/null || true
      [ -s "$3" ] && return 0
      jq -r '.text // empty' "$2" > "$3" 2>/dev/null || true
      [ -s "$3" ] && return 0
      jq -r '.. | .text? // empty' "$2" > "$3" 2>/dev/null || true ;;
    claude|cursor|droid) jq -r 'select(.is_error != true) | .result // empty' "$2" > "$3" 2>/dev/null || true ;;
    gemini|agy) jq -r '.response // empty' "$2" > "$3" 2>/dev/null || true ;;
    qwen) jq -r '.[-1].result // empty' "$2" > "$3" 2>/dev/null || true ;;
    codex) cat "$2.fim" > "$3" 2>/dev/null || true; rm -f "$2.fim" ;;
    *) cat "$2" > "$3" ;;
  esac
  [ -s "$3" ]
}

# h_failure <raw-output>: what is left of the output after a failed call. Only the tail: a proposal may talk about rate limits.
h_failure() { { tail -c 2000 "$1" 2>/dev/null; tail -c 2000 "$1.stderr" 2>/dev/null; } | tr -d '\000'; }
# Permanent failure: retrying only wastes time. Every harness words it differently.
h_auth_failed() { h_failure "$1" | grep -qiE 'FreeTierError|Free usage limit|statusCode[^0-9]*40[13]|unauthorized|not logged in|please log ?in|invalid api key|usage limit'; }
# Transient failure: waiting fixes it.
h_limit_failed() { h_failure "$1" | grep -qiE '(^|[^0-9])429([^0-9]|$)|rate.?limit|too many requests|overloaded|resource.?exhausted|try again'; }
