#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# GSR Config — Configuration utility
# Usage: gsr-config.sh <command> [args]
#
# Commands:
#   ensure                      Create config.json if absent (from defaults)
#   scan                        Scan environment (jq, git CLI, MCP, auth)
#   get <key.path>              Get value (stdout) — requires jq
#   set <key.path> <value>      Set value in config.json — requires jq
#   dump <section>              Dump section as key=value pairs (1 call)
#   resolve-model <agent-name>  Effective model (profile + overrides)
#   profile                     Active profile name
#   config-mode                 "jq" or "claude"
# =============================================================================

# --- Resolve paths relative to project root ---
# Walk up from script location or cwd to find .claude/gsr/
find_project_root() {
  local dir="${1:-.}"
  dir=$(cd "$dir" && pwd)
  while [ "$dir" != "/" ]; do
    if [ -d "$dir/.claude/gsr" ]; then
      echo "$dir"
      return 0
    fi
    dir=$(dirname "$dir")
  done
  # Fallback: cwd
  echo "$(pwd)"
}

PROJECT_ROOT=$(find_project_root)
CONFIG_DIR="${PROJECT_ROOT}/.claude/gsr"
CONFIG_PATH="${CONFIG_DIR}/config.json"
DEFAULTS_PATH="${CONFIG_DIR}/config-defaults.json"
AGENTS_DIR="${PROJECT_ROOT}/.claude/agents/gsr"

# --- Colors ---
if [[ -t 1 ]]; then
  C_RESET='\033[0m'; C_GREEN='\033[0;32m'; C_YELLOW='\033[0;33m'
  C_RED='\033[0;31m'; C_BLUE='\033[0;34m'
else
  C_RESET=''; C_GREEN=''; C_YELLOW=''; C_RED=''; C_BLUE=''
fi

info()  { echo -e "${C_BLUE}[config]${C_RESET} $*"; }
ok()    { echo -e "${C_GREEN}[config]${C_RESET} $*"; }
warn()  { echo -e "${C_YELLOW}[config]${C_RESET} $*" >&2; }
err()   { echo -e "${C_RED}[config]${C_RESET} $*" >&2; }

# --- jq detection ---
has_jq() { command -v jq &>/dev/null; }

# =============================================================================
# Model profiles — hardcoded (profiles are a convention, not user config)
# =============================================================================

# Profile → role → model
# Format: PROFILE_<NAME>_<ROLE>=model
PROFILE_quality_orchestrator=opus
PROFILE_quality_worker=opus
PROFILE_quality_generator=sonnet

PROFILE_balanced_orchestrator=opus
PROFILE_balanced_worker=sonnet
PROFILE_balanced_generator=sonnet

PROFILE_budget_orchestrator=sonnet
PROFILE_budget_worker=sonnet
PROFILE_budget_generator=haiku

# Agent → role mapping
agent_to_role() {
  case "$1" in
    gsr-planner)          echo "orchestrator" ;;
    gsr-analyst)          echo "worker" ;;
    gsr-synthesizer)      echo "worker" ;;
    research-prompt-agent) echo "worker" ;;
    gsr-generator)        echo "generator" ;;
    gsr-bootstrapper)     echo "generator" ;;
    *) err "Unknown agent: $1"; return 1 ;;
  esac
}

# Resolve profile + role → model
profile_role_to_model() {
  local profile="$1" role="$2"
  local var="PROFILE_${profile}_${role}"
  echo "${!var:-sonnet}"
}

# All known agents
ALL_AGENTS="gsr-planner gsr-analyst gsr-synthesizer research-prompt-agent gsr-generator gsr-bootstrapper"

# Valid profiles
VALID_PROFILES="quality balanced budget"

# =============================================================================
# Commands
# =============================================================================

# --- config-mode ---
cmd_config_mode() {
  if has_jq; then
    echo "jq"
  else
    echo "claude"
  fi
}

