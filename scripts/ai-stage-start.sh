#!/usr/bin/env bash
set -euo pipefail
export GIT_PAGER=cat
source "$(dirname "$0")/ai-common.sh"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ---------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------
STAGE_ID=""
IMPORT_FILE=""
FLAGS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --import)
      IMPORT_FILE="${2:-}"
      if [ -z "$IMPORT_FILE" ]; then
        echo "Error: --import requires a file path"
        exit 1
      fi
      shift 2
      ;;
    --paste)
      if ! command -v pbpaste >/dev/null 2>&1; then
        echo "Error: pbpaste not found (macOS only). Use --import <file> instead."
        exit 1
      fi
      IMPORT_FILE="$(mktemp)"
      pbpaste > "$IMPORT_FILE"
      echo "Captured clipboard to temp file"
      shift
      ;;
    --no-push|--force)
      FLAGS+=("$1")
      shift
      ;;
    -*)
      echo "Unknown option: $1"
      exit 1
      ;;
    *)
      if [ -z "$STAGE_ID" ]; then
        STAGE_ID="$1"
      else
        FLAGS+=("$1")
      fi
      shift
      ;;
  esac
done

if [ -z "$STAGE_ID" ]; then
  cat <<'EOF'
Usage: ./scripts/ai-stage-start.sh <stage-id> [options]

Options:
  --import <file>   Import ChatGPT output from a file into .ai/ artifacts
  --paste           Import ChatGPT output from clipboard (macOS pbpaste)
  --no-push         Skip pushing to remote after commit
  --force           Skip uncommitted artifact check

If tmp/chatgpt.md exists, it is auto-imported (no --import needed).

Examples:
  # Auto-import from tmp/chatgpt.md
  pbpaste > tmp/chatgpt.md
  ./scripts/ai-stage-start.sh 0.3

  # Explicit import from a file
  ./scripts/ai-stage-start.sh 0.3 --import path/to/output.md

  # Import from clipboard
  ./scripts/ai-stage-start.sh 0.3 --paste
EOF
  exit 1
fi

HAS_FLAG() { [[ " ${FLAGS[*]:-} " == *" $1 "* ]]; }

require_git_repo

# ---------------------------------------------------------
# Check previous stage is complete and merged to main
# ---------------------------------------------------------
PREV_STATUS="$(current_stage_status)"
PREV_STAGE="$(current_stage_id)"

if [ -n "$PREV_STATUS" ] && [ "$PREV_STATUS" != "Complete" ] && [ -n "$PREV_STAGE" ] && [ "$PREV_STAGE" != "$STAGE_ID" ]; then
  echo "ERROR: Previous stage $PREV_STAGE has status '$PREV_STATUS' (not Complete)"
  echo "Complete the previous stage first: ./scripts/ai-run.sh --complete-stage $PREV_STAGE"
  echo
  echo "Override? (y/N)"
  read -r CONFIRM
  if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "Aborted."
    exit 1
  fi
fi

# Verify previous stage was actually merged to main
if [ -n "$PREV_STAGE" ] && [ "$PREV_STAGE" != "$STAGE_ID" ]; then
  # Fetch latest main to check merge status
  git fetch origin main 2>/dev/null || true

  # Check if main contains a completion commit for the previous stage
  PREV_MERGED="$(git log --oneline origin/main --grep="complete stage ${PREV_STAGE}\|Merge.*stage-${PREV_STAGE}" 2>/dev/null | head -1 || true)"

  if [ -z "$PREV_MERGED" ]; then
    echo "WARNING: Previous stage $PREV_STAGE does not appear to be merged to main."
    echo "The new branch may not include the previous stage's code."
    echo
    echo "Continue anyway? (y/N)"
    read -r CONFIRM
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
      echo "Aborted. Merge stage $PREV_STAGE to main first."
      exit 1
    fi
  else
    echo "Previous stage $PREV_STAGE confirmed merged to main."
  fi
fi

# ---------------------------------------------------------
# Guard: refuse to start if stage artifacts are uncommitted
# ---------------------------------------------------------
NEW_STAGE_SLUG="$(echo "$STAGE_ID" | tr '.' '_')"
DIRTY_ARTIFACTS=()
NEW_STAGE_ARTIFACTS=()

