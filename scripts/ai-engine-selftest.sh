#!/usr/bin/env bash
set -euo pipefail

# =========================================================
# ai-engine-selftest.sh — Workflow Engine Self-Test
#
# Validates that the AI workflow engine itself is correctly
# wired: templates have required sections, scripts exist,
# context bundles include expected files.
#
# Usage:
#   ./scripts/ai-engine-selftest.sh
#
# This tests the engine, not the project.
# =========================================================

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

PASS=0
FAIL=0

pass() { ((PASS++)); echo "  ✓ $1"; }
fail() { ((FAIL++)); echo "  ✗ $1"; }

echo ""
echo "# AI Workflow Engine Self-Test"
echo "  Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# =========================================================
# 1. Template structure checks
# =========================================================

echo "## 1. Templates"
echo ""

# Spec template must have required sections
SPEC_T=".ai/templates/spec_template.md"
if [[ -f "$SPEC_T" ]]; then
  grep -q "## Verification Checklist"          "$SPEC_T" && pass "spec_template: has Verification Checklist"          || fail "spec_template: MISSING Verification Checklist"
  grep -q "## Preflight Clarification Intent"  "$SPEC_T" && pass "spec_template: has Preflight Clarification Intent"  || fail "spec_template: MISSING Preflight Clarification Intent"
  grep -q "### Mandatory"                      "$SPEC_T" && pass "spec_template: has Mandatory tier"                  || fail "spec_template: MISSING Mandatory tier"
  grep -q "### Optional"                       "$SPEC_T" && pass "spec_template: has Optional tier"                   || fail "spec_template: MISSING Optional tier"
  grep -q "Quality rule"                       "$SPEC_T" && pass "spec_template: has quality rule"                    || fail "spec_template: MISSING quality rule"
else
  fail "spec_template.md not found"
fi

# Diff review template must have conformance section
REVIEW_T=".ai/templates/diff_review_template.md"
if [[ -f "$REVIEW_T" ]]; then
  grep -q "Spec Checklist Conformance"         "$REVIEW_T" && pass "diff_review_template: has Checklist Conformance"  || fail "diff_review_template: MISSING Checklist Conformance"
  grep -q "Assumptions Made"                   "$REVIEW_T" && pass "diff_review_template: has Assumptions tracking"   || fail "diff_review_template: MISSING Assumptions tracking"
  grep -q "Evidence"                           "$REVIEW_T" && pass "diff_review_template: has Evidence column"        || fail "diff_review_template: MISSING Evidence column"
else
  fail "diff_review_template.md not found"
fi

# Plan template must have checklist preservation rule
PLAN_T=".ai/templates/plan_template.md"
if [[ -f "$PLAN_T" ]]; then
  grep -q "Checklist Preservation"             "$PLAN_T"  && pass "plan_template: has Checklist Preservation Rule"   || fail "plan_template: MISSING Checklist Preservation Rule"
else
  fail "plan_template.md not found"
fi

# Preflight template must have assumptions section
PRE_T=".ai/templates/preflight_template.md"
if [[ -f "$PRE_T" ]]; then
  grep -q "## Assumptions"                    "$PRE_T"   && pass "preflight_template: has Assumptions section"       || fail "preflight_template: MISSING Assumptions section"
else
  fail "preflight_template.md not found"
fi

echo ""

# =========================================================
# 2. Command file checks
# =========================================================

echo "## 2. Command Files"
echo ""

CMD_01=".ai/commands/01_plan_feature.md"
if [[ -f "$CMD_01" ]]; then
  grep -q "Verification Checklist"             "$CMD_01" && pass "01_plan: requires Verification Checklist"           || fail "01_plan: MISSING Verification Checklist requirement"
  grep -q "Preflight Clarification Intent"     "$CMD_01" && pass "01_plan: requires Preflight Clarification Intent"   || fail "01_plan: MISSING Preflight Clarification Intent requirement"
else
  fail "01_plan_feature.md not found"
fi

CMD_02=".ai/commands/02_implement_feature.md"
if [[ -f "$CMD_02" ]]; then
  grep -q "Preflight Clarification Check"      "$CMD_02" && pass "02_implement: requires Preflight Clarification"    || fail "02_implement: MISSING Preflight Clarification requirement"
  grep -q "Spec Checklist Status"              "$CMD_02" && pass "02_implement: requires Spec Checklist Status"      || fail "02_implement: MISSING Spec Checklist Status output"
