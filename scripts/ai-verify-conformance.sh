#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/ai-common.sh"

REPO_ROOT="$(repo_root)"
cd "$REPO_ROOT"

# =========================================================
# ai-verify-conformance.sh — Spec-to-Code Conformance Check
#
# Reads the current stage's spec and verifies that the
# implementation matches what was specified.
#
# Usage:
#   ./scripts/ai-verify-conformance.sh
#   ./scripts/ai-verify-conformance.sh --spec path/to/spec.md
#
# Checks:
#   1. Files listed in spec exist in the repo
#   2. Only allowed files were modified
#   3. Protected files were not touched
#   4. Required endpoints are present in route files
#   5. Required tests exist
#   6. Unexpected changes outside stage scope
#
# Output: Markdown conformance report to stdout + file
# =========================================================

SPEC_PATH="${2:-}"
if [[ -z "$SPEC_PATH" ]]; then
  SPEC_PATH="$(stage_spec_path)"
fi

if [[ -z "$SPEC_PATH" || ! -f "$SPEC_PATH" ]]; then
  echo "ERROR: No spec found. Provide --spec path or ensure CURRENT_STAGE.md is set."
  exit 1
fi

STAGE_ID="$(current_stage_id)"
SLUG="$(current_stage_slug)"
PACKAGE_REL="$(stage_package_dir)"
REVIEW_DIR="$(stage_review_dir)"
mkdir -p "$REVIEW_DIR"
VERSION_DIR="$(ensure_version_dir "$REVIEW_DIR")"
REPORT_FILE="${VERSION_DIR}/conformance.md"

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

# Categorized failure tracking
STRUCTURE_FAILS=()
CHECKLIST_FAILS=()
SCOPE_FAILS=()
TEST_FAILS=()

pass() { ((PASS_COUNT++)); echo "  ✓ PASS: $1"; }
fail() { ((FAIL_COUNT++)); echo "  ✗ FAIL: $1"; }
warn() { ((WARN_COUNT++)); echo "  ⚠ WARN: $1"; }

# Categorized fail helpers
structure_fail() { STRUCTURE_FAILS+=("$1"); fail "[STRUCTURE] $1"; }
checklist_fail() { CHECKLIST_FAILS+=("$1"); fail "[CHECKLIST] $1"; }
scope_fail()     { SCOPE_FAILS+=("$1");     fail "[SCOPE] $1"; }
test_fail()      { TEST_FAILS+=("$1");      fail "[TEST] $1"; }

# =========================================================
# Load project config (if exists)
# =========================================================
PROJECT_CONF="${REPO_ROOT}/.ai/config/project.conf"
if [[ -f "$PROJECT_CONF" ]]; then
  source "$PROJECT_CONF"
fi

# =========================================================
# Parse spec sections
# =========================================================

# Extract lines under a heading (## or ###) until next heading
extract_section() {
  local file="$1"
  local heading="$2"
  awk -v h="$heading" '
    BEGIN { found=0 }
    /^##/ && tolower($0) ~ tolower(h) { found=1; next }
    found && /^##/ { found=0 }
    found && NF { print }
  ' "$file"
}

# Extract file paths from a section (lines starting with - or * that look like paths)
extract_paths() {
  grep -oE '`[^`]+\.(kt|ts|tsx|js|json|yaml|yml|md|sh)`' | sed 's/`//g' || true
}

# Extract endpoint patterns (METHOD /path)
extract_endpoints() {
  grep -oE '(GET|POST|PUT|DELETE|PATCH)\s+/[^ )`]+' | sed 's/\s\+/ /' || true
}

