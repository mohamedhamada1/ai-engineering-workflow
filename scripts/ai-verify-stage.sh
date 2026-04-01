#!/usr/bin/env bash
set -euo pipefail
export GIT_PAGER=cat
source "$(dirname "$0")/ai-common.sh"

require_git_repo

MODE="${1:---full}"  # --full (default) or --quick (skip build/test)
EXIT_CODE=0

print_header "BRANCH"
git branch --show-current

echo
print_header "CURRENT STAGE"
echo "Stage ID: $(current_stage_id)"
echo "Status: $(current_stage_status)"
PKG="$(stage_package_dir || true)"
echo "Package: ${PKG:-}"

# ---------------------------------------------------------
# 1) Validate CURRENT_STAGE.md
# ---------------------------------------------------------
echo
print_header "STAGE FILE VALIDATION"
if validate_current_stage; then
  echo "PASS — CURRENT_STAGE.md is well-formed"
else
  echo "FAIL — CURRENT_STAGE.md validation failed"
  EXIT_CODE=1
fi

# ---------------------------------------------------------
# 2) Check for spec/plan artifacts
# ---------------------------------------------------------
echo
print_header "ARTIFACT FILES"
SPEC="$(stage_spec_path)"
PLAN="$(stage_plan_path)"
REVIEW="$(stage_review_path)"
IMPL="$(stage_implementation_path)"

if [ -n "$SPEC" ] && [ -f "$SPEC" ]; then
  echo "PASS — Spec found: $SPEC"
else
  echo "WARN — No spec file found"
fi

if [ -n "$PLAN" ] && [ -f "$PLAN" ]; then
  echo "PASS — Plan found: $PLAN"
else
  echo "WARN — No plan file found"
fi

if [ -n "$REVIEW" ] && [ -f "$REVIEW" ]; then
  echo "PASS — Review found: $REVIEW"
else
  echo "WARN — No review file found"
fi

if [ -n "$IMPL" ] && [ -f "$IMPL" ]; then
  echo "PASS — Implementation request found: $IMPL"
else
  echo "INFO — No implementation request found"
fi

# ---------------------------------------------------------
# 3) Package directory check
# ---------------------------------------------------------
echo
print_header "PACKAGE VERIFICATION"

if [ -z "${PKG:-}" ]; then
  echo "WARN — Package not found in CURRENT_STAGE.md"
elif [ ! -d "$PKG" ]; then
  echo "WARN — Package directory does not exist: $PKG"
else
  echo "PASS — Package directory exists: $PKG"
  BUILD_SYS="$(detect_build_system "$PKG")"
  echo "PASS — Build system detected: $BUILD_SYS"
fi

# ---------------------------------------------------------
# 4) Protected file check
# ---------------------------------------------------------
echo
print_header "PROTECTED FILE CHECK"
if ! check_protected_files "warn"; then
  EXIT_CODE=1
fi

# ---------------------------------------------------------
# 5) Build + test (unless --quick)
# ---------------------------------------------------------
if [ "$MODE" = "--full" ] && [ -n "${PKG:-}" ]; then
  BUILD_SYS="$(detect_build_system "$PKG")"

  if [ "$BUILD_SYS" != "unknown" ]; then
    echo
    print_header "BUILD ($BUILD_SYS)"
    if run_build "$PKG"; then
      echo "PASS — Build succeeded ($BUILD_SYS)"
    else
      echo "FAIL — Build failed ($BUILD_SYS)"
      EXIT_CODE=1
    fi

    echo
    print_header "TEST ($BUILD_SYS)"
    if run_tests "$PKG"; then
      echo "PASS — Tests passed ($BUILD_SYS)"
    else
      echo "FAIL — Tests failed ($BUILD_SYS)"
      EXIT_CODE=1
    fi
  else
    echo
    echo "WARN — Unknown build system for $PKG — skipping build/test"
  fi
elif [ "$MODE" = "--quick" ]; then
  echo
  echo "SKIPPED — build/test (--quick mode)"
fi

# ---------------------------------------------------------
# Result
# ---------------------------------------------------------
echo
if [ "$EXIT_CODE" -eq 0 ]; then
  print_header "VERIFICATION RESULT: PASS"
else
  print_header "VERIFICATION RESULT: ISSUES FOUND"
fi

exit "$EXIT_CODE"
