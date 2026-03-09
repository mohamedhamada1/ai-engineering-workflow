#!/usr/bin/env bash

# ai-run.sh — AI Engineering Workflow Context Bundle Generator
#
# Assembles context bundles for AI agents (ChatGPT, Gemini, Claude)
# and optionally runs Claude pipeline steps directly.
#
# Usage:
#   ./scripts/ai-run.sh --chatgpt [--full|--paths]
#   ./scripts/ai-run.sh --gemini  [--full|--paths]
#   ./scripts/ai-run.sh --claude  [--full|--paths]
#
#   ./scripts/ai-run.sh --claude-run
#   ./scripts/ai-run.sh --claude-preflight
#   ./scripts/ai-run.sh --claude-implement
#   ./scripts/ai-run.sh --claude-diff-review
#   ./scripts/ai-run.sh --claude-stabilize
#   ./scripts/ai-run.sh --claude-pr-check
#   ./scripts/ai-run.sh --claude-all
#
# Examples:
#   ./scripts/ai-run.sh --chatgpt --full | pbcopy
#   ./scripts/ai-run.sh --gemini --full | pbcopy
#   ./scripts/ai-run.sh --claude-preflight
#   ./scripts/ai-run.sh --claude-all

set -euo pipefail

MODE="${1:-}"
STYLE="${2:---full}"

SCRIPT_PATH="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$0")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

usage() {
  cat <<'EOF'
AI Engineering Workflow — Context Bundle Generator

Usage:
  ./scripts/ai-run.sh --chatgpt [--full|--paths]
  ./scripts/ai-run.sh --gemini  [--full|--paths]
  ./scripts/ai-run.sh --claude  [--full|--paths]

  ./scripts/ai-run.sh --claude-run           (context only, no action)
  ./scripts/ai-run.sh --claude-preflight     (preflight grounding)
  ./scripts/ai-run.sh --claude-implement     (implement feature)
  ./scripts/ai-run.sh --claude-diff-review   (diff safety review)
  ./scripts/ai-run.sh --claude-stabilize     (stabilize failures)
  ./scripts/ai-run.sh --claude-pr-check      (PR scope audit)
  ./scripts/ai-run.sh --claude-all           (full pipeline)

Examples:
  ./scripts/ai-run.sh --chatgpt --full | pbcopy
  ./scripts/ai-run.sh --gemini --full | pbcopy
  ./scripts/ai-run.sh --claude --full | pbcopy
  ./scripts/ai-run.sh --claude-preflight
  ./scripts/ai-run.sh --claude-all
EOF
  exit 1
}

require_repo() {
  [[ -d "$REPO_ROOT/.ai" ]] || {
    echo "Error: .ai directory not found in repository root." >&2
    echo "Detected repo root: $REPO_ROOT" >&2
    echo "Run this script from your repository root or a scripts/ subdirectory." >&2
    exit 1
  }
}

require_claude() {
  if ! command -v claude >/dev/null 2>&1; then
    echo "Error: Claude CLI (claude) not found in PATH." >&2
    echo "Install it from: https://github.com/anthropics/claude-code" >&2
    exit 1
  fi
}

print_section() {
  local title="$1"
  echo
  echo "=================================================="
  echo " $title"
  echo "=================================================="
}

print_file_full() {
  local label="$1"
  local path="$2"
  print_section "$label :: $path"
  if [[ -f "$path" ]]; then
    cat "$path"
  else
    echo "[ Missing file: $path ]"
  fi
}

print_file_path() {
  echo "$1"
}

# ---------------------------------------------------------------------------
# Spec / Plan discovery
# ---------------------------------------------------------------------------

latest_spec() {
  find .ai/specs -maxdepth 1 -type f -name '*.md' 2>/dev/null | sort | tail -n 1 || true
}

latest_plan() {
  find .ai/plans -maxdepth 1 -type f -name '*.md' 2>/dev/null | sort | tail -n 1 || true
}

require_latest_feature() {
  local spec plan
  spec="$(latest_spec)"
  plan="$(latest_plan)"

  [[ -n "$spec" ]] || {
    echo "Error: No spec file found in .ai/specs/" >&2
    echo "Create a spec using the template at .ai/templates/spec_template.md" >&2
    exit 1
  }

  [[ -n "$plan" ]] || {
    echo "Error: No plan file found in .ai/plans/" >&2
    echo "Create a plan using the template at .ai/templates/plan_template.md" >&2
    exit 1
  }
}

