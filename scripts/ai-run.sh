#!/usr/bin/env bash
set -euo pipefail
export GIT_PAGER=cat
source "$(dirname "$0")/ai-common.sh"

MODE="${1:-}"
STYLE="${2:---full}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

usage() {
  cat <<'EOF'
AI Engineering Workflow — Final Orchestrator

Context bundles:
  ./scripts/ai-run.sh --chatgpt [--full|--compact|--paths]
  ./scripts/ai-run.sh --gemini  [--full|--compact|--paths]
  ./scripts/ai-run.sh --claude  [--full|--paths]

Claude execution:
  ./scripts/ai-run.sh --claude-run
  ./scripts/ai-run.sh --claude-preflight
  ./scripts/ai-run.sh --claude-implement
  ./scripts/ai-run.sh --claude-diff-review
  ./scripts/ai-run.sh --claude-stabilize
  ./scripts/ai-run.sh --claude-pr-check
  ./scripts/ai-run.sh --claude-all
  ./scripts/ai-run.sh --claude-all-no-post

Local helpers:
  ./scripts/ai-run.sh --verify-stage [--full|--quick]
  ./scripts/ai-run.sh --diff-evidence
  ./scripts/ai-run.sh --review-bundle
  ./scripts/ai-run.sh --post-review
  ./scripts/ai-run.sh --complete-stage <stage-id> [--dry-run]
  ./scripts/ai-run.sh --stage-start <stage-id> [--no-push]
  ./scripts/ai-run.sh --stage-status [--all]
  ./scripts/ai-run.sh --stage-execute [--resume|--from N]
  ./scripts/ai-run.sh --stage-revise "reviewer feedback here"
  ./scripts/ai-run.sh --import-chatgpt <file|--paste>
  ./scripts/ai-run.sh --update-context [--apply <file>]
  ./scripts/ai-run.sh --verify-conformance [--spec <path>]
  ./scripts/ai-run.sh --reality-sync [--append]
EOF
  exit 1
}

require_repo() {
  [[ -d "$REPO_ROOT/.ai" ]] || {
    echo "Error: .ai directory not found in repository root." >&2
    echo "Detected repo root: $REPO_ROOT" >&2
    exit 1
  }
}

require_claude() {
  if ! command -v claude >/dev/null 2>&1; then
    echo "Error: Claude CLI (claude) not found in PATH." >&2
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
  if [[ -n "$path" && -f "$path" ]]; then
    cat "$path"
  else
    echo "[ Missing file: $path ]"
  fi
}

print_file_path() {
  echo "$1"
}

safe_run_script() {
  local path="$1"
  shift || true
  if [[ -x "$path" ]]; then
    "$path" "$@"
  else
    echo "Error: script not found or not executable: $path" >&2
    exit 1
  fi
}

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
  if claude < "$tmp_context"; then
    rm -f "$tmp_context"
  else
    local exit_code=$?
    echo "WARN: Claude exited with code $exit_code"
    echo "Context preserved at: $tmp_context"
    return $exit_code
  fi
}

print_stage_summary() {
  echo "Stage ID: $(current_stage_id)"
  echo "Status: $(current_stage_status)"
}

print_prompt_chatgpt() {
  cat <<'EOF'
Use the attached project context for architecture, feature design, spec creation, planning, and workflow-safe review.

Please rely on:
- docs/AI_REPO_BRAIN.md
- docs/AI_PROJECT_CONTEXT.md
- docs/AI_WORKFLOW.md
- ROADMAP.md
- CURRENT_STAGE.md

If a specific feature is being discussed, use the current stage spec, plan, review, and implementation files if attached.
EOF
}

print_prompt_gemini() {
  cat <<'EOF'
Use the attached project context as a red-team reviewer.

Please review:
- architectural consistency
- scope boundaries
- roadmap alignment
- backward compatibility risks
- hidden dependency risks
- spec / plan consistency
- stage-boundary violations
- invariant violations

Issue a clear GO / NO-GO / GO WITH CHANGES with rationale.
EOF
}

