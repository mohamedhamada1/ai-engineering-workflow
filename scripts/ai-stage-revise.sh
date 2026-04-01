#!/usr/bin/env bash
set -euo pipefail
export GIT_PAGER=cat
source "$(dirname "$0")/ai-common.sh"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

ARG1="${1:-}"
ARG2="${2:-}"

# Support: --file path/to/feedback.md  OR  "inline feedback string"
if [ "$ARG1" = "--file" ] && [ -n "$ARG2" ]; then
  if [ ! -f "$ARG2" ]; then
    echo "Error: feedback file not found: $ARG2"
    exit 1
  fi
  FEEDBACK="$(cat "$ARG2")"
elif [ -n "$ARG1" ] && [ "$ARG1" != "--file" ]; then
  FEEDBACK="$ARG1"
else
  echo "Usage:"
  echo "  ./scripts/ai-stage-revise.sh --file feedback.md"
  echo "  ./scripts/ai-stage-revise.sh \"short inline feedback\""
  echo
  echo "Examples:"
  echo "  ./scripts/ai-stage-revise.sh --file /tmp/chatgpt_feedback.md"
  echo "  ./scripts/ai-stage-revise.sh \"fulfillmentTargetId should be a value class\""
  exit 1
fi

require_git_repo

STAGE_ID="$(current_stage_id)"
STAGE_NAME="$(current_stage_name)"
PACKAGE_REL="$(stage_package_dir || true)"

echo "========================================="
echo " Stage Revision: $STAGE_ID"
echo "========================================="
echo "  Feedback: $FEEDBACK"
echo "  Package: $PACKAGE_REL"
echo

# ---------------------------------------------------------
# Step 1: Run Claude with feedback context
# ---------------------------------------------------------
echo "[1/4] Running Claude with revision feedback..."

require_stage_files

tmp="$(mktemp)"

# Build context
{
  echo "### Project Context Bundle"
  echo
  echo "### Current Stage"
  echo "Stage ID: $STAGE_ID"
  echo "Status: $(current_stage_status)"
  echo
  [ -f "docs/AI_PROJECT_CONTEXT.md" ] && cat "docs/AI_PROJECT_CONTEXT.md"
  echo
  [ -f "docs/AI_REPO_BRAIN.md" ] && cat "docs/AI_REPO_BRAIN.md"
  echo
  [ -f "docs/AI_WORKFLOW.md" ] && cat "docs/AI_WORKFLOW.md"
  echo
  [ -f "ROADMAP.md" ] && cat "ROADMAP.md"
  echo
  [ -f "CURRENT_STAGE.md" ] && cat "CURRENT_STAGE.md"
  echo
  [ -f "KNOWN_ISSUES.md" ] && cat "KNOWN_ISSUES.md"
  echo

  # Include spec/plan/review
  SPEC="$(stage_spec_path)"
  PLAN="$(stage_plan_path)"
  REVIEW="$(stage_review_path)"
  IMPL="$(stage_implementation_path)"

  echo "### Latest Spec"
  echo
  [ -n "$SPEC" ] && [ -f "$SPEC" ] && cat "$SPEC" || echo "No spec found."
  echo
  echo "### Latest Plan"
  echo
  [ -n "$PLAN" ] && [ -f "$PLAN" ] && cat "$PLAN" || echo "No plan found."
  echo
  echo "### Latest Review"
  echo
  [ -n "$REVIEW" ] && [ -f "$REVIEW" ] && cat "$REVIEW" || echo "No review found."
  echo
  echo "### Latest Implementation Request"
  echo
  [ -n "$IMPL" ] && [ -f "$IMPL" ] && cat "$IMPL" || echo "No implementation request found."
  echo

  # Include current diff so Claude knows what exists
  echo "### Current Implementation Diff (committed)"
  echo
  echo '```diff'
  BASE_BRANCH="$(detect_base_branch)"
  DIFF_BASE="$(resolve_diff_base "$BASE_BRANCH" "HEAD" "$STAGE_ID")"
  if [ -n "$PACKAGE_REL" ]; then
    git diff "${DIFF_BASE}..HEAD" -- "$PACKAGE_REL/" settings.gradle.kts 2>/dev/null || true
  else
    git diff "${DIFF_BASE}..HEAD" 2>/dev/null || true
  fi
  echo '```'
  echo

  # Also include uncommitted working tree changes (from prior revision rounds)
  UNCOMMITTED=""
  if [ -n "$PACKAGE_REL" ]; then
    UNCOMMITTED="$(git diff -- "$PACKAGE_REL/" settings.gradle.kts TEST_REPORT.md KNOWN_ISSUES.md 2>/dev/null || true)"
  else
    UNCOMMITTED="$(git diff 2>/dev/null || true)"
  fi

  if [ -n "$UNCOMMITTED" ]; then
    echo "### Uncommitted Changes (working tree)"
    echo
    echo '```diff'
    echo "$UNCOMMITTED"
    echo '```'
    echo
  fi

  # The revision task
  cat <<EOF
### Claude Task :: Revision

The implementation for Stage $STAGE_ID was reviewed by ChatGPT (architect) and/or Gemini (red-team).

**Reviewer feedback:**

$FEEDBACK

**Instructions:**

1. Read and understand the feedback above
2. Review the current implementation (see diff above)
3. Make ONLY the changes requested by the feedback
4. Do NOT expand scope beyond what the feedback requests
5. Do NOT refactor unrelated code
6. Ensure build and tests still pass after changes

If the feedback is unclear or conflicts with the spec, explain the conflict but still attempt a reasonable interpretation.
EOF
} > "$tmp"

