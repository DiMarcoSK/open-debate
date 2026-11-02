# harness.sh - chamada headless de cada harness (source de debate.sh e probe.sh). Requer TO, SCRIPT_DIR.
# Todo harness recebe a persona dentro do prompt, entao nada precisa estar instalado nele.
# Fora do opencode a chamada e somente leitura: quem grava o arquivo e o debate.sh, a partir do texto devolvido.

h_binario() {
  case "$1" in
    cursor) if command -v cursor-agent >/dev/null 2>&1; then printf cursor-agent; else printf agent; fi ;;
    custom) printf sh ;;
    opencode|claude|codex|gemini|agy|omp|pi|dsh|droid|copilot|qwen|cline) printf '%s' "$1" ;;
    *) return 1 ;;
  esac
}

h_existe() {
  b="$(h_binario "$1")" || { echo "erro: harness desconhecido: $1" >&2; return 2; }
  command -v "$b" >/dev/null 2>&1 || { echo "erro: $b nao encontrado no PATH" >&2; return 2; }
  if [ "$1" = "custom" ] && [ -z "${HARNESS_CMD:-}" ]; then echo "erro: HARNESS=custom exige HARNESS_CMD" >&2; return 2; fi
}

persona() { awk 'c >= 2 { print } /^---$/ { c++ }' "$SCRIPT_DIR/../personas/$1.md"; }

h_prompt() { printf '%s\n\n## Tarefa\n\n%s\n' "$(persona "$1")" "$2"; }

# h_chama: a chamada em si. stdin fechado, porque varios CLIs esperam entrada por pipe e travam.
h_chama() {
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
        exec $TO "$(h_binario cursor)" "$@" "$ta" ;;
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
      *) echo "harness desconhecido: $h" >&2; exit 2 ;;
    esac
  ) < /dev/null > "$ra" 2> "$ra.stderr"
}

# h_run <harness> <agent> <tarefa> <modelo> <dir> <saida-bruta>; stderr vai para <saida-bruta>.stderr
# A chamada fica em funcao propria: em dash, redirecionar um grupo em volta do subshell descarta os redirecionamentos internos.
# O 2>/dev/null aqui cala o aviso do shell quando o alarme do TIMEOUT mata a chamada.
h_run() {
  h="$1"; ag="$2"; ta="$3"; mo="$4"; di="$5"; ra="$6"
  [ "$h" = "opencode" ] || ta="$(h_prompt "$ag" "$ta")"
  h_chama 2>/dev/null
}

# h_texto <harness> <saida-bruta> <destino>: extrai a resposta final.
h_texto() {
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

# Ultima palavra sobre "acabou a cota ou a sessao": cada harness escreve de um jeito.
h_auth_falhou() { grep -qiE 'FreeTierError|Free usage limit|statusCode[^0-9]*40[13]|unauthorized|not logged in|please log ?in|invalid api key|usage limit|rate limit' "$1" "$1.stderr" 2>/dev/null; }
