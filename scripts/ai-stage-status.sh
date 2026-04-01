#!/usr/bin/env bash
set -euo pipefail
export GIT_PAGER=cat
source "$(dirname "$0")/ai-common.sh"

require_git_repo

MODE="${1:-}"

# ---------------------------------------------------------
# --all: Dashboard view of all stages from ROADMAP
# ---------------------------------------------------------
if [ "$MODE" = "--all" ]; then
  if [ ! -f ROADMAP.md ]; then
    echo "ROADMAP.md not found."
    exit 1
  fi

  CURRENT="$(current_stage_id)"

  # Count stages by status
  TOTAL=0; COMPLETE=0; PLANNED=0; IN_PROG=0; ABSORBED=0; DEFERRED=0

  while IFS='|' read -r id name status; do
    [ -z "$id" ] && continue
    TOTAL=$((TOTAL + 1))
    case "$status" in
      Complete*) COMPLETE=$((COMPLETE + 1)) ;;
      Planned*)  PLANNED=$((PLANNED + 1)) ;;
      *Progress*) IN_PROG=$((IN_PROG + 1)) ;;
      Absorbed*) ABSORBED=$((ABSORBED + 1)) ;;
      Deferred*) DEFERRED=$((DEFERRED + 1)) ;;
    esac
  done < <(awk '
    /^## Stage [0-9]/ {
      stage = $0
      sub(/^## Stage /, "", stage)
      split(stage, parts, " — ")
      id = parts[1]
      name = parts[2]
      getline
      status = $0
      sub(/^Status: /, "", status)
      gsub(/[[:space:]]+$/, "", status)
      print id "|" name "|" status
    }
  ' ROADMAP.md)

  # Progress bar
  if [ "$TOTAL" -gt 0 ]; then
    PCT=$((COMPLETE * 100 / TOTAL))
    BAR_WIDTH=40
    FILLED=$((PCT * BAR_WIDTH / 100))
    EMPTY=$((BAR_WIDTH - FILLED))
    BAR="$(printf '%0.s█' $(seq 1 $FILLED 2>/dev/null) || true)$(printf '%0.s░' $(seq 1 $EMPTY 2>/dev/null) || true)"
  else
    PCT=0; BAR=""
  fi

  echo
  echo "  ╔══════════════════════════════════════════════════╗"
  echo "  ║          STAGE DASHBOARD                        ║"
  echo "  ╠══════════════════════════════════════════════════╣"
  printf "  ║  Progress: [%-40s] %3d%%  ║\n" "$BAR" "$PCT"
  echo "  ║                                                  ║"
  printf "  ║  Complete: %-4d  Planned: %-4d  In Progress: %-3d ║\n" "$COMPLETE" "$PLANNED" "$IN_PROG"
  printf "  ║  Absorbed: %-4d  Deferred: %-4d  Total: %-4d     ║\n" "$ABSORBED" "$DEFERRED" "$TOTAL"
  echo "  ║                                                  ║"
  printf "  ║  Current:  %-39s ║\n" "${CURRENT:-none}"
  echo "  ╚══════════════════════════════════════════════════╝"
  echo

  # Stage listing grouped by status
  echo "  IN PROGRESS / PLANNED"
  echo "  ─────────────────────────────────────────────────────────────"

  awk -v current="$CURRENT" '
    /^## Stage [0-9]/ {
      stage = $0
      sub(/^## Stage /, "", stage)
      split(stage, parts, " — ")
      id = parts[1]
      name = parts[2]
      if (length(name) > 40) name = substr(name, 1, 37) "..."
      getline
      status = $0
      sub(/^Status: /, "", status)
      gsub(/[[:space:]]+$/, "", status)

      if (status ~ /Complete/ || status ~ /Absorbed/) next

      marker = "  "
      if (id == current) marker = "► "
      if (status ~ /Progress/) stat_icon = "🔄"
      else if (status ~ /Planned/) stat_icon = "📋"
      else if (status ~ /Deferred/) stat_icon = "⏸ "
      else stat_icon = "  "

      printf "  %s%s %-12s %-40s %s\n", marker, stat_icon, id, name, status
    }
  ' ROADMAP.md

  echo
  echo "  RECENTLY COMPLETED (last 10)"
  echo "  ─────────────────────────────────────────────────────────────"

  awk '
    /^## Stage [0-9]/ {
      stage = $0
      sub(/^## Stage /, "", stage)
      split(stage, parts, " — ")
      id = parts[1]
      name = parts[2]
      if (length(name) > 40) name = substr(name, 1, 37) "..."
      getline
      status = $0
      sub(/^Status: /, "", status)
      gsub(/[[:space:]]+$/, "", status)

      if (status ~ /Complete/) {
        printf "  ✓  %-12s %-40s %s\n", id, name, status
      }
    }
  ' ROADMAP.md | tail -10

  echo
  exit 0
fi

# ---------------------------------------------------------
# Default: Current stage status
# ---------------------------------------------------------
print_header "STAGE STATUS"
echo "Stage ID: $(current_stage_id)"
echo "Stage Name: $(current_stage_name)"
echo "Status: $(current_stage_status)"
echo "Package: $(stage_package_dir || true)"

# Show checkpoint if resume is available
if [ -f .ai/execute_checkpoint ]; then
  echo "Execute checkpoint: step $(cat .ai/execute_checkpoint) completed"
  echo "  Resume with: ./scripts/ai-run.sh --stage-execute --resume"
fi
echo

print_header "BRANCH"
git branch --show-current
echo

print_header "GIT STATUS"
git status --short
echo

print_header "CHANGED FILES (all)"
all_changed_files
echo

print_header "PROTECTED FILE CHECK"
check_protected_files "warn"