# --- ensure ---
cmd_ensure() {
  if [ ! -f "$CONFIG_PATH" ]; then
    if [ ! -f "$DEFAULTS_PATH" ]; then
      err "Defaults file not found: $DEFAULTS_PATH"
      return 1
    fi
    cp "$DEFAULTS_PATH" "$CONFIG_PATH"
    ok "Created config.json from defaults"
  fi
}

# --- scan ---
cmd_scan() {
  cmd_ensure

  local jq_available="false"
  local config_mode="claude"
  local git_cli="null"
  local git_cli_authenticated="false"
  local git_mcp="null"
  local git_mcp_authenticated="false"
  local git_provider="null"

  # 1. jq
  if has_jq; then
    jq_available="true"
    config_mode="jq"
  fi

  # 2. Git CLI — gh
  if command -v gh &>/dev/null; then
    git_cli="gh"
    git_provider="github"
    if gh auth status &>/dev/null 2>&1; then
      git_cli_authenticated="true"
    fi
  # 2b. Git CLI — glab
  elif command -v glab &>/dev/null; then
    git_cli="glab"
    git_provider="gitlab"
    if glab auth status &>/dev/null 2>&1; then
      git_cli_authenticated="true"
    fi
  fi

  # 3. MCP — scan settings files for github/gitlab MCP servers
  local settings_files=()
  [ -f "${PROJECT_ROOT}/.claude/settings.json" ] && settings_files+=("${PROJECT_ROOT}/.claude/settings.json")
  [ -f "${HOME}/.claude/settings.json" ] && settings_files+=("${HOME}/.claude/settings.json")

  for sf in "${settings_files[@]}"; do
    if has_jq; then
      # Look for MCP server keys containing "github" or "gitlab"
      local mcp_keys
      mcp_keys=$(jq -r '(.mcpServers // {}) | keys[]' "$sf" 2>/dev/null || true)
      for key in $mcp_keys; do
        if echo "$key" | grep -qi "github"; then
          git_mcp="github"
          git_mcp_authenticated="true"
          [ "$git_provider" = "null" ] && git_provider="github"
        elif echo "$key" | grep -qi "gitlab"; then
          git_mcp="gitlab"
          git_mcp_authenticated="true"
          [ "$git_provider" = "null" ] && git_provider="gitlab"
        fi
      done
    else
      # Fallback: grep for github/gitlab in settings
      if grep -qi '"github"' "$sf" 2>/dev/null; then
        git_mcp="github"
        git_mcp_authenticated="true"
        [ "$git_provider" = "null" ] && git_provider="github"
      elif grep -qi '"gitlab"' "$sf" 2>/dev/null; then
        git_mcp="gitlab"
        git_mcp_authenticated="true"
        [ "$git_provider" = "null" ] && git_provider="gitlab"
      fi
    fi
  done

  # 4. Write to config.json
  if has_jq; then
    local tmp="${CONFIG_PATH}.tmp"
    jq --arg jq_available "$jq_available" \
       --arg config_mode "$config_mode" \
       --arg git_cli "$git_cli" \
       --argjson git_cli_auth "$git_cli_authenticated" \
       --arg git_mcp "$git_mcp" \
       --argjson git_mcp_auth "$git_mcp_authenticated" \
       --arg git_provider "$git_provider" \
       '.environment = {
          jq_available: ($jq_available == "true"),
          config_mode: $config_mode,
          git_cli: (if $git_cli == "null" then null else $git_cli end),
          git_cli_authenticated: $git_cli_auth,
          git_mcp: (if $git_mcp == "null" then null else $git_mcp end),
          git_mcp_authenticated: $git_mcp_auth,
          git_provider: (if $git_provider == "null" then null else $git_provider end)
        }' "$CONFIG_PATH" > "$tmp" && mv "$tmp" "$CONFIG_PATH"
  else
    # Fallback: sed-based replacement on formatted JSON
    # Replace the environment block using python if available, or basic sed
    if command -v python3 &>/dev/null; then
      python3 -c "