{
echo ""
echo "# CONFORMANCE REPORT — Stage ${STAGE_ID}"
echo ""
echo "Spec: ${SPEC_PATH}"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""
echo "---"
echo ""

# =========================================================
# Check 0: Required Sections (structural gates)
# =========================================================

echo "## 0. Required Sections"
echo ""

# Check spec has Verification Checklist
if grep -q "^## Verification Checklist" "$SPEC_PATH"; then
  pass "Spec contains '## Verification Checklist' section"
else
  structure_fail "Spec MISSING '## Verification Checklist' section"
fi

# Check spec has Preflight Clarification Intent
if grep -q "^## Preflight Clarification Intent" "$SPEC_PATH"; then
  pass "Spec contains '## Preflight Clarification Intent' section"
else
  warn "Spec MISSING '## Preflight Clarification Intent' section (recommended)"
fi

# Check implementation artifact has Preflight Clarification Check (if it exists)
IMPL_PATH="$(stage_implementation_path || true)"
[[ -z "$IMPL_PATH" ]] && IMPL_PATH=".ai/implementations/${SLUG}.implementation.md"
if [[ -f "$IMPL_PATH" ]]; then
  if grep -q "^## Preflight Clarification Check" "$IMPL_PATH"; then
    pass "Implementation contains '## Preflight Clarification Check' section"
  else
    structure_fail "Implementation MISSING '## Preflight Clarification Check' section"
  fi
else
  echo "  (no implementation artifact found at ${IMPL_PATH} — skipping)"
fi

# Check review artifact has Spec Checklist Conformance (if any review exists)
REVIEW_FILES=$(find .ai/reviews/ -name "*.review.md" -newer "$SPEC_PATH" 2>/dev/null | head -1)
# Also check per-stage subfolder
if [[ -z "$REVIEW_FILES" ]]; then
  REVIEW_FILES=$(find "$REVIEW_DIR" -name "*.review.md" -newer "$SPEC_PATH" 2>/dev/null | head -1)
fi
if [[ -n "$REVIEW_FILES" ]]; then
  if grep -q "Spec Checklist Conformance\|Checklist Conformance" "$REVIEW_FILES"; then
    pass "Review contains checklist conformance section"
  else
    warn "Review MISSING checklist conformance section (recommended)"
  fi
else
  echo "  (no recent review artifact found — skipping)"
fi

echo ""

# =========================================================
# Check 1: Files to Create
# =========================================================

echo "## 1. Files to Create"
echo ""

FILES_TO_CREATE=$(extract_section "$SPEC_PATH" "files.to.create\|must.create\|new.files\|files.created" | extract_paths)

if [[ -z "$FILES_TO_CREATE" ]]; then
  echo "  (no explicit file creation list found in spec — skipping)"
  echo ""
else
  while IFS= read -r filepath; do
    # Search for the filename anywhere in the repo
    basename_file="$(basename "$filepath")"
    found=$(find "$REPO_ROOT" -name "$basename_file" -not -path '*/.git/*' -not -path '*/node_modules/*' -not -path '*/.next/*' -not -path '*/build/*' 2>/dev/null | head -1)
    if [[ -n "$found" ]]; then
      pass "$basename_file exists ($found)"
    else
      checklist_fail "$basename_file NOT FOUND"
    fi
  done <<< "$FILES_TO_CREATE"
  echo ""
fi

# =========================================================
# Check 2: Protected Files Untouched
# =========================================================

echo "## 2. Protected Files"
echo ""

# Protected paths — loaded from .ai/config/project.conf or defaults
if [[ -z "${PROTECTED_PATHS:-}" ]]; then
  _PROTECTED_PATHS=("packages/shared_contracts/src/main")
else
  read -ra _PROTECTED_PATHS <<< "$PROTECTED_PATHS"
fi

# Get changed files from diff against main
CHANGED_FILES=$(git diff --name-only main...HEAD 2>/dev/null || git diff --name-only HEAD~1 2>/dev/null || echo "")

if [[ -z "$CHANGED_FILES" ]]; then
  echo "  (no diff available — skipping)"
  echo ""
else
  PROTECTED_VIOLATION=false
  for protected in "${_PROTECTED_PATHS[@]}"; do
    violations=$(echo "$CHANGED_FILES" | grep "^${protected}" || true)
    if [[ -n "$violations" ]]; then
      scope_fail "Protected path modified: ${protected}"
      echo "$violations" | while read -r v; do echo "    - $v"; done
      PROTECTED_VIOLATION=true
    else
      pass "Protected path untouched: ${protected}"
    fi
  done
  echo ""
fi

# =========================================================
# Check 3: Required Endpoints Present
# =========================================================

echo "## 3. Required Endpoints"
echo ""

REQUIRED_ENDPOINTS=$(extract_section "$SPEC_PATH" "endpoint\|route\|api.surface\|in.scope" | extract_endpoints)

if [[ -z "$REQUIRED_ENDPOINTS" ]]; then
  echo "  (no explicit endpoints found in spec — skipping)"
  echo ""
else
  # Build concatenated route content for matching (including Ktor nested routes)
  _ALL_ROUTE_CONTENT=""
  while IFS= read -r -d '' _rf; do
    _ALL_ROUTE_CONTENT+="$(cat "$_rf" 2>/dev/null || true)"$'\n'
  done < <(find "$REPO_ROOT/apps" \( -name "*Routes.kt" -o -name "*routes.kt" -o -name "Main.kt" \) -print0 2>/dev/null)

  while IFS= read -r endpoint; do
    path=$(echo "$endpoint" | awk '{print $2}')
    # Normalize path for grep (replace {param} with wildcard pattern)
    path_pattern=$(echo "$path" | sed 's/{[^}]*}/[^"\/]*/g')

    # Strategy 1: Direct full-path match (e.g., route("/api/checkout/create"))
    if echo "$_ALL_ROUTE_CONTENT" | grep -qi "$path_pattern" 2>/dev/null; then
      pass "Endpoint found: $endpoint"
    else
      # Strategy 2: Ktor nested route detection
      # For path like /api/admin/bookings/{id}/complete, check if:
      #   - A route() call contains a parent prefix (e.g., /api/admin/bookings)
      #   - AND a get/post/put/delete() call contains the leaf (e.g., /complete)
      _found_nested=false
      _leaf="$(basename "$path")"
      _parent="$(dirname "$path")"

      # Try progressively shorter parent prefixes
      while [ "$_parent" != "/" ] && [ "$_parent" != "." ]; do
        if echo "$_ALL_ROUTE_CONTENT" | grep -q "route(\"${_parent}" 2>/dev/null; then
          if echo "$_ALL_ROUTE_CONTENT" | grep -qiE "(get|post|put|delete|patch)\(\"/?${_leaf}" 2>/dev/null; then
            _found_nested=true
            break
          fi
        fi
        _leaf="$(basename "$_parent")/${_leaf}"
        _parent="$(dirname "$_parent")"
      done

      if [ "$_found_nested" = true ]; then
        pass "Endpoint found (nested route): $endpoint"
      else
        checklist_fail "Endpoint MISSING: $endpoint"
      fi
    fi
  done <<< "$REQUIRED_ENDPOINTS"
  echo ""
fi

# =========================================================
# Check 4: Required Tests
# =========================================================

echo "## 4. Required Tests"
echo ""

# Count new test files in the diff
NEW_TEST_FILES=$(echo "$CHANGED_FILES" | grep -c "src/test/\|__tests__/\|\.test\.\|Test\.kt" || echo "0")
echo "  New/modified test files: ${NEW_TEST_FILES}"

# Check spec mentions specific test requirements
TEST_SECTION=$(extract_section "$SPEC_PATH" "test\|required.test\|acceptance")
TEST_NAMES=$(echo "$TEST_SECTION" | grep -oE '[A-Z][a-zA-Z]*Test' | sort -u || true)

if [[ -n "$TEST_NAMES" ]]; then
  while IFS= read -r test_name; do
    found=$(find "$REPO_ROOT" -name "${test_name}.kt" -o -name "${test_name}.ts" 2>/dev/null | head -1)
    if [[ -n "$found" ]]; then
      pass "Test file exists: ${test_name}"
    else
      warn "Test file not found: ${test_name} (may be named differently)"
    fi
  done <<< "$TEST_NAMES"
fi

if [[ "$NEW_TEST_FILES" -eq 0 ]]; then
  warn "No test files in diff — verify tests were included"
fi
echo ""

# =========================================================
# Check 5: Unexpected Changes (scope check)
# =========================================================

echo "## 5. Scope Check"
echo ""

# Extract expected package/app from spec
STAGE_PACKAGE=$(stage_package_dir || true)

if [[ -n "$STAGE_PACKAGE" && -n "$CHANGED_FILES" ]]; then
  # Files outside the expected package (excluding .ai/, docs/, config files)
  UNEXPECTED=$(echo "$CHANGED_FILES" | grep -v "^${STAGE_PACKAGE}" | grep -v "^\.ai/" | grep -v "^docs/" | grep -v "^ROADMAP\|^CURRENT_STAGE\|^KNOWN_ISSUES\|^TEST_REPORT\|^settings\|^build" || true)
  if [[ -n "$UNEXPECTED" ]]; then
    warn "Files changed outside primary package (${STAGE_PACKAGE}):"
    echo "$UNEXPECTED" | while read -r f; do echo "    - $f"; done
  else
    pass "All changes within expected scope"
  fi
else
  echo "  (no primary package defined — scope check skipped)"
fi
echo ""

# =========================================================
# Summary
# =========================================================

# =========================================================
# Check 6: Verification Checklist Items
# =========================================================

echo "## 6. Verification Checklist Items"
echo ""

# Extract checklist items paired with optional VERIFY: markers.
# Format: each line is "ITEM|||VERIFY_PATTERN" (VERIFY_PATTERN may be empty).
CHECKLIST_RAW=$(extract_section "$SPEC_PATH" "verification.checklist\|required.artifacts\|core.behavior\|safety.*invariant\|^tests")
CHECKLIST_PAIRED=$(echo "$CHECKLIST_RAW" | awk '
  /^[ \t]*- \[/ {
    if (item != "") print item "|||" verify
    sub(/^[ \t]*- \[.\] /, "")
    item = $0; verify = ""
    next
  }
  /^[ \t]*VERIFY:/ {
    sub(/^[ \t]*VERIFY:[ \t]*/, "")
    verify = $0
    next
  }
  END { if (item != "") print item "|||" verify }
' || true)

if [[ -z "$CHECKLIST_PAIRED" ]]; then
  echo "  (no checklist items found in spec — skipping)"
else
  CHECKLIST_TOTAL=0
  CHECKLIST_FILE_HITS=0

  # Build list of source files in the target package for VERIFY grep
  VERIFY_FILES=""
  if [[ -n "$PACKAGE_REL" ]] && [[ -d "$REPO_ROOT/$PACKAGE_REL/src" ]]; then
    VERIFY_FILES=$(find "$REPO_ROOT/$PACKAGE_REL/src" \( -name "*.kt" -o -name "*.ts" -o -name "*.tsx" \) -not -path '*/build/*' 2>/dev/null || true)
  fi

  while IFS= read -r paired; do
    item="${paired%%|||*}"
    verify="${paired##*|||}"
    ((CHECKLIST_TOTAL++))

    # Priority 1: VERIFY: annotation — grep source files for the pattern
    if [[ -n "$verify" ]] && [[ -n "$VERIFY_FILES" ]]; then
      if echo "$VERIFY_FILES" | xargs grep -lq "$verify" 2>/dev/null; then
        pass "Checklist: $item (VERIFY: '$verify' found in source)"
        ((CHECKLIST_FILE_HITS++))
        continue
      else
        checklist_fail "Checklist: $item (VERIFY: '$verify' NOT found in source)"
        continue
      fi
    fi

    # Priority 2: Try to extract a file/class name from the item text
    file_ref=$(echo "$item" | grep -oE '[A-Z][a-zA-Z]*\.(kt|ts|tsx)' | head -1 || true)
    class_ref=$(echo "$item" | grep -oE '[A-Z][a-zA-Z]+Test' | head -1 || true)
    endpoint_ref=$(echo "$item" | grep -oE '(GET|POST|PUT|DELETE|PATCH)\s*/[^ ]+' | head -1 || true)

    if [[ -n "$file_ref" ]]; then
      found=$(find "$REPO_ROOT" -name "$file_ref" -not -path '*/.git/*' -not -path '*/build/*' 2>/dev/null | head -1)
      if [[ -n "$found" ]]; then
        pass "Checklist: $item (file found: $found)"
        ((CHECKLIST_FILE_HITS++))
      else
        warn "Checklist: $item (file NOT found: $file_ref)"
      fi
    elif [[ -n "$class_ref" ]]; then
      found=$(find "$REPO_ROOT" -name "${class_ref}.kt" -o -name "${class_ref}.ts" 2>/dev/null | head -1)
      if [[ -n "$found" ]]; then
        pass "Checklist: $item (test found: $found)"
        ((CHECKLIST_FILE_HITS++))
      else
        warn "Checklist: $item (test NOT found: $class_ref)"
      fi
    elif [[ -n "$endpoint_ref" ]]; then
      local _ep_path; _ep_path="$(echo "$endpoint_ref" | awk '{print $2}')"
      if find "$REPO_ROOT/apps" \( -name "*Routes.kt" -o -name "*routes.kt" \) -print0 2>/dev/null \
           | xargs -0 grep -lq "$_ep_path" 2>/dev/null; then
        pass "Checklist: $item (endpoint found)"
        ((CHECKLIST_FILE_HITS++))
      else
        warn "Checklist: $item (endpoint not verified)"
      fi
    else
      echo "  - SKIP (no verifiable reference): $item"
    fi
  done <<< "$CHECKLIST_PAIRED"
  echo ""
  echo "  Checklist items: ${CHECKLIST_TOTAL} total, ${CHECKLIST_FILE_HITS} verified"
fi
echo ""

echo "---"
echo ""
echo "## Summary"
echo ""
echo "| Result | Count |"
echo "|--------|-------|"
echo "| PASS   | ${PASS_COUNT} |"
echo "| FAIL   | ${FAIL_COUNT} |"
echo "| WARN   | ${WARN_COUNT} |"
echo ""

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  echo "**VERDICT: FAIL** — ${FAIL_COUNT} conformance failure(s) found."
else
  if [[ "$WARN_COUNT" -gt 0 ]]; then
    echo "**VERDICT: PASS WITH WARNINGS** — ${WARN_COUNT} warning(s), review recommended."
  else
    echo "**VERDICT: PASS** — All checks passed."
  fi
fi

echo ""
echo "## Failure Breakdown"
echo ""
echo "| Category | Count | Details |"
echo "|----------|-------|---------|"
echo "| STRUCTURE | ${#STRUCTURE_FAILS[@]} | Missing required artifact sections |"
echo "| CHECKLIST | ${#CHECKLIST_FAILS[@]} | Missing files, endpoints, or checklist items |"
echo "| SCOPE     | ${#SCOPE_FAILS[@]} | Protected path or scope violations |"
echo "| TEST      | ${#TEST_FAILS[@]} | Missing or insufficient test coverage |"

if [[ ${#STRUCTURE_FAILS[@]} -gt 0 || ${#CHECKLIST_FAILS[@]} -gt 0 || ${#SCOPE_FAILS[@]} -gt 0 || ${#TEST_FAILS[@]} -gt 0 ]]; then
  echo ""
  for f in "${STRUCTURE_FAILS[@]:-}"; do [[ -n "$f" ]] && echo "  STRUCTURE: $f"; done
  for f in "${CHECKLIST_FAILS[@]:-}"; do [[ -n "$f" ]] && echo "  CHECKLIST: $f"; done
  for f in "${SCOPE_FAILS[@]:-}"; do [[ -n "$f" ]] && echo "  SCOPE: $f"; done
  for f in "${TEST_FAILS[@]:-}"; do [[ -n "$f" ]] && echo "  TEST: $f"; done
fi

echo ""
} | tee "$REPORT_FILE"

echo ""
echo "Report saved to: ${REPORT_FILE}"
