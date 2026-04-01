#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/ai-common.sh"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

INPUT_FILE="${1:-}"

usage() {
  cat <<'EOF'
Import ChatGPT output into .ai/ artifact files.

Usage:
  ./scripts/ai-import-chatgpt.sh <file>
  ./scripts/ai-import-chatgpt.sh --paste

Options:
  <file>     Path to a file containing ChatGPT's full output
  --paste    Open a temp file, paste from clipboard (pbpaste), then parse

The script detects sections in TWO formats and splits them into:
  .ai/specs/          .ai/plans/          .ai/reviews/          .ai/implementations/

Format A — Delimiter (preferred):
  # === SPEC ===
  # FILE: .ai/specs/stage_X_Y_name.md
  (content)
  # === PLAN ===
  # FILE: .ai/plans/stage_X_Y_name.plan.md
  (content)
  # === REVIEW ===
  ...
  # === IMPLEMENTATION ===
  ...

Format B — Header-based (legacy):
  # Stage X.Y — Name                        → spec
  # Stage X.Y — Implementation Plan          → plan
  # Gemini Review Request — Stage X.Y ...    → review
  # Claude Implementation Request — ...      → implementation

You can include all four in one file, or any subset.

Examples:
  # Paste ChatGPT output into a file, then import
  pbpaste > tmp/chatgpt.md
  ./scripts/ai-import-chatgpt.sh tmp/chatgpt.md

  # Or import directly from clipboard
  ./scripts/ai-import-chatgpt.sh --paste
EOF
  exit 1
}

if [ -z "$INPUT_FILE" ]; then
  usage
fi

# Handle --paste: grab from clipboard into a temp file
if [ "$INPUT_FILE" = "--paste" ]; then
  if ! command -v pbpaste >/dev/null 2>&1; then
    echo "Error: pbpaste not found (macOS only). Use a file path instead."
    exit 1
  fi
  INPUT_FILE="$(mktemp)"
  pbpaste > "$INPUT_FILE"
  echo "Captured clipboard to: $INPUT_FILE"
  CLEANUP_TMP=true
else
  CLEANUP_TMP=false
fi

if [ ! -f "$INPUT_FILE" ]; then
  echo "Error: file not found: $INPUT_FILE"
  exit 1
fi

if [ ! -s "$INPUT_FILE" ]; then
  echo "Error: file is empty: $INPUT_FILE"
  [ "$CLEANUP_TMP" = true ] && rm -f "$INPUT_FILE"
  exit 1
fi

# ---------------------------------------------------------
# Pre-process: strip wrapper formatting that ChatGPT adds
#
# ChatGPT output varies widely. Common wrapper formats:
#
#   # 1) `.ai/specs/stage_7_12_foo.md`        ← numbered file-path header
#   ## 1. Spec                                 ← numbered section header
#   ### SPEC                                   ← labeled section header
#   **Spec:**                                  ← bold label
#   ````md  /  ```md  /  ```markdown           ← code fence open
#   ````    /  ```                              ← code fence close
#   ---                                        ← horizontal rule between sections
#   > Note: below is the spec...               ← blockquote preamble
#
# We strip these so the parser can find the real `# ` headers inside.
# ---------------------------------------------------------
CLEAN_FILE="$(mktemp)"
# Detect delimiter format (# === SPEC ===) — if present, skip aggressive header stripping
if grep -qE '^# === (SPEC|PLAN|REVIEW|IMPLEMENTATION|IMPL) ===' "$INPUT_FILE"; then
  # Delimiter format: only strip code fences and blockquote preamble
  sed -E \
    -e '/^````/d' \
    -e '/^```md$/d' \
    -e '/^```markdown$/d' \
    -e '/^```text$/d' \
    -e '/^```$/d' \
    -e '/^> *(Note|Below|Here|The following|This is)/d' \
    "$INPUT_FILE" > "$CLEAN_FILE"
