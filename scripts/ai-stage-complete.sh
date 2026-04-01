#!/usr/bin/env bash
set -euo pipefail
export GIT_PAGER=cat
source "$(dirname "$0")/ai-common.sh"

STAGE_ID="${1:-}"
DRY_RUN="${2:-}"

if [ -z "$STAGE_ID" ]; then
  echo "Usage: ./scripts/ai-stage-complete.sh <stage-id> [--dry-run]"
  exit 1
fi

require_git_repo

CURRENT_STAGE="$(current_stage_id)"
CURRENT_PACKAGE="$(stage_package_dir || true)"

if [ -z "$CURRENT_STAGE" ]; then
  echo "Could not detect current stage from CURRENT_STAGE.md"
  exit 1
fi

if [ "$STAGE_ID" != "$CURRENT_STAGE" ]; then
  echo "Stage mismatch: passed '$STAGE_ID' but CURRENT_STAGE.md says '$CURRENT_STAGE'"
  exit 1
fi

# ---------------------------------------------------------
# Idempotency check
# ---------------------------------------------------------
CURRENT_STATUS="$(current_stage_status)"
if [ "$CURRENT_STATUS" = "Complete" ]; then
  # Check if there are uncommitted changes — if so, we still need to
  # commit/push/merge even though the status file already says Complete.
  UNCOMMITTED="$(git status --porcelain 2>/dev/null || true)"
  if [ -z "$UNCOMMITTED" ]; then
    # Also check if we're already on main (fully merged)
    CURRENT_BRANCH="$(git branch --show-current)"
    if [ "$CURRENT_BRANCH" = "main" ]; then
      echo "Stage $STAGE_ID is already marked Complete and merged. Nothing to do."
      exit 0
    fi
  fi
  echo "Stage $STAGE_ID is marked Complete but has uncommitted changes or is not merged."
  echo "Continuing with commit/push/merge..."
fi

# ---------------------------------------------------------
# Resolve package (never use hardcoded fallback)
# ---------------------------------------------------------
if [ -z "${CURRENT_PACKAGE:-}" ]; then
  CURRENT_PACKAGE="$(resolve_package_for_stage "$STAGE_ID")"
fi

if [ -z "${CURRENT_PACKAGE:-}" ]; then
  echo "ERROR: Could not determine package for stage $STAGE_ID"
  echo "Set Package: in CURRENT_STAGE.md manually."
  exit 1
fi

echo "========================================="
echo " Stage Completion: $STAGE_ID"
echo "========================================="

# ---------------------------------------------------------
# Run verification
# ---------------------------------------------------------
echo
echo "Running verification..."
./scripts/ai-verify-stage.sh --quick || true

# ---------------------------------------------------------
# Guard: refuse to complete if package has uncommitted code
# (Skip this guard when status is already Complete — the script
#  will commit everything in the bundling step below.)
# ---------------------------------------------------------
if [ "$CURRENT_STATUS" != "Complete" ] && [ -n "${CURRENT_PACKAGE:-}" ] && [ -d "$CURRENT_PACKAGE" ]; then
  UNCOMMITTED_PKG="$(git status --porcelain "$CURRENT_PACKAGE" 2>/dev/null || true)"
  if [ -n "$UNCOMMITTED_PKG" ]; then
    echo
    echo "ERROR: Uncommitted files detected in package directory ($CURRENT_PACKAGE):"
    echo
    echo "$UNCOMMITTED_PKG" | while IFS= read -r line; do
      echo "  $line"
    done
    echo
    echo "Stage completion requires all implementation code to be committed."
    echo "Please commit your changes first, then re-run this script."
    echo
    echo "  git add $CURRENT_PACKAGE/"
    echo "  git commit -m 'feat(stage-${STAGE_ID}): implement ...'"
    echo "  ./scripts/ai-stage-complete.sh $STAGE_ID"
    exit 1
  fi
fi

