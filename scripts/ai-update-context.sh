#!/usr/bin/env bash
set -euo pipefail
export GIT_PAGER=cat
source "$(dirname "$0")/ai-common.sh"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

require_git_repo

MODE="${1:---generate}"  # --generate (default) or --apply <file>

CONTEXT_OUT_DIR=".ai/context_updates"
mkdir -p "$CONTEXT_OUT_DIR"

# ---------------------------------------------------------
# --apply mode: import updated context files from ChatGPT
# ---------------------------------------------------------
if [ "$MODE" = "--apply" ]; then
  INPUT_FILE="${2:-}"
  if [ -z "$INPUT_FILE" ] || [ ! -f "$INPUT_FILE" ]; then
    echo "Usage: ./scripts/ai-update-context.sh --apply <file>"
    echo "  The file should contain ChatGPT's updated context output."
    echo "  Sections are detected by headers:"
    echo "    # AI Project Context   → docs/AI_PROJECT_CONTEXT.md"
    echo "    # AI Repo Brain        → docs/AI_REPO_BRAIN.md"
    echo "    # Supply Orchestration SDK — Roadmap → ROADMAP.md"
    exit 1
  fi

  echo "========================================="
  echo " Applying Context Update"
  echo "========================================="
  echo

  CURRENT_SECTION=""
  CURRENT_OUTPUT=""
  APPLIED=0

  flush_context_section() {
    if [ -n "$CURRENT_SECTION" ] && [ -n "$CURRENT_OUTPUT" ]; then
      case "$CURRENT_SECTION" in
        project_context)
          echo "$CURRENT_OUTPUT" > docs/AI_PROJECT_CONTEXT.md
          echo "  Updated: docs/AI_PROJECT_CONTEXT.md"
          APPLIED=$((APPLIED + 1))
          ;;
        repo_brain)
          echo "$CURRENT_OUTPUT" > docs/AI_REPO_BRAIN.md
          echo "  Updated: docs/AI_REPO_BRAIN.md"
          APPLIED=$((APPLIED + 1))
          ;;
        roadmap)
          echo "$CURRENT_OUTPUT" > ROADMAP.md
          echo "  Updated: ROADMAP.md"
          APPLIED=$((APPLIED + 1))
          ;;
      esac
    fi
    CURRENT_OUTPUT=""
  }

  while IFS= read -r line; do
    if echo "$line" | grep -qi '^# AI Project Context'; then
      flush_context_section
      CURRENT_SECTION="project_context"
      CURRENT_OUTPUT="$line"
      continue
    elif echo "$line" | grep -qi '^# AI Repo Brain'; then
      flush_context_section
      CURRENT_SECTION="repo_brain"
      CURRENT_OUTPUT="$line"
      continue
    elif echo "$line" | grep -qiE '^# .+ — Roadmap$|^# .+ Roadmap$'; then
      flush_context_section
      CURRENT_SECTION="roadmap"
      CURRENT_OUTPUT="$line"
      continue
    fi

    if [ -n "$CURRENT_SECTION" ]; then
      CURRENT_OUTPUT="${CURRENT_OUTPUT}
${line}"
    fi
  done < "$INPUT_FILE"

  flush_context_section

  echo
  echo "  Files updated: $APPLIED"

  if [ "$APPLIED" -gt 0 ]; then
    echo
    echo "Review the changes:"
    echo "  git diff docs/AI_PROJECT_CONTEXT.md docs/AI_REPO_BRAIN.md ROADMAP.md"
    echo
    echo "If correct, commit:"
    echo "  git add docs/AI_PROJECT_CONTEXT.md docs/AI_REPO_BRAIN.md ROADMAP.md"
    echo "  git commit -m \"docs: update project context, repo brain, and roadmap\""
  fi

  exit 0
fi

# ---------------------------------------------------------
# --generate mode: create a context refresh bundle for ChatGPT
# ---------------------------------------------------------
CONTEXT_VERSION_DIR="$(next_version_dir "$CONTEXT_OUT_DIR")"
OUT_FILE="${CONTEXT_VERSION_DIR}/context_refresh.md"

echo "========================================="
echo " Context Refresh Bundle"
echo "========================================="
echo

