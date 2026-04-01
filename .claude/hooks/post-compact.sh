#!/usr/bin/env bash
# Hook: SessionStart (matcher: compact)
# Re-injects critical context after Claude's context window gets compacted.
# Without this, Claude forgets the current stage after compaction.
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
  exit 0
fi

# ---------------------------------------------------------
# Re-inject minimal context after compaction
# ---------------------------------------------------------
cat <<EOF
[Post-Compaction Context Refresh]

Current Stage: $STAGE_ID
Status: $STAGE_STATUS
Package: $STAGE_PACKAGE
Branch: $(git branch --show-current 2>/dev/null || echo "unknown")

IMPORTANT: Context was compacted. Key rules:
- Do NOT modify files outside package: $STAGE_PACKAGE
- Follow the spec/plan in .ai/ artifacts
- Run ./gradlew build and ./gradlew test before finishing

[End Context Refresh]
EOF

exit 0
