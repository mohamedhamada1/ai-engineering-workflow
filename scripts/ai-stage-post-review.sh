#!/usr/bin/env bash
set -euo pipefail
export GIT_PAGER=cat
source "$(dirname "$0")/ai-common.sh"

require_git_repo

# ---------------------------------------------------------
# Parse arguments: optional stage ID, defaults to current
# ---------------------------------------------------------
TARGET_STAGE="${1:-}"

if [ -n "$TARGET_STAGE" ]; then
  STAGE_ID="$TARGET_STAGE"

  # Resolve package from stage_package_map or ROADMAP
  PKG="$(resolve_package_for_stage "$STAGE_ID" 2>/dev/null || true)"

  # Resolve stage name from ROADMAP
  STAGE_ESCAPED="$(echo "$STAGE_ID" | sed 's/\./\\./g')"
  STAGE_NAME="$(grep -oE "^## Stage ${STAGE_ESCAPED} — .+" ROADMAP.md 2>/dev/null | sed "s/^## Stage ${STAGE_ESCAPED} — //" | head -1 || true)"

  # Find the branch for this stage
  STAGE_BRANCH=""
  # Check local branches first
  STAGE_BRANCH="$(git branch --list "feat/stage-${STAGE_ID}*" | head -1 | tr -d '* ' || true)"
  # Fallback: check remote branches
  if [ -z "$STAGE_BRANCH" ]; then
    STAGE_BRANCH="$(git branch -r --list "origin/feat/stage-${STAGE_ID}*" | head -1 | tr -d ' ' | sed 's|^origin/||' || true)"
  fi

  if [ -z "$STAGE_BRANCH" ]; then
    echo "WARNING: Could not find branch for stage $STAGE_ID"
    echo "Using current branch instead."
    STAGE_BRANCH="$(git branch --show-current)"
  fi
else
  STAGE_ID="$(current_stage_id)"
  STAGE_NAME="$(current_stage_name)"
  PKG="$(stage_package_dir || true)"
  STAGE_BRANCH="$(git branch --show-current)"
fi

BASE_BRANCH="$(detect_base_branch)"
CURRENT_BRANCH="$(git branch --show-current)"
OUT_DIR="$(stage_review_dir)"
mkdir -p "$OUT_DIR"
VERSION_DIR="$(next_version_dir "$OUT_DIR")"
OUT_FILE="${VERSION_DIR}/post_review.md"

# If we need to generate for a different branch, use that branch's ref for diffs
DIFF_REF="$STAGE_BRANCH"

# ---------------------------------------------------------
# Compute the real diff base (handles merged branches).
# ---------------------------------------------------------
DIFF_BASE="$(resolve_diff_base "$BASE_BRANCH" "$DIFF_REF" "$STAGE_ID")"

echo "========================================="
echo " Post-Review Bundle: Stage $STAGE_ID"
echo "========================================="
echo "  Stage branch: $STAGE_BRANCH"
echo "  Diff base: $DIFF_BASE"
echo "  Package: $PKG"
if [ "$STAGE_BRANCH" != "$CURRENT_BRANCH" ]; then
  echo "  (generating from branch $STAGE_BRANCH, currently on $CURRENT_BRANCH)"
fi
echo