if [ "$DRY_RUN" = "--dry-run" ]; then
  echo
  echo "DRY RUN — showing what would be changed without modifying files."
  echo
fi

# ---------------------------------------------------------
# 1) Update CURRENT_STAGE.md
# ---------------------------------------------------------
echo
echo "[1/6] Marking stage $STAGE_ID as Complete in CURRENT_STAGE.md..."

if [ "$DRY_RUN" != "--dry-run" ]; then
  cat > CURRENT_STAGE.md <<EOF
# Current Stage

Stage: $STAGE_ID

Status: Complete

Package: $CURRENT_PACKAGE
EOF
else
  echo "  (dry-run) Would write Status: Complete to CURRENT_STAGE.md"
fi

# ---------------------------------------------------------
# 2) Update ROADMAP.md — stage status + progress table
# ---------------------------------------------------------
echo
echo "[2/6] Updating ROADMAP.md..."

STAGE_ESCAPED="$(echo "$STAGE_ID" | sed 's/\./\\./g')"

# Check if already marked Complete in ROADMAP
if grep -q "^## Stage ${STAGE_ESCAPED} —" ROADMAP.md 2>/dev/null; then
  ROADMAP_STATUS="$(awk "/^## Stage ${STAGE_ESCAPED} —/,/^Status:/{print}" ROADMAP.md | grep '^Status:' | head -n1 | sed 's/Status: //')"

  if [ "$ROADMAP_STATUS" = "Complete" ]; then
    echo "  Stage already marked Complete in ROADMAP.md — skipping"
  elif [ "$DRY_RUN" != "--dry-run" ]; then
    sed_i "/^## Stage ${STAGE_ESCAPED} —/,/^Status:/{s/^Status: .*/Status: Complete/;}" ROADMAP.md

    # Determine which phase this stage belongs to
    PHASE=""
    case "$STAGE_ID" in
      0.*) PHASE="Phase 0 — Discovery" ;;
      1.*) PHASE="Phase 1 — Foundation" ;;
      2.*) PHASE="Phase 2 — Availability Core" ;;
      3.*) PHASE="Phase 3 — Booking Orchestration" ;;
      4.*) PHASE="Phase 4 — Commerce Ordering" ;;
      5.*) PHASE="Phase 5 — Platform Delivery" ;;
      6.*) PHASE="Phase 6 — HandyHub First Consumer" ;;
    esac

    if [ -n "$PHASE" ]; then
      LINE="$(grep -n "| $PHASE" ROADMAP.md | head -n1 || true)"

      if [ -n "$LINE" ]; then
        LINE_NUM="$(echo "$LINE" | cut -d: -f1)"
        LINE_CONTENT="$(echo "$LINE" | cut -d: -f2-)"

        STAGES="$(echo "$LINE_CONTENT" | awk -F'|' '{gsub(/ /,"",$3); print $3}')"
        COMPLETE="$(echo "$LINE_CONTENT" | awk -F'|' '{gsub(/ /,"",$4); print $4}')"
        REMAINING="$(echo "$LINE_CONTENT" | awk -F'|' '{gsub(/ /,"",$5); print $5}')"

        if [ "$REMAINING" -gt 0 ] 2>/dev/null; then
          NEW_COMPLETE=$((COMPLETE + 1))
          NEW_REMAINING=$((REMAINING - 1))
          sed_i "${LINE_NUM}s/| ${COMPLETE} | ${REMAINING} |/| ${NEW_COMPLETE} | ${NEW_REMAINING} |/" ROADMAP.md
          echo "  Updated phase row: $PHASE — $NEW_COMPLETE/$STAGES complete"
        else
          echo "  Phase $PHASE already shows 0 remaining — skipping table update"
        fi
      fi

      # Update the Total row
      TOTAL_LINE="$(grep -n '| \*\*Total\*\*' ROADMAP.md | head -n1 || true)"
      if [ -n "$TOTAL_LINE" ]; then
        TOTAL_LINE_NUM="$(echo "$TOTAL_LINE" | cut -d: -f1)"
        TOTAL_CONTENT="$(echo "$TOTAL_LINE" | cut -d: -f2-)"

        T_COMPLETE="$(echo "$TOTAL_CONTENT" | awk -F'|' '{gsub(/[ *]/,"",$4); print $4}')"
        T_REMAINING="$(echo "$TOTAL_CONTENT" | awk -F'|' '{gsub(/[ *]/,"",$5); print $5}')"

        if [ "$T_REMAINING" -gt 0 ] 2>/dev/null; then
          NEW_T_COMPLETE=$((T_COMPLETE + 1))
          NEW_T_REMAINING=$((T_REMAINING - 1))
          T_STAGES="$(echo "$TOTAL_CONTENT" | awk -F'|' '{gsub(/[ *]/,"",$3); print $3}')"
          sed_i "${TOTAL_LINE_NUM}s/.*/| **Total** | **${T_STAGES}** | **${NEW_T_COMPLETE}** | **${NEW_T_REMAINING}** |/" ROADMAP.md
          echo "  Updated total row: $NEW_T_COMPLETE/$T_STAGES complete"
        fi
      fi
    fi

    echo "  ROADMAP.md updated."
  else
    echo "  (dry-run) Would update ROADMAP.md status and progress table"
  fi
else
  echo "  WARN: Could not find stage ${STAGE_ID} section in ROADMAP.md"
fi

# ---------------------------------------------------------
# 3) Update docs/AI_REPO_BRAIN.md — stage line + phase header
# ---------------------------------------------------------
echo
echo "[3/6] Updating docs/AI_REPO_BRAIN.md..."

if [ -f docs/AI_REPO_BRAIN.md ] && [ "$DRY_RUN" != "--dry-run" ]; then
  STAGE_SHORT="${STAGE_ID}"
  BRAIN_LINE="$(grep -n "^- ${STAGE_SHORT} —" docs/AI_REPO_BRAIN.md | head -n1 || true)"

  if [ -n "$BRAIN_LINE" ]; then
    BRAIN_LINE_NUM="$(echo "$BRAIN_LINE" | cut -d: -f1)"
    BRAIN_CONTENT="$(echo "$BRAIN_LINE" | cut -d: -f2-)"

    if echo "$BRAIN_CONTENT" | grep -q '\*\*Planned\*\*'; then
      STAGE_NAME="$(echo "$BRAIN_CONTENT" | sed 's/^- [0-9.]* — //; s/ — \*\*Planned\*\*//')"
      PKG_SUBDIR=""
      if [ -n "${CURRENT_PACKAGE:-}" ]; then
        PKG_SUBDIR="$(basename "$CURRENT_PACKAGE")"
      fi
      if [ -n "$PKG_SUBDIR" ] && [ "$PKG_SUBDIR" != "$(echo "$CURRENT_PACKAGE" | tr -d '/')" ]; then
        NEW_BRAIN_LINE="- ${STAGE_SHORT} — ${STAGE_NAME} (${PKG_SUBDIR})"
      else
        NEW_BRAIN_LINE="- ${STAGE_SHORT} — ${STAGE_NAME} (${CURRENT_PACKAGE})"
      fi
      sed_i "${BRAIN_LINE_NUM}s|.*|${NEW_BRAIN_LINE}|" docs/AI_REPO_BRAIN.md
      echo "  Updated stage line in repo brain"
    else
      echo "  Stage line already updated in repo brain — skipping"
    fi
  else
    echo "  WARN: Could not find stage ${STAGE_SHORT} line in repo brain"
  fi

  # Update phase header if it contains a progress count
  PHASE_NUM="${STAGE_ID%%.*}"
  PHASE_HEADER_LINE="$(grep -n "^### Phase ${PHASE_NUM} —" docs/AI_REPO_BRAIN.md | head -n1 || true)"
  if [ -n "$PHASE_HEADER_LINE" ]; then
    PH_LINE_NUM="$(echo "$PHASE_HEADER_LINE" | cut -d: -f1)"
    PH_CONTENT="$(echo "$PHASE_HEADER_LINE" | cut -d: -f2-)"

    if echo "$PH_CONTENT" | grep -qE '\([0-9]+ of [0-9]+ Complete\)'; then
      PH_DONE="$(echo "$PH_CONTENT" | sed -E 's/.*\(([0-9]+) of ([0-9]+) Complete\).*/\1/')"
      PH_TOTAL="$(echo "$PH_CONTENT" | sed -E 's/.*\(([0-9]+) of ([0-9]+) Complete\).*/\2/')"
      PH_NEW_DONE=$((PH_DONE + 1))
      if [ "$PH_NEW_DONE" -ge "$PH_TOTAL" ]; then
        NEW_PH="$(echo "$PH_CONTENT" | sed -E "s/\([0-9]+ of [0-9]+ Complete\)/(All Complete)/")"
      else
        NEW_PH="$(echo "$PH_CONTENT" | sed -E "s/\([0-9]+ of [0-9]+ Complete\)/(${PH_NEW_DONE} of ${PH_TOTAL} Complete)/")"
      fi
      sed_i "${PH_LINE_NUM}s|.*|${NEW_PH}|" docs/AI_REPO_BRAIN.md
      echo "  Updated phase header in repo brain"
    fi
  fi

  echo "  docs/AI_REPO_BRAIN.md updated."
elif [ "$DRY_RUN" = "--dry-run" ]; then
  echo "  (dry-run) Would update docs/AI_REPO_BRAIN.md"
else
  echo "  WARN: docs/AI_REPO_BRAIN.md not found — skipping"
fi

# ---------------------------------------------------------
# 4) Commit and push
# ---------------------------------------------------------
if [ "$DRY_RUN" = "--dry-run" ]; then
  echo
  echo "DRY RUN complete. No files were modified."
  exit 0
fi

echo
echo "[4/6] Bundling stage artifacts..."

# Bundle all stage-related artifacts that may have been left uncommitted.
# This prevents leftover untracked/modified files from bleeding into the
# next stage branch.

STAGE_SLUG="$(echo "$STAGE_ID" | tr '.' '_')"
ARTIFACT_PATTERNS=(
  ".ai/specs/stage_${STAGE_SLUG}_*"
  ".ai/plans/stage_${STAGE_SLUG}_*"
  ".ai/reviews/stage_${STAGE_SLUG}_*"
  ".ai/reviews/stage_${STAGE_SLUG}/"
  ".ai/reviews/stage_${STAGE_SLUG}/v*/"
  ".ai/implementations/stage_${STAGE_SLUG}_*"
)

BUNDLED=0
for pattern in "${ARTIFACT_PATTERNS[@]}"; do
  # shellcheck disable=SC2086
  for f in $pattern; do
    if [ -f "$f" ]; then
      safe_git_add "$f" && BUNDLED=$((BUNDLED + 1))
    elif [ -d "$f" ]; then
      # Recurse into directories (e.g., v1/, v2/ version folders)
      while IFS= read -r df; do
        [ -z "$df" ] && continue
        safe_git_add "$df" && BUNDLED=$((BUNDLED + 1))
      done < <(find "$f" -type f 2>/dev/null)
    fi
  done
done

# Also pick up shared workflow artifacts that commonly change during a stage
for f in \
  .ai/stage_package_map.sh \
  scripts/ai-common.sh \
  scripts/ai-run.sh \
  scripts/ai-stage-execute.sh \
  scripts/ai-stage-post-review.sh \
  scripts/ai-stage-revise.sh \
  scripts/ai-verify-stage.sh \
  scripts/ai-import-chatgpt.sh \
  scripts/ai-stage-complete.sh \
  scripts/ai-update-context.sh \
  flow_commands.md \
  TEST_REPORT.md \
  tmp/chatgpt.md \
  tmp/feedback.md; do
  if [ -f "$f" ] && ! git check-ignore -q "$f" 2>/dev/null; then
    if ! git diff --quiet "$f" 2>/dev/null; then
      safe_git_add "$f" && BUNDLED=$((BUNDLED + 1))
    elif ! git ls-files --error-unmatch "$f" >/dev/null 2>&1; then
      safe_git_add "$f" && BUNDLED=$((BUNDLED + 1))
    fi
  fi
done

# Pick up the package directory itself (new or modified source files)
if [ -n "${CURRENT_PACKAGE:-}" ] && [ -d "$CURRENT_PACKAGE" ]; then
  safe_git_add "$CURRENT_PACKAGE/" && BUNDLED=$((BUNDLED + 1))
fi

# Pick up context/doc files that commonly change during a stage
for f in \
  docs/AI_PROJECT_CONTEXT.md \
  docs/AI_REPO_BRAIN.md \
  .ai/sessions/latest.md \
  .ai/review_bundles/ \
  .ai/reviews/stage_${STAGE_SLUG}/; do
  if [ -e "$f" ] && ! git check-ignore -q "$f" 2>/dev/null; then
    safe_git_add "$f" && BUNDLED=$((BUNDLED + 1))
  fi
done

echo "  Bundled $BUNDLED artifact/workflow files"

echo
echo "[5/6] Committing and pushing..."

# Stage specific files only
git add CURRENT_STAGE.md ROADMAP.md settings.gradle.kts 2>/dev/null || true
[ -f docs/AI_REPO_BRAIN.md ] && git add docs/AI_REPO_BRAIN.md

FEATURE_BRANCH="$(git branch --show-current)"

if git diff --cached --quiet; then
  echo "No staged changes to commit — all completion updates already committed."
else
  COMMIT_MSG="feat(stage-${STAGE_ID}): complete stage ${STAGE_ID}"

  echo
  echo "Committing: $COMMIT_MSG"
  git commit -m "$COMMIT_MSG"
fi

# Always push before merge to ensure remote is up to date
echo
echo "Pushing $FEATURE_BRANCH..."
git push origin "$FEATURE_BRANCH" 2>/dev/null || {
  echo "  Regular push failed (likely rebased). Trying force-with-lease..."
  git push --force-with-lease origin "$FEATURE_BRANCH"
}

# ---------------------------------------------------------
# 6) Merge feature branch into main
# ---------------------------------------------------------
echo
echo "[6/6] Merging $FEATURE_BRANCH into main..."

# Auto-resolve merge conflicts for safe files (AI artifacts, docs, stage metadata)
# Keeps the feature branch version for these files, which is always more up-to-date.
auto_resolve_safe_conflicts() {
  local conflicted
  conflicted="$(git diff --name-only --diff-filter=U 2>/dev/null || true)"
  if [ -z "$conflicted" ]; then
    return 0
  fi

  local resolved=0
  local blocked=0
  local safe_patterns=(".ai/" "docs/" "CURRENT_STAGE.md" "ROADMAP.md" "TEST_REPORT.md" "KNOWN_ISSUES.md" "flow_commands.md")

  while IFS= read -r file; do
    local is_safe=false
    for pattern in "${safe_patterns[@]}"; do
      if [[ "$file" == ${pattern}* || "$file" == "$pattern" ]]; then
        is_safe=true
        break
      fi
    done

    if $is_safe; then
      echo "  AUTO-RESOLVE (keep ours): $file"
      git checkout --theirs "$file" 2>/dev/null || git checkout --ours "$file" 2>/dev/null || true
      git add "$file"
      ((resolved++))
    else
      echo "  CONFLICT (needs manual resolution): $file"
      ((blocked++))
    fi
  done <<< "$conflicted"

  if [ "$blocked" -gt 0 ]; then
    echo ""
    echo "  ERROR: $blocked conflict(s) in code files require manual resolution."
    echo "  Resolve them, then run: git add <files> && git commit --no-edit"
    return 1
  fi

  if [ "$resolved" -gt 0 ]; then
    echo "  Auto-resolved $resolved safe file conflict(s)."
    git commit --no-edit
  fi
  return 0
}