print_prompt_claude_context() {
  cat <<'EOF'
Use the attached project context for repo-grounded execution.

Do not implement anything yet.
Understand:
- architecture
- workflow
- roadmap
- current stage
- known risks
- test state
- current stage spec / plan / review / implementation request

Wait for the next stage-specific instruction unless a Claude execution mode is explicitly running.
EOF
}

latest_spec() { stage_spec_path; }
latest_plan() { stage_plan_path; }
latest_review() { stage_review_path; }
latest_implementation() { stage_implementation_path; }

print_latest_feature_paths() {
  local spec plan review impl
  spec="$(latest_spec)"
  plan="$(latest_plan)"
  review="$(latest_review)"
  impl="$(latest_implementation)"

  [[ -n "$spec" ]] && echo "$spec"
  [[ -n "$plan" ]] && echo "$plan"
  [[ -n "$review" ]] && echo "$review"
  [[ -n "$impl" ]] && echo "$impl"
}

print_latest_feature_full() {
  local spec plan review impl
  spec="$(latest_spec)"
  plan="$(latest_plan)"
  review="$(latest_review)"
  impl="$(latest_implementation)"

  print_file_full "LATEST SPEC" "$spec"
  print_file_full "LATEST PLAN" "$plan"
  print_file_full "LATEST REVIEW" "$review"
  print_file_full "LATEST IMPLEMENTATION REQUEST" "$impl"
}

append_common_claude_context() {
  local out="$1"
  {
    echo "### Project Context Bundle"
    echo
    echo "### Current Stage"
    print_stage_summary
    echo
    [[ -f "docs/AI_PROJECT_CONTEXT.md" ]] && cat "docs/AI_PROJECT_CONTEXT.md"
    echo
    [[ -f "docs/AI_REPO_BRAIN.md" ]] && cat "docs/AI_REPO_BRAIN.md"
    echo
    [[ -f "docs/AI_WORKFLOW.md" ]] && cat "docs/AI_WORKFLOW.md"
    echo
    [[ -f "ROADMAP.md" ]] && cat "ROADMAP.md"
    echo
    [[ -f "CURRENT_STAGE.md" ]] && cat "CURRENT_STAGE.md"
    echo
    [[ -f "TEST_REPORT.md" ]] && cat "TEST_REPORT.md"
    echo
    [[ -f "KNOWN_ISSUES.md" ]] && cat "KNOWN_ISSUES.md"
    echo
  } >> "$out"
}

append_latest_spec_plan_review_impl() {
  local out="$1"
  local spec plan review impl
  spec="$(latest_spec)"
  plan="$(latest_plan)"
  review="$(latest_review)"
  impl="$(latest_implementation)"

  {
    echo "### Latest Spec"
    echo
    [[ -n "$spec" && -f "$spec" ]] && cat "$spec" || echo "No spec found."
    echo
    echo "### Latest Plan"
    echo
    [[ -n "$plan" && -f "$plan" ]] && cat "$plan" || echo "No plan found."
    echo
    echo "### Latest Review"
    echo
    [[ -n "$review" && -f "$review" ]] && cat "$review" || echo "No review found."
    echo
    echo "### Latest Implementation Request"
    echo
    [[ -n "$impl" && -f "$impl" ]] && cat "$impl" || echo "No implementation request found."
    echo
  } >> "$out"
}

append_local_script_output_if_exists() {
  local out="$1"
  local label="$2"
  local script_path="$3"
  shift 3 || true
  if [[ -x "$script_path" ]]; then
    {
      echo "### $label"
      echo
      "$script_path" "$@" || true
      echo
    } >> "$out"
  fi
}

