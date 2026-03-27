#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# GSR Workflow — Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/sebc-dev/gsr/main/install.sh | bash
#
# Options (via env vars):
#   GSR_PHASES="discovery"    Install specific phases (comma-separated)
#   GSR_PHASES="all"          Install all available phases (default)
#   GSR_TARGET="/path"        Target project directory (default: current dir)
#   GSR_BRANCH="main"         Git branch to install from (default: main)
#   GSR_FORCE=1               Overwrite existing files without prompting
#   GSR_DRY_RUN=1             Show what would be installed without writing
#   GSR_LIST=1                List available phases and exit
# =============================================================================

REPO="sebc-dev/gsr"
BRANCH="${GSR_BRANCH:-main}"
BASE_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}"
TARGET="${GSR_TARGET:-.}"
FORCE="${GSR_FORCE:-0}"
DRY_RUN="${GSR_DRY_RUN:-0}"
LIST="${GSR_LIST:-0}"

# --- Colors (disabled if not a terminal) ---
if [[ -t 1 ]]; then
  C_RESET='\033[0m'; C_GREEN='\033[0;32m'; C_YELLOW='\033[0;33m'
  C_RED='\033[0;31m'; C_BLUE='\033[0;34m'; C_BOLD='\033[1m'
else
  C_RESET=''; C_GREEN=''; C_YELLOW=''; C_RED=''; C_BLUE=''; C_BOLD=''
fi

info()  { echo -e "${C_BLUE}[info]${C_RESET}  $*"; }
ok()    { echo -e "${C_GREEN}[ok]${C_RESET}    $*"; }
warn()  { echo -e "${C_YELLOW}[warn]${C_RESET}  $*"; }
err()   { echo -e "${C_RED}[err]${C_RESET}   $*" >&2; }
fatal() { err "$@"; exit 1; }

# =============================================================================
# Phase Registry
#
# To add a new phase:
#   1. Create a function: phase_<name>_files() that echoes file paths (one per line)
#   2. Add the phase name to AVAILABLE_PHASES
#   3. Add a description to phase_<name>_desc()
#
# File paths are relative to the repo root, installed under .claude/ in target.
# Only files under .claude/ are supported (minus settings.json).
# =============================================================================

AVAILABLE_PHASES="discovery plan"

# --- Discovery phase ---

phase_discovery_desc() {
  echo "Interactive 6-phase interview generating discovery.md + project bootstrap"
}

phase_discovery_files() {
  cat <<'FILES'
.claude/gsr/discovery-phases.md
.claude/gsr/discovery-output.md
.claude/gsr/discovery-research.md
.claude/commands/gsr/discover.md
.claude/commands/gsr/discover-resume.md
.claude/commands/gsr/discover-abort.md
.claude/commands/gsr/discover-save.md
.claude/commands/gsr/bootstrap.md
.claude/agents/research-prompt-agent.md
.claude/agents/gsr-synthesizer.md
.claude/agents/gsr-bootstrapper.md
FILES
}

# --- Plan phase ---

phase_plan_desc() {
  echo "Progressive planning: bootstrap docs → Epics → Stories → atomic Phases (JIT)"
}

phase_plan_files() {
  cat <<'FILES'
.claude/commands/gsr/plan.md
.claude/commands/gsr/plan-story.md
.claude/commands/gsr/plan-phases.md
.claude/commands/gsr/plan-status.md
.claude/commands/gsr/plan-abort.md
.claude/agents/gsr-analyst.md
.claude/agents/gsr-planner.md
.claude/agents/gsr-generator.md
.claude/gsr/plan-output.md
.claude/gsr/plan-research.md
FILES
}

# --- (Future phases go here) ---

# =============================================================================
# Commands
# =============================================================================

cmd_list() {
  echo -e "\n${C_BOLD}GSR Workflow — Available phases${C_RESET}\n"
  for phase in $AVAILABLE_PHASES; do
    local desc
    desc=$(phase_${phase}_desc)
    local count
    count=$(phase_${phase}_files | wc -l | tr -d ' ')
    echo -e "  ${C_GREEN}${phase}${C_RESET}  (${count} files)"
    echo -e "    ${desc}\n"
  done
}