if command -v claude >/dev/null 2>&1; then
  echo
  echo "=============================================="
  echo " Launching Claude Code (revision)"
  echo "=============================================="
  if claude < "$tmp"; then
    rm -f "$tmp"
  else
    echo "WARN: Claude exited with non-zero code"
    echo "Context preserved at: $tmp"
  fi
else
  echo "Error: Claude CLI not found in PATH." >&2
  rm -f "$tmp"
  exit 1
fi

# ---------------------------------------------------------
# Step 2: Verification
# ---------------------------------------------------------
echo
echo "[2/4] Running Verification..."
./scripts/ai-verify-stage.sh || true

# ---------------------------------------------------------
# Step 3: Commit revision
# ---------------------------------------------------------
echo
echo "[3/4] Committing revision..."

if [ -n "$PACKAGE_REL" ] && [ -d "$PACKAGE_REL" ]; then
  safe_git_add "$PACKAGE_REL/src/" "$PACKAGE_REL/build.gradle.kts"
fi

if ! git diff --quiet settings.gradle.kts 2>/dev/null; then
  safe_git_add settings.gradle.kts
fi

# Stage lifecycle files that revisions commonly touch
for lifecycle_file in CURRENT_STAGE.md TEST_REPORT.md KNOWN_ISSUES.md; do
  if [ -f "$lifecycle_file" ] && ! git diff --quiet "$lifecycle_file" 2>/dev/null; then
    safe_git_add "$lifecycle_file"
  fi
done

if git diff --cached --quiet; then
  echo "  No changes to commit."
else
  # Truncate feedback for commit message (max 72 chars)
  SHORT_FEEDBACK="$(echo "$FEEDBACK" | head -c 60)"
  COMMIT_MSG="fix(stage-${STAGE_ID}): revise — ${SHORT_FEEDBACK}"
  echo "  Committing: $COMMIT_MSG"
  git commit -m "$COMMIT_MSG"

  # Push so post-review bundles generated later pick up the revision
  CURRENT_BRANCH="$(git branch --show-current)"
  echo "  Pushing $CURRENT_BRANCH..."
  git push origin "$CURRENT_BRANCH" 2>&1 || echo "  WARN: push failed — bundle will still work locally"
fi

# ---------------------------------------------------------
# Step 4: Regenerate post-review bundle
# ---------------------------------------------------------
echo
echo "[4/4] Regenerating post-review bundle..."
./scripts/ai-stage-post-review.sh

echo
echo "========================================="
echo " Revision Complete"
echo "========================================="
echo
echo "Next command — copy updated post-review bundle for external review:"
echo
echo "  cat .ai/reviews/stage_${STAGE_ID//./_}/post_review_${STAGE_ID//./_}_*.md | pbcopy"
echo
echo "Then after ChatGPT + Gemini review:"
echo
echo "  GO           → ./scripts/ai-run.sh --complete-stage $STAGE_ID"
echo "  GO W/CHANGES → ./scripts/ai-run.sh --stage-revise \"more feedback\""
echo
