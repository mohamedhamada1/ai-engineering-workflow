#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/ai-common.sh"

REPO_ROOT="$(repo_root)"
cd "$REPO_ROOT"

# =========================================================
# ai-generate-reality-sync.sh — Post-Stage Reality Snapshot
#
# Generates a compact summary of what actually changed in the
# repo after a stage was implemented. This snapshot is appended
# to the architect-facing context file so future specs are
# grounded in reality, not plans.
#
# Usage:
#   ./scripts/ai-generate-reality-sync.sh
#   ./scripts/ai-generate-reality-sync.sh --append
#
# Output:
#   - Prints reality sync to stdout
#   - With --append: also appends to PROJECT_CONTEXT_FOR_SPEC_ARCHITECT.md
# =========================================================

APPEND=false
if [[ "${1:-}" == "--append" ]]; then
  APPEND=true
fi

STAGE_ID="$(current_stage_id)"
SLUG="$(current_stage_slug)"
CONTEXT_FILE=".ai/context/PROJECT_CONTEXT_FOR_SPEC_ARCHITECT.md"
REVIEW_DIR="$(stage_review_dir)"
mkdir -p "$REVIEW_DIR"
VERSION_DIR="$(ensure_version_dir "$REVIEW_DIR")"
SYNC_FILE="${VERSION_DIR}/reality_sync.md"

# Get diff against main
DIFF_BASE="main"
CHANGED_FILES=$(git diff --name-only ${DIFF_BASE}...HEAD 2>/dev/null || git diff --name-only HEAD~1 2>/dev/null || echo "")
DIFF_STAT=$(git diff --stat ${DIFF_BASE}...HEAD 2>/dev/null || git diff --stat HEAD~1 2>/dev/null || echo "")