else
  # Traditional format: strip wrapper formatting that ChatGPT adds
  sed -E \
    -e '/^#{1,3} [0-9]+[\)\.] /d' \
    -e '/^#{1,3} *(SPEC|PLAN|REVIEW|IMPLEMENTATION|Spec|Plan|Review|Implementation) *$/d' \
    -e '/^````/d' \
    -e '/^```md$/d' \
    -e '/^```markdown$/d' \
    -e '/^```text$/d' \
    -e '/^```$/d' \
    -e '/^\*\*(Spec|Plan|Review|Implementation|Feature Spec|Implementation Plan|Gemini Review|Claude Implementation)[:\*]/d' \
    -e '/^> *(Note|Below|Here|The following|This is)/d' \
    "$INPUT_FILE" > "$CLEAN_FILE"
fi
INPUT_FILE="$CLEAN_FILE"
CLEANUP_CLEAN=true

# ---------------------------------------------------------
# Detect stage ID from CURRENT_STAGE.md or from the file
# ---------------------------------------------------------
STAGE_ID="$(current_stage_id)"

if [ -z "$STAGE_ID" ]; then
  # Try to detect from file content — supports both pure numeric (7.15) and alphanumeric (8.0g) stage IDs
  STAGE_ID="$(grep -oE 'Stage [0-9]+\.[0-9]+[a-zA-Z]?' "$INPUT_FILE" | head -1 | awk '{print $2}')"
fi

if [ -z "$STAGE_ID" ]; then
  # Fallback: try to extract from # FILE: .ai/specs/stage_X_Y_name.md directive
  STAGE_ID="$(grep -oE '# FILE:.*stage_([0-9]+)_([0-9]+[a-zA-Z]?)_' "$INPUT_FILE" | head -1 | sed -E 's/.*stage_([0-9]+)_([0-9]+[a-zA-Z]?)_.*/\1.\2/' || true)"
fi

if [ -z "$STAGE_ID" ]; then
  echo "Error: Could not determine stage ID from CURRENT_STAGE.md or file content."
  [ "$CLEANUP_TMP" = true ] && rm -f "$INPUT_FILE"
  exit 1
fi

STAGE_SLUG="$(echo "$STAGE_ID" | tr '.' '_')"

echo "========================================="
echo " Import ChatGPT Output: Stage $STAGE_ID"
echo "========================================="
echo

# ---------------------------------------------------------
# Detect stage name slug from file content
# ---------------------------------------------------------
# Extract stage name from file content
# Try multiple patterns to handle different ChatGPT output formats
STAGE_ID_ESC="$(echo "$STAGE_ID" | sed 's/\./\\./g')"
STAGE_NAME_RAW=""

# Pattern 1: "Stage 8.0h — Name" or "Stage 8.0h: Name" (exact ID match)
if [ -z "$STAGE_NAME_RAW" ]; then
  STAGE_NAME_RAW="$(grep -m1 "Stage ${STAGE_ID}" "$INPUT_FILE" | sed -E "s/.*Stage ${STAGE_ID}[^A-Za-z]*//" | sed 's/^[[:space:]]*//' | head -1 || true)"
fi

# Pattern 2: "# Feature Spec — Stage X.Y Name" (title line with spec prefix)
if [ -z "$STAGE_NAME_RAW" ]; then
  STAGE_NAME_RAW="$(grep -m1 -i "Feature Spec.*Stage" "$INPUT_FILE" | sed -E "s/.*Stage [0-9]+(\.[0-9]+)*[^A-Za-z]*//" | sed 's/^[[:space:]]*//' | head -1 || true)"
fi

# Pattern 3: "# Plan — Stage X.Y Name" or "# Implementation Plan"
if [ -z "$STAGE_NAME_RAW" ]; then
  STAGE_NAME_RAW="$(grep -m1 -i "Plan.*Stage\|Implementation.*Stage" "$INPUT_FILE" | sed -E "s/.*Stage [0-9]+(\.[0-9]+)*[^A-Za-z]*//" | sed 's/^[[:space:]]*//' | head -1 || true)"
fi