# ---------------------------------------------------------
# Pre-generation validation: ensure package diff is non-empty
# ---------------------------------------------------------
if [ -n "$PKG" ]; then
  PKG_CHANGED_FILES="$(git diff --name-only "${DIFF_BASE}..${DIFF_REF}" -- "$PKG/" 2>/dev/null || true)"

  if [ -z "$PKG_CHANGED_FILES" ]; then
    # Also check uncommitted changes in the package
    PKG_UNCOMMITTED="$(git diff --name-only -- "$PKG/" 2>/dev/null || true)"
    PKG_UNTRACKED="$(git ls-files --others --exclude-standard "$PKG/" 2>/dev/null || true)"

    if [ -z "$PKG_UNCOMMITTED" ] && [ -z "$PKG_UNTRACKED" ]; then
      echo "ERROR: Package diff is empty for $PKG"
      echo ""
      echo "The post-review bundle would contain no actual implementation changes."
      echo "This usually means:"
      echo "  - Implementation files have not been committed yet"
      echo "  - The commit message was misleading (claimed implementation but only changed lifecycle files)"
      echo "  - Implementation was committed to a different branch"
      echo ""
      echo "Committed changes in diff range:"
      git diff --name-only "${DIFF_BASE}..${DIFF_REF}" 2>/dev/null || echo "  (none)"
      echo ""
      echo "Aborting bundle generation. Commit the implementation first."
      exit 1
    else
      echo "WARNING: Package has uncommitted/untracked changes that will be included as a working-tree section."
      echo "  Consider committing before generating the bundle."
      echo ""
    fi
  fi

  # Check that at least one source or test file is in the diff (not just build config)
  PKG_SRC_FILES="$(echo "$PKG_CHANGED_FILES" | grep -E '\.(kt|java|scala|dart|ts|js|py|rs|go|swift|yaml|yml|md)$' || true)"
  if [ -n "$PKG_CHANGED_FILES" ] && [ -z "$PKG_SRC_FILES" ]; then
    echo "WARNING: Package diff contains only non-source files (no .kt/.java/.ts etc.)."
    echo "  Changed files: $PKG_CHANGED_FILES"
    echo "  If this is expected (e.g. build config only), proceed with caution."
    echo ""
  fi

  # Check for "only lifecycle files" scenario: commits claim implementation
  # but the overall diff contains zero package source files
  IMPL_COMMITS="$(git log --oneline --grep="feat\|implement\|fix" "${DIFF_BASE}..${DIFF_REF}" 2>/dev/null || true)"
  if [ -n "$IMPL_COMMITS" ] && [ -z "$PKG_SRC_FILES" ]; then
    echo "ERROR: Commit history contains implementation commits but no package source files were found."
    echo ""
    echo "Implementation commits:"
    echo "$IMPL_COMMITS"
    echo ""
    echo "All changed files:"
    git diff --name-only "${DIFF_BASE}..${DIFF_REF}" 2>/dev/null || echo "  (none)"
    echo ""
    echo "This usually means the implementation was not committed or was committed to a different branch."
    echo "Aborting bundle generation."
    exit 1
  fi
fi