else
  fail "02_implement_feature.md not found"
fi

CMD_06=".ai/commands/06_diff_review.md"
if [[ -f "$CMD_06" ]]; then
  grep -q "Spec Checklist Conformance"         "$CMD_06" && pass "06_diff_review: requires Checklist Conformance"    || fail "06_diff_review: MISSING Checklist Conformance step"
else
  fail "06_diff_review.md not found"
fi

echo ""

# =========================================================
# 3. Doc checks
# =========================================================

echo "## 3. Workflow Docs"
echo ""

WORKFLOW="docs/AI_WORKFLOW.md"
if [[ -f "$WORKFLOW" ]]; then
  grep -q "Mandatory Execution Flow"          "$WORKFLOW" && pass "AI_WORKFLOW: has Mandatory Execution Flow"        || fail "AI_WORKFLOW: MISSING Mandatory Execution Flow"
  grep -q "Preflight Clarification Check"     "$WORKFLOW" && pass "AI_WORKFLOW: has Preflight Clarification Check"   || fail "AI_WORKFLOW: MISSING Preflight Clarification Check"
  grep -q "Verification Checklist"            "$WORKFLOW" && pass "AI_WORKFLOW: has Verification Checklist"          || fail "AI_WORKFLOW: MISSING Verification Checklist"
else
  fail "docs/AI_WORKFLOW.md not found"
fi

BRAIN="docs/AI_REPO_BRAIN.md"
if [[ -f "$BRAIN" ]]; then
  grep -q "AI Role Responsibilities"          "$BRAIN"   && pass "AI_REPO_BRAIN: has Role Responsibilities"         || fail "AI_REPO_BRAIN: MISSING Role Responsibilities"
  grep -q "Clarification Policy"              "$BRAIN"   && pass "AI_REPO_BRAIN: has Clarification Policy"          || fail "AI_REPO_BRAIN: MISSING Clarification Policy"
else
  fail "docs/AI_REPO_BRAIN.md not found"
fi

CONTEXT="docs/AI_PROJECT_CONTEXT.md"
if [[ -f "$CONTEXT" ]]; then
  grep -q "Workflow Hardening"                "$CONTEXT"  && pass "AI_PROJECT_CONTEXT: has Workflow Hardening"       || fail "AI_PROJECT_CONTEXT: MISSING Workflow Hardening"
else
  fail "docs/AI_PROJECT_CONTEXT.md not found"
fi

echo ""

# =========================================================
# 4. Script + config checks
# =========================================================

echo "## 4. Scripts & Config"
echo ""

[[ -f "scripts/ai-verify-conformance.sh" ]]  && pass "ai-verify-conformance.sh exists"  || fail "ai-verify-conformance.sh MISSING"
[[ -f "scripts/ai-run.sh" ]]                 && pass "ai-run.sh exists"                 || fail "ai-run.sh MISSING"
[[ -f ".ai/config/project.conf" ]]           && pass "project.conf exists"              || fail "project.conf MISSING"

# Check ai-run.sh bundles include templates
if grep -q "TEMPLATE :: SPEC" scripts/ai-run.sh; then
  pass "ai-run.sh: ChatGPT bundle includes spec template"
else
  fail "ai-run.sh: ChatGPT bundle MISSING spec template"
fi

if grep -q "TEMPLATE :: TASK CHECKLIST" scripts/ai-run.sh; then
  pass "ai-run.sh: Gemini bundle includes task checklist"
else
  fail "ai-run.sh: Gemini bundle MISSING task checklist"
fi

echo ""

# =========================================================
# Summary
# =========================================================

echo "---"
echo ""
echo "## Summary"
echo ""
echo "  PASS: ${PASS}"
echo "  FAIL: ${FAIL}"
echo ""

if [[ "$FAIL" -gt 0 ]]; then
  echo "**ENGINE SELF-TEST: FAIL** — ${FAIL} issue(s) found."
  echo "Fix these before running a stage through the hardened flow."
  exit 1
else
  echo "**ENGINE SELF-TEST: PASS** — All checks passed."
  echo "Workflow engine is correctly wired."
  exit 0
fi