# Pattern 4: "# FILE: .ai/specs/stage_8_0h_name.md" directive
if [ -z "$STAGE_NAME_RAW" ]; then
  STAGE_NAME_RAW="$(grep -m1 '# FILE:.*stage_' "$INPUT_FILE" \
    | sed -E "s/.*stage_${STAGE_SLUG}_//" \
    | sed -E 's/\.(spec|plan|review|implementation)?\.?md$//' \
    | tr '_' ' ' || true)"
fi

# Pattern 5: First H1 line that looks like a title (fallback)
if [ -z "$STAGE_NAME_RAW" ]; then
  STAGE_NAME_RAW="$(grep -m1 '^# ' "$INPUT_FILE" | sed 's/^# //' | sed -E 's/^(Feature Spec|Plan|Review|Implementation)[^A-Za-z]*//' | sed 's/^[[:space:]]*//' || true)"
fi

# Pattern 6: Infer from ROADMAP.md for this stage ID
if [ -z "$STAGE_NAME_RAW" ] && [ -f ROADMAP.md ]; then
  STAGE_NAME_RAW="$(grep -m1 "^## Stage ${STAGE_ID_ESC} " ROADMAP.md 2>/dev/null | sed -E "s/^## Stage ${STAGE_ID_ESC}[^A-Za-z]*//" || true)"
fi

if [ -n "$STAGE_NAME_RAW" ]; then
  # Strip trailing markdown formatting (**, *, `, etc.)
  STAGE_NAME_RAW="$(echo "$STAGE_NAME_RAW" | sed -E 's/[\*\`]+$//' | sed 's/[[:space:]]*$//')"
  NAME_SLUG="$(echo "$STAGE_NAME_RAW" \
    | sed -E 's/ (followed by|and then|plus|with the|then the|including) .*//i' \
    | sed -E 's/ [\+\&] .*//' \
    | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | tr -cd '[:alnum:]_' \
    | sed 's/__*/_/g' | sed 's/_$//' \
    | head -c 40)"
else
  NAME_SLUG="unnamed"
fi

echo "  Stage: $STAGE_ID"
echo "  Name: ${STAGE_NAME_RAW:-unknown}"
echo "  Slug: stage_${STAGE_SLUG}_${NAME_SLUG}"
echo

# ---------------------------------------------------------
# Ensure directories exist
# ---------------------------------------------------------
REVIEW_DIR=".ai/reviews/stage_${STAGE_SLUG}"
mkdir -p .ai/specs .ai/plans "$REVIEW_DIR" .ai/implementations

# ---------------------------------------------------------
# Output file paths
# ---------------------------------------------------------
SPEC_FILE=".ai/specs/stage_${STAGE_SLUG}_${NAME_SLUG}.md"
PLAN_FILE=".ai/plans/stage_${STAGE_SLUG}_${NAME_SLUG}.plan.md"
REVIEW_FILE="${REVIEW_DIR}/stage_${STAGE_SLUG}_${NAME_SLUG}.review.md"
IMPL_FILE=".ai/implementations/stage_${STAGE_SLUG}_${NAME_SLUG}.implementation.md"

# ---------------------------------------------------------
# Section detection: classify each "# ..." header line.
#
# Supported header formats (case-insensitive, dash-flexible):
#
#   Implementation:
#     # Claude Implementation Request — Stage X.Y Name
#     # Stage X.Y — Claude Implementation Request
#     # Implementation — Stage X.Y ...
#     # Implementation Request: ...
#     # Claude Executor Request — ...
#
#   Review:
#     # Gemini Review Request — Stage X.Y Name
#     # Stage X.Y — Gemini Review Request
#     # Red-Team Review Request — Stage X.Y Name
#     # Review — Stage X.Y ...
#     # Gatekeeper Review — ...
#     # Review Request: ...
#
#   Plan:
#     # Stage X.Y — Implementation Plan
#     # Implementation Plan — Stage X.Y Name
#     # Implementation Plan: ...
#     # Plan — Stage X.Y ...
#     # Plan: ...
#     # Stage X.Y — Name  (followed by ## Implementation Plan on next line)
#
#   Spec (catch-all for stage headers not matched above):
#     # Stage X.Y — Name
#     # Feature Spec: Name
#     # Spec — Stage X.Y ...
#     # Spec: Name
#     # Feature Specification: Name
#
#   Skipped (never start a section):
#     # .ai/specs/...          (file-path headers)
#     # 1) do something        (instructional numbered steps)
#     Lines before any section header is detected
# ---------------------------------------------------------

