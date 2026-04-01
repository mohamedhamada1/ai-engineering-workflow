#!/usr/bin/env bash
set -euo pipefail

repo_root() {
  git rev-parse --show-toplevel
}

# ---------------------------------------------------------
# Safe git add — skips gitignored files instead of failing
# Usage: safe_git_add file1 file2 ...
# Returns 0 even if some files are ignored or missing
# ---------------------------------------------------------
safe_git_add() {
  for _sga_file in "$@"; do
    if [ ! -e "$_sga_file" ]; then
      continue
    fi
    if git check-ignore -q "$_sga_file" 2>/dev/null; then
      continue
    fi
    git add "$_sga_file" 2>/dev/null || true
  done
}

require_git_repo() {
  git rev-parse --show-toplevel >/dev/null 2>&1 || {
    echo "Not inside a git repository."
    exit 1
  }
}

print_header() {
  echo "===== $1 ====="
}

# ---------------------------------------------------------
# Cross-platform sed -i helper
# Usage: sed_i 'sed-expression' file
# ---------------------------------------------------------
sed_i() {
  if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}

# ---------------------------------------------------------
# CURRENT_STAGE.md helpers
# Standard format:
#
# # Current Stage
#
# Stage: 9.5
#
# Status: Planning
#
# Package: packages/some_package
# ---------------------------------------------------------

current_stage_id() {
  if [ -f CURRENT_STAGE.md ]; then
    awk '/^Stage: /{print $2}' CURRENT_STAGE.md | head -n1
  fi
}

current_stage_name() {
  local stage_id
  stage_id="$(current_stage_id)"
  if [ -z "$stage_id" ]; then
    echo ""
    return
  fi
  local escaped
  escaped="$(echo "$stage_id" | sed 's/\./\\./g')"
  if [ -f ROADMAP.md ]; then
    grep -m1 "^## Stage ${escaped} —" ROADMAP.md 2>/dev/null \
      | sed "s/^## Stage ${escaped} — //" || echo ""
  else
    echo ""
  fi
}

current_stage_status() {
  if [ -f CURRENT_STAGE.md ]; then
    awk -F'Status: ' '/^Status: /{print $2}' CURRENT_STAGE.md | head -n1
  fi
}

# ---------------------------------------------------------
# Package resolution (reads Package: from CURRENT_STAGE.md)
# ---------------------------------------------------------

stage_package_dir() {
  if [ -f CURRENT_STAGE.md ]; then
    awk -F'Package: ' '/^Package: /{print $2}' CURRENT_STAGE.md | head -n1
  fi
}

# ---------------------------------------------------------
# Validation
# ---------------------------------------------------------

validate_current_stage() {
  local stage_id status pkg
  stage_id="$(current_stage_id)"
  status="$(current_stage_status)"
  pkg="$(stage_package_dir || true)"

  if [ -z "$stage_id" ]; then
    echo "ERROR: CURRENT_STAGE.md missing or has no Stage field"
    return 1
  fi
  if [ -z "$status" ]; then
    echo "ERROR: CURRENT_STAGE.md missing Status field"
    return 1
  fi
  if [ -z "$pkg" ]; then
    echo "WARN: CURRENT_STAGE.md missing Package field"
  fi
  return 0
}

# ---------------------------------------------------------
# Stage file helpers
# ---------------------------------------------------------

stage_slug() {
  echo "${1:-}" | tr '.' '_'
}

current_stage_slug() {
  stage_slug "$(current_stage_id)"
}

stage_spec_path() {
  local slug
  slug="$(current_stage_slug)"
  find .ai/specs -maxdepth 1 -type f -name "stage_${slug}_*.md" 2>/dev/null | grep -v '\.plan\.\|\.review\.\|\.implementation\.' | sort | head -n1 || true
}

stage_plan_path() {
  local slug
  slug="$(current_stage_slug)"
  find .ai/plans -maxdepth 1 -type f -name "stage_${slug}_*.plan.md" 2>/dev/null | sort | head -n1 || true
}

stage_review_dir() {
  local slug
  slug="$(current_stage_slug)"
  echo ".ai/reviews/stage_${slug}"
}

