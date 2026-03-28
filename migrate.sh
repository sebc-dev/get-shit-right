#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# GSR Workflow — Migration Script
# Migrates from old skill-based GTD architecture to new Command+Agents+References GSR
#
# Usage: curl -fsSL https://raw.githubusercontent.com/sebc-dev/gsr/main/migrate.sh | bash
#   or:  bash migrate.sh [target_dir]
#
# Options (via env vars):
#   GSR_TARGET="/path"    Target project directory (default: current dir)
#   GSR_BRANCH="main"     Git branch to install from (default: main)
#   GSR_DRY_RUN=1         Show what would be done without writing
#
# What it does:
#   1. Removes old skill-based architecture (.claude/skills/gtd-discovery/)
#   2. Removes old GTD-named commands (.claude/commands/gtd/)
#   3. Removes old agent files at root level (.claude/agents/gtd-*.md, gsr-*.md)
#   4. Removes old reference directory (.claude/gtd/)
#   5. Cleans settings.json skill permissions if present
#   6. Reinstalls GSR via install.sh
#
# Preserves: discovery.md, docs/*, CLAUDE.md, SPEC.md, and all project files
# =============================================================================

TARGET="${GSR_TARGET:-${1:-.}}"
BRANCH="${GSR_BRANCH:-main}"
DRY_RUN="${GSR_DRY_RUN:-0}"

REPO="sebc-dev/gsr"
BASE_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}"

# --- Colors ---
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

# --- Resolve target ---
if [[ -d "$TARGET" ]]; then
  TARGET=$(cd "$TARGET" && pwd)
else
  fatal "Target directory does not exist: $TARGET"
fi

CLAUDE_DIR="${TARGET}/.claude"

if [[ ! -d "$CLAUDE_DIR" ]]; then
  fatal "No .claude/ directory found in ${TARGET}. Is this a Claude Code project?"
fi

echo -e "\n${C_BOLD}GSR Workflow — Migration${C_RESET}"
echo -e "Target:  ${TARGET}"
echo -e "Branch:  ${BRANCH}"
[[ "$DRY_RUN" == "1" ]] && echo -e "${C_YELLOW}Dry run — nothing will be modified${C_RESET}"
echo ""

# =============================================================================
# Step 1: Detect old architecture
# =============================================================================

OLD_FILES_FOUND=0

detect() {
  local path="$1"
  local desc="$2"
  if [[ -e "${TARGET}/${path}" ]]; then
    warn "Found old: ${path} (${desc})"
    OLD_FILES_FOUND=1
    return 0
  fi
  return 1
}

info "Scanning for old architecture..."

detect ".claude/skills/gtd-discovery" "skill orchestrator" || true
detect ".claude/commands/gtd" "GTD-named commands" || true
detect ".claude/gtd" "GTD-named references (post-skill migration)" || true
detect ".claude/agents/research-prompt-agent.md" "agent at root level" || true

# Check for gtd-* or gsr-* agents at root (before subdirectory move)
for f in "${CLAUDE_DIR}"/agents/gtd-*.md "${CLAUDE_DIR}"/agents/gsr-*.md; do
  [[ -e "$f" ]] && detect ".claude/agents/$(basename "$f")" "agent at root level" || true
done

# Check for old VERSION at .claude/gtd/VERSION
detect ".claude/gtd/VERSION" "old version file" || true

if [[ $OLD_FILES_FOUND -eq 0 ]]; then
  # Also check if current GSR is already installed
  if [[ -d "${CLAUDE_DIR}/commands/gsr" && -d "${CLAUDE_DIR}/agents/gsr" && -d "${CLAUDE_DIR}/gsr" ]]; then
    info "Current GSR architecture already in place. Nothing to migrate."
    exit 0
  fi
  warn "No old architecture detected, but GSR is not fully installed either."
  info "Proceeding with fresh install..."
fi

# =============================================================================
# Step 2: Remove old files
# =============================================================================

removed=0

