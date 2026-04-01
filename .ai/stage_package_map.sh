#!/usr/bin/env bash
# Project-specific stage-to-package mapping
# Sourced by ai-common.sh — do not execute directly.
#
# Maps stage IDs to their primary package directory.
# Used by: ai-stage-start.sh, ai-stage-execute.sh, ai-stage-complete.sh
#
# Example:
#   "1.0") echo "packages/core" ;;
#   "2.0") echo "packages/feature_x" ;;
#   "3.*") echo "packages/feature_y" ;;   # wildcard for all 3.x stages

stage_package_map() {
  local stage_id="${1:-}"
  case "$stage_id" in
    # Add your stage-to-package mappings here:
    # "1.0") echo "packages/my_package" ;;
    # "2.*") echo "packages/other_package" ;;
    *) echo "" ;;
  esac
}