classify_header() {
  local hdr="$1"
  # Normalize: lowercase, replace all dash variants (em-dash, en-dash) with plain hyphen
  local norm
  norm="$(echo "$hdr" | sed $'s/\xe2\x80\x94/-/g; s/\xe2\x80\x93/-/g' | tr '[:upper:]' '[:lower:]')"

  # --- Delimiter format: # === SPEC === / # === PLAN === / etc. ---
  case "$norm" in
    *"=== spec ==="*|*"===spec==="*) echo "spec_delim"; return ;;
    *"=== plan ==="*|*"===plan==="*) echo "plan_delim"; return ;;
    *"=== review ==="*|*"===review==="*) echo "review_delim"; return ;;
    *"=== implementation ==="*|*"===implementation==="*|*"=== impl ==="*) echo "impl_delim"; return ;;
  esac

  # --- FILE: directive (used in delimiter format) ---
  case "$norm" in
    "# file:"*) echo "file_directive"; return ;;
  esac

  # --- Implementation (check before plan to avoid "implementation plan" false match) ---
  case "$norm" in
    *"implementation request"*|*"executor request"*) echo "implementation"; return ;;
    "# implementation -"*|"# implementation:"*) echo "implementation"; return ;;
  esac

  # --- Review ---
  case "$norm" in
    *"review request"*|*"red team review"*|*"red-team review"*|*"gatekeeper review"*) echo "review"; return ;;
    "# review -"*|"# review:"*) echo "review"; return ;;
  esac

  # --- Plan ---
  case "$norm" in
    *"implementation plan"*) echo "plan"; return ;;
    "# plan -"*|"# plan:"*) echo "plan"; return ;;
  esac

  # --- Skip: file-path headers (but NOT # FILE: directives, handled above), numbered steps ---
  case "$hdr" in
    "# .ai/"*) echo "skip"; return ;;
    "# "[0-9]*")"*|"# "[0-9]*"."*) echo "skip"; return ;;
  esac

  # --- Spec (various formats) ---
  case "$norm" in
    "# stage "[0-9]*) echo "stage"; return ;;
    "# feature spec"*|"# spec:"*|"# spec -"*|"# specification"*) echo "stage"; return ;;
  esac

  echo "skip"
}

CURRENT_SECTION=""
CURRENT_OUTPUT=""
FOUND_SPEC=false
FOUND_PLAN=false
FOUND_REVIEW=false
FOUND_IMPL=false

flush_section() {
  if [ -n "$CURRENT_SECTION" ] && [ -n "$CURRENT_OUTPUT" ]; then
    case "$CURRENT_SECTION" in
      spec)           echo "$CURRENT_OUTPUT" > "$SPEC_FILE";   FOUND_SPEC=true ;;
      plan)           echo "$CURRENT_OUTPUT" > "$PLAN_FILE";   FOUND_PLAN=true ;;
      review)         echo "$CURRENT_OUTPUT" > "$REVIEW_FILE"; FOUND_REVIEW=true ;;
      implementation) echo "$CURRENT_OUTPUT" > "$IMPL_FILE";   FOUND_IMPL=true ;;
    esac
  fi
  CURRENT_OUTPUT=""
}

PENDING_STAGE_HEADER=""
DELIM_MODE=false  # True when using # === SECTION === format
while IFS= read -r line; do
  # When a bare stage header is held, check the next line to decide plan vs spec.
  if [ -n "$PENDING_STAGE_HEADER" ]; then
    if echo "$line" | grep -qiE "^##? Implementation Plan"; then
      flush_section; CURRENT_SECTION="plan"
      CURRENT_OUTPUT="${PENDING_STAGE_HEADER}