remove_path() {
  local path="${TARGET}/$1"
  local desc="$2"
  if [[ -e "$path" ]]; then
    if [[ "$DRY_RUN" == "1" ]]; then
      echo -e "  ${C_RED}-${C_RESET} $1 (${desc})"
    else
      rm -rf "$path"
      ok "Removed: $1"
    fi
    removed=$((removed + 1))
  fi
}

echo ""
info "Removing old architecture..."

# Old skill directory (the main thing to remove)
remove_path ".claude/skills/gtd-discovery" "skill orchestrator + references"

# Remove empty skills/ dir if nothing else is in it
if [[ -d "${CLAUDE_DIR}/skills" ]]; then
  if [[ -z "$(ls -A "${CLAUDE_DIR}/skills" 2>/dev/null)" ]]; then
    remove_path ".claude/skills" "empty skills directory"
  else
    warn ".claude/skills/ has other contents, keeping it"
  fi
fi

# Old GTD-named commands
remove_path ".claude/commands/gtd" "GTD-named commands"

# Old GTD-named references
remove_path ".claude/gtd" "GTD-named references"

# Old agents at root level (before agents/gsr/ subdirectory move)
for f in "${CLAUDE_DIR}"/agents/gtd-*.md "${CLAUDE_DIR}"/agents/gsr-*.md; do
  [[ -e "$f" ]] && remove_path ".claude/agents/$(basename "$f")" "agent at root level"
done
if [[ -f "${CLAUDE_DIR}/agents/research-prompt-agent.md" ]]; then
  remove_path ".claude/agents/research-prompt-agent.md" "agent at root level"
fi

# Clean settings.json skill permissions if present
SETTINGS="${CLAUDE_DIR}/settings.json"
if [[ -f "$SETTINGS" ]]; then
  if grep -q "gtd-discovery" "$SETTINGS" 2>/dev/null; then
    if [[ "$DRY_RUN" == "1" ]]; then
      echo -e "  ${C_YELLOW}~${C_RESET} .claude/settings.json (would clean GTD skill permissions)"
    else
      # Remove gtd-discovery related entries from permissions
      # Use a temp file to avoid issues with in-place editing
      tmp_settings=$(mktemp)
      # Remove lines containing gtd-discovery
      grep -v "gtd-discovery" "$SETTINGS" > "$tmp_settings" || true
      # Clean up trailing commas in JSON arrays (simple best-effort)
      sed -i 's/,\s*]/]/g' "$tmp_settings"
      mv "$tmp_settings" "$SETTINGS"
      ok "Cleaned settings.json (removed GTD skill permissions)"
    fi
    removed=$((removed + 1))
  fi
fi

# =============================================================================
# Step 3: Summary and reinstall
# =============================================================================

echo ""
if [[ $removed -gt 0 ]]; then
  info "${removed} old items removed"
else
  info "No old files to remove"
fi

echo ""
info "Installing current GSR architecture..."
echo ""

if [[ "$DRY_RUN" == "1" ]]; then
  info "Dry run — would run: GSR_TARGET=\"${TARGET}\" GSR_BRANCH=\"${BRANCH}\" GSR_FORCE=1 bash install.sh"
  echo ""
  echo -e "${C_GREEN}Dry run complete.${C_RESET} Run without GSR_DRY_RUN=1 to apply."
  exit 0
fi

# Run the installer with force (since we just cleaned up)
if [[ -f "$(dirname "$0")/install.sh" ]]; then
  # Local execution (from the repo)
  GSR_TARGET="$TARGET" GSR_BRANCH="$BRANCH" GSR_FORCE=1 bash "$(dirname "$0")/install.sh"
else
  # Remote execution (via curl)
  curl -fsSL "${BASE_URL}/install.sh" | GSR_TARGET="$TARGET" GSR_BRANCH="$BRANCH" GSR_FORCE=1 bash
fi

echo -e "\n${C_GREEN}${C_BOLD}Migration complete!${C_RESET}"
echo -e "Old skill-based GTD architecture removed, new GSR installed.\n"