# ---------------------------------------------------------
# Build the review bundle (package-scoped)
# ---------------------------------------------------------
{
  cat <<EOF
# Post-Implementation Review Bundle

## Stage: $STAGE_ID — $STAGE_NAME
- **Branch:** $STAGE_BRANCH
- **Base branch:** $BASE_BRANCH
- **Package:** $PKG
- **Generated:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")

---

## Review Request

This bundle contains the complete implementation output for Stage $STAGE_ID.

**ChatGPT (Architect):** Please review for architectural correctness, scope discipline, and alignment with the spec/plan.

**Gemini (Red-Team):** Please red-team for boundary violations, hidden risks, invariant breaks, and backward compatibility concerns.

**Decision requested:** GO / NO-GO / GO WITH CHANGES

---

## Commit History (branch vs $DIFF_BASE)

\`\`\`
EOF

  git log --oneline "${DIFF_BASE}..${DIFF_REF}" 2>/dev/null || echo "(no commits diverged from $DIFF_BASE)"

  echo '```'
  echo
  echo "---"
  echo

  # ---------------------------------------------------------
  # Package-scoped file stats and diff only
  # ---------------------------------------------------------
  echo "## Files Changed (package + stage lifecycle)"
  echo
  echo '```'
  if [ -n "$PKG" ]; then
    git diff --stat "${DIFF_BASE}..${DIFF_REF}" -- "$PKG/" settings.gradle.kts CURRENT_STAGE.md 2>/dev/null || echo "(no diff)"
  else
    git diff --stat "${DIFF_BASE}..${DIFF_REF}" 2>/dev/null || echo "(no diff)"
  fi
  echo '```'
  echo
  echo "---"
  echo

  echo "## Changed File List (package + stage lifecycle files)"
  echo
  echo '```'
  if [ -n "$PKG" ]; then
    git diff --name-only "${DIFF_BASE}..${DIFF_REF}" -- "$PKG/" settings.gradle.kts CURRENT_STAGE.md 2>/dev/null || echo "(none)"
  else
    git diff --name-only "${DIFF_BASE}..${DIFF_REF}" 2>/dev/null || echo "(none)"
  fi
  echo '```'
  echo
  echo "---"
  echo

  echo "## Package Diff (source + tests + build config)"
  echo
  echo '```diff'
  if [ -n "$PKG" ]; then
    git diff "${DIFF_BASE}..${DIFF_REF}" -- "$PKG/" settings.gradle.kts 2>/dev/null || echo "(no diff)"
  else
    git diff "${DIFF_BASE}..${DIFF_REF}" 2>/dev/null || echo "(no diff)"
  fi
  echo '```'
  echo

  # ---------------------------------------------------------
  # Include uncommitted working tree changes if present
  # (covers the case where revision is not yet committed)
  # ---------------------------------------------------------
  UNCOMMITTED_DIFF=""
  if [ -n "$PKG" ]; then
    UNCOMMITTED_DIFF="$(git diff -- "$PKG/" settings.gradle.kts TEST_REPORT.md KNOWN_ISSUES.md 2>/dev/null || true)"
  else
    UNCOMMITTED_DIFF="$(git diff 2>/dev/null || true)"
  fi

  if [ -n "$UNCOMMITTED_DIFF" ]; then
    echo "## Uncommitted Changes (working tree)"
    echo
    echo "> These changes exist in the working tree but have not been committed yet."
    echo
    echo '```diff'
    echo "$UNCOMMITTED_DIFF"
    echo '```'
    echo
  fi

  echo "---"
  echo

  # ---------------------------------------------------------
  # Verification results (only run if on the target branch)
  # ---------------------------------------------------------
  echo "## Verification Results"
  echo
  echo '```'
  if [ "$STAGE_BRANCH" = "$CURRENT_BRANCH" ]; then
    ./scripts/ai-verify-stage.sh --full 2>&1 || true
  else
    echo "(Skipped — not on branch $STAGE_BRANCH. Switch to it to include verification.)"
  fi
  echo '```'
  echo
  echo "---"
  echo

  # ---------------------------------------------------------
  # Protected file check
  # ---------------------------------------------------------
  echo "## Protected File Check"
  echo
  echo '```'
  if [ "$STAGE_BRANCH" = "$CURRENT_BRANCH" ]; then
    check_protected_files "warn" 2>&1 || true
  else
    echo "(Skipped — not on branch $STAGE_BRANCH)"
  fi
  echo '```'
  echo
  echo "---"
  echo

  # ---------------------------------------------------------
  # Architecture boundary check
  # ---------------------------------------------------------
  echo "## Scope Boundary Analysis"
  echo
  CHANGED_FILES="$(git diff --name-only "${DIFF_BASE}..${DIFF_REF}" 2>/dev/null || true)"

  if [ -n "$CHANGED_FILES" ] && [ -n "$PKG" ]; then
    OUTSIDE_SCOPE=""
    while IFS= read -r file; do
      [ -z "$file" ] && continue
      # Allow: target package, .ai/, CURRENT_STAGE.md, settings.gradle.kts, docs/, scripts/
      case "$file" in
        "${PKG}/"*) ;;
        .ai/*) ;;
        CURRENT_STAGE.md) ;;
        settings.gradle.kts) ;;
        docs/*) ;;
        scripts/*) ;;
        ROADMAP.md) ;;
        TEST_REPORT.md) ;;
        KNOWN_ISSUES.md) ;;
        *) OUTSIDE_SCOPE="${OUTSIDE_SCOPE}${file}\n" ;;
      esac
    done <<< "$CHANGED_FILES"

    if [ -n "$OUTSIDE_SCOPE" ]; then
      echo "WARNING: Files changed outside expected scope ($PKG):"
      echo
      echo '```'
      echo -e "$OUTSIDE_SCOPE"
      echo '```'
    else
      echo "PASS — All changes are within expected scope."
      echo "  Primary package: $PKG"
      echo "  Also allowed: settings.gradle.kts (module registration), CURRENT_STAGE.md (stage lifecycle)"
    fi
  else
    echo "No changed files to check or no package defined."
  fi
  echo
  echo "---"
  echo

  # ---------------------------------------------------------
  # Current stage context
  # ---------------------------------------------------------
  echo "## Current Stage File"
  echo
  [ -f CURRENT_STAGE.md ] && cat CURRENT_STAGE.md || echo "(missing)"
  echo
  echo "---"
  echo

  echo "## Known Issues"
  echo
  [ -f KNOWN_ISSUES.md ] && cat KNOWN_ISSUES.md || echo "(none)"
  echo

} > "$OUT_FILE"

echo "Post-review bundle written to: $OUT_FILE"
echo
echo "Share this file with:"
echo "  - ChatGPT for architectural review"
echo "  - Gemini for red-team review"
echo
echo "Quick copy (macOS):"
echo "  cat $OUT_FILE | pbcopy"
