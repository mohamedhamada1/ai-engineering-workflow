#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------
# Source of truth for AI workflow scripts
# Change this if you move the canonical scripts elsewhere
# ---------------------------------------------------------
SOURCE_PROJECT="/Users/adres/Documents/GitHub/supply_orchestration_sdk"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Don't sync to yourself
if [ "$REPO_ROOT" = "$SOURCE_PROJECT" ]; then
  echo "This IS the source project. Nothing to sync."
  echo
  echo "To push scripts to other projects, run from the target project:"
  echo "  ./scripts/ai-sync-scripts.sh"
  exit 0
fi

echo "========================================="
echo " Sync AI Scripts"
echo "========================================="
echo "  Source: $SOURCE_PROJECT/scripts/"
echo "  Target: $REPO_ROOT/scripts/"
echo

# Scripts to sync (all ai-* except project-specific ones)
SCRIPTS=(
  ai-common.sh
  ai-diff-evidence.sh
  ai-import-chatgpt.sh
  ai-review-bundle.sh
  ai-run.sh
  ai-stage-complete.sh
  ai-stage-execute.sh
  ai-stage-post-review.sh
  ai-stage-revise.sh
  ai-stage-start.sh
  ai-stage-status.sh
  ai-sync-scripts.sh
  ai-update-context.sh
  ai-verify-stage.sh
)

UPDATED=0
SKIPPED=0

for script in "${SCRIPTS[@]}"; do
  src="$SOURCE_PROJECT/scripts/$script"
  dst="$REPO_ROOT/scripts/$script"

  if [ ! -f "$src" ]; then
    echo "  SKIP: $script (not found in source)"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  if [ -f "$dst" ] && diff -q "$src" "$dst" >/dev/null 2>&1; then
    echo "  OK:   $script (already up to date)"
    SKIPPED=$((SKIPPED + 1))
  else
    cp "$src" "$dst"
    chmod +x "$dst"
    echo "  SYNC: $script"
    UPDATED=$((UPDATED + 1))
  fi
done

# Also sync flow_commands.md
src="$SOURCE_PROJECT/flow_commands.md"
dst="$REPO_ROOT/flow_commands.md"
if [ -f "$src" ]; then
  if [ -f "$dst" ] && diff -q "$src" "$dst" >/dev/null 2>&1; then
    echo "  OK:   flow_commands.md (already up to date)"
  else
    cp "$src" "$dst"
    echo "  SYNC: flow_commands.md"
    UPDATED=$((UPDATED + 1))
  fi
fi

echo
echo "  Updated: $UPDATED"
echo "  Already current: $SKIPPED"
echo
echo "Note: .ai/stage_package_map.sh is project-specific and NOT synced."
