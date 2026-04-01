#!/usr/bin/env bash
# Hook: Stop
# Saves a session summary log after Claude finishes responding.
# Captures what changed during this session for next session's context.
set -euo pipefail

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$REPO_ROOT"

SESSION_DIR="$REPO_ROOT/.ai/sessions"
mkdir -p "$SESSION_DIR"

# ---------------------------------------------------------
# Read current stage info
# ---------------------------------------------------------
STAGE_ID=""
if [ -f CURRENT_STAGE.md ]; then
  STAGE_ID="$(awk '/^Stage: /{print $2}' CURRENT_STAGE.md | head -1)"
fi

# ---------------------------------------------------------
# Capture session state
# ---------------------------------------------------------
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
BRANCH="$(git branch --show-current 2>/dev/null || echo "unknown")"

# Get uncommitted changes
CHANGED_FILES="$(git status --short 2>/dev/null | wc -l | tr -d ' ')"
CHANGED_LIST="$(git status --short 2>/dev/null | head -10 || true)"

# Get recent commits since last session save
LAST_SESSION="$(ls -t "$SESSION_DIR"/*.md 2>/dev/null | head -1 || true)"
RECENT_COMMITS=""
if [ -n "$LAST_SESSION" ]; then
  # Get timestamp from last session
  LAST_TS="$(grep 'Timestamp:' "$LAST_SESSION" 2>/dev/null | head -1 | sed 's/.*Timestamp: //' || true)"
  if [ -n "$LAST_TS" ]; then
    RECENT_COMMITS="$(git log --oneline --since="$LAST_TS" 2>/dev/null | head -10 || true)"
  fi
fi

if [ -z "$RECENT_COMMITS" ]; then
  RECENT_COMMITS="$(git log --oneline -5 2>/dev/null || echo "(none)")"
fi

# ---------------------------------------------------------
# Write session summary (keep only the latest — not a growing log)
# ---------------------------------------------------------
SESSION_FILE="$SESSION_DIR/latest.md"

cat > "$SESSION_FILE" <<EOF
## Last Session Summary
- Timestamp: $TIMESTAMP
- Stage: ${STAGE_ID:-none}
- Branch: $BRANCH
- Uncommitted files: $CHANGED_FILES

Recent commits:
$RECENT_COMMITS

Working tree:
$CHANGED_LIST
EOF

exit 0