import json, sys
with open('$CONFIG_PATH', 'r') as f:
    cfg = json.load(f)
cfg['environment'] = {
    'jq_available': $jq_available == 'true',
    'config_mode': '$config_mode',
    'git_cli': None if '$git_cli' == 'null' else '$git_cli',
    'git_cli_authenticated': $git_cli_authenticated == 'true',
    'git_mcp': None if '$git_mcp' == 'null' else '$git_mcp',
    'git_mcp_authenticated': $git_mcp_authenticated == 'true',
    'git_provider': None if '$git_provider' == 'null' else '$git_provider'
}
with open('$CONFIG_PATH', 'w') as f:
    json.dump(cfg, f, indent=2)
    f.write('\n')
" 2>/dev/null
    else
      warn "Neither jq nor python3 available — environment scan results not saved"
      warn "Config will be managed by Claude Code (Read/Write tools)"
    fi
  fi

  # 5. Display results
  echo ""
  info "Environment scan results:"
  echo ""

  if [ "$jq_available" = "true" ]; then
    ok "jq: available (config mode: jq)"
  else
    warn "jq: not found (config mode: claude — use Claude Code Read/Write)"
    echo "    Install: https://jqlang.github.io/jq/download/"
  fi

  if [ "$git_cli" != "null" ]; then
    if [ "$git_cli_authenticated" = "true" ]; then
      ok "Git CLI: $git_cli (authenticated)"
    else
      warn "Git CLI: $git_cli (not authenticated — run '$git_cli auth login')"
    fi
  else
    info "Git CLI: not found (gh/glab)"
  fi

  if [ "$git_mcp" != "null" ]; then
    ok "Git MCP: $git_mcp (detected in settings)"
  else
    info "Git MCP: not detected"
  fi

  if [ "$git_provider" != "null" ]; then
    ok "Provider: $git_provider"
  else
    info "Provider: not detected"
  fi

  echo ""
}

# --- get ---
cmd_get() {
  local key="$1"
  if ! has_jq; then
    err "jq required for 'get'. Use Claude Code Read tool on $CONFIG_PATH instead."
    return 1
  fi
  if [ ! -f "$CONFIG_PATH" ]; then
    err "Config not found. Run 'gsr-config.sh ensure' first."
    return 1
  fi
  jq -r ".$key // empty" "$CONFIG_PATH"
}

# --- set ---
cmd_set() {
  local key="$1"
  local value="$2"
  if ! has_jq; then
    err "jq required for 'set'. Use Claude Code Write tool on $CONFIG_PATH instead."
    return 1
  fi
  if [ ! -f "$CONFIG_PATH" ]; then
    err "Config not found. Run 'gsr-config.sh ensure' first."
    return 1
  fi

  # Validate known constrained values
  case "$key" in
    models.active_profile)
      if ! echo "$VALID_PROFILES" | grep -qw "$value"; then
        err "Invalid profile: '$value'. Valid: $VALID_PROFILES"
        return 1
      fi
      ;;
    workflow.mode)
      if [[ "$value" != "interactive" && "$value" != "yolo" ]]; then
        err "Invalid mode: '$value'. Valid: interactive, yolo"
        return 1
      fi
      ;;
    workflow.granularity)
      if [[ "$value" != "fine" && "$value" != "standard" && "$value" != "flexible" ]]; then
        err "Invalid granularity: '$value'. Valid: fine, standard, flexible"
        return 1
      fi
      ;;
    git.branching_strategy)
      if [[ "$value" != "none" && "$value" != "phase" && "$value" != "story" ]]; then
        err "Invalid branching strategy: '$value'. Valid: none, phase, story"
        return 1
      fi
      ;;
  esac

  local tmp="${CONFIG_PATH}.tmp"
  # Detect value type: boolean, number, or string
  if [[ "$value" == "true" || "$value" == "false" ]]; then
    jq ".$key = $value" "$CONFIG_PATH" > "$tmp" && mv "$tmp" "$CONFIG_PATH"
  elif [[ "$value" =~ ^[0-9]+$ ]]; then
    jq ".$key = $value" "$CONFIG_PATH" > "$tmp" && mv "$tmp" "$CONFIG_PATH"
  else
    jq --arg v "$value" ".$key = \$v" "$CONFIG_PATH" > "$tmp" && mv "$tmp" "$CONFIG_PATH"
  fi
}

