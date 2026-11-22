# harness.sh - headless call of each harness (sourced by debate.sh, brainstorm.sh and probe.sh). Needs TO, SCRIPT_DIR.
# Every harness gets the persona inside the prompt, so nothing needs to be installed in it.
# Outside opencode the call is read-only: debate.sh writes the file, from the returned text.

# The file comes from the returned text. Without this line, the agent tries to write, gets a permission denial and replies with a permission request.
OUTPUT='OUTPUT: in this run you do not write files: do not use Write or Edit. Your whole final answer is the content of the requested file, with no comment before or after and no code fence around it. Write it in English, whatever the language of the brief.'

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
  # A headless Claude Code call loads the user's MCP servers, skills, hooks, CLAUDE.md and every built-in tool definition,
  # and resends them on every turn. The panel only reads and searches: these flags leave just those tools. --safe-mode
  # also keeps the user's hooks out: a Stop hook that asks for one more turn replaces the answer with its reply.
  # A version without a flag keeps the call without it.
  if [ "$1" = "claude" ] && [ -z "${H_CLAUDE_FLAGS+x}" ]; then
    H_CLAUDE_FLAGS=""; hh="$(claude --help < /dev/null 2>/dev/null || true)"
    case "$hh" in *--tools*) case "$hh" in *--strict-mcp-config*) case "$hh" in *--disable-slash-commands*)
      H_CLAUDE_FLAGS="--tools Read,Glob,Grep,WebSearch,WebFetch --strict-mcp-config --disable-slash-commands" ;; esac ;; esac ;; esac
    case "$hh" in *--safe-mode*) H_CLAUDE_FLAGS="$H_CLAUDE_FLAGS --safe-mode" ;; esac
  fi
  if [ "$1" = "custom" ] && [ -z "${HARNESS_CMD:-}" ]; then echo "error: HARNESS=custom needs HARNESS_CMD" >&2; return 2; fi
}

# persona <agent>: the persona body. A case seat (debate-x-<slug>, made by the agenda) lives in the case, in $OUT/personas.
persona() {
  case "$1" in debate-x-*) pf="${OUT:-.}/personas/$1.md" ;; *) pf="$SCRIPT_DIR/../personas/$1.md" ;; esac
  awk 'c >= 2 { print } /^---$/ { c++ }' "$pf"
}

# h_prompt <agent> <task> [context]: persona, the inlined case files, then the task, last, where the model reads it best.
h_prompt() { printf '%s\n\n%s## Task\n\n%s\n' "$(persona "$1")" "${3:+$3

}" "$2"; }

# h_inline_max <harness>: how many bytes of case files fit in its prompt. An argument is capped at 128 KiB on Linux
# (persona and task included); a harness that reads the prompt on stdin has no such cap, only the model's context.
h_inline_max() { case "$1" in claude) printf 320000 ;; *) printf 96000 ;; esac; }

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
        # shellcheck disable=SC2086
        set -- "$@" ${H_CLAUDE_FLAGS:-}
        [ -z "$mo" ] || set -- "$@" --model "$mo"
        # The prompt goes on stdin: an argument is capped at 128 KiB on Linux, and the inlined case files can pass that.
        # With its files inlined, a call takes 1 turn: a 1-hour cache write (2x the input price) is never read again,
        # a 5-minute one costs 1.25x and still covers every turn of a call that searches the web.
        FORCE_PROMPT_CACHING_5M="${FORCE_PROMPT_CACHING_5M:-1}"; export FORCE_PROMPT_CACHING_5M
        printf '%s' "$ta" | exec $TO claude -p "$@" ;;
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

# h_run <harness> <agent> <task> <model> <dir> <raw-output> [context]; stderr goes to <raw-output>.stderr
# opencode runs its installed agent, which holds the persona; a case seat runs as debate-specialist with its persona in the prompt.
# The call lives in its own function: in dash, redirecting a group around the subshell drops the inner redirections.
# The 2>/dev/null here silences the shell notice when the TIMEOUT alarm kills the call.
h_run() {
  h="$1"; ag="$2"; ta="$3"; mo="$4"; di="$5"; ra="$6"; cx="${7:-}"
  if [ "$h" != "opencode" ]; then ta="$(h_prompt "$ag" "$ta" "$cx")"
  else
    case "$ag" in
      debate-x-*) ta="$(h_prompt "$ag" "$ta" "$cx")"; ag=debate-specialist ;;
      *) [ -z "$cx" ] || ta="$(printf '%s\n\n## Task\n\n%s' "$cx" "$ta")" ;;
    esac
  fi
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

# h_tokens <harness> <raw-output>: "<input> <output>" tokens of the call, cache included in the input; nothing when
# the harness does not report usage in its output (codex, pi, dsh, cline, custom...).
h_tokens() {
  [ -s "$2" ] || return 0
  case "$1" in
    opencode) jq -rs '[.[] | select(.type == "step_finish" or .type == "step-finish") | .part.tokens // empty]
      | if length == 0 then empty else
        [(map((.input // 0) + (.cache.read // 0) + (.cache.write // 0)) | add), (map((.output // 0) + (.reasoning // 0)) | add)] | @tsv end' "$2" ;;
    claude|cursor|droid) jq -r 'select(.usage != null) | .usage
      | [(.input_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0), (.output_tokens // 0)] | @tsv' "$2" ;;
    gemini|agy) jq -r 'select(.stats.models != null) | [.stats.models[] | .tokens // empty]
      | if length == 0 then empty else [(map(.prompt // 0) | add), (map((.candidates // 0) + (.thoughts // 0)) | add)] | @tsv end' "$2" ;;
  esac 2>/dev/null | tr '\t' ' ' | head -1 || true
}

# h_failure <raw-output>: what is left of the output after a failed call. Only the tail: a proposal may talk about rate limits.
h_failure() { { tail -c 2000 "$1" 2>/dev/null; tail -c 2000 "$1.stderr" 2>/dev/null; } | tr -d '\000'; }
# Permanent failure: retrying only wastes time. Every harness words it differently.
h_auth_failed() { h_failure "$1" | grep -qiE 'FreeTierError|Free usage limit|statusCode[^0-9]*40[13]|unauthorized|not logged in|please log ?in|invalid api key|usage limit'; }
# Transient failure: waiting fixes it.
h_limit_failed() { h_failure "$1" | grep -qiE '(^|[^0-9])429([^0-9]|$)|rate.?limit|too many requests|overloaded|resource.?exhausted|try again'; }
