#!/usr/bin/env bash
set -euo pipefail
export GIT_PAGER=cat
source "$(dirname "$0")/ai-common.sh"

require_git_repo

print_header "BRANCH"
git branch --show-current

echo
print_header "CURRENT STAGE"
echo "Stage ID: $(current_stage_id)"
echo "Status: $(current_stage_status)"
echo "Package: $(stage_package_dir)"

echo
print_header "GIT STATUS"
git status --short

echo
print_header "CHANGED FILES"
CHANGED="$(git diff --name-only)"
echo "$CHANGED"

echo
print_header "DIFF STAT"
git diff --stat

echo
print_header "PROTECTED FILE CHECK (RELAXED)"
HIT=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  if echo "$CHANGED" | grep -Fxq "$f"; then
    echo "WARN: protected file changed -> $f"
    HIT=1
  fi
done < <(protected_files_list)

if [ "$HIT" -eq 0 ]; then
  echo "PASS — no protected files changed"
else
  echo "RELAXED MODE — continuing despite protected file changes"
fi

echo
print_header "DEPENDENCY / BUILD FILE CHANGES"
echo "$CHANGED" | grep -E 'pubspec\.yaml|package\.json|Podfile|Package\.swift|build\.gradle|settings\.gradle|Cargo\.toml|requirements\.txt' || echo "No dependency/build file changes detected"

echo
print_header "STAGED FILES"
git diff --cached --name-only || true