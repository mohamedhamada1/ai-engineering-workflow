#!/usr/bin/env bash
set -euo pipefail
export GIT_PAGER=cat
source "$(dirname "$0")/ai-common.sh"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# ---------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------
RESUME=false
START_FROM=""

while [ $# -gt 0 ]; do
  case "$1" in
    --resume)  RESUME=true; shift ;;
    --from)    START_FROM="${2:-}"; shift 2 ;;
    *)         echo "Unknown option: $1"; exit 1 ;;
  esac
done

PACKAGE_REL="$(stage_package_dir)"
STAGE_ID="$(current_stage_id)"
CHECKPOINT_FILE=".ai/execute_checkpoint"

# ---------------------------------------------------------
# Checkpoint helpers
# ---------------------------------------------------------
save_checkpoint() {
  local step="$1"
  echo "$step" > "$CHECKPOINT_FILE"
}

read_checkpoint() {
  if [ -f "$CHECKPOINT_FILE" ]; then
    cat "$CHECKPOINT_FILE"
  else
    echo "0"
  fi
}

clear_checkpoint() {
  rm -f "$CHECKPOINT_FILE"
}

should_run_step() {
  local step="$1"
  [ "$step" -ge "$RESUME_FROM" ]
}

# ---------------------------------------------------------
# Determine starting step
# ---------------------------------------------------------
RESUME_FROM=0

if [ -n "$START_FROM" ]; then
  RESUME_FROM="$START_FROM"
  echo "Starting from step $RESUME_FROM (--from)"
elif [ "$RESUME" = true ] && [ -f "$CHECKPOINT_FILE" ]; then
  LAST_COMPLETED="$(read_checkpoint)"
  RESUME_FROM=$((LAST_COMPLETED + 1))
  if [ "$RESUME_FROM" -gt 4 ]; then
    echo "All steps already completed. Use without --resume to re-run."
    exit 0
  fi
  echo "Resuming from step $RESUME_FROM (last completed: $LAST_COMPLETED)"
else
  # Fresh run — clear any stale checkpoint
  clear_checkpoint
fi

# ---------------------------------------------------------
# Pre-execute validation
# ---------------------------------------------------------
echo "========================================="
echo " Stage Execution — Full Pipeline"
echo "========================================="
echo "Stage ID: $STAGE_ID"
echo "Package: $PACKAGE_REL"