{

echo "# REALITY SYNC — After Stage ${STAGE_ID}"
echo ""
echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""
echo "---"
echo ""

# =========================================================
# New Files
# =========================================================

echo "## New Files"
echo ""

NEW_FILES=$(git diff --name-only --diff-filter=A ${DIFF_BASE}...HEAD 2>/dev/null || echo "")
if [[ -n "$NEW_FILES" ]]; then
  echo "$NEW_FILES" | while read -r f; do echo "- \`$f\`"; done
else
  echo "- (none)"
fi
echo ""

# =========================================================
# Modified Files
# =========================================================

echo "## Modified Files"
echo ""

MOD_FILES=$(git diff --name-only --diff-filter=M ${DIFF_BASE}...HEAD 2>/dev/null || echo "")
if [[ -n "$MOD_FILES" ]]; then
  echo "$MOD_FILES" | while read -r f; do echo "- \`$f\`"; done
else
  echo "- (none)"
fi
echo ""

# =========================================================
# New Endpoints (grep route files for path patterns)
# =========================================================

echo "## New Endpoints"
echo ""

# Find route files that were added or modified
ROUTE_FILES=$(echo "$CHANGED_FILES" | grep -i "route" | grep "\.kt$\|\.ts$" || true)
if [[ -n "$ROUTE_FILES" ]]; then
  while IFS= read -r rf; do
    if [[ -f "$rf" ]]; then
      # Extract route patterns from Kotlin (Ktor) or TypeScript
      routes=$(grep -oE '(get|post|put|delete|patch)\s*\(\s*"[^"]*"' "$rf" 2>/dev/null | sed 's/[("'"'"']//g; s/\s\+/ /g' || true)
      routes2=$(grep -oE 'route\s*\(\s*"[^"]*"' "$rf" 2>/dev/null | sed 's/route//; s/[("'"'"' ]//g' || true)
      if [[ -n "$routes" ]]; then
        echo "### $rf"
        echo "$routes" | while read -r r; do echo "- \`$r\`"; done
        echo ""
      fi
      if [[ -n "$routes2" ]]; then
        echo "### $rf (route blocks)"
        echo "$routes2" | while read -r r; do echo "- \`$r\`"; done
        echo ""
      fi
    fi
  done <<< "$ROUTE_FILES"
else
  echo "- (no route file changes detected)"
  echo ""
fi

# =========================================================
# New Public Types (Kotlin classes/interfaces/enums + TS exports)
# =========================================================

echo "## New Public Types"
echo ""

if [[ -n "$NEW_FILES" ]]; then
  # Kotlin: data class, sealed class, enum class, interface, object
  KT_TYPES=$(echo "$NEW_FILES" | grep "\.kt$" | while read -r f; do
    if [[ -f "$f" ]]; then
      grep -oE '(data class|sealed class|sealed interface|enum class|interface|object|class)\s+[A-Z][A-Za-z0-9]+' "$f" 2>/dev/null || true
    fi
  done | sort -u)

  # TypeScript: export interface, export type, export enum, export class
  TS_TYPES=$(echo "$NEW_FILES" | grep "\.ts$\|\.tsx$" | while read -r f; do
    if [[ -f "$f" ]]; then
      grep -oE 'export\s+(interface|type|enum|class)\s+[A-Z][A-Za-z0-9]+' "$f" 2>/dev/null || true
    fi
  done | sort -u)

  if [[ -n "$KT_TYPES" ]]; then
    echo "### Kotlin"
    echo "$KT_TYPES" | while read -r t; do echo "- \`$t\`"; done
    echo ""
  fi
  if [[ -n "$TS_TYPES" ]]; then
    echo "### TypeScript"
    echo "$TS_TYPES" | while read -r t; do echo "- \`$t\`"; done
    echo ""
  fi
  if [[ -z "$KT_TYPES" && -z "$TS_TYPES" ]]; then
    echo "- (no new public types detected)"
    echo ""
  fi
else
  echo "- (no new files)"
  echo ""
fi

# =========================================================
# New Tests
# =========================================================

echo "## Tests"
echo ""

NEW_TEST_FILES=$(echo "$NEW_FILES" | grep -i "test\|spec" || true)
MOD_TEST_FILES=$(echo "$MOD_FILES" | grep -i "test\|spec" || true)

if [[ -n "$NEW_TEST_FILES" ]]; then
  echo "### New Test Files"
  echo "$NEW_TEST_FILES" | while read -r f; do echo "- \`$f\`"; done
  echo ""
fi

if [[ -n "$MOD_TEST_FILES" ]]; then
  echo "### Modified Test Files"
  echo "$MOD_TEST_FILES" | while read -r f; do echo "- \`$f\`"; done
  echo ""
fi

# Count test methods if possible
TOTAL_NEW_TESTS=0
if [[ -n "$NEW_TEST_FILES" ]]; then
  while IFS= read -r tf; do
    if [[ -f "$tf" ]]; then
      count=$(grep -c '@Test\|fun.*test\|it(\|describe(\|test(' "$tf" 2>/dev/null || echo "0")
      TOTAL_NEW_TESTS=$((TOTAL_NEW_TESTS + count))
    fi
  done <<< "$NEW_TEST_FILES"
fi
echo "New test methods (approximate): ${TOTAL_NEW_TESTS}"
echo ""

# =========================================================
# Diff Stats
# =========================================================

echo "## Diff Stats"
echo ""
echo '```'
echo "$DIFF_STAT" | tail -5
echo '```'
echo ""

} | tee "$SYNC_FILE"

echo ""
echo "Reality sync saved to: ${SYNC_FILE}"

# =========================================================
# Optionally append to architect context
# =========================================================

if [[ "$APPEND" == true && -f "$CONTEXT_FILE" ]]; then
  echo "" >> "$CONTEXT_FILE"
  echo "---" >> "$CONTEXT_FILE"
  echo "" >> "$CONTEXT_FILE"
  cat "$SYNC_FILE" >> "$CONTEXT_FILE"
  echo ""
  echo "Appended to: ${CONTEXT_FILE}"
fi