print_latest_feature_paths() {
  local spec plan
  spec="$(latest_spec)"
  plan="$(latest_plan)"
  [[ -n "$spec" ]] && echo "$spec"
  [[ -n "$plan" ]] && echo "$plan"
}

print_latest_feature_full() {
  local spec plan
  spec="$(latest_spec)"
  plan="$(latest_plan)"

  if [[ -n "$spec" ]]; then
    print_file_full "LATEST SPEC" "$spec"
  else
    print_section "LATEST SPEC"
    echo "[ No spec found in .ai/specs/ ]"
  fi

  if [[ -n "$plan" ]]; then
    print_file_full "LATEST PLAN" "$plan"
  else
    print_section "LATEST PLAN"
    echo "[ No plan found in .ai/plans/ ]"
  fi
}

# ---------------------------------------------------------------------------
# Prompt headers
# ---------------------------------------------------------------------------

print_prompt_chatgpt() {
  cat <<'EOF'
Use the attached project context for architecture, feature design, spec creation, planning, and workflow-safe review.

Please rely on:
- docs/AI_REPO_BRAIN.md for detailed architecture, invariants, and module structure
- docs/AI_PROJECT_CONTEXT.md for high-level product and package context
- docs/AI_WORKFLOW.md for process rules
- ROADMAP.md for roadmap truth
- CURRENT_STAGE.md for active execution state

If a specific feature is being discussed, use the latest spec and plan if attached.
EOF
}

print_prompt_gemini() {
  cat <<'EOF'
Use the attached project context as a red-team reviewer.

Please review:
- Architectural consistency
- Scope boundaries
- Roadmap alignment
- Backward compatibility risks
- Hidden dependency risks
- Spec / plan consistency
- Safety for SDK or platform code
- Invariant violations

Prioritize catching file-scope mistakes, symbol rename risks, and invariant violations.
Issue a clear GO or NO-GO with specific rationale.
EOF
}

print_prompt_claude_context() {
  cat <<'EOF'
Use the attached project context for repo-grounded execution.

Do not implement anything yet.
Understand:
- Architecture
- Workflow
- Roadmap
- Current stage
- Known risks
- Test state

Wait for the next step-specific instruction.
EOF
}

# ---------------------------------------------------------------------------
# Output: paths mode
# ---------------------------------------------------------------------------

emit_paths_chatgpt() {
  print_section "Context Bundle for ChatGPT (PATHS)"
  print_prompt_chatgpt
  print_section "FILES"
  print_file_path "docs/AI_PROJECT_CONTEXT.md"
  print_file_path "docs/AI_REPO_BRAIN.md"
  print_file_path "docs/AI_WORKFLOW.md"
  print_file_path "ROADMAP.md"
  print_file_path "CURRENT_STAGE.md"
}

emit_paths_gemini() {
  print_section "Context Bundle for Gemini (PATHS)"
  print_prompt_gemini
  print_section "FILES"
  print_file_path "docs/AI_PROJECT_CONTEXT.md"
  print_file_path "docs/AI_REPO_BRAIN.md"
  print_file_path "docs/AI_WORKFLOW.md"
  print_file_path "ROADMAP.md"
  print_file_path "CURRENT_STAGE.md"
  print_file_path "KNOWN_ISSUES.md"
  print_latest_feature_paths
}

emit_paths_claude() {
  print_section "Context Bundle for Claude (PATHS)"
  print_prompt_claude_context
  print_section "FILES"
  print_file_path "docs/AI_REPO_BRAIN.md"
  print_file_path "docs/AI_WORKFLOW.md"
  print_file_path "ROADMAP.md"
  print_file_path "CURRENT_STAGE.md"
  print_file_path "TEST_REPORT.md"
  print_file_path "KNOWN_ISSUES.md"
  print_latest_feature_paths
  print_file_path ".ai/commands/05_preflight_grounding.md"
  print_file_path ".ai/commands/02_implement_feature.md"
  print_file_path ".ai/commands/06_diff_review.md"
  print_file_path ".ai/commands/03_stabilize_feature.md"
  print_file_path ".ai/commands/04_pr_check.md"
}

# ---------------------------------------------------------------------------
# Output: full mode
# ---------------------------------------------------------------------------