${line}"
      PENDING_STAGE_HEADER=""
      continue
    else
      if [ "$CURRENT_SECTION" != "spec" ]; then
        flush_section; CURRENT_SECTION="spec"
        CURRENT_OUTPUT="$PENDING_STAGE_HEADER"
      fi
      PENDING_STAGE_HEADER=""
      # Fall through to process current line normally
    fi
  fi

  # Only classify lines that start with "# " (h1 headers)
  if echo "$line" | grep -qE "^# "; then
    local_type="$(classify_header "$line")"
    case "$local_type" in
      # --- Delimiter format: # === SPEC === etc. ---
      spec_delim)
        flush_section; CURRENT_SECTION="spec"; CURRENT_OUTPUT=""; DELIM_MODE=true
        continue ;;
      plan_delim)
        flush_section; CURRENT_SECTION="plan"; CURRENT_OUTPUT=""; DELIM_MODE=true
        continue ;;
      review_delim)
        flush_section; CURRENT_SECTION="review"; CURRENT_OUTPUT=""; DELIM_MODE=true
        continue ;;
      impl_delim)
        flush_section; CURRENT_SECTION="implementation"; CURRENT_OUTPUT=""; DELIM_MODE=true
        continue ;;
      file_directive)
        # Skip the # FILE: line — it's metadata, not content
        continue ;;
      # --- Traditional header format ---
      implementation)
        flush_section; CURRENT_SECTION="implementation"; CURRENT_OUTPUT="$line"
        continue ;;
      review)
        flush_section; CURRENT_SECTION="review"; CURRENT_OUTPUT="$line"
        continue ;;
      plan)
        flush_section; CURRENT_SECTION="plan"; CURRENT_OUTPUT="$line"
        continue ;;
      stage)
        PENDING_STAGE_HEADER="$line"
        continue ;;
      skip)
        # In delimiter mode, skip lines don't break out of the current section
        if [ "$DELIM_MODE" = true ] && [ -n "$CURRENT_SECTION" ]; then
          CURRENT_OUTPUT="${CURRENT_OUTPUT}
${line}"
        fi
        continue ;;
    esac
  fi

  if [ -n "$CURRENT_SECTION" ]; then
    CURRENT_OUTPUT="${CURRENT_OUTPUT}
${line}"
  fi
done < "$INPUT_FILE"

# Flush any pending stage header that never resolved
if [ -n "$PENDING_STAGE_HEADER" ] && [ "$CURRENT_SECTION" != "spec" ]; then
  flush_section; CURRENT_SECTION="spec"
  CURRENT_OUTPUT="$PENDING_STAGE_HEADER"
fi
flush_section

# ---------------------------------------------------------
# Auto-fix spec heading format
#
# ChatGPT often produces bare headings like:
#   Verification Checklist
#   Preflight Clarification Intent
#
# But the conformance script requires ## prefix:
#   ## Verification Checklist
#   ## Preflight Clarification Intent
#
# Fix them automatically after import.
# ---------------------------------------------------------
if [ "$FOUND_SPEC" = true ] && [ -f "$SPEC_FILE" ]; then
  HEADING_FIXES=0

  # List of required headings that must have ## prefix
  # Use | as sed delimiter to avoid conflicts with special chars in headings
  for heading in "Verification Checklist" "Preflight Clarification Intent" \
                 "Open Questions" "Reviewer Notes" "Data Model Changes" \
                 "Public API Changes" "Dependencies"; do
    # Check if heading exists WITHOUT ## prefix (bare line or with tab/bullet prefix)
    if grep -qF "${heading}" "$SPEC_FILE" 2>/dev/null; then
      # Only fix if the ## version doesn't already exist
      if ! grep -q "^## ${heading}" "$SPEC_FILE" 2>/dev/null; then
        sed_i "s|^${heading}$|## ${heading}|" "$SPEC_FILE"
        sed_i "s|^	${heading}$|## ${heading}|" "$SPEC_FILE"
        HEADING_FIXES=$((HEADING_FIXES + 1))
      fi
    fi
  done

  # Also fix sub-headings under Verification Checklist
  # Use | as sed delimiter to avoid conflicts with / in heading names
  for subheading in "Required Artifacts" "Core Behavior" "Safety / Invariants" "Tests"; do
    if grep -qF "${subheading}" "$SPEC_FILE" 2>/dev/null; then
      if ! grep -q "^### ${subheading}" "$SPEC_FILE" 2>/dev/null; then
        sed_i "s|^${subheading}$|### ${subheading}|" "$SPEC_FILE"
        sed_i "s|^	${subheading}$|### ${subheading}|" "$SPEC_FILE"
        HEADING_FIXES=$((HEADING_FIXES + 1))
      fi
    fi
  done

  if [ "$HEADING_FIXES" -gt 0 ]; then
    echo "  Auto-fixed $HEADING_FIXES spec heading(s) to use ## prefix"
  fi