{
  cat <<'HEADER'
# Context Refresh Request

You are the architect for this project. The following bundle contains the current state of the project documentation and codebase.

Please regenerate the following three files based on the current state:

1. **AI Project Context** (`docs/AI_PROJECT_CONTEXT.md`) — high-level project purpose, architecture, and direction
2. **AI Repo Brain** (`docs/AI_REPO_BRAIN.md`) — condensed implementation truth: packages, interfaces, models, build commands
3. **Roadmap** (`ROADMAP.md`) — stage-by-stage roadmap with accurate completion status

Rules:
- Preserve existing structure and format of each file
- Update completion status based on actual implemented packages
- Add any new packages/models/interfaces discovered in the codebase
- Remove references to things that no longer exist
- Keep the content accurate to what is actually implemented
- Do NOT invent features that don't exist in the code
- Output each file with its original header so they can be split back

Output format — return all three files concatenated, each starting with its header:
```
# AI Project Context
...

# AI Repo Brain
...

# <Project Name> — Roadmap
...
```

---

HEADER

  echo "## Current docs/AI_PROJECT_CONTEXT.md"
  echo
  [ -f docs/AI_PROJECT_CONTEXT.md ] && cat docs/AI_PROJECT_CONTEXT.md || echo "(missing)"
  echo
  echo "---"
  echo

  echo "## Current docs/AI_REPO_BRAIN.md"
  echo
  [ -f docs/AI_REPO_BRAIN.md ] && cat docs/AI_REPO_BRAIN.md || echo "(missing)"
  echo
  echo "---"
  echo

  echo "## Current ROADMAP.md"
  echo
  [ -f ROADMAP.md ] && cat ROADMAP.md || echo "(missing)"
  echo
  echo "---"
  echo

  echo "## Current CURRENT_STAGE.md"
  echo
  [ -f CURRENT_STAGE.md ] && cat CURRENT_STAGE.md || echo "(missing)"
  echo
  echo "---"
  echo

  echo "## Current KNOWN_ISSUES.md"
  echo
  [ -f KNOWN_ISSUES.md ] && cat KNOWN_ISSUES.md || echo "(missing)"
  echo
  echo "---"
  echo

  echo "## Current TEST_REPORT.md"
  echo
  [ -f TEST_REPORT.md ] && cat TEST_REPORT.md || echo "(missing)"
  echo
  echo "---"
  echo

  echo "## Git Log (last 30 commits)"
  echo
  echo '```'
  git log --oneline -30 2>/dev/null || echo "(no commits)"
  echo '```'
  echo
  echo "---"
  echo

  echo "## Package/Module Structure"
  echo
  echo '```'
  if [ -d "packages" ]; then
    find packages -maxdepth 3 -name "build.gradle.kts" -o -name "pubspec.yaml" 2>/dev/null | sort
  fi
  if [ -f "pubspec.yaml" ]; then
    echo "pubspec.yaml (root)"
  fi
  echo '```'
  echo
  echo "---"
  echo

  echo "## Source File Tree"
  echo
  echo '```'
  if [ -d "packages" ]; then
    find packages -type f -name "*.kt" -o -name "*.dart" -o -name "*.swift" -o -name "*.ts" 2>/dev/null | head -200 | sort
  elif [ -d "lib" ]; then
    find lib -type f -name "*.dart" -o -name "*.kt" -o -name "*.swift" -o -name "*.ts" 2>/dev/null | head -200 | sort
  elif [ -d "src" ]; then
    find src -type f -name "*.dart" -o -name "*.kt" -o -name "*.swift" -o -name "*.ts" 2>/dev/null | head -200 | sort
  fi
  echo '```'
  echo

} > "$OUT_FILE"

echo "Context refresh bundle written to: $OUT_FILE"
echo
echo "Workflow:"
echo "  1. Copy bundle:  cat $OUT_FILE | pbcopy"
echo "  2. Paste into ChatGPT"
echo "  3. ChatGPT returns updated context/brain/roadmap"
echo "  4. Save response: pbpaste > tmp/context_update.md"
echo "  5. Apply:  ./scripts/ai-update-context.sh --apply tmp/context_update.md"
echo "  6. Review: git diff docs/ ROADMAP.md"
echo "  7. Commit: git add docs/ ROADMAP.md && git commit -m 'docs: refresh context'"