# Try merge, auto-resolve safe conflicts if needed
do_local_merge() {
  git checkout main
  git pull origin main 2>/dev/null || true
  if git merge "$FEATURE_BRANCH" --no-ff -m "Merge $FEATURE_BRANCH into main" 2>/dev/null; then
    echo "  Merged cleanly."
  else
    echo "  Merge conflicts detected — attempting auto-resolution..."
    if auto_resolve_safe_conflicts; then
      echo "  Merge completed after auto-resolution."
    else
      echo "  BLOCKED: Manual conflict resolution required."
      echo "  After resolving: git add <files> && git commit --no-edit && git push origin main"
      exit 1
    fi
  fi
  git push origin main
}

# Check if gh CLI is available for PR-based merge
if command -v gh >/dev/null 2>&1; then
  echo "  Creating PR and merging via GitHub..."
  PR_URL="$(gh pr create \
    --base main \
    --head "$FEATURE_BRANCH" \
    --title "feat(stage-${STAGE_ID}): complete stage ${STAGE_ID}" \
    --body "Automated merge for stage ${STAGE_ID} completion." 2>/dev/null || true)"

  if [ -n "$PR_URL" ]; then
    echo "  PR created: $PR_URL"
    gh pr merge "$PR_URL" --merge --delete-branch 2>/dev/null || {
      echo "  WARN: Could not auto-merge PR. Falling back to local merge."
      do_local_merge
    }
  else
    echo "  WARN: Could not create PR. Falling back to local merge."
    do_local_merge
  fi
else
  # No gh CLI — do a local merge
  echo "  gh CLI not found — performing local merge"
  do_local_merge
fi

# Always ensure we end on main with latest code
CURRENT_AFTER="$(git branch --show-current)"
if [ "$CURRENT_AFTER" != "main" ]; then
  git checkout main
  git pull origin main 2>/dev/null || true
fi

# Clean up local feature branch (remote already deleted by gh --delete-branch or merged)
if [ "$FEATURE_BRANCH" != "main" ] && git show-ref --verify --quiet "refs/heads/$FEATURE_BRANCH" 2>/dev/null; then
  echo
  echo "Cleaning up local branch: $FEATURE_BRANCH"
  git branch -d "$FEATURE_BRANCH" 2>/dev/null || {
    echo "  WARN: Could not delete local branch (may have unmerged changes). Skipping."
  }
fi

# Clear any leftover execute checkpoint
rm -f .ai/execute_checkpoint

# ---------------------------------------------------------
# Stage diff summary
# ---------------------------------------------------------
echo
BASE_BRANCH="$(detect_base_branch)"
DIFF_BASE="$(resolve_diff_base "$BASE_BRANCH" "HEAD" "$STAGE_ID")"
DIFF_STAT="$(git diff --shortstat "${DIFF_BASE}..HEAD" 2>/dev/null || true)"

echo "========================================="
echo " Stage $STAGE_ID Complete"
echo "========================================="
echo
echo "Updated files:"
echo "  - CURRENT_STAGE.md (Status: Complete)"
echo "  - ROADMAP.md (stage status + progress table)"
echo "  - docs/AI_REPO_BRAIN.md (stage line + phase header)"
if [ -n "$DIFF_STAT" ]; then
  echo
  echo "Stage diff summary:"
  echo "  Package: ${CURRENT_PACKAGE}"
  echo "  $DIFF_STAT"
fi
echo
echo "Branch merged into main. You are now on main."
echo
echo "Next command — start the next stage:"
echo
echo "  ./scripts/ai-run.sh --stage-start <next-stage-id>"
echo
echo "  Dashboard: ./scripts/ai-run.sh --stage-status --all"
echo