fi

# ---------------------------------------------------------
# Report results
# ---------------------------------------------------------
echo "Results:"
echo

FILES_CREATED=0

if [ "$FOUND_SPEC" = true ]; then
  LINES="$(wc -l < "$SPEC_FILE" | tr -d ' ')"
  echo "  SPEC           → $SPEC_FILE ($LINES lines)"
  FILES_CREATED=$((FILES_CREATED + 1))
else
  echo "  SPEC           → (not found in input)"
fi

if [ "$FOUND_PLAN" = true ]; then
  LINES="$(wc -l < "$PLAN_FILE" | tr -d ' ')"
  echo "  PLAN           → $PLAN_FILE ($LINES lines)"
  FILES_CREATED=$((FILES_CREATED + 1))
else
  echo "  PLAN           → (not found in input)"
fi

if [ "$FOUND_REVIEW" = true ]; then
  LINES="$(wc -l < "$REVIEW_FILE" | tr -d ' ')"
  echo "  REVIEW         → $REVIEW_FILE ($LINES lines)"
  FILES_CREATED=$((FILES_CREATED + 1))
else
  echo "  REVIEW         → (not found in input)"
fi

if [ "$FOUND_IMPL" = true ]; then
  LINES="$(wc -l < "$IMPL_FILE" | tr -d ' ')"
  echo "  IMPLEMENTATION → $IMPL_FILE ($LINES lines)"
  FILES_CREATED=$((FILES_CREATED + 1))
else
  echo "  IMPLEMENTATION → (not found in input)"
fi

echo
echo "  Files created: $FILES_CREATED"

if [ "$FILES_CREATED" -eq 0 ]; then
  echo
  echo "WARNING: No sections detected. Make sure the file contains headers like:"
  echo "  # Stage X.Y — Some Name            (spec)"
  echo "  # Stage X.Y — Implementation Plan   (plan)"
  echo "  # Gemini Review Request — ...        (review)"
  echo "  # Claude Implementation Request — ...(implementation)"
fi

# ---------------------------------------------------------
# Auto-generate missing artifacts from spec
# When ChatGPT only provides the spec, generate plan, review,
# and implementation stubs so the pipeline can proceed.
# ---------------------------------------------------------
if [ "$FOUND_SPEC" = true ]; then
  GENERATED=0

  if [ "$FOUND_PLAN" != true ]; then
    cat > "$PLAN_FILE" <<PLAN_EOF
# Plan — Stage ${STAGE_ID} ${STAGE_NAME_RAW:-}

## Goal
$(head -20 "$SPEC_FILE" | grep -v '^#' | grep -v '^---' | grep -v '^\s*$' | head -5)

## Implementation Steps
<!-- Auto-generated from spec. Review and refine before execution. -->

$(awk '/^### /{found=1} found{print}' "$SPEC_FILE")

## Non-Goals
$(awk '/^## Out of Scope/,/^## /{print}' "$SPEC_FILE" | grep -v '^##' || echo "See spec for out-of-scope items.")
PLAN_EOF
    FOUND_PLAN=true
    GENERATED=$((GENERATED + 1))
    LINES="$(wc -l < "$PLAN_FILE" | tr -d ' ')"
    echo
    echo "  PLAN (auto)    → $PLAN_FILE ($LINES lines)"
  fi

  if [ "$FOUND_REVIEW" != true ]; then
    cat > "$REVIEW_FILE" <<REVIEW_EOF
