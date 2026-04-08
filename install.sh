#!/usr/bin/env bash
# signet-first skill installer
# Run this script OR paste it into your agent's terminal to install the skill.
#
# Prerequisites:
#   - Signet installed and running (signet status)
#   - A Signet-compatible harness (OpenCode, Claude Code, or Codex)
#
# Usage:
#   curl -sL https://raw.githubusercontent.com/ostico/signet-first/master/install.sh | bash
#
# Or with a specific harness:
#   HARNESS=claude-code curl -sL ... | bash
#   HARNESS=codex curl -sL ... | bash

set -euo pipefail

REPO="https://raw.githubusercontent.com/ostico/signet-first/master"
HARNESS="${HARNESS:-auto}"

# Detect harness if not specified
if [ "$HARNESS" = "auto" ]; then
  if [ -d "$HOME/.config/opencode" ]; then
    HARNESS="opencode"
  elif [ -d "$HOME/.claude" ]; then
    HARNESS="claude-code"
  elif [ -d "$HOME/.agents/skills" ]; then
    HARNESS="codex"
  else
    echo "ERROR: Could not detect harness. Set HARNESS=opencode|claude-code|codex"
    exit 1
  fi
fi

# Set skills directory based on harness
case "$HARNESS" in
  opencode)
    SKILLS_DIR="$HOME/.config/opencode/skills/signet-first"
    ;;
  claude-code)
    SKILLS_DIR="$HOME/.claude/skills/signet-first"
    ;;
  codex)
    SKILLS_DIR="$HOME/.agents/skills/signet-first"
    ;;
  *)
    echo "ERROR: Unknown harness '$HARNESS'. Use opencode|claude-code|codex"
    exit 1
    ;;
esac

echo "Installing signet-first skill for $HARNESS..."
echo "Target: $SKILLS_DIR"

# Create directory and download
mkdir -p "$SKILLS_DIR"
curl -sL "$REPO/SKILL.md" -o "$SKILLS_DIR/SKILL.md"

# Verify
if [ -f "$SKILLS_DIR/SKILL.md" ]; then
  echo "OK: signet-first installed at $SKILLS_DIR/SKILL.md"
  echo ""
  echo "Restart your agent session to activate the skill."
  echo "The skill triggers automatically on every session."
else
  echo "ERROR: Installation failed — SKILL.md not found at $SKILLS_DIR/SKILL.md"
  exit 1
fi

# Check Signet health
if command -v signet &> /dev/null; then
  echo ""
  echo "Checking Signet..."
  if signet status &> /dev/null; then
    echo "OK: Signet daemon is running."
  else
    echo "WARNING: Signet daemon is not running. Start it with: signet daemon start"
  fi
else
  echo ""
  echo "WARNING: Signet CLI not found. Install Signet first:"
  echo "  https://github.com/signetai/signet"
fi