# Check .ai/, scripts/, tmp/, and common docs for uncommitted files.
# Files that belong to the NEW stage (matching its slug) are allowed —
# they were created in preparation (e.g. spec imported from ChatGPT).
while IFS= read -r f; do
  [ -z "$f" ] && continue
  # Allow .ai/ files whose name matches the stage being started
  if echo "$f" | grep -qE "^\.ai/.*/stage_${NEW_STAGE_SLUG}_"; then
    NEW_STAGE_ARTIFACTS+=("$f")
  # Allow tmp/ files — these are scratch/input files for the new stage
  elif echo "$f" | grep -qE "^tmp/"; then
    NEW_STAGE_ARTIFACTS+=("$f")
  else
    DIRTY_ARTIFACTS+=("$f")
  fi
done < <(git status --porcelain .ai/ scripts/ tmp/ flow_commands.md TEST_REPORT.md 2>/dev/null | awk '{print $2}')

if [ ${#NEW_STAGE_ARTIFACTS[@]} -gt 0 ]; then
  echo "Detected ${#NEW_STAGE_ARTIFACTS[@]} file(s) for new stage $STAGE_ID (will be included in initial commit):"
  for f in "${NEW_STAGE_ARTIFACTS[@]}"; do
    echo "  $f"
  done
fi

if [ ${#DIRTY_ARTIFACTS[@]} -gt 0 ]; then
  echo
  echo "Auto-committing ${#DIRTY_ARTIFACTS[@]} uncommitted artifact(s) from previous stage:"
  for f in "${DIRTY_ARTIFACTS[@]}"; do
    echo "  $f"
    safe_git_add "$f"
  done
  git commit -m "chore: commit outstanding artifacts before stage ${STAGE_ID}"
  echo "  Committed."
fi

# ---------------------------------------------------------
# Resolve package directory from stage ID
# ---------------------------------------------------------
PACKAGE_DIR="$(resolve_package_for_stage "$STAGE_ID" 2>/dev/null || true)"

if [ -z "$PACKAGE_DIR" ]; then
  # Try to infer from ROADMAP stage name
  STAGE_ESCAPED_PKG="$(echo "$STAGE_ID" | sed 's/\./\\./g')"
  ROADMAP_NAME="$(grep -m1 "^## Stage ${STAGE_ESCAPED_PKG} —" ROADMAP.md 2>/dev/null \
    | sed "s/^## Stage ${STAGE_ESCAPED_PKG} — //" || true)"

  if [ -n "$ROADMAP_NAME" ]; then
    # Convert "Vendor Onboarding Flow" → "vendor_onboarding_flow"
    INFERRED="packages/$(echo "$ROADMAP_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | tr -cd '[:alnum:]_')"
    echo "Auto-inferred package from ROADMAP: $INFERRED"
    PACKAGE_DIR="$INFERRED"
  else
    echo "WARNING: Could not resolve package for stage $STAGE_ID"
    echo "Enter package directory (e.g., packages/my_package):"
    read -r PACKAGE_DIR
  fi

  # Persist the mapping so it never prompts again
  if [ -n "$PACKAGE_DIR" ]; then
    persist_stage_mapping "$STAGE_ID" "$PACKAGE_DIR"
  fi
fi

echo "========================================="
echo " Starting Stage $STAGE_ID"
echo "========================================="
echo

# ---------------------------------------------------------
# 1) Update CURRENT_STAGE.md
# ---------------------------------------------------------
echo "[1/5] Updating CURRENT_STAGE.md..."

cat > CURRENT_STAGE.md <<EOF
# Current Stage

Stage: $STAGE_ID

Status: Planning

Package: $PACKAGE_DIR
EOF

echo "  Stage: $STAGE_ID"
echo "  Package: $PACKAGE_DIR"

# ---------------------------------------------------------
# 2) Import ChatGPT output into .ai/ artifact files
# ---------------------------------------------------------
echo
echo "[2/5] Importing ChatGPT artifacts..."

# Auto-detect tmp/chatgpt.md if no explicit --import or --paste was given
if [ -z "$IMPORT_FILE" ] && [ -f tmp/chatgpt.md ] && [ -s tmp/chatgpt.md ]; then
  IMPORT_FILE="tmp/chatgpt.md"
  echo "  Auto-detected: tmp/chatgpt.md"
fi

IMPORT_COUNT=0

if [ -n "$IMPORT_FILE" ] && [ -f "$IMPORT_FILE" ] && [ -s "$IMPORT_FILE" ]; then
  echo "  Importing from: $IMPORT_FILE"

  # Delegate to the shared import script
  "$SCRIPT_DIR/ai-import-chatgpt.sh" "$IMPORT_FILE" || true

  # Count how many artifact files were created for this stage
  STAGE_SLUG="$(echo "$STAGE_ID" | tr '.' '_')"
  IMPORT_COUNT=$(find .ai/specs .ai/plans .ai/reviews .ai/implementations -maxdepth 1 -type f -name "stage_${STAGE_SLUG}_*" 2>/dev/null | wc -l | tr -d ' ')

  # ---------------------------------------------------------
  # Reconcile ROADMAP title with spec title
  # The spec (from ChatGPT) is authoritative for the stage name.
  # If ROADMAP has a different title, update it now so the branch
  # name, commit messages, and future lookups are all consistent.
  # ---------------------------------------------------------
  STAGE_NAME_RAW="$(grep -m1 -oE "Stage ${STAGE_ID} — .+" "$IMPORT_FILE" | sed "s/Stage ${STAGE_ID} — //" | head -1 || true)"
  if [ -z "$STAGE_NAME_RAW" ]; then
    STAGE_NAME_RAW="$(grep -m1 -oE "Stage ${STAGE_ID} .+" "$IMPORT_FILE" | sed "s/Stage ${STAGE_ID} //" | head -1 || true)"
  fi

  if [ -n "$STAGE_NAME_RAW" ]; then
    STAGE_ESCAPED_R="$(echo "$STAGE_ID" | sed 's/\./\\./g')"
    ROADMAP_TITLE="$(grep -oE "^## Stage ${STAGE_ESCAPED_R} — .+" ROADMAP.md 2>/dev/null | sed "s/^## Stage ${STAGE_ESCAPED_R} — //" | head -1 || true)"

    SPEC_TITLE="$(echo "$STAGE_NAME_RAW" \
      | sed -E 's/ (followed by|and then|plus|with the|then the|including) .*//i' \
      | sed -E 's/ [\+\&] .*//' \
      | sed 's/ *$//')"

    if [ -n "$ROADMAP_TITLE" ] && [ -n "$SPEC_TITLE" ] && [ "$ROADMAP_TITLE" != "$SPEC_TITLE" ]; then
      echo
      echo "  Reconciling ROADMAP title:"
      echo "    Was:  $ROADMAP_TITLE"
      echo "    Now:  $SPEC_TITLE"
      sed_i "s/^## Stage ${STAGE_ESCAPED_R} — .*/## Stage ${STAGE_ID} — ${SPEC_TITLE}/" ROADMAP.md
    fi
  fi
else
  echo "  No import source found (no tmp/chatgpt.md, --import, or --paste)"
  echo "  Skipping import — you can create .ai/ files manually"
fi

# ---------------------------------------------------------
# 3) Detect existing .ai artifact files for this stage
# ---------------------------------------------------------
echo
echo "[3/5] Checking for .ai artifact files..."

STAGE_SLUG="$(echo "$STAGE_ID" | tr '.' '_')"

SPEC_FILE="$(find .ai/specs -maxdepth 1 -type f -name "stage_${STAGE_SLUG}_*.md" 2>/dev/null | grep -v '\.plan\.\|\.review\.\|\.implementation\.' | sort | head -n1 || true)"
PLAN_FILE="$(find .ai/plans -maxdepth 1 -type f -name "stage_${STAGE_SLUG}_*.plan.md" 2>/dev/null | sort | head -n1 || true)"
REVIEW_FILE="$(find ".ai/reviews/stage_${STAGE_SLUG}" -maxdepth 1 -type f -name "*.review.md" 2>/dev/null | sort | head -n1 || true)"
# Legacy flat layout fallback
if [ -z "$REVIEW_FILE" ]; then
  REVIEW_FILE="$(find .ai/reviews -maxdepth 1 -type f -name "stage_${STAGE_SLUG}_*.review.md" 2>/dev/null | sort | head -n1 || true)"
fi
IMPL_FILE="$(find .ai/implementations -maxdepth 1 -type f -name "stage_${STAGE_SLUG}_*.implementation.md" 2>/dev/null | sort | head -n1 || true)"

FOUND_FILES=0
FILES_TO_ADD=()

if [ -n "$SPEC_FILE" ] && [ -f "$SPEC_FILE" ]; then
  echo "  Found spec: $SPEC_FILE"
  FILES_TO_ADD+=("$SPEC_FILE")
  FOUND_FILES=$((FOUND_FILES + 1))
else
  echo "  No spec file found"
fi

if [ -n "$PLAN_FILE" ] && [ -f "$PLAN_FILE" ]; then
  echo "  Found plan: $PLAN_FILE"
  FILES_TO_ADD+=("$PLAN_FILE")
  FOUND_FILES=$((FOUND_FILES + 1))
else
  echo "  No plan file found"
fi

if [ -n "$REVIEW_FILE" ] && [ -f "$REVIEW_FILE" ]; then
  echo "  Found review: $REVIEW_FILE"
  FILES_TO_ADD+=("$REVIEW_FILE")
  FOUND_FILES=$((FOUND_FILES + 1))
else
  echo "  No review file found"
fi

if [ -n "$IMPL_FILE" ] && [ -f "$IMPL_FILE" ]; then
  echo "  Found implementation: $IMPL_FILE"
  FILES_TO_ADD+=("$IMPL_FILE")
  FOUND_FILES=$((FOUND_FILES + 1))
else
  echo "  No implementation file found"
fi

echo "  Total artifact files found: $FOUND_FILES"

# ---------------------------------------------------------
# 3b) Pre-start artifact validation
# ---------------------------------------------------------
echo
echo "[3b] Validating artifact quality..."

VALIDATION_WARNINGS=()
VALIDATION_ERRORS=()

if [ -n "$SPEC_FILE" ] && [ -f "$SPEC_FILE" ]; then
  # Check for Verification Checklist
  if ! grep -q "^## Verification Checklist\|^## Verification checklist" "$SPEC_FILE" 2>/dev/null; then
    if grep -qi "Verification Checklist" "$SPEC_FILE" 2>/dev/null; then
      VALIDATION_WARNINGS+=("Spec has Verification Checklist but heading needs '## ' prefix for conformance script")
    else
      VALIDATION_ERRORS+=("Spec MISSING '## Verification Checklist' — required for conformance")
    fi
  fi

  # Check for Preflight Clarification Intent
  if ! grep -qi "Preflight Clarification" "$SPEC_FILE" 2>/dev/null; then
    VALIDATION_WARNINGS+=("Spec MISSING Preflight Clarification Intent — Claude may ask unnecessary questions")
  fi

  # Check checklist has actual items
  CHECKLIST_ITEMS=$(grep -c "^\- \[ \]\|^  - \[ \]\|^	•" "$SPEC_FILE" 2>/dev/null || echo "0")
  if [ "$CHECKLIST_ITEMS" -lt 3 ] 2>/dev/null; then
    VALIDATION_WARNINGS+=("Spec has only $CHECKLIST_ITEMS checklist items — consider adding more")
  fi
else
  VALIDATION_ERRORS+=("No spec file found — cannot validate")
fi

# Check review for NO-GO
if [ -n "$REVIEW_FILE" ] && [ -f "$REVIEW_FILE" ]; then
  if grep -qi "NO.GO\|REJECTED\|BLOCKED" "$REVIEW_FILE" 2>/dev/null; then
    if ! grep -qi "GO.*Conditional\|Decision.*GO" "$REVIEW_FILE" 2>/dev/null; then
      VALIDATION_ERRORS+=("Review contains NO-GO / REJECTED — fix before proceeding")
    fi
  fi
else
  VALIDATION_WARNINGS+=("No review file — stage not yet reviewed by Gemini")
fi

# Report
if [ ${#VALIDATION_ERRORS[@]} -gt 0 ]; then
  for err in "${VALIDATION_ERRORS[@]}"; do echo "  FAIL: $err"; done
fi
if [ ${#VALIDATION_WARNINGS[@]} -gt 0 ]; then
  for w in "${VALIDATION_WARNINGS[@]}"; do echo "  WARN: $w"; done
fi
if [ ${#VALIDATION_ERRORS[@]} -eq 0 ] && [ ${#VALIDATION_WARNINGS[@]} -eq 0 ]; then
  echo "  PASS: All validations passed"
fi

# Block on errors unless --force
if [ ${#VALIDATION_ERRORS[@]} -gt 0 ] && ! HAS_FLAG "--force"; then
  echo ""
  echo "  Fix errors in ChatGPT/Gemini and re-import, or use --force to override."
  exit 1
fi

# ---------------------------------------------------------
# 4) Ensure we branch from an up-to-date main
# ---------------------------------------------------------
echo
echo "[4/5] Creating branch from main..."

STAGE_ESCAPED="$(echo "$STAGE_ID" | sed 's/\./\\./g')"
STAGE_NAME="$(grep -A0 "^## Stage ${STAGE_ESCAPED} —" ROADMAP.md 2>/dev/null | head -n1 | sed "s/^## Stage ${STAGE_ESCAPED} — //" || true)"

if [ -n "$STAGE_NAME" ]; then
  BRANCH_SLUG="$(echo "$STAGE_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')"
  BRANCH_NAME="feat/stage-${STAGE_ID}-${BRANCH_SLUG}"
else
  BRANCH_NAME="feat/stage-${STAGE_ID}"
fi

CURRENT_BRANCH="$(git branch --show-current)"

if [ "$CURRENT_BRANCH" = "$BRANCH_NAME" ]; then
  echo "  Already on branch: $BRANCH_NAME"
elif git show-ref --verify --quiet "refs/heads/$BRANCH_NAME" 2>/dev/null; then
  echo "  Branch $BRANCH_NAME already exists — switching to it"
  git checkout "$BRANCH_NAME"
else
  # Stash any uncommitted work (import artifacts, CURRENT_STAGE.md, etc.)
  STASHED=false
  if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null || [ -n "$(git ls-files --others --exclude-standard)" ]; then
    git stash --include-untracked -m "stage-start: stash before branching from main"
    STASHED=true
  fi

  # Switch to main and pull latest
  echo "  Switching to main and pulling latest..."
  git checkout main
  git pull origin main 2>/dev/null || true

  # Create new branch from main
  echo "  Creating branch: $BRANCH_NAME (from main)"
  git checkout -b "$BRANCH_NAME"

  # Restore stashed work
  if [ "$STASHED" = true ]; then
    if ! git stash pop 2>/dev/null; then
      echo "  Stash pop had conflicts — auto-resolving with our (new stage) versions..."
      # For lifecycle files, the new stage's version always wins
      for conflict_file in CURRENT_STAGE.md ROADMAP.md; do
        if git diff --name-only --diff-filter=U 2>/dev/null | grep -q "^${conflict_file}$"; then
          git checkout --theirs "$conflict_file" 2>/dev/null || true
          git add "$conflict_file" 2>/dev/null || true
          echo "    Resolved: $conflict_file (using new stage version)"
        fi
      done
      # Check if there are remaining conflicts
      REMAINING_CONFLICTS="$(git diff --name-only --diff-filter=U 2>/dev/null || true)"
      if [ -n "$REMAINING_CONFLICTS" ]; then
        echo "  WARN: Unresolved conflicts remain in:"
        echo "$REMAINING_CONFLICTS" | while IFS= read -r f; do echo "    $f"; done
        echo "  Please resolve manually before continuing."
      fi
    fi
  fi
fi

# ---------------------------------------------------------
# 5) Stage, commit, and push
# ---------------------------------------------------------
echo
echo "[5/5] Committing and pushing..."

git add CURRENT_STAGE.md

# Include ROADMAP.md if it was updated (title reconciliation)
if ! git diff --quiet ROADMAP.md 2>/dev/null; then
  git add ROADMAP.md
fi

if [ ${#FILES_TO_ADD[@]} -gt 0 ]; then
  for f in "${FILES_TO_ADD[@]}"; do
    safe_git_add "$f"
  done
fi

# Also include new-stage artifacts detected by the dirty-check guard
# (these are .ai/ and tmp/ files matching the new stage slug)
if [ ${#NEW_STAGE_ARTIFACTS[@]} -gt 0 ]; then
  for f in "${NEW_STAGE_ARTIFACTS[@]}"; do
    safe_git_add "$f"
  done
fi

if git diff --cached --quiet; then
  echo "  No changes to commit."
else
  COMMIT_MSG="chore: start stage ${STAGE_ID} — ${STAGE_NAME:-planning}"

  echo "  Committing: $COMMIT_MSG"
  git commit -m "$COMMIT_MSG"

  if ! HAS_FLAG "--no-push"; then
    echo "  Pushing..."
    git push -u origin "$BRANCH_NAME"
  else
    echo "  Skipping push (--no-push)"
  fi
fi

echo
echo "========================================="
echo " Stage $STAGE_ID Started"
echo "========================================="
echo
echo "  Branch: $BRANCH_NAME"
echo "  Package: $PACKAGE_DIR"
echo "  Artifacts imported: $IMPORT_COUNT"
echo "  Artifact files committed: $FOUND_FILES"
echo
echo "Next command:"
echo
echo "  ./scripts/ai-run.sh --stage-execute"
echo
