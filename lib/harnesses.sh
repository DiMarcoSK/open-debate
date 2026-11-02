# harnesses.sh - harness catalog (sourced by bin/open-debate).
# h_load <id> fills:
#   H_ID H_NAME H_BINS  accepted binaries, space separated
#   H_USER              per-user install root
#   H_PROJ              per-project install root, relative to cwd ("." = the project itself)
#   H_SKILLS H_AGENTS H_CMDS  directories relative to the root; empty = does not exist in the harness
#   H_FMT               agent format: opencode claude codex cursor gemini omp droid copilot qwen none
#   H_MODE              native (own agents and command), subagents (entry + agents) or cli (entry + headless)
#   H_INVOKE            how the user calls the debate
#   H_DELEGATE          delegation instruction given to the orchestrator
#   H_MARK              directory whose existence signals the harness, besides the binary
#   H_EVID              ran = actually called; docs = official docs only
HARNESSES="opencode claude codex cursor gemini agy omp pi dsh droid copilot qwen cline"

h_load() {
  H_ID="$1"; H_AGENTS=""; H_CMDS=""; H_SKILLS="skills"; H_FMT="none"; H_MODE="subagents"; H_INVOKE="/debate <idea>"; H_MARK=""; H_EVID="docs"; H_DELEGATE=""
  case "$1" in
    opencode)
      H_NAME="opencode"; H_BINS="opencode"; H_USER="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"; H_PROJ=".opencode"
      H_AGENTS="agents"; H_CMDS="commands"; H_FMT="opencode"; H_MODE="native"; H_EVID="ran" ;;
    claude)
      H_NAME="Claude Code"; H_BINS="claude"; H_USER="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"; H_PROJ=".claude"
      H_AGENTS="agents"; H_FMT="claude"; H_MARK="$H_USER"; H_EVID="ran"
      H_DELEGATE="call the Agent tool with subagent_type set to the specialist's name." ;;
    codex)
      H_NAME="Codex CLI"; H_BINS="codex"; H_USER="$HOME"; H_PROJ="."
      H_SKILLS=".agents/skills"; H_AGENTS=".codex/agents"; H_FMT="codex"; H_INVOKE="\$debate <idea>"; H_MARK="$HOME/.codex"
      H_DELEGATE="spawn a subagent and name the specialist in your request, for example: have debate-arch do <task>." ;;
    cursor)
      H_NAME="Cursor"; H_BINS="cursor-agent agent"; H_USER="$HOME/.cursor"; H_PROJ=".cursor"
      H_AGENTS="agents"; H_FMT="cursor"; H_MARK="$H_USER"
      H_DELEGATE="call the Task tool with the specialist's name." ;;
    gemini)
      H_NAME="Gemini CLI"; H_BINS="gemini"; H_USER="$HOME/.gemini"; H_PROJ=".gemini"
      H_AGENTS="agents"; H_CMDS="commands"; H_FMT="gemini"
      H_DELEGATE="each specialist is exposed as a tool with its own name; call that tool." ;;
    agy)
      H_NAME="Antigravity CLI"; H_BINS="agy"; H_USER="$HOME/.gemini/config"; H_PROJ=".agents"; H_MODE="cli" ;;
    omp)
      H_NAME="oh-my-pi"; H_BINS="omp"; H_USER="${PI_CODING_AGENT_DIR:-$HOME/.omp/agent}"; H_PROJ=".omp"
      H_AGENTS="agents"; H_FMT="omp"; H_INVOKE="/skill:debate <idea>"; H_MARK="$H_USER"; H_EVID="ran"
      H_DELEGATE="call the task tool with agent set to the specialist's name." ;;
    pi)
      H_NAME="Pi"; H_BINS="pi"; H_USER="$HOME/.pi/agent"; H_PROJ=".pi"; H_MODE="cli"; H_INVOKE="/skill:debate <idea>" ;;
    dsh)
      H_NAME="DeepSeek Harness"; H_BINS="dsh"; H_USER="${DSH_HOME:-$HOME/.dsh}"; H_PROJ=".dsh"; H_MODE="cli"; H_MARK="$H_USER" ;;
    droid)
      H_NAME="Factory Droid"; H_BINS="droid"; H_USER="$HOME/.factory"; H_PROJ=".factory"
      H_AGENTS="droids"; H_FMT="droid"; H_MARK="$H_USER"
      H_DELEGATE="call the Task tool with subagent_type set to the specialist's name." ;;
    copilot)
      H_NAME="GitHub Copilot CLI"; H_BINS="copilot"; H_USER="${COPILOT_HOME:-$HOME/.copilot}"; H_PROJ=".github"
      H_AGENTS="agents"; H_FMT="copilot"; H_MARK="$H_USER"
      H_DELEGATE="delegate to the custom agent with the specialist's name." ;;
    qwen)
      H_NAME="Qwen Code"; H_BINS="qwen"; H_USER="$HOME/.qwen"; H_PROJ=".qwen"
      H_AGENTS="agents"; H_CMDS="commands"; H_FMT="qwen"; H_MARK="$H_USER"
      H_DELEGATE="call the task tool with the specialist's name." ;;
    cline)
      H_NAME="Cline"; H_BINS="cline"; H_USER="$HOME/.cline"; H_PROJ=".cline"; H_MODE="cli"; H_MARK="$H_USER" ;;
    *) return 1 ;;
  esac
}

h_bin() { for b in $H_BINS; do if command -v "$b" >/dev/null 2>&1; then printf '%s' "$b"; return 0; fi; done; return 1; }
h_detected() { h_bin >/dev/null || { [ -n "$H_MARK" ] && [ -d "$H_MARK" ]; }; }
detected_list() { for h in $HARNESSES; do h_load "$h"; if h_detected; then printf '%s ' "$h"; fi; done; }