stage_review_path() {
  local dir
  dir="$(stage_review_dir)"
  # Check new per-stage folder first, fall back to flat layout
  local result
  result="$(find "$dir" -maxdepth 1 -type f -name "*.review.md" 2>/dev/null | sort | head -n1 || true)"
  if [ -n "$result" ]; then
    echo "$result"
    return
  fi
  # Legacy flat layout fallback
  local slug
  slug="$(current_stage_slug)"
  find .ai/reviews -maxdepth 1 -type f -name "stage_${slug}_*.review.md" 2>/dev/null | sort | head -n1 || true
}

stage_implementation_path() {
  local slug
  slug="$(current_stage_slug)"
  find .ai/implementations -maxdepth 1 -type f -name "stage_${slug}_*.implementation.md" 2>/dev/null | sort | head -n1 || true
}

require_stage_files() {
  local spec plan
  spec="$(stage_spec_path)"
  plan="$(stage_plan_path)"

  [ -n "$spec" ] && [ -f "$spec" ] || {
    echo "Missing stage spec for current stage: $(current_stage_id)"
    exit 1
  }

  [ -n "$plan" ] && [ -f "$plan" ] || {
    echo "Missing stage plan for current stage: $(current_stage_id)"
    exit 1
  }
}

require_stage_review() {
  local review
  review="$(stage_review_path)"

  [ -n "$review" ] && [ -f "$review" ] || {
    echo "Missing stage review for current stage: $(current_stage_id)"
    exit 1
  }
}

require_stage_implementation() {
  local impl
  impl="$(stage_implementation_path)"

  [ -n "$impl" ] && [ -f "$impl" ] || {
    echo "Missing stage implementation request for current stage: $(current_stage_id)"
    exit 1
  }
}

# ---------------------------------------------------------
# Changed files helpers (combines staged + unstaged + untracked)
# ---------------------------------------------------------

all_changed_files() {
  {
    git diff --name-only 2>/dev/null
    git diff --cached --name-only 2>/dev/null
    git ls-files --others --exclude-standard 2>/dev/null
  } | sort -u
}

# ---------------------------------------------------------
# Protected file check
# Returns: 0 if clean, 1 if violations found
# Outputs violations to stdout
# ---------------------------------------------------------

check_protected_files() {
  local mode="${1:-warn}"  # warn or strict
  local changed
  changed="$(all_changed_files)"
  local hit=0

  while IFS= read -r f; do
    [ -z "$f" ] && continue
    if echo "$changed" | grep -Fxq "$f"; then
      echo "VIOLATION: protected file changed -> $f"
      hit=1
    fi
  done < <(protected_files_list)

  if [ "$hit" -eq 0 ]; then
    echo "PASS -- no protected files changed"
    return 0
  fi

  if [ "$mode" = "strict" ]; then
    return 1
  fi
  return 0
}

# ---------------------------------------------------------
# Base branch detection
# ---------------------------------------------------------

detect_base_branch() {
  if git show-ref --verify --quiet refs/heads/main 2>/dev/null; then
    echo "main"
  elif git show-ref --verify --quiet refs/heads/master 2>/dev/null; then
    echo "master"
  else
    echo "main"
  fi
}

# ---------------------------------------------------------
# Diff base detection with merged-branch fork-point fallback
#
# After a feature branch is merged to main, a three-dot diff
# (main...HEAD or main...branch) returns empty because both
# sides share the same commits. This function detects that
# case and finds the real fork point by locating the
# "start stage" commit marker.
#
# Usage:
#   DIFF_BASE="$(resolve_diff_base <base_branch> <diff_ref> [stage_id])"
#
# Arguments:
#   base_branch  — e.g. "main"
#   diff_ref     — the branch or ref to diff against (e.g. HEAD, feat/stage-0.3)
#   stage_id     — optional stage ID for fork-point commit search
#
# Returns the resolved diff base (may be the original base
# branch or a fork-point parent commit).
# ---------------------------------------------------------

