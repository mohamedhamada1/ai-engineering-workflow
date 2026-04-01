#!/usr/bin/env bash
# Hook: PreToolUse (Bash) — Secret & sensitive file detection
# Fires before git commit commands. Warns if staged files may contain secrets.
set -euo pipefail

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$REPO_ROOT"

WARNINGS=()

# Check staged files for sensitive patterns
STAGED_FILES="$(git diff --cached --name-only 2>/dev/null || true)"
[ -z "$STAGED_FILES" ] && exit 0

# 1. Sensitive file names
while IFS= read -r f; do
  [ -z "$f" ] && continue
  case "$f" in
    *.env|*.env.*|.env) WARNINGS+=("SENSITIVE FILE: $f (environment variables)") ;;
    *credentials*|*secret*|*private_key*) WARNINGS+=("SENSITIVE FILE: $f") ;;
    *google-services.json) WARNINGS+=("SENSITIVE FILE: $f (Firebase config)") ;;
    *keystore*|*.jks|*.p12|*.pem) WARNINGS+=("SENSITIVE FILE: $f (key/certificate)") ;;
  esac
done <<< "$STAGED_FILES"

# 2. Check staged content for secret patterns (only in text files, limit scan)
while IFS= read -r f; do
  [ -z "$f" ] && continue
  # Skip binary and large files
  [ ! -f "$f" ] && continue
  SIZE=$(wc -c < "$f" 2>/dev/null | tr -d ' ')
  [ "$SIZE" -gt 100000 ] && continue

  # Scan for common secret patterns in staged diff
  SECRETS=$(git diff --cached -- "$f" 2>/dev/null | grep -inE \
    'AKIA[0-9A-Z]{16}|ghp_[0-9a-zA-Z]{36}|sk_live_|sk_test_|-----BEGIN (RSA |EC )?PRIVATE KEY|password\s*=\s*["\x27][^"\x27]{8,}' \
    2>/dev/null | head -3 || true)

  if [ -n "$SECRETS" ]; then
    WARNINGS+=("POSSIBLE SECRET in $f — review before committing")
  fi
done <<< "$STAGED_FILES"

# Report
if [ ${#WARNINGS[@]} -gt 0 ]; then
  echo "⚠️  SECRET DETECTION WARNING"
  for w in "${WARNINGS[@]}"; do
    echo "  ⚠ $w"
  done
  echo ""
  echo "Review these files before committing. Remove secrets or add to .gitignore."
fi

exit 0