# --- profile ---
cmd_profile() {
  if [ ! -f "$CONFIG_PATH" ]; then
    echo "balanced"
    return
  fi
  if has_jq; then
    local p
    p=$(jq -r '.models.active_profile // "balanced"' "$CONFIG_PATH")
    echo "$p"
  else
    # Fallback: grep
    local p
    p=$(grep -o '"active_profile"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_PATH" 2>/dev/null \
        | head -1 | sed 's/.*: *"//;s/"//')
    echo "${p:-balanced}"
  fi
}

# --- resolve-model ---
cmd_resolve_model() {
  local agent="$1"

  # Validate agent name
  if ! echo "$ALL_AGENTS" | grep -qw "$agent"; then
    err "Unknown agent: '$agent'. Known: $ALL_AGENTS"
    return 1
  fi

  # 1. Check overrides
  if [ -f "$CONFIG_PATH" ] && has_jq; then
    local override
    override=$(jq -r ".models.overrides[\"$agent\"] // empty" "$CONFIG_PATH" 2>/dev/null)
    if [ -n "$override" ]; then
      echo "$override"
      return
    fi
  fi

  # 2. Resolve via profile + role
  local profile
  profile=$(cmd_profile)
  local role
  role=$(agent_to_role "$agent")
  profile_role_to_model "$profile" "$role"
}

# --- dump ---
cmd_dump() {
  local section="$1"
  if [ ! -f "$CONFIG_PATH" ]; then
    err "Config not found. Run 'gsr-config.sh ensure' first."
    return 1
  fi

  case "$section" in
    discovery)
      if has_jq; then
        jq -r '
          "mode=" + (.workflow.mode // "interactive"),
          "max_questions_per_phase=" + ((.workflow.discovery.max_questions_per_phase // 5) | tostring),
          "max_returns_per_phase=" + ((.workflow.discovery.max_returns_per_phase // 3) | tostring),
          "max_interview_exchanges=" + ((.workflow.discovery.max_interview_exchanges // 30) | tostring),
          "timeout_minutes=" + ((.workflow.discovery.timeout_minutes // 45) | tostring),
          "research_enabled=" + ((.workflow.research.enabled // true) | tostring),
          "max_deep_research=" + ((.workflow.research.max_deep // 3) | tostring),
          "max_quick_research=" + ((.workflow.research.max_quick // 5) | tostring)
        ' "$CONFIG_PATH"
      else
        _dump_fallback_discovery
      fi
      ;;

    plan)
      if has_jq; then
        jq -r '
          "granularity=" + (.workflow.granularity // "flexible"),
          "max_stories_per_epic=" + ((.workflow.plan.max_stories_per_epic // 6) | tostring),
          "max_phases_per_story=" + ((.workflow.plan.max_phases_per_story // 8) | tostring),
          "max_epics=" + ((.workflow.plan.max_epics // 10) | tostring),
          "max_review_cycles=" + ((.workflow.plan.max_review_cycles // 3) | tostring),
          "timeout_minutes=" + ((.workflow.plan.timeout_minutes // 30) | tostring),
          "research_enabled=" + ((.workflow.research.enabled // true) | tostring),
          "max_deep_research=" + ((.workflow.research.max_deep // 3) | tostring),
          "max_quick_research=" + ((.workflow.research.max_quick // 5) | tostring)
        ' "$CONFIG_PATH"
      else
        _dump_fallback_plan
      fi
      ;;

    models)
      local profile
      profile=$(cmd_profile)
      echo "active_profile=$profile"
      for agent in $ALL_AGENTS; do
        local model
        model=$(cmd_resolve_model "$agent")
        echo "${agent}=$model"
      done
      ;;

    git)
      if has_jq; then
        jq -r '
          "provider=" + (.environment.git_provider // "unknown"),
          "branching_strategy=" + (.git.branching_strategy // "none"),
          "branch_template_phase=" + (.git.branch_templates.phase // "gsr/phase-{phase}-{slug}"),
          "branch_template_story=" + (.git.branch_templates.story // "gsr/{epic}-{story}"),
          "conventional_commits=" + ((.git.conventional_commits // true) | tostring),
          "git_cli=" + (.environment.git_cli // "none"),
          "git_cli_authenticated=" + ((.environment.git_cli_authenticated // false) | tostring),
          "git_mcp=" + (.environment.git_mcp // "none"),
          "git_mcp_authenticated=" + ((.environment.git_mcp_authenticated // false) | tostring)
        ' "$CONFIG_PATH"
      else
        _dump_fallback_git
      fi
      ;;

    output)
      if has_jq; then
        jq -r '
          "claude_md_max_lines=" + ((.output.claude_md_max_lines // 60) | tostring),
          "spec_format=" + (.output.spec_format // "lean"),
          "plan_format=" + (.output.plan_format // "xml")
        ' "$CONFIG_PATH"
      else
        _dump_fallback_output
      fi
      ;;

    environment)
      if has_jq; then
        jq -r '
          "jq_available=" + ((.environment.jq_available // false) | tostring),
          "config_mode=" + (.environment.config_mode // "claude"),
          "git_cli=" + (.environment.git_cli // "none"),
          "git_cli_authenticated=" + ((.environment.git_cli_authenticated // false) | tostring),
          "git_mcp=" + (.environment.git_mcp // "none"),
          "git_mcp_authenticated=" + ((.environment.git_mcp_authenticated // false) | tostring),
          "git_provider=" + (.environment.git_provider // "unknown")
        ' "$CONFIG_PATH"
      else
        _dump_fallback_environment
      fi
      ;;

    *)
      err "Unknown section: '$section'"
      echo "Valid sections: discovery, plan, models, git, output, environment" >&2
      return 1
      ;;
  esac
}

# --- Fallback dump functions (no jq) ---
# Parse formatted JSON with grep/sed — works on pretty-printed JSON only

_grep_json_string() {
  local key="$1"
  grep -o "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$CONFIG_PATH" 2>/dev/null \
    | head -1 | sed 's/.*: *"//;s/"//'
}

_grep_json_value() {
  local key="$1"
  grep -o "\"$key\"[[:space:]]*:[[:space:]]*[^,}]*" "$CONFIG_PATH" 2>/dev/null \
    | head -1 | sed 's/.*: *//' | tr -d ' '
}

_dump_fallback_discovery() {
  echo "mode=$(_grep_json_string "mode" || echo "interactive")"
  echo "max_questions_per_phase=$(_grep_json_value "max_questions_per_phase" || echo "5")"
  echo "max_returns_per_phase=$(_grep_json_value "max_returns_per_phase" || echo "3")"
  echo "max_interview_exchanges=$(_grep_json_value "max_interview_exchanges" || echo "30")"
  echo "timeout_minutes=$(_grep_json_value "timeout_minutes" || echo "45")"
  echo "research_enabled=$(_grep_json_value "enabled" || echo "true")"
  echo "max_deep_research=$(_grep_json_value "max_deep" || echo "3")"
  echo "max_quick_research=$(_grep_json_value "max_quick" || echo "5")"
}

_dump_fallback_plan() {
  echo "granularity=$(_grep_json_string "granularity" || echo "flexible")"
  echo "max_stories_per_epic=$(_grep_json_value "max_stories_per_epic" || echo "6")"
  echo "max_phases_per_story=$(_grep_json_value "max_phases_per_story" || echo "8")"
  echo "max_epics=$(_grep_json_value "max_epics" || echo "10")"
  echo "max_review_cycles=$(_grep_json_value "max_review_cycles" || echo "3")"
  echo "timeout_minutes=$(_grep_json_value "timeout_minutes" || echo "30")"
  echo "research_enabled=$(_grep_json_value "enabled" || echo "true")"
  echo "max_deep_research=$(_grep_json_value "max_deep" || echo "3")"
  echo "max_quick_research=$(_grep_json_value "max_quick" || echo "5")"
}

_dump_fallback_git() {
  echo "provider=$(_grep_json_string "git_provider" || echo "unknown")"
  echo "branching_strategy=$(_grep_json_string "branching_strategy" || echo "none")"
  echo "branch_template_phase=$(_grep_json_string "phase" || echo "gsr/phase-{phase}-{slug}")"
  echo "branch_template_story=$(_grep_json_string "story" || echo "gsr/{epic}-{story}")"
  echo "conventional_commits=$(_grep_json_value "conventional_commits" || echo "true")"
  echo "git_cli=$(_grep_json_string "git_cli" || echo "none")"
  echo "git_cli_authenticated=$(_grep_json_value "git_cli_authenticated" || echo "false")"
  echo "git_mcp=$(_grep_json_string "git_mcp" || echo "none")"
  echo "git_mcp_authenticated=$(_grep_json_value "git_mcp_authenticated" || echo "false")"
}

_dump_fallback_output() {
  echo "claude_md_max_lines=$(_grep_json_value "claude_md_max_lines" || echo "60")"
  echo "spec_format=$(_grep_json_string "spec_format" || echo "lean")"
  echo "plan_format=$(_grep_json_string "plan_format" || echo "xml")"
}

_dump_fallback_environment() {
  echo "jq_available=$(_grep_json_value "jq_available" || echo "false")"
  echo "config_mode=$(_grep_json_string "config_mode" || echo "claude")"
  echo "git_cli=$(_grep_json_string "git_cli" || echo "none")"
  echo "git_cli_authenticated=$(_grep_json_value "git_cli_authenticated" || echo "false")"
  echo "git_mcp=$(_grep_json_string "git_mcp" || echo "none")"
  echo "git_mcp_authenticated=$(_grep_json_value "git_mcp_authenticated" || echo "false")"
  echo "git_provider=$(_grep_json_string "git_provider" || echo "unknown")"
}

# =============================================================================
# Main
# =============================================================================

if [ $# -lt 1 ]; then
  echo "Usage: gsr-config.sh <command> [args]"
  echo ""
  echo "Commands:"
  echo "  ensure                      Create config.json if absent"
  echo "  scan                        Scan environment (jq, git CLI, MCP)"
  echo "  get <key.path>              Get config value (requires jq)"
  echo "  set <key.path> <value>      Set config value (requires jq)"
  echo "  dump <section>              Dump section (discovery|plan|models|git|output|environment)"
  echo "  resolve-model <agent-name>  Resolve model for agent"
  echo "  profile                     Show active profile"
  echo "  config-mode                 Show config mode (jq|claude)"
  exit 1
fi

command="$1"
shift

case "$command" in
  ensure)        cmd_ensure ;;
  scan)          cmd_scan ;;
  get)           cmd_get "${1:?Missing key}" ;;
  set)           cmd_set "${1:?Missing key}" "${2:?Missing value}" ;;
  dump)          cmd_dump "${1:?Missing section}" ;;
  resolve-model) cmd_resolve_model "${1:?Missing agent name}" ;;
  profile)       cmd_profile ;;
  config-mode)   cmd_config_mode ;;
  *)
    err "Unknown command: '$command'"
    exit 1
    ;;
esac