resolve_diff_base() {
  local base_branch="${1:?resolve_diff_base requires base_branch}"
  local diff_ref="${2:?resolve_diff_base requires diff_ref}"
  local stage_id="${3:-$(current_stage_id)}"
  local diff_base="$base_branch"

  # Check if the three-dot diff (symmetric difference) produces anything.
  # If empty, the branch is fully merged and we need the fork point.
  local standard_diff
  standard_diff="$(git diff --name-only "${diff_base}...${diff_ref}" 2>/dev/null || true)"

  if [ -z "$standard_diff" ] && [ -n "$stage_id" ]; then
    # Branch was already merged — find the fork point.
    # Look for the "chore: start stage" commit to locate the fork.
    local start_commit
    start_commit="$(git log --oneline --grep="start stage ${stage_id}" "${diff_ref}" 2>/dev/null | tail -1 | awk '{print $1}' || true)"
    if [ -n "$start_commit" ]; then
      diff_base="${start_commit}^"
      echo "  (branch already merged — using fork point ${diff_base})" >&2
    fi
  fi

  echo "$diff_base"
}

# ---------------------------------------------------------
# Stage-to-package mapping
# ---------------------------------------------------------

resolve_package_for_stage() {
  local stage_id="${1:-}"
  local result=""

  # 1) Check explicit mapping file (fastest, most reliable)
  if [ -f ".ai/stage_package_map.sh" ]; then
    # shellcheck disable=SC1091
    source ".ai/stage_package_map.sh"
    if type -t stage_package_map >/dev/null 2>&1; then
      result="$(stage_package_map "$stage_id")"
      if [ -n "$result" ]; then
        echo "$result"
        return 0
      fi
    fi
  fi

  # 2) Fallback: read Package: from CURRENT_STAGE.md if it matches this stage
  if [ -f CURRENT_STAGE.md ]; then
    local cs_stage cs_pkg
    cs_stage="$(awk '/^Stage: /{print $2}' CURRENT_STAGE.md | head -n1)"
    cs_pkg="$(awk -F'Package: ' '/^Package: /{print $2}' CURRENT_STAGE.md | head -n1)"
    if [ "$cs_stage" = "$stage_id" ] && [ -n "$cs_pkg" ]; then
      echo "$cs_pkg"
      return 0
    fi
  fi

  # 3) Fallback: extract from spec file (Primary Package / Package field)
  local slug spec_file
  slug="$(echo "$stage_id" | tr '.' '_')"
  spec_file="$(find .ai/specs -maxdepth 1 -type f -name "stage_${slug}_*.md" 2>/dev/null | grep -v '\.plan\.\|\.review\.\|\.implementation\.' | sort | head -n1 || true)"
  if [ -n "$spec_file" ] && [ -f "$spec_file" ]; then
    result="$(grep -m1 -E '^\- Primary Package:|^Primary Package:' "$spec_file" 2>/dev/null | sed -E 's/.*:\s*//' | tr -d ' ' || true)"
    if [ -n "$result" ]; then
      echo "$result"
      return 0
    fi
  fi

  # 4) No resolution possible
  echo ""
  return 1
}

# ---------------------------------------------------------
# Persist a stage → package mapping (idempotent)
# Usage: persist_stage_mapping "7.2" "packages/my_package"
# ---------------------------------------------------------
persist_stage_mapping() {
  local stage_id="${1:?persist_stage_mapping requires stage_id}"
  local pkg_dir="${2:?persist_stage_mapping requires package_dir}"
  local map_file=".ai/stage_package_map.sh"

  [ -f "$map_file" ] || return 0

  # Already mapped — skip
  if grep -qF "\"${stage_id}\")" "$map_file" 2>/dev/null; then
    return 0
  fi

  # Insert before the catch-all *) line
  if grep -q '^\s*\*)' "$map_file"; then
    sed_i "s|^\(    \*)\)|    \"${stage_id}\") echo \"${pkg_dir}\" ;;\n\1|" "$map_file"
    echo "  Registered mapping: ${stage_id} -> ${pkg_dir}"
  fi
}

# ---------------------------------------------------------
# Build system detection
# ---------------------------------------------------------

detect_build_system() {
  local pkg="${1:-}"

  # Package-level detection (check the target directory first)
  if [ -n "$pkg" ] && [ -f "$pkg/build.gradle.kts" ]; then
    echo "gradle"
  elif [ -n "$pkg" ] && [ -f "$pkg/pubspec.yaml" ]; then
    echo "flutter"
  elif is_openapi_contract_dir "$pkg"; then
    echo "openapi"
  elif [ -n "$pkg" ] && [ -f "$pkg/package.json" ]; then
    echo "node"
  elif [ -n "$pkg" ] && [ -f "$pkg/Package.swift" ]; then
    echo "swift"
  # Repo-root fallback (only if no package-level match)
  elif [ -f "build.gradle.kts" ] || [ -f "build.gradle" ]; then
    echo "gradle"
  elif [ -f "pubspec.yaml" ]; then
    echo "flutter"
  elif [ -f "package.json" ]; then
    echo "node"
  elif [ -f "Package.swift" ]; then
    echo "swift"
  else
    echo "unknown"
  fi
}

# ---------------------------------------------------------
# OpenAPI contract directory detection
# Returns 0 if the directory contains .yaml/.yml OpenAPI files
# ---------------------------------------------------------
is_openapi_contract_dir() {
  local dir="${1:-}"
  [ -n "$dir" ] && [ -d "$dir" ] || return 1
  # Check for any .yaml or .yml file containing "openapi:" at the top level
  find "$dir" -maxdepth 1 -type f \( -name "*.yaml" -o -name "*.yml" \) 2>/dev/null | head -1 | grep -q . || return 1
  return 0
}

# Run build for detected build system
run_build() {
  local pkg="${1:-}"
  local build_system
  build_system="$(detect_build_system "$pkg")"

  case "$build_system" in
    gradle)
      local gradle_pkg=":$(echo "$pkg" | tr '/' ':')"
      ./gradlew "${gradle_pkg}:build" --no-daemon 2>&1
      ;;
    flutter)
      if [ -n "$pkg" ] && [ -d "$pkg" ]; then
        (cd "$pkg" && flutter pub get && dart analyze) 2>&1
      else
        flutter pub get && dart analyze 2>&1
      fi
      ;;
    node)
      if [ -n "$pkg" ] && [ -d "$pkg" ]; then
        (cd "$pkg" && npm ci && npm run lint && npm run build) 2>&1
      else
        npm ci && npm run lint && npm run build 2>&1
      fi
      ;;
    swift)
      swift build 2>&1
      ;;
    openapi)
      validate_openapi_contracts "$pkg" 2>&1
      ;;
    *)
      echo "Unknown build system — skipping build"
      return 0
      ;;
  esac
}

# Run tests for detected build system
run_tests() {
  local pkg="${1:-}"
  local build_system
  build_system="$(detect_build_system "$pkg")"

  case "$build_system" in
    gradle)
      local gradle_pkg=":$(echo "$pkg" | tr '/' ':')"
      ./gradlew "${gradle_pkg}:test" --no-daemon 2>&1
      ;;
    flutter)
      if [ -n "$pkg" ] && [ -d "$pkg" ]; then
        (cd "$pkg" && flutter test) 2>&1
      else
        flutter test 2>&1
      fi
      ;;
    node)
      if [ -n "$pkg" ] && [ -d "$pkg" ]; then
        (cd "$pkg" && npm test) 2>&1
      else
        npm test 2>&1
      fi
      ;;
    swift)
      swift test 2>&1
      ;;
    openapi)
      echo "OpenAPI contracts validated during build step — no separate test phase"
      return 0
      ;;
    *)
      echo "Unknown build system — skipping tests"
      return 0
      ;;
  esac
}

# ---------------------------------------------------------
# OpenAPI contract validation
#
# Validates YAML files in a contract directory:
#   1. YAML parse validity (syntax)
#   2. Required OpenAPI fields (openapi, info, info.title, info.version)
#   3. $ref reference resolution (local file refs exist)
#
# Uses Ruby's built-in YAML parser (ships with macOS/most Linux).
# Falls back to basic checks if Ruby is unavailable.
# ---------------------------------------------------------
validate_openapi_contracts() {
  local dir="${1:?validate_openapi_contracts requires a directory}"
  local exit_code=0
  local yaml_files=()
  local all_yaml_files=()

  # Collect all YAML files (top-level and subdirectories), excluding dependencies
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    all_yaml_files+=("$f")
  done < <(find "$dir" -type d \( -name node_modules -o -name generated -o -name .git \) -prune -o -type f \( -name "*.yaml" -o -name "*.yml" \) -print 2>/dev/null | sort)

  # Identify top-level API spec files (contain "openapi:" field)
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    yaml_files+=("$f")
  done < <(find "$dir" -maxdepth 1 -type f \( -name "*.yaml" -o -name "*.yml" \) 2>/dev/null | sort)

  if [ ${#all_yaml_files[@]} -eq 0 ]; then
    echo "WARN: No YAML files found in $dir"
    return 1
  fi

  echo "Validating ${#all_yaml_files[@]} YAML file(s) in $dir..."

  local rel="" check_result="" ref_errors=0 f_dir="" ref_path="" resolved=""

  # Step 1: YAML parse validation for all files
  for f in "${all_yaml_files[@]}"; do
    rel="${f#./}"
    if command -v ruby >/dev/null 2>&1; then
      if ruby -e "require 'yaml'; YAML.load_file('$f', permitted_classes: [Date, Time])" 2>/dev/null; then
        echo "  PASS — YAML parse: $rel"
      else
        echo "  FAIL — YAML parse error: $rel"
        exit_code=1
      fi
    else
      if [ -s "$f" ] && file "$f" | grep -q text; then
        echo "  PASS — file readable: $rel (no YAML parser available for deep check)"
      else
        echo "  FAIL — file unreadable or empty: $rel"
        exit_code=1
      fi
    fi
  done

  # Step 2: OpenAPI structure validation for top-level spec files
  for f in "${yaml_files[@]}"; do
    rel="${f#./}"
    if command -v ruby >/dev/null 2>&1; then
      check_result="$(ruby -e "
        require 'yaml'
        doc = YAML.load_file('$f', permitted_classes: [Date, Time])
        exit 0 unless doc.is_a?(Hash)
        errors = []
        errors << 'missing openapi field' unless doc['openapi']
        if doc['info'].is_a?(Hash)
          errors << 'missing info.title' unless doc['info']['title']
          errors << 'missing info.version' unless doc['info']['version']
        elsif doc.key?('info')
          errors << 'info is not a mapping'
        end
        if doc['openapi'] || doc['paths'] || doc['info']
          if errors.empty?
            puts 'OK'
          else
            puts errors.join(', ')
          end
        else
          puts 'COMPONENT'
        end
      " 2>&1)"

      if [ "$check_result" = "OK" ]; then
        echo "  PASS — OpenAPI structure: $rel"
      elif [ "$check_result" = "COMPONENT" ]; then
        echo "  PASS — component schema: $rel (not a root spec)"
      else
        echo "  FAIL — OpenAPI structure: $rel ($check_result)"
        exit_code=1
      fi
    fi
  done

  # Step 3: $ref reference resolution
  ref_errors=0
  for f in "${all_yaml_files[@]}"; do
    f_dir="$(dirname "$f")"
    while IFS= read -r ref_line; do
      [ -z "$ref_line" ] && continue
      ref_path="$(echo "$ref_line" | sed -E "s/.*\\\$ref: ['\"]?([^#'\"]+).*/\1/" | sed "s/['\"]//g")"
      if [ -z "$ref_path" ] || echo "$ref_path" | grep -qE '^\$ref|^#'; then
        continue
      fi
      resolved="${f_dir}/${ref_path}"
      if [ ! -f "$resolved" ]; then
        echo "  FAIL — broken \$ref in $(basename "$f"): $ref_path (resolved: $resolved)"
        ref_errors=$((ref_errors + 1))
        exit_code=1
      fi
    done < <(grep '\$ref:' "$f" 2>/dev/null | grep -v '#/' || true)
  done

  if [ "$ref_errors" -eq 0 ]; then
    echo "  PASS — all \$ref file references resolve"
  fi

  return "$exit_code"
}

# ---------------------------------------------------------
# Versioned directory helpers
#
# Creates incremental version subdirectories (v1/, v2/, v3/)
# inside a stage review directory. Multiple scripts running
# in the same pipeline share the same version folder.
#
# next_version_dir  — always creates a NEW v{N+1}/ directory
# ensure_version_dir — reuses latest v{N}/ or creates v1/ if none exist
# current_version_dir — returns latest v{N}/ without creating
#
# Typical usage in a pipeline:
#   1st script:  VERSION_DIR="$(next_version_dir "$REVIEW_DIR")"
#   2nd script:  VERSION_DIR="$(ensure_version_dir "$REVIEW_DIR")"
#   3rd script:  VERSION_DIR="$(ensure_version_dir "$REVIEW_DIR")"
#   All three write into the same v{N}/ folder.
#
# Standalone re-run (e.g., conformance recheck):
#   VERSION_DIR="$(next_version_dir "$REVIEW_DIR")"
#   Creates a fresh v{N+1}/ folder.
# ---------------------------------------------------------

# Always creates a NEW version directory (v1, v2, v3...).
# Use this when starting a fresh review run.
next_version_dir() {
  local parent="${1:?next_version_dir requires parent directory}"
  local version=1

  if [ -d "$parent" ]; then
    local latest
    latest="$(find "$parent" -maxdepth 1 -type d -name 'v[0-9]*' 2>/dev/null | sort -V | tail -1 || true)"
    if [ -n "$latest" ]; then
      local current_v
      current_v="$(basename "$latest" | sed -E 's/^v([0-9]+)$/\1/')"
      if [ -n "$current_v" ] && [ "$current_v" -eq "$current_v" ] 2>/dev/null; then
        version=$((current_v + 1))
      fi
    fi
  fi

  local vdir="${parent}/v${version}"
  mkdir -p "$vdir"
  echo "$vdir"
}

# Reuses the latest version directory, or creates v1/ if none exist.
# Use this when adding files to an existing review run.
ensure_version_dir() {
  local parent="${1:?ensure_version_dir requires parent directory}"

  if [ -d "$parent" ]; then
    local latest
    latest="$(find "$parent" -maxdepth 1 -type d -name 'v[0-9]*' 2>/dev/null | sort -V | tail -1 || true)"
    if [ -n "$latest" ]; then
      echo "$latest"
      return 0
    fi
  fi

  # No version dirs exist — create v1
  local vdir="${parent}/v1"
  mkdir -p "$vdir"
  echo "$vdir"
}

# Returns the latest version directory without creating.
# Returns empty string if none exist.
current_version_dir() {
  local parent="${1:?current_version_dir requires parent directory}"

  if [ -d "$parent" ]; then
    local latest
    latest="$(find "$parent" -maxdepth 1 -type d -name 'v[0-9]*' 2>/dev/null | sort -V | tail -1 || true)"
    if [ -n "$latest" ]; then
      echo "$latest"
      return 0
    fi
  fi

  echo ""
}

protected_files_list() {
  # Files that Claude must not modify during implementation.
  # CURRENT_STAGE.md and ROADMAP.md are excluded because stage
  # workflow scripts (ai-stage-start, ai-stage-execute, ai-stage-complete)
  # legitimately modify them as part of the stage lifecycle.

  # Engine-level protected files (always protected)
  cat <<'EOT'
docs/AI_WORKFLOW.md
docs/AI_AGENT_ROLES.md
.ai/templates/spec_template.md
.ai/templates/plan_template.md
.ai/templates/preflight_template.md
.ai/templates/diff_review_template.md
.ai/templates/stabilize_template.md
.ai/commands/01_plan_feature.md
.ai/commands/02_implement_feature.md
.ai/commands/03_stabilize_feature.md
.ai/commands/04_pr_check.md
.ai/commands/05_preflight_grounding.md
.ai/commands/06_diff_review.md
EOT

  # Project-level protected files (from .ai/config/project.conf)
  if [ -f ".ai/config/project.conf" ]; then
    grep -E "^PROTECTED_PATHS=" ".ai/config/project.conf" 2>/dev/null \
      | sed 's/^PROTECTED_PATHS=//' | tr ',' '\n' | sed 's/^[[:space:]]*//' | grep -v '^$' || true
  fi
}