emit_full_chatgpt() {
  print_section "Context Bundle for ChatGPT (FULL)"
  print_prompt_chatgpt
  print_file_full "PROJECT CONTEXT"  "docs/AI_PROJECT_CONTEXT.md"
  print_file_full "REPO BRAIN"       "docs/AI_REPO_BRAIN.md"
  print_file_full "AI WORKFLOW"      "docs/AI_WORKFLOW.md"
  print_file_full "ROADMAP"          "ROADMAP.md"
  print_file_full "CURRENT STAGE"    "CURRENT_STAGE.md"
  print_latest_feature_full
}

emit_full_gemini() {
  print_section "Context Bundle for Gemini (FULL)"
  print_prompt_gemini
  print_file_full "PROJECT CONTEXT"  "docs/AI_PROJECT_CONTEXT.md"
  print_file_full "REPO BRAIN"       "docs/AI_REPO_BRAIN.md"
  print_file_full "AI WORKFLOW"      "docs/AI_WORKFLOW.md"
  print_file_full "ROADMAP"          "ROADMAP.md"
  print_file_full "CURRENT STAGE"    "CURRENT_STAGE.md"
  print_file_full "KNOWN ISSUES"     "KNOWN_ISSUES.md"
  print_latest_feature_full
}

emit_full_claude() {
  print_section "Context Bundle for Claude (FULL)"
  print_prompt_claude_context
  print_file_full "REPO BRAIN"    "docs/AI_REPO_BRAIN.md"
  print_file_full "AI WORKFLOW"   "docs/AI_WORKFLOW.md"
  print_file_full "ROADMAP"       "ROADMAP.md"
  print_file_full "CURRENT STAGE" "CURRENT_STAGE.md"
  print_file_full "TEST REPORT"   "TEST_REPORT.md"
  print_file_full "KNOWN ISSUES"  "KNOWN_ISSUES.md"
  print_latest_feature_full
  print_file_full "COMMAND :: PREFLIGHT"   ".ai/commands/05_preflight_grounding.md"
  print_file_full "COMMAND :: IMPLEMENT"   ".ai/commands/02_implement_feature.md"
  print_file_full "COMMAND :: DIFF REVIEW" ".ai/commands/06_diff_review.md"
  print_file_full "COMMAND :: STABILIZE"   ".ai/commands/03_stabilize_feature.md"
  print_file_full "COMMAND :: PR CHECK"    ".ai/commands/04_pr_check.md"
}

# ---------------------------------------------------------------------------
# Claude runner helpers
# ---------------------------------------------------------------------------

make_tmp_context() {
  mktemp
}

run_claude_with_input() {
  local tmp_context="$1"
  require_claude
  echo
  echo "=============================================="
  echo " Launching Claude Code"
  echo "=============================================="
  claude < "$tmp_context"
  rm -f "$tmp_context"
}

append_common_claude_context() {
  local out="$1"
  {
    echo "### Project Context Bundle"
    echo
    [[ -f "docs/AI_REPO_BRAIN.md" ]]   && cat "docs/AI_REPO_BRAIN.md"
    echo
    [[ -f "docs/AI_WORKFLOW.md" ]]     && cat "docs/AI_WORKFLOW.md"
    echo
    [[ -f "ROADMAP.md" ]]              && cat "ROADMAP.md"
    echo
    [[ -f "CURRENT_STAGE.md" ]]        && cat "CURRENT_STAGE.md"
    echo
    [[ -f "TEST_REPORT.md" ]]          && cat "TEST_REPORT.md"
    echo
    [[ -f "KNOWN_ISSUES.md" ]]         && cat "KNOWN_ISSUES.md"
    echo
  } >> "$out"
}

append_latest_spec_plan() {
  local out="$1"
  local spec plan
  spec="$(latest_spec)"
  plan="$(latest_plan)"
  {
    echo "### Latest Spec"
    echo
    if [[ -n "$spec" ]]; then cat "$spec"; else echo "No spec found."; fi
    echo
    echo "### Latest Plan"
    echo
    if [[ -n "$plan" ]]; then cat "$plan"; else echo "No plan found."; fi
    echo
  } >> "$out"
}

# ---------------------------------------------------------------------------
# Claude runner modes
# ---------------------------------------------------------------------------

run_claude_context_only() {
  local tmp
  tmp="$(make_tmp_context)"
  append_common_claude_context "$tmp"
  {
    echo "### Claude Task"
    echo
    cat <<'EOF'
Use this project context to understand the repository.

Do not implement anything yet.
Do not modify any code.
Wait for the next stage-specific instruction.
EOF
  } >> "$tmp"
  run_claude_with_input "$tmp"
}

run_claude_preflight() {
  require_latest_feature
  local tmp
  tmp="$(make_tmp_context)"
  append_common_claude_context "$tmp"
  append_latest_spec_plan "$tmp"
  {
    echo "### Claude Task :: Preflight Grounding"
    echo
    cat ".ai/commands/05_preflight_grounding.md"
  } >> "$tmp"
  run_claude_with_input "$tmp"
}

run_claude_implement() {
  require_latest_feature
  local tmp
  tmp="$(make_tmp_context)"
  append_common_claude_context "$tmp"
  append_latest_spec_plan "$tmp"
  {
    echo "### Claude Task :: Implementation"
    echo
    cat ".ai/commands/02_implement_feature.md"
  } >> "$tmp"
  run_claude_with_input "$tmp"
}

run_claude_diff_review() {
  require_latest_feature
  local tmp
  tmp="$(make_tmp_context)"
  append_common_claude_context "$tmp"
  append_latest_spec_plan "$tmp"
  {
    echo "### Current Git Diff"
    echo
    git diff || true
    echo
    echo "### Claude Task :: Diff Review"
    echo
    cat ".ai/commands/06_diff_review.md"
  } >> "$tmp"
  run_claude_with_input "$tmp"
}

run_claude_stabilize() {
  require_latest_feature
  local tmp
  tmp="$(make_tmp_context)"
  append_common_claude_context "$tmp"
  append_latest_spec_plan "$tmp"
  {
    echo "### Claude Task :: Stabilization"
    echo
    cat ".ai/commands/03_stabilize_feature.md"
  } >> "$tmp"
  run_claude_with_input "$tmp"
}

run_claude_pr_check() {
  require_latest_feature
  local tmp
  tmp="$(make_tmp_context)"
  append_common_claude_context "$tmp"
  append_latest_spec_plan "$tmp"
  {
    echo "### Current Git Diff"
    echo
    git diff || true
    echo
    echo "### Claude Task :: PR Check"
    echo
    cat ".ai/commands/04_pr_check.md"
  } >> "$tmp"
  run_claude_with_input "$tmp"
}

run_claude_all() {
  require_latest_feature
  local tmp
  tmp="$(make_tmp_context)"
  append_common_claude_context "$tmp"
  append_latest_spec_plan "$tmp"
  {
    cat <<'EOF'
### Claude Task :: Full Execution Pipeline

Execute the full workflow in this exact order:

1. Preflight grounding
2. If and only if preflight returns GO → implement feature
3. Diff review
4. Stabilization
5. PR check

Rules:
- Stop immediately if preflight returns NO-GO
- Do not skip steps
- Do not expand scope
- Follow the command instructions below in sequence

---

### Step 1 :: Preflight
EOF
    cat ".ai/commands/05_preflight_grounding.md"
    echo
    cat <<'EOF'

---

### Step 2 :: Implement (only if Step 1 = GO)
EOF
    cat ".ai/commands/02_implement_feature.md"
    echo
    cat <<'EOF'

---

### Step 3 :: Diff Review
EOF
    cat ".ai/commands/06_diff_review.md"
    echo
    cat <<'EOF'

---

### Step 4 :: Stabilize
EOF
    cat ".ai/commands/03_stabilize_feature.md"
    echo
    cat <<'EOF'

---

### Step 5 :: PR Check
EOF
    cat ".ai/commands/04_pr_check.md"
  } >> "$tmp"
  run_claude_with_input "$tmp"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
  require_repo

  case "$MODE" in
    --chatgpt)
      case "$STYLE" in
        --paths) emit_paths_chatgpt ;;
        --full)  emit_full_chatgpt ;;
        *) usage ;;
      esac
      ;;
    --gemini)
      case "$STYLE" in
        --paths) emit_paths_gemini ;;
        --full)  emit_full_gemini ;;
        *) usage ;;
      esac
      ;;
    --claude)
      case "$STYLE" in
        --paths) emit_paths_claude ;;
        --full)  emit_full_claude ;;
        *) usage ;;
      esac
      ;;
    --claude-run)          run_claude_context_only ;;
    --claude-preflight)    run_claude_preflight ;;
    --claude-implement)    run_claude_implement ;;
    --claude-diff-review)  run_claude_diff_review ;;
    --claude-stabilize)    run_claude_stabilize ;;
    --claude-pr-check)     run_claude_pr_check ;;
    --claude-all)          run_claude_all ;;
    *) usage ;;
  esac
}

main