if should_run_step 0; then
  echo
  echo "Validating .ai artifacts..."

  MISSING_ARTIFACTS=()
  SPEC="$(stage_spec_path)"
  PLAN="$(stage_plan_path)"
  REVIEW="$(stage_review_path)"
  IMPL="$(stage_implementation_path)"

  [ -z "$SPEC" ] || [ ! -s "$SPEC" ] && MISSING_ARTIFACTS+=("spec")
  [ -z "$PLAN" ] || [ ! -s "$PLAN" ] && MISSING_ARTIFACTS+=("plan")
  [ -z "$REVIEW" ] || [ ! -s "$REVIEW" ] && MISSING_ARTIFACTS+=("review")
  [ -z "$IMPL" ] || [ ! -s "$IMPL" ] && MISSING_ARTIFACTS+=("implementation")

  if [ ${#MISSING_ARTIFACTS[@]} -gt 0 ]; then
    echo "  ERROR: Missing or empty artifacts: ${MISSING_ARTIFACTS[*]}"
    echo "  All 4 artifacts (spec, plan, review, implementation) are required."
    echo "  To fix: re-import with ./scripts/ai-run.sh --import-chatgpt tmp/chatgpt.md"
    echo
    exit 1
  else
    echo "  All 4 artifacts present (spec, plan, review, implementation)"
  fi
fi

echo
echo "Pipeline steps:"
echo "  [1/4] Claude Full Pipeline (preflight → implement → diff review → stabilize → PR check)"
echo "  [2/4] Verification (build + test) → auto-updates TEST_REPORT.md"
echo "  [3/4] Commit + Push"
echo "  [4/4] Generate post-review bundle"
echo
echo "Hard rule: all 4 steps must complete. The pipeline fails loudly on incomplete execution."

# ---------------------------------------------------------
# Step 0: Update status to In Progress
# ---------------------------------------------------------
if should_run_step 0; then
  echo
  echo "[0/4] Updating status to In Progress..."

  cat > CURRENT_STAGE.md <<EOF
# Current Stage

Stage: $STAGE_ID

Status: In Progress

Package: $PACKAGE_REL
EOF
fi

# ---------------------------------------------------------
# Step 1: Claude Full Pipeline (single session)
#   Covers: preflight → implement → diff review → stabilize → PR check
#   Hard rule: Claude must complete all steps in one uninterrupted run.
# ---------------------------------------------------------
if should_run_step 1; then
  echo
  echo "[1/4] Running Claude Full Pipeline (preflight → implement → diff review → stabilize → PR check)..."
  CLAUDE_EXIT=0
  if ! ./scripts/ai-run.sh --claude-all; then
    CLAUDE_EXIT=$?
    echo
    echo "WARN: Claude full pipeline returned non-zero exit code ($CLAUDE_EXIT)."
    echo "Proceeding to verification to assess state..."
  fi
  save_checkpoint 1
fi

# ---------------------------------------------------------
# Step 2: Verification (build + test) + auto TEST_REPORT.md
# ---------------------------------------------------------
if should_run_step 2; then
  echo
  echo "[2/4] Running Verification..."

  VERIFY_OUTPUT="$(mktemp)"
  VERIFY_EXIT=0
  ./scripts/ai-verify-stage.sh --full 2>&1 | tee "$VERIFY_OUTPUT" || VERIFY_EXIT=$?

  # Auto-update TEST_REPORT.md with results
  STAGE_NAME="$(current_stage_name)"
  TODAY="$(date +%Y-%m-%d)"
  BUILD_SYS="$(detect_build_system "$PACKAGE_REL")"

  # Count tests if Gradle output is available
  TEST_COUNT=""
  if [ "$BUILD_SYS" = "gradle" ]; then
    TEST_COUNT="$(grep -oE '[0-9]+ tests?' "$VERIFY_OUTPUT" | tail -1 || true)"
  fi

  if [ "$VERIFY_EXIT" -eq 0 ]; then
    RESULT="PASS"
    RESULT_DETAIL="${TEST_COUNT:+$TEST_COUNT, }full build passes"
  else
    RESULT="FAIL"
    RESULT_DETAIL="see verification output"
  fi

  # Determine test command
  case "$BUILD_SYS" in
    gradle)
      GRADLE_PKG=":$(echo "$PACKAGE_REL" | tr '/' ':')"
      TEST_CMD="./gradlew ${GRADLE_PKG}:test" ;;
    openapi)
      TEST_CMD="OpenAPI contract validation" ;;
    *)
      TEST_CMD="./scripts/ai-verify-stage.sh" ;;
  esac

  # Build the new latest run section
  NEW_LATEST="## Latest Run