emit_paths_chatgpt() {
  print_section "Context Bundle for ChatGPT (PATHS)"
  print_prompt_chatgpt
  print_section "FILES"
  print_file_path "docs/AI_PROJECT_CONTEXT.md"
  print_file_path "docs/AI_REPO_BRAIN.md"
  print_file_path "docs/AI_WORKFLOW.md"
  print_file_path "ROADMAP.md"
  print_file_path "CURRENT_STAGE.md"
  for ctx_file in .ai/context/*.md; do
    [[ -f "$ctx_file" ]] && print_file_path "$ctx_file"
  done
  print_latest_feature_paths
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
  for ctx_file in .ai/context/*.md; do
    [[ -f "$ctx_file" ]] && print_file_path "$ctx_file"
  done
  print_latest_feature_paths
}

emit_paths_claude() {
  print_section "Context Bundle for Claude (PATHS)"
  print_prompt_claude_context
  print_section "FILES"
  print_file_path "docs/AI_PROJECT_CONTEXT.md"
  print_file_path "docs/AI_REPO_BRAIN.md"
  print_file_path "docs/AI_WORKFLOW.md"
  print_file_path "ROADMAP.md"
  print_file_path "CURRENT_STAGE.md"
  print_file_path "TEST_REPORT.md"
  print_file_path "KNOWN_ISSUES.md"
  for ctx_file in .ai/context/*.md; do
    [[ -f "$ctx_file" ]] && print_file_path "$ctx_file"
  done
  print_latest_feature_paths
  print_file_path ".ai/commands/05_preflight_grounding.md"
  print_file_path ".ai/commands/02_implement_feature.md"
  print_file_path ".ai/commands/06_diff_review.md"
  print_file_path ".ai/commands/03_stabilize_feature.md"
  print_file_path ".ai/commands/04_pr_check.md"
}

# Files excluded from engineering context bundles (business/sales docs, not architecture)
CONTEXT_EXCLUDES="full_project.md|BUSINESS_PLAN.md|PRODUCT_STRATEGY_FULL_PLATFORM.md"

emit_full_chatgpt() {
  print_section "Context Bundle for ChatGPT (FULL)"
  print_prompt_chatgpt
  print_file_full "PROJECT CONTEXT" "docs/AI_PROJECT_CONTEXT.md"
  print_file_full "REPO BRAIN" "docs/AI_REPO_BRAIN.md"
  print_file_full "AI WORKFLOW" "docs/AI_WORKFLOW.md"
  print_file_full "ROADMAP" "ROADMAP.md"
  print_file_full "CURRENT STAGE" "CURRENT_STAGE.md"
  # Include execution context files (skip business docs and oversized files)
  for ctx_file in .ai/context/*.md; do
    [[ -f "$ctx_file" ]] || continue
    [[ "$(basename "$ctx_file")" =~ ^($CONTEXT_EXCLUDES)$ ]] && continue
    print_file_full "CONTEXT: $(basename "$ctx_file" .md)" "$ctx_file"
  done
  # Include architect command + spec template so ChatGPT knows the required format
  print_file_full "COMMAND :: PLAN FEATURE" ".ai/commands/01_plan_feature.md"
  print_file_full "TEMPLATE :: SPEC" ".ai/templates/spec_template.md"
  print_latest_feature_full
}

# Compact bundle — trimmed roadmap (progress table + current phase only), no large context files
emit_compact_chatgpt() {
  print_section "Context Bundle for ChatGPT (COMPACT)"
  echo "NOTE: This is a size-optimized bundle. Use --full for complete context."
  echo ""
  print_prompt_chatgpt
  print_file_full "PROJECT CONTEXT" "docs/AI_PROJECT_CONTEXT.md"
  print_file_full "AI WORKFLOW" "docs/AI_WORKFLOW.md"
  print_file_full "CURRENT STAGE" "CURRENT_STAGE.md"

  # Trimmed repo brain: keep architecture + packages + interfaces + invariants
  # Skip per-stage completion details (Completed Stages section is huge)
  echo ""
  echo "===== REPO BRAIN (trimmed — architecture + packages + interfaces) ====="
  awk '
    BEGIN { skip=0 }
    /^# Completed Stages/    { skip=1 }
    /^# Canonical Architecture/ { skip=0 }
    !skip { print }
  ' docs/AI_REPO_BRAIN.md 2>/dev/null || true
  echo ""

  # Trimmed roadmap: progress table + execution priority + Phase 8
  # Skips Phases 0-7 full stage definitions (already completed)
  echo ""
  echo "===== ROADMAP (trimmed — progress + Phase 8 + strategy) ====="
  awk '
    BEGIN { show=0 }
    /^# Supply Orchestration SDK/ { show=1 }
    /^# Phase 0 /    { show=0 }
    /^# Phase 8 /    { show=1 }
    /^# Phase 6 — Provider Marketplace Foundation \(Revised\)/ { show=1 }
    /^# Strategic Direction/ { show=1 }
    show { print }
  ' ROADMAP.md 2>/dev/null || true
  echo ""

  print_file_full "COMMAND :: PLAN FEATURE" ".ai/commands/01_plan_feature.md"
  print_file_full "TEMPLATE :: SPEC" ".ai/templates/spec_template.md"
  print_latest_feature_full
}

emit_full_gemini() {
  print_section "Context Bundle for Gemini (FULL)"
  print_prompt_gemini
  print_file_full "PROJECT CONTEXT" "docs/AI_PROJECT_CONTEXT.md"
  print_file_full "REPO BRAIN" "docs/AI_REPO_BRAIN.md"
  print_file_full "AI WORKFLOW" "docs/AI_WORKFLOW.md"
  print_file_full "ROADMAP" "ROADMAP.md"
  print_file_full "CURRENT STAGE" "CURRENT_STAGE.md"
  print_file_full "KNOWN ISSUES" "KNOWN_ISSUES.md"
  for ctx_file in .ai/context/*.md; do
    [[ -f "$ctx_file" ]] || continue
    [[ "$(basename "$ctx_file")" =~ ^($CONTEXT_EXCLUDES)$ ]] && continue
    print_file_full "CONTEXT: $(basename "$ctx_file" .md)" "$ctx_file"
  done
  # Include spec template + task checklist so Gemini can validate checklist completeness
  print_file_full "TEMPLATE :: SPEC" ".ai/templates/spec_template.md"
  print_file_full "TEMPLATE :: TASK CHECKLIST" ".ai/templates/task_checklist.md"
  print_latest_feature_full
}

emit_full_claude() {
  print_section "Context Bundle for Claude (FULL)"
  print_prompt_claude_context
  print_file_full "PROJECT CONTEXT" "docs/AI_PROJECT_CONTEXT.md"
  print_file_full "REPO BRAIN" "docs/AI_REPO_BRAIN.md"
  print_file_full "AI WORKFLOW" "docs/AI_WORKFLOW.md"
  print_file_full "ROADMAP" "ROADMAP.md"
  print_file_full "CURRENT STAGE" "CURRENT_STAGE.md"
  print_file_full "TEST REPORT" "TEST_REPORT.md"
  print_file_full "KNOWN ISSUES" "KNOWN_ISSUES.md"
  for ctx_file in .ai/context/*.md; do
    [[ -f "$ctx_file" ]] && print_file_full "CONTEXT: $(basename "$ctx_file" .md)" "$ctx_file"
  done
  print_latest_feature_full
  print_file_full "COMMAND :: PREFLIGHT" ".ai/commands/05_preflight_grounding.md"
  print_file_full "COMMAND :: IMPLEMENT" ".ai/commands/02_implement_feature.md"
  print_file_full "COMMAND :: DIFF REVIEW" ".ai/commands/06_diff_review.md"
  print_file_full "COMMAND :: STABILIZE" ".ai/commands/03_stabilize_feature.md"
  print_file_full "COMMAND :: PR CHECK" ".ai/commands/04_pr_check.md"
}


run_claude_context_only() {
  local tmp
  tmp="$(make_tmp_context)"
  append_common_claude_context "$tmp"
  append_latest_spec_plan_review_impl "$tmp"
  {
    echo "### Claude Task"
    echo
    cat <<'EOF'
Use this project context to understand the repository.

Do not implement anything yet.
Do not modify code.
Wait for the next stage-specific instruction.
EOF
  } >> "$tmp"
  run_claude_with_input "$tmp"
}

run_claude_preflight() {
  require_stage_files
  require_stage_review
  local tmp
  tmp="$(make_tmp_context)"
  append_common_claude_context "$tmp"
  append_latest_spec_plan_review_impl "$tmp"
  {
    echo "### Claude Task :: Preflight Grounding"
    echo
    cat ".ai/commands/05_preflight_grounding.md"
  } >> "$tmp"
  run_claude_with_input "$tmp"
}

run_claude_implement() {
  require_stage_files
  require_stage_review
  require_stage_implementation
  local tmp
  tmp="$(make_tmp_context)"
  append_common_claude_context "$tmp"
  append_latest_spec_plan_review_impl "$tmp"
  {
    echo "### Claude Task :: Implementation"
    echo
    cat ".ai/commands/02_implement_feature.md"
  } >> "$tmp"
  run_claude_with_input "$tmp"
}

run_claude_all_no_post() {
  require_stage_files
  require_stage_review
  require_stage_implementation
  local tmp
  tmp="$(make_tmp_context)"
  append_common_claude_context "$tmp"
  append_latest_spec_plan_review_impl "$tmp"
  append_local_script_output_if_exists "$tmp" "Local Verify Stage Output" "$SCRIPT_DIR/ai-verify-stage.sh" "--quick"
  {
    cat <<'EOF'
### Claude Task :: Preflight + Implementation

Execute the workflow in this exact order:

1. Preflight grounding
2. If and only if preflight returns GO → implement feature

Rules:
- Stop immediately if preflight returns NO-GO
- Do not skip steps
- Do not expand scope

Note: This mode covers preflight and implementation only.
Diff review, stabilization, and PR check are handled by subsequent pipeline steps.

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
  } >> "$tmp"
  run_claude_with_input "$tmp"
}

run_claude_diff_review() {
  require_stage_files
  local tmp
  tmp="$(make_tmp_context)"
  append_common_claude_context "$tmp"
  append_latest_spec_plan_review_impl "$tmp"
  append_local_script_output_if_exists "$tmp" "Local Diff Evidence" "$SCRIPT_DIR/ai-diff-evidence.sh"
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
  require_stage_files
  local tmp
  tmp="$(make_tmp_context)"
  append_common_claude_context "$tmp"
  append_latest_spec_plan_review_impl "$tmp"
  append_local_script_output_if_exists "$tmp" "Local Verify Stage Output" "$SCRIPT_DIR/ai-verify-stage.sh" "--quick"
  {
    echo "### Claude Task :: Stabilization"
    echo
    cat ".ai/commands/03_stabilize_feature.md"
  } >> "$tmp"
  run_claude_with_input "$tmp"
}

run_claude_pr_check() {
  require_stage_files
  local tmp
  tmp="$(make_tmp_context)"
  append_common_claude_context "$tmp"
  append_latest_spec_plan_review_impl "$tmp"
  append_local_script_output_if_exists "$tmp" "Local Diff Evidence" "$SCRIPT_DIR/ai-diff-evidence.sh"
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
  require_stage_files
  require_stage_review
  require_stage_implementation
  local tmp
  tmp="$(make_tmp_context)"
  append_common_claude_context "$tmp"
  append_latest_spec_plan_review_impl "$tmp"
  append_local_script_output_if_exists "$tmp" "Local Verify Stage Output" "$SCRIPT_DIR/ai-verify-stage.sh" "--quick"
  append_local_script_output_if_exists "$tmp" "Local Diff Evidence" "$SCRIPT_DIR/ai-diff-evidence.sh"
  {
    cat <<'EOF'
### Claude Task :: Full Execution Pipeline

Execute the workflow in this exact order — all steps in one uninterrupted session:

1. Preflight grounding
2. If and only if preflight returns GO → implement feature
3. Diff review
4. Stabilize only if needed
5. PR check
6. Post-review artifacts (create .postreview.md + review bundle)
7. Commit all changes (implementation + artifacts + settings)
8. Post-implementation summary (confirm each step's outcome)

### Completion Rule (Non-Negotiable)

A stage-execute run is NOT complete unless all 8 steps above are finished and reported.
Do NOT stop after implementation. After implementation finishes, you MUST continue through
diff review, stabilization, PR check, post-review artifacts, and commit — in the same session.

The only acceptable reasons to stop early:
- Preflight returns NO-GO (stop before implementation)
- Diff review returns UNSAFE with a blocking issue that cannot be resolved
- Stabilization hits a BLOCKED condition that cannot be resolved

If none of these blocking conditions occur, you must complete all 8 steps and end with
a final summary confirming each step's outcome:

```
## Stage Execution Summary
- Preflight: GO / NO-GO
- Implementation: DONE / SKIPPED
- Diff Review: SAFE / WARN / UNSAFE
- Stabilization: STABILIZED / NOT NEEDED / BLOCKED
- PR Check: PASS / FAIL
- Post-Review Artifacts: WRITTEN / SKIPPED
- Commit: COMMITTED / SKIPPED
- Pipeline: COMPLETE
```

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

### Step 4 :: Stabilize (only if Step 3 finds issues)
EOF
    cat ".ai/commands/03_stabilize_feature.md"
    echo
    cat <<'EOF'

---

### Step 5 :: PR Check
EOF
    cat ".ai/commands/04_pr_check.md"
    echo
    cat <<'EOF'

---

### Step 6 :: Post-Review Artifacts (Non-Negotiable)

After completing the PR check, you MUST create both post-review artifact files before
reporting the final summary. These files are required for external architectural review.

**File 1:** `.ai/reviews/stage_X_Y/stage_X_Y_<name>.postreview.md`

This is the diff review report. It must contain:
- Changed files table (path, APPROVED/UNEXPECTED/PROTECTED classification)
- Unexpected changes (if any)
- API surface changes (PLANNED/UNPLANNED)
- Dependency changes (PLANNED/UNPLANNED)
- Invariant check (each invariant: PRESERVED / VIOLATED)
- Verdict: SAFE / WARN / UNSAFE

**File 2:** `.ai/reviews/stage_X_Y/post_review_X_Y_<name>.md`

This is the full review bundle for ChatGPT/Gemini architectural review. It must contain:
- Summary (what was implemented and why)
- Package structure (directory tree)
- Key design decisions (numbered list)
- Test results (count, coverage areas, build status)
- Boundary verification (what was NOT introduced)
- Files changed summary

Use the naming convention from previous stages (check `.ai/reviews/stage_X_Y/`
for examples). Replace X_Y with the stage number (dots replaced with underscores) and <name>
with the stage slug. All review artifacts for a stage go in `.ai/reviews/stage_X_Y/`.

Do NOT skip this step. Do NOT report the final summary until both files are written.

---

### Step 7 :: Commit All Changes (Non-Negotiable)

After all implementation files, artifact updates, and post-review files are written,
you MUST commit everything to the branch. The `--complete-stage` script will REJECT
completion if there are uncommitted files in the package directory.

Commit procedure:
1. Stage ALL relevant files:
   - The entire package directory (e.g. `packages/cart_supply_resolution/`)
   - `settings.gradle.kts` (if modified)
   - `CURRENT_STAGE.md`
   - `TEST_REPORT.md`
   - `.ai/reviews/stage_X_Y/` directory (all review artifacts for this stage)
2. Commit with message: `feat(stage-X.Y): implement stage X.Y — <stage name>`
3. Push to the remote branch

Do NOT skip this step. Uncommitted files will block `--complete-stage`.
EOF
  } >> "$tmp"
  run_claude_with_input "$tmp"
}

run_verify_stage() { safe_run_script "$SCRIPT_DIR/ai-verify-stage.sh" "${STYLE:-}"; }
run_diff_evidence() { safe_run_script "$SCRIPT_DIR/ai-diff-evidence.sh"; }
run_review_bundle() { safe_run_script "$SCRIPT_DIR/ai-review-bundle.sh"; }
run_post_review() { safe_run_script "$SCRIPT_DIR/ai-stage-post-review.sh" "$@"; }
run_complete_stage() { safe_run_script "$SCRIPT_DIR/ai-stage-complete.sh" "$1" "${2:-}"; }
run_stage_start() { safe_run_script "$SCRIPT_DIR/ai-stage-start.sh" "$1" "${2:-}"; }
run_stage_execute() { safe_run_script "$SCRIPT_DIR/ai-stage-execute.sh" "$@"; }
run_import_chatgpt() { safe_run_script "$SCRIPT_DIR/ai-import-chatgpt.sh" "$@"; }
run_update_context() { safe_run_script "$SCRIPT_DIR/ai-update-context.sh" "$@"; }
run_stage_revise() { safe_run_script "$SCRIPT_DIR/ai-stage-revise.sh" "$@"; }

run_stage_status() { safe_run_script "$SCRIPT_DIR/ai-stage-status.sh" "$@"; }
run_verify_conformance() { safe_run_script "$SCRIPT_DIR/ai-verify-conformance.sh" "$@"; }
run_reality_sync() { safe_run_script "$SCRIPT_DIR/ai-generate-reality-sync.sh" "$@"; }

main() {
  require_repo

  case "$MODE" in
    --chatgpt)
      mkdir -p "$REPO_ROOT/.ai/exports"
      local chatgpt_file="$REPO_ROOT/.ai/exports/chatgpt_context.md"
      case "$STYLE" in
        --paths) emit_paths_chatgpt ;;
        --full)
          emit_full_chatgpt > "$chatgpt_file"
          local fsize; fsize=$(wc -c < "$chatgpt_file" | awk '{printf "%.0f", $1/1024}')
          echo "Written to: $chatgpt_file (${fsize}KB)" >&2
          echo "Copied to clipboard." >&2
          cat "$chatgpt_file" | pbcopy 2>/dev/null || true
          cat "$chatgpt_file"
          ;;
        --compact)
          emit_compact_chatgpt > "$chatgpt_file"
          local csize; csize=$(wc -c < "$chatgpt_file" | awk '{printf "%.0f", $1/1024}')
          echo "Written to: $chatgpt_file (${csize}KB)" >&2
          echo "Copied to clipboard." >&2
          cat "$chatgpt_file" | pbcopy 2>/dev/null || true
          cat "$chatgpt_file"
          ;;
        *) usage ;;
      esac
      ;;
    --gemini)
      mkdir -p "$REPO_ROOT/.ai/exports"
      local gemini_file="$REPO_ROOT/.ai/exports/gemini_context.md"
      case "$STYLE" in
        --paths) emit_paths_gemini ;;
        --full)
          emit_full_gemini > "$gemini_file"
          local gsize; gsize=$(wc -c < "$gemini_file" | awk '{printf "%.0f", $1/1024}')
          echo "Written to: $gemini_file (${gsize}KB)" >&2
          echo "Copied to clipboard." >&2
          cat "$gemini_file" | pbcopy 2>/dev/null || true
          cat "$gemini_file"
          ;;
        *) usage ;;
      esac
      ;;
    --claude)
      case "$STYLE" in
        --paths) emit_paths_claude ;;
        --full) emit_full_claude ;;
        *) usage ;;
      esac
      ;;
    --claude-run) run_claude_context_only ;;
    --claude-preflight) run_claude_preflight ;;
    --claude-implement) run_claude_implement ;;
    --claude-diff-review) run_claude_diff_review ;;
    --claude-stabilize) run_claude_stabilize ;;
    --claude-pr-check) run_claude_pr_check ;;
    --claude-all-no-post) run_claude_all_no_post ;;
    --claude-all-post|--claude-all) run_claude_all ;;
    --verify-stage) run_verify_stage ;;
    --diff-evidence) run_diff_evidence ;;
    --review-bundle) run_review_bundle ;;
    --post-review) run_post_review "${2:-}" ;;
    --complete-stage) run_complete_stage "${2:-}" "${3:-}" ;;
    --stage-start) run_stage_start "${2:-}" "${3:-}" ;;
    --stage-status) shift; run_stage_status "$@" ;;
    --stage-execute) shift; run_stage_execute "$@" ;;
    --stage-revise) shift; run_stage_revise "$@" ;;
    --import-chatgpt) shift; run_import_chatgpt "$@" ;;
    --update-context) shift; run_update_context "$@" ;;
    --verify-conformance) shift; run_verify_conformance "$@" ;;
    --reality-sync) shift; run_reality_sync "$@" ;;
    *) usage ;;
  esac
}

main "$@"