# Gemini Review Request — Stage ${STAGE_ID} ${STAGE_NAME_RAW:-}

Please red-team the proposed Stage ${STAGE_ID} architecture.

## Stage
- Stage: ${STAGE_ID}
- Name: ${STAGE_NAME_RAW:-}

## What This Stage Introduces
$(awk '/^## Implementation Scope/,/^## Out of Scope/{print}' "$SPEC_FILE" | grep -v '^##' | head -30 || awk '/^### /{print}' "$SPEC_FILE")

## Required Invariants
$(awk '/^## Architectural Invariants/,/^## /{print}' "$SPEC_FILE" | grep -v '^##' || echo "See spec for invariants.")

## Review Questions
1. Is the scope appropriate for this stage?
2. Does the design preserve existing architecture invariants?
3. Are there any hidden coupling or regression risks?
4. Is there any likely scope creep?
5. Are there any security or maintainability concerns?

## Output Format
Please respond with:
- GO / GO WITH CHANGES / NO-GO
- critical risks
- required corrections
- optional improvements
- final recommendation
REVIEW_EOF
    FOUND_REVIEW=true
    GENERATED=$((GENERATED + 1))
    LINES="$(wc -l < "$REVIEW_FILE" | tr -d ' ')"
    echo "  REVIEW (auto)  → $REVIEW_FILE ($LINES lines)"
  fi

  if [ "$FOUND_IMPL" != true ]; then
    # Extract the package from CURRENT_STAGE.md if available
    IMPL_PACKAGE="$(awk -F'Package: ' '/^Package: /{print $2}' CURRENT_STAGE.md 2>/dev/null | head -n1 || true)"

    cat > "$IMPL_FILE" <<IMPL_EOF
# Claude Implementation Request — Stage ${STAGE_ID} ${STAGE_NAME_RAW:-}

You are working in the \`supply_orchestration_sdk\` repo.

## Stage
- Stage: ${STAGE_ID}
- Package: \`${IMPL_PACKAGE:-TBD}\`

## Objective
$(head -20 "$SPEC_FILE" | grep -v '^#' | grep -v '^---' | grep -v '^\s*$' | head -5)

## First: Ground in the Repo
Before making changes:
- inspect the current state of the target package
- inspect existing conventions and patterns
- inspect roadmap and stage metadata

## In Scope
$(awk '/^## Implementation Scope/,/^## Out of Scope/{print}' "$SPEC_FILE" | grep -v '^##' || awk '/^### /{print}' "$SPEC_FILE")

## Out of Scope
$(awk '/^## Out of Scope/,/^## /{print}' "$SPEC_FILE" | grep -v '^##' || echo "See spec.")

## Required Architecture Rules
$(awk '/^## Architectural Invariants/,/^## /{print}' "$SPEC_FILE" | grep -v '^##' || echo "See spec for invariants.")

## Required Output
At the end, provide:
1. changed files
2. architecture summary
3. test/build results
4. scope check
5. risks/follow-ups
6. PR check report
IMPL_EOF
    FOUND_IMPL=true
    GENERATED=$((GENERATED + 1))
    LINES="$(wc -l < "$IMPL_FILE" | tr -d ' ')"
    echo "  IMPL (auto)    → $IMPL_FILE ($LINES lines)"
  fi

  if [ "$GENERATED" -gt 0 ]; then
    echo
    echo "  Auto-generated $GENERATED missing artifact(s) from spec."
    echo "  Review and refine before running --stage-execute."
    FILES_CREATED=$((FILES_CREATED + GENERATED))
  fi
fi

# Cleanup temp files
[ "${CLEANUP_CLEAN:-false}" = true ] && rm -f "$CLEAN_FILE"
[ "$CLEANUP_TMP" = true ] && rm -f "$INPUT_FILE"

echo
echo "========================================="
echo " Import Complete"
echo "========================================="
echo
echo "Next: run ./scripts/ai-run.sh --stage-start $STAGE_ID"
