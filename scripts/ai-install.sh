#!/usr/bin/env bash
set -euo pipefail

# =========================================================
# ai-install.sh — One-time setup for AI workflow on a new device
#
# Usage:
#   ./scripts/ai-install.sh
#
# What it does:
#   1. Makes all workflow scripts executable
#   2. Adds 'ai' alias to ~/.zshrc (or ~/.bashrc)
#   3. Adds Zsh autocompletion for 'ai' commands
#   4. Verifies required tools are installed
#   5. Runs engine self-test
# =========================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "========================================="
echo " AI Workflow Engine — Installation"
echo "========================================="
echo
echo "Repo: $REPO_ROOT"
echo

# ---------------------------------------------------------
# 1) Make all scripts executable
# ---------------------------------------------------------
echo "[1/5] Making scripts executable..."
chmod +x "$SCRIPT_DIR"/ai-*.sh "$SCRIPT_DIR"/ai "$SCRIPT_DIR"/_ai 2>/dev/null || true
echo "  Done."
echo

# ---------------------------------------------------------
# 2) Check required tools
# ---------------------------------------------------------
echo "[2/5] Checking required tools..."

MISSING=()
for tool in git grep sed awk find; do
  if command -v "$tool" >/dev/null 2>&1; then
    echo "  ✓ $tool"
  else
    echo "  ✗ $tool (MISSING)"
    MISSING+=("$tool")
  fi
done

# Optional but recommended
for tool in pbcopy pbpaste pandoc claude; do
  if command -v "$tool" >/dev/null 2>&1; then
    echo "  ✓ $tool (optional)"
  else
    echo "  - $tool (not found — optional)"
  fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
  echo
  echo "  ERROR: Missing required tools: ${MISSING[*]}"
  echo "  Install them before using the workflow."
  exit 1
fi
echo

# ---------------------------------------------------------
# 3) Detect shell and config file
# ---------------------------------------------------------
echo "[3/5] Configuring shell..."

SHELL_NAME="$(basename "${SHELL:-/bin/zsh}")"
case "$SHELL_NAME" in
  zsh)  RC_FILE="$HOME/.zshrc" ;;
  bash) RC_FILE="$HOME/.bashrc" ;;
  *)    RC_FILE="$HOME/.${SHELL_NAME}rc" ;;
esac

echo "  Shell: $SHELL_NAME"
echo "  Config: $RC_FILE"

# ---------------------------------------------------------
# 4) Add alias and completion to shell config
# ---------------------------------------------------------
echo
echo "[4/5] Adding ai alias and autocompletion..."

# Check if already installed
if grep -q "# AI workflow shortcuts" "$RC_FILE" 2>/dev/null; then
  echo "  Already installed in $RC_FILE — updating..."
  # Remove old block
  sed -i.bak '/# AI workflow shortcuts/,/compinit/d' "$RC_FILE" 2>/dev/null || true
  rm -f "${RC_FILE}.bak"
fi

# Add fresh block
cat >> "$RC_FILE" <<RCEOF

# AI workflow shortcuts + autocompletion
alias ai='./scripts/ai'
fpath+=("$SCRIPT_DIR")
autoload -Uz compinit && compinit -u
RCEOF

echo "  Added to $RC_FILE:"
echo "    alias ai='./scripts/ai'"
echo "    fpath+=(\"$SCRIPT_DIR\")"
echo "    autoload -Uz compinit && compinit -u"

# Clear completion cache
rm -f ~/.zcompdump* 2>/dev/null || true
echo "  Cleared completion cache."
echo

# ---------------------------------------------------------
# 5) Run engine self-test (if available)
# ---------------------------------------------------------
echo "[5/5] Running engine self-test..."
if [[ -x "$SCRIPT_DIR/ai-engine-selftest.sh" ]]; then
  "$SCRIPT_DIR/ai-engine-selftest.sh" 2>&1 | tail -10
else
  echo "  Self-test script not found — skipping"
fi
echo

# ---------------------------------------------------------
# Done
# ---------------------------------------------------------
echo "========================================="
echo " Installation Complete"
echo "========================================="
echo
echo "  To activate now:  source $RC_FILE"
echo "  Then try:         ai help"
echo "  Tab-complete:     ai <tab>"
echo
echo "  Quick reference:"
echo "    ai start <id>     Start a stage"
echo "    ai exec           Execute pipeline"
echo "    ai done <id>      Complete stage"
echo "    ai gpt            ChatGPT context"
echo "    ai check          Conformance check"
echo "    ai status         Current status"
echo "    ai help           Full command list"
echo
