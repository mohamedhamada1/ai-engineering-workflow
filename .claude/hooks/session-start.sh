#!/usr/bin/env bash
# Hook: SessionStart (startup|resume|compact)
# Injects compact stage context into Claude's conversation.
# Output goes to stdout → Claude sees it as context.
set -euo pipefail

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$REPO_ROOT"

# ---------------------------------------------------------
# Read current stage info
# ---------------------------------------------------------
STAGE_ID=""
STAGE_STATUS=""
STAGE_PACKAGE=""

if [ -f CURRENT_STAGE.md ]; then
  STAGE_ID="$(awk '/^Stage: /{print $2}' CURRENT_STAGE.md | head -1)"
  STAGE_STATUS="$(awk -F'Status: ' '/^Status: /{print $2}' CURRENT_STAGE.md | head -1)"
  STAGE_PACKAGE="$(awk -F'Package: ' '/^Package: /{print $2}' CURRENT_STAGE.md | head -1)"
fi

if [ -z "$STAGE_ID" ]; then
  echo "[Session Context] No active stage found."
  exit 0
fi

# ---------------------------------------------------------
# Resolve stage name from ROADMAP
# ---------------------------------------------------------
STAGE_ESCAPED="$(echo "$STAGE_ID" | sed 's/\./\\./g')"
STAGE_NAME="$(grep -oE "^## Stage ${STAGE_ESCAPED} — .+" ROADMAP.md 2>/dev/null | sed "s/^## Stage ${STAGE_ESCAPED} — //" | head -1 || true)"

# ---------------------------------------------------------
# Output compact context
# ---------------------------------------------------------
cat <<EOF
[Session Context — Auto-loaded]

Current Stage: $STAGE_ID — ${STAGE_NAME:-unknown}
Status: $STAGE_STATUS
Package: $STAGE_PACKAGE
Branch: $(git branch --show-current 2>/dev/null || echo "unknown")
EOF

# Show checkpoint if resumable
if [ -f .ai/execute_checkpoint ]; then
  echo "Execute checkpoint: step $(cat .ai/execute_checkpoint) completed (resume with --stage-execute --resume)"
fi

# Show recent commits on this branch
echo ""
echo "Recent commits (this branch):"
git log --oneline -5 2>/dev/null || echo "  (none)"

# Show uncommitted changes summary
CHANGES="$(git status --short 2>/dev/null | wc -l | tr -d ' ')"
if [ "$CHANGES" -gt 0 ]; then
  echo ""
  echo "Uncommitted changes: $CHANGES file(s)"
  git status --short 2>/dev/null | head -10
fi

# ---------------------------------------------------------
# Load stage spec summary (first 20 lines only — keep compact)
# ---------------------------------------------------------
STAGE_SLUG="$(echo "$STAGE_ID" | tr '.' '_')"
SPEC_FILE="$(find .ai/specs -maxdepth 1 -type f -name "stage_${STAGE_SLUG}_*.md" 2>/dev/null | grep -v '\.plan\.\|\.review\.\|\.implementation\.' | sort | head -n1 || true)"

if [ -n "$SPEC_FILE" ] && [ -f "$SPEC_FILE" ]; then
  echo ""
  echo "Stage spec summary (from $SPEC_FILE):"
  head -25 "$SPEC_FILE"
  echo "  ... (use Read tool for full spec)"
fi

# ---------------------------------------------------------
# Load last session log if exists
# ---------------------------------------------------------
LATEST_SESSION="$(ls -t .ai/sessions/*.md 2>/dev/null | head -1 || true)"
if [ -n "$LATEST_SESSION" ] && [ -f "$LATEST_SESSION" ]; then
  echo ""
  echo "Last session summary (from $LATEST_SESSION):"
  cat "$LATEST_SESSION"
fi

echo ""
echo "[End Session Context]"
exit 0