- Date: $TODAY
- Stage: $STAGE_ID
- Package: \`$PACKAGE_REL\`
- Result: $RESULT ($RESULT_DETAIL)
- Command: \`$TEST_CMD\`
- Mode: Full (automated by stage-execute)"

  # Build the history line
  HISTORY_LINE="| $TODAY | $STAGE_ID | $RESULT | ${STAGE_NAME:-implementation} — $RESULT_DETAIL |"

  if [ -f TEST_REPORT.md ]; then
    # Update existing file: replace Latest Run section, prepend history line
    TEMP_REPORT="$(mktemp)"
    LATEST_TMP="$(mktemp)"
    echo "$NEW_LATEST" > "$LATEST_TMP"

    awk -v latest_file="$LATEST_TMP" -v hist_line="$HISTORY_LINE" '
      /^## Latest Run/ {
        in_latest=1
        while ((getline line < latest_file) > 0) print line
        close(latest_file)
        next
      }
      in_latest && /^## / { in_latest=0; print ""; print $0; next }
      in_latest { next }
      /^## History/ { print; getline; print; getline; print; print hist_line; next }
      { print }
    ' TEST_REPORT.md > "$TEMP_REPORT"

    rm -f "$LATEST_TMP"
    mv "$TEMP_REPORT" TEST_REPORT.md
  else
    # Create new TEST_REPORT.md
    cat > TEST_REPORT.md <<REPORT_EOF
# Test Report

$NEW_LATEST

## History
| Date | Stage | Result | Notes |
|------|-------|--------|-------|
$HISTORY_LINE

## Known Open Issues
- None
REPORT_EOF
  fi

  echo
  echo "  TEST_REPORT.md updated ($RESULT)"

  rm -f "$VERIFY_OUTPUT"
  save_checkpoint 2
fi

# ---------------------------------------------------------
# Step 3: Commit implementation to branch
# ---------------------------------------------------------
if should_run_step 3; then
  echo
  echo "[3/4] Committing implementation to branch..."

  STAGE_NAME="$(current_stage_name)"

  # Stage the target package files (source + test + build config)
  if [ -n "$PACKAGE_REL" ] && [ -d "$PACKAGE_REL" ]; then
    if [ -d "$PACKAGE_REL/src" ]; then
      # Gradle/standard package — stage source + build config
      safe_git_add "$PACKAGE_REL/src/" "$PACKAGE_REL/build.gradle.kts"
    else
      # Non-Gradle package (e.g. OpenAPI contracts) — stage all files
      safe_git_add "$PACKAGE_REL/"
    fi
  fi

  # Stage settings.gradle.kts if it changed (new module wiring)
  if ! git diff --quiet settings.gradle.kts 2>/dev/null || git ls-files --others --exclude-standard settings.gradle.kts 2>/dev/null | grep -q .; then
    safe_git_add settings.gradle.kts
  fi

  # Stage artifact files updated during implementation
  safe_git_add CURRENT_STAGE.md TEST_REPORT.md KNOWN_ISSUES.md

  if git diff --cached --quiet; then
    echo "  No new changes to commit."
  else
    COMMIT_MSG="feat(stage-${STAGE_ID}): implement stage ${STAGE_ID} — ${STAGE_NAME:-implementation}"
    echo "  Committing: $COMMIT_MSG"
    git commit -m "$COMMIT_MSG"

    # Push to remote so work is preserved and branch is shareable for review
    CURRENT_BRANCH="$(git branch --show-current)"
    echo "  Pushing $CURRENT_BRANCH..."
    git push origin "$CURRENT_BRANCH" 2>/dev/null || git push -u origin "$CURRENT_BRANCH" 2>/dev/null || echo "  WARN: push failed — continuing locally"
  fi
  save_checkpoint 3
fi

# ---------------------------------------------------------
# Step 4: Generate post-review bundle for ChatGPT/Gemini
# ---------------------------------------------------------
if should_run_step 4; then
  echo
  echo "[4/4] Generating post-review bundle..."
  ./scripts/ai-stage-post-review.sh || echo "  WARN: Post-review bundle generation failed — you can regenerate with: ./scripts/ai-run.sh --post-review"
  save_checkpoint 4
fi

# ---------------------------------------------------------
# Completion validation — fail loudly on incomplete execution
# ---------------------------------------------------------
INCOMPLETE=()

# Check: TEST_REPORT.md should have been updated by step 2
if [ ! -f TEST_REPORT.md ]; then
  INCOMPLETE+=("TEST_REPORT.md missing — verification step may not have run")
fi

# Check: there should be a commit on this branch for this stage
LATEST_COMMIT_MSG="$(git log -1 --format=%s 2>/dev/null || true)"
if [[ "$LATEST_COMMIT_MSG" != *"stage-${STAGE_ID}"* ]] && [[ "$LATEST_COMMIT_MSG" != *"stage ${STAGE_ID}"* ]]; then
  INCOMPLETE+=("No commit found for stage ${STAGE_ID} — commit step may not have run")
fi

# Check: post-review bundle should exist (versioned dirs, flat dir, or legacy review_bundles)
BUNDLE_PATTERN_VERSIONED=".ai/reviews/stage_${STAGE_ID//./_}/v*/post_review.md"
BUNDLE_PATTERN_FLAT=".ai/reviews/stage_${STAGE_ID//./_}/post_review_${STAGE_ID//./_}_*.md"
BUNDLE_PATTERN_LEGACY=".ai/review_bundles/post_review_${STAGE_ID//./_}_*.md"
BUNDLE_COUNT="$(( $(ls $BUNDLE_PATTERN_VERSIONED 2>/dev/null | wc -l | tr -d ' ') + $(ls $BUNDLE_PATTERN_FLAT 2>/dev/null | wc -l | tr -d ' ') + $(ls $BUNDLE_PATTERN_LEGACY 2>/dev/null | wc -l | tr -d ' ') ))"
if [ "$BUNDLE_COUNT" -eq 0 ]; then
  INCOMPLETE+=("No post-review bundle found — post-review step may not have run")
fi

if [ ${#INCOMPLETE[@]} -gt 0 ]; then
  echo
  echo "========================================="
  echo " INCOMPLETE EXECUTION DETECTED"
  echo "========================================="
  echo
  echo "A stage-execute run is not complete unless all 4 steps are finished."
  echo "The following checks failed:"
  echo
  for item in "${INCOMPLETE[@]}"; do
    echo "  - $item"
  done
  echo
  echo "To resume from where it stopped:"
  echo "  ./scripts/ai-run.sh --stage-execute --resume"
  echo
  # Do NOT clear checkpoint so --resume works
  exit 1
fi

# Clear checkpoint on successful completion
clear_checkpoint

echo
echo "========================================="
echo " Stage Execution Complete — Running Post-Checks"
echo "========================================="
echo

# --- Auto: Post-Review Bundle (first — creates new version folder) ---
echo "[post-1/3] Generating post-review bundle..."
if [[ -x "$SCRIPT_DIR/ai-stage-post-review.sh" ]]; then
  "$SCRIPT_DIR/ai-stage-post-review.sh" || echo "WARN: Post-review bundle generation failed"
else
  echo "WARN: ai-stage-post-review.sh not found — skipping"
fi
echo

# --- Auto: Conformance Check (joins same version folder) ---
echo "[post-2/3] Running spec-to-code conformance check..."
CONFORMANCE_PASS=true
if [[ -x "$SCRIPT_DIR/ai-verify-conformance.sh" ]]; then
  if ! "$SCRIPT_DIR/ai-verify-conformance.sh"; then
    CONFORMANCE_PASS=false
    echo ""
    echo "  ⚠ Conformance check found issues. Review the report above."
    echo "  These should be addressed before external review."
  fi
else
  echo "WARN: ai-verify-conformance.sh not found — skipping"
fi
echo

# --- Auto: Reality Sync (joins same version folder) ---
echo "[post-3/3] Generating reality sync snapshot..."
if [[ -x "$SCRIPT_DIR/ai-generate-reality-sync.sh" ]]; then
  "$SCRIPT_DIR/ai-generate-reality-sync.sh" || echo "WARN: Reality sync failed"
else
  echo "WARN: ai-generate-reality-sync.sh not found — skipping"
fi
echo

# --- Auto-commit post-check artifacts ---
echo "[post-commit] Committing post-check artifacts..."
STAGE_SLUG_POST="${STAGE_ID//./_}"
REVIEW_DIR=".ai/reviews/stage_${STAGE_SLUG_POST}"

if [ -d "$REVIEW_DIR" ]; then
  # Add all version folders and their contents
  find "$REVIEW_DIR" -type f 2>/dev/null | while IFS= read -r f; do
    safe_git_add "$f"
  done

  if ! git diff --cached --quiet 2>/dev/null; then
    git commit -m "chore(stage-${STAGE_ID}): post-execution artifacts (conformance + review + sync)"
    echo "  Committed post-check artifacts."
    git push origin "$(git branch --show-current)" 2>/dev/null || echo "  WARN: Push failed — push manually"
  else
    echo "  No new artifacts to commit."
  fi
fi
echo

# --- Summary ---
echo "========================================="
echo " All Done — Ready for External Review"
echo "========================================="
echo
if [ "$CONFORMANCE_PASS" = true ]; then
  echo "  ✓ Conformance: PASS"
else
  echo "  ⚠ Conformance: ISSUES FOUND (review report)"
fi
echo
echo "  Next steps:"
echo "    ai gpt                    # copy context for ChatGPT review"
echo "    ai done $STAGE_ID              # after GO from reviewers"
echo "    ai revise \"feedback\"       # if GO WITH CHANGES"
echo
