#!/usr/bin/env bash
set -euo pipefail
export GIT_PAGER=cat
source "$(dirname "$0")/ai-common.sh"

require_git_repo

STAGE_ID="$(current_stage_id)"
STAGE_SLUG="$(stage_slug "$STAGE_ID")"
OUT_DIR="$(stage_review_dir)"
mkdir -p "$OUT_DIR"
VERSION_DIR="$(ensure_version_dir "$OUT_DIR")"
OUT_FILE="${VERSION_DIR}/review_bundle.txt"
BASE_BRANCH="$(detect_base_branch)"
DIFF_BASE="$(resolve_diff_base "$BASE_BRANCH" "HEAD" "$STAGE_ID")"

{
  echo "===== DATE ====="
  date

  echo
  echo "===== REPO ====="
  repo_root

  echo
  echo "===== BRANCH ====="
  git branch --show-current

  echo
  echo "===== CURRENT STAGE ====="
  echo "Stage ID: $STAGE_ID"
  echo "Stage Name: $(current_stage_name)"
  echo "Status: $(current_stage_status)"
  echo "Package: $(stage_package_dir || true)"

  echo
  echo "===== GIT STATUS ====="
  git status --short

  echo
  echo "===== ALL CHANGED FILES ====="
  all_changed_files

  echo
  echo "===== DIFF STAT (vs $DIFF_BASE) ====="
  git diff --stat "${DIFF_BASE}..HEAD" 2>/dev/null || git diff --stat

  echo
  echo "===== FULL DIFF (vs $DIFF_BASE) ====="
  git diff "${DIFF_BASE}..HEAD" 2>/dev/null || git diff

  echo
  echo "===== SPEC ====="
  SPEC="$(stage_spec_path)"
  [ -n "$SPEC" ] && [ -f "$SPEC" ] && cat "$SPEC" || echo "(not found)"

  echo
  echo "===== PLAN ====="
  PLAN="$(stage_plan_path)"
  [ -n "$PLAN" ] && [ -f "$PLAN" ] && cat "$PLAN" || echo "(not found)"

  echo
  echo "===== REVIEW ====="
  REVIEW="$(stage_review_path)"
  [ -n "$REVIEW" ] && [ -f "$REVIEW" ] && cat "$REVIEW" || echo "(not found)"

  echo
  echo "===== CURRENT_STAGE.md ====="
  [ -f CURRENT_STAGE.md ] && cat CURRENT_STAGE.md || echo "CURRENT_STAGE.md missing"

  echo
  echo "===== ROADMAP.md ====="
  [ -f ROADMAP.md ] && cat ROADMAP.md || echo "ROADMAP.md missing"

  echo
  echo "===== TEST_REPORT.md ====="
  [ -f TEST_REPORT.md ] && cat TEST_REPORT.md || echo "TEST_REPORT.md missing"

  echo
  echo "===== KNOWN_ISSUES.md ====="
  [ -f KNOWN_ISSUES.md ] && cat KNOWN_ISSUES.md || echo "KNOWN_ISSUES.md missing"
} > "$OUT_FILE"

echo "Wrote $OUT_FILE"
