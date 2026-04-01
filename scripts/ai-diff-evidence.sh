#!/usr/bin/env bash
set -euo pipefail
export GIT_PAGER=cat
source "$(dirname "$0")/ai-common.sh"
require_git_repo

print_header "REPO"
echo "$(repo_root)"

print_header "CURRENT STAGE"
echo "Stage ID: $(current_stage_id)"
echo "Status: $(current_stage_status)"
echo "Package: $(stage_package_dir || true)"

echo
print_header "BRANCH"
git branch --show-current

echo
print_header "GIT STATUS"
git status --short

echo
print_header "UNTRACKED FILES"
git ls-files --others --exclude-standard || echo "None"

echo
print_header "CHANGED FILES (unstaged)"
git diff --name-only

echo
print_header "DIFF STAT (unstaged)"
git diff --stat

echo
print_header "STAGED FILES"
git diff --cached --name-only || true

echo
print_header "STAGED DIFF STAT"
git diff --cached --stat || true

echo
print_header "PROTECTED FILE CHECK"
check_protected_files "warn"

echo
print_header "DEPENDENCY / BUILD FILE CHANGES"
all_changed_files | grep -E 'pubspec\.yaml|package\.json|Podfile|Package\.swift|build\.gradle|settings\.gradle|Cargo\.toml|requirements\.txt' || echo "No dependency/build file changes detected"