cmd_install() {
  local phases_input="${GSR_PHASES:-all}"
  local phases

  if [[ "$phases_input" == "all" ]]; then
    phases=$AVAILABLE_PHASES
  else
    phases=$(echo "$phases_input" | tr ',' ' ')
  fi

  # Validate phases
  for phase in $phases; do
    if ! type "phase_${phase}_files" &>/dev/null; then
      fatal "Unknown phase: '${phase}'. Run with GSR_LIST=1 to see available phases."
    fi
  done

  # Collect all files
  local all_files=""
  for phase in $phases; do
    local files
    files=$(phase_${phase}_files)
    all_files="${all_files}${files}"$'\n'
  done
  all_files=$(echo "$all_files" | sort -u | sed '/^$/d')

  local total
  total=$(echo "$all_files" | wc -l | tr -d ' ')
  local phase_list
  phase_list=$(echo "$phases" | tr ' ' ', ')

  echo -e "\n${C_BOLD}GSR Workflow — Installer${C_RESET}"
  echo -e "Phases:  ${C_GREEN}${phase_list}${C_RESET}"
  echo -e "Target:  ${TARGET}"
  echo -e "Files:   ${total}"
  echo -e "Branch:  ${BRANCH}\n"

  if [[ "$DRY_RUN" == "1" ]]; then
    info "Dry run — nothing will be written\n"
  fi

  local installed=0
  local skipped=0
  local failed=0

  while IFS= read -r file; do
    [[ -z "$file" ]] && continue

    local dest="${TARGET}/${file}"
    local dest_dir
    dest_dir=$(dirname "$dest")

    # Check existing
    if [[ -f "$dest" && "$FORCE" != "1" && "$DRY_RUN" != "1" ]]; then
      warn "Exists, skipped: ${file} (use GSR_FORCE=1 to overwrite)"
      skipped=$((skipped + 1))
      continue
    fi

    if [[ "$DRY_RUN" == "1" ]]; then
      if [[ -f "$dest" ]]; then
        echo -e "  ${C_YELLOW}~${C_RESET} ${file} (would overwrite)"
      else
        echo -e "  ${C_GREEN}+${C_RESET} ${file}"
      fi
      installed=$((installed + 1))
      continue
    fi

    # Download and install
    mkdir -p "$dest_dir"

    local url="${BASE_URL}/${file}"
    local http_code
    http_code=$(curl -fsSL -w '%{http_code}' -o "$dest" "$url" 2>/dev/null) || true

    if [[ "$http_code" == "200" ]]; then
      ok "${file}"
      installed=$((installed + 1))
    else
      err "Failed (HTTP ${http_code}): ${file}"
      rm -f "$dest"
      failed=$((failed + 1))
    fi
  done <<< "$all_files"

  # Summary
  echo -e "\n${C_BOLD}Summary${C_RESET}"
  [[ $installed -gt 0 ]] && echo -e "  ${C_GREEN}${installed} installed${C_RESET}"
  [[ $skipped -gt 0 ]]   && echo -e "  ${C_YELLOW}${skipped} skipped${C_RESET}"
  [[ $failed -gt 0 ]]    && echo -e "  ${C_RED}${failed} failed${C_RESET}"

  if [[ "$DRY_RUN" != "1" && $failed -eq 0 ]]; then
    echo -e "\n${C_GREEN}Done.${C_RESET} Commands available:"
    for phase in $phases; do
      case "$phase" in
        discovery)
          echo "  /gsr:discover \"project description\""
          echo "  /gsr:discover-resume"
          echo "  /gsr:bootstrap"
          ;;
        plan)
          echo "  /gsr:plan [path/to/SPEC.md] [--granularity=flexible]"
          echo "  /gsr:plan-story [epic-slug/story-slug]"
          echo "  /gsr:plan-phases [epic-slug/story-slug]"
          echo "  /gsr:plan-status"
          echo "  /gsr:plan-abort"
          ;;
        # Future phases: add cases here
      esac
    done
    echo ""
  fi

  [[ $failed -gt 0 ]] && exit 1
  return 0
}

# =============================================================================
# Main
# =============================================================================

# Resolve target to absolute path
if [[ -d "$TARGET" ]]; then
  TARGET=$(cd "$TARGET" && pwd)
else
  TARGET=$(mkdir -p "$TARGET" && cd "$TARGET" && pwd)
fi

if [[ "$LIST" == "1" ]]; then
  cmd_list
  exit 0
fi

cmd_install
