#!/usr/bin/env bash
# signet-first — full setup installer
#
# Platforms: Linux (tested), macOS (tested), Windows (not supported — use WSL)
#
# Installs from scratch:
#   1. Signet (AI memory system)
#   2. signet-first skill (Signet-first memory protocol)
#
# Signet's knowledge graph traversal + FTS5 keyword search handle all skill
# search patterns. No embedding provider is required.
#
# Usage (one-liner):
#   curl -sL https://raw.githubusercontent.com/ostico/signet-first/master/install.sh | bash
#
# Options (environment variables):
#   HARNESS=opencode|claude-code|codex   Force harness (default: auto-detect)
#   SKIP_SIGNET=1                        Skip Signet install (already have it)
#   SKILL_ONLY=1                         Skip everything, just install the skill
#
# Examples:
#   curl -sL .../install.sh | bash                          # Full install
#   curl -sL .../install.sh | SKILL_ONLY=1 bash             # Just the skill
#   curl -sL .../install.sh | HARNESS=claude-code bash      # Force Claude Code

set -uo pipefail

REPO="https://raw.githubusercontent.com/ostico/signet-first/master"
HARNESS="${HARNESS:-auto}"
SKIP_SIGNET="${SKIP_SIGNET:-0}"
SKILL_ONLY="${SKILL_ONLY:-0}"

if [ -t 1 ]; then
  GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
else
  GREEN=''; YELLOW=''; RED=''; BOLD=''; NC=''
fi

ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; }
step() { echo -e "\n${BOLD}[$1]${NC} $2"; }

# ─── Harness detection ────────────────────────────────────────────────────────

detect_harness() {
  if [ "$HARNESS" != "auto" ]; then return; fi

  if [ -d "$HOME/.config/opencode" ]; then
    HARNESS="opencode"
  elif [ -d "$HOME/.claude" ]; then
    HARNESS="claude-code"
  elif [ -d "$HOME/.agents/skills" ]; then
    HARNESS="codex"
  else
    HARNESS="opencode"
    warn "No harness directory found — defaulting to opencode"
  fi
}

skills_dir() {
  case "$HARNESS" in
    opencode)    echo "$HOME/.config/opencode/skills/signet-first" ;;
    claude-code) echo "$HOME/.claude/skills/signet-first" ;;
    codex)       echo "$HOME/.agents/skills/signet-first" ;;
    *)           echo "$HOME/.config/opencode/skills/signet-first" ;;
  esac
}

# ─── Step 1: Node.js check ───────────────────────────────────────────────────

check_node() {
  if [ "$SKILL_ONLY" = "1" ] || [ "$SKIP_SIGNET" = "1" ]; then return 0; fi

  step "1/3" "Node.js"

  if command -v node &> /dev/null; then
    NODE_VER=$(node --version)
    NODE_MAJOR=$(echo "$NODE_VER" | sed 's/v//' | cut -d. -f1)
    if [ "$NODE_MAJOR" -ge 20 ]; then
      ok "Node.js $NODE_VER"
      return 0
    else
      fail "Node.js $NODE_VER too old (need v20+)"
    fi
  else
    fail "Node.js not found"
  fi

  echo "  Install Node.js 22:"
  echo "    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash"
  echo "    source ~/.\"\${SHELL##*/}rc\" && nvm install 22"
  return 1
}

# ─── Step 2: Signet ──────────────────────────────────────────────────────────

install_signet() {
  if [ "$SKILL_ONLY" = "1" ] || [ "$SKIP_SIGNET" = "1" ]; then return 0; fi

  step "2/3" "Signet"

  if command -v bun &> /dev/null; then
    ok "Bun already installed ($(bun --version 2>/dev/null))"
  else
    echo "  Installing Bun (Signet daemon runtime)..."
    curl -fsSL https://bun.sh/install | bash > /dev/null 2>&1
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
    if command -v bun &> /dev/null; then
      ok "Bun installed ($(bun --version 2>/dev/null))"
    else
      warn "Bun installation failed — daemon won't start"
      echo "  Try manually: curl -fsSL https://bun.sh/install | bash"
    fi
  fi

  if command -v signet &> /dev/null; then
    ok "Signet already installed ($(signet --version 2>/dev/null || echo 'unknown'))"
  else
    echo "  Installing signetai..."
    npm install -g signetai 2>&1 | tail -3
    if command -v signet &> /dev/null; then
      ok "Signet installed ($(signet --version 2>/dev/null))"
    else
      fail "Signet installation failed"
      echo "  Try manually: npm install -g signetai"
      return 1
    fi
  fi

  if [ -f "$HOME/.agents/agent.yaml" ]; then
    ok "Signet already configured (~/.agents/agent.yaml exists)"
  else
    echo "  Running signet setup (non-interactive)..."
    signet setup --non-interactive \
      --name "Smart-Agent" \
      --description "Personal AI assistant" \
      --harness "$HARNESS" \
      --deployment-type local \
      --extraction-provider "$HARNESS" \
      --embedding-provider none \
      --skip-git \
      2>&1 | tail -5
    if [ -f "$HOME/.agents/agent.yaml" ]; then
      ok "Signet configured"
    else
      warn "Setup may still be running — check with: signet status"
    fi
  fi

  if signet status 2>&1 | grep -q "Daemon running"; then
    ok "Signet daemon running"
  else
    echo "  Starting Signet daemon..."
    signet daemon start 2>&1 | tail -3
    sleep 3
    if signet status 2>&1 | grep -q "Daemon running"; then
      ok "Signet daemon started"
    else
      warn "Daemon may need manual start: signet daemon start"
    fi
  fi

  echo "  Syncing harness plugins..."
  signet sync > /dev/null 2>&1
  ok "Harness plugins synced"

  if [ "$HARNESS" = "opencode" ]; then
    local CONFIG="$HOME/.config/opencode/opencode.json"
    if [ -f "$CONFIG" ] && grep -q '"signet"' "$CONFIG"; then
      ok "Signet MCP already in opencode.json"
    else
      warn "Add signet MCP to opencode.json manually:"
      echo '    "mcp": { "signet": { "command": ["signet-mcp"], "enabled": true } }'
    fi
  fi
}

# ─── Step 3: signet-first skill ──────────────────────────────────────────────

install_skill() {
  step "3/3" "signet-first skill + plugin"

  local DIR
  DIR=$(skills_dir)

  if [ -d "$DIR/.git" ]; then
    ok "signet-first already cloned at $DIR"
    echo "  Updating..."
    git -C "$DIR" pull --ff-only 2>&1 | tail -3
  elif command -v git &> /dev/null; then
    echo "  Cloning repository (includes hooks + plugin files)..."
    git clone https://github.com/Ostico/signet-first.git "$DIR" 2>&1 | tail -3
  else
    echo "  git not available — falling back to SKILL.md download"
    mkdir -p "$DIR"
    curl -sL "$REPO/SKILL.md" -o "$DIR/SKILL.md"
  fi

  if [ -f "$DIR/SKILL.md" ]; then
    ok "signet-first installed at $DIR"
  else
    fail "Installation failed"
    echo "  Try manually: git clone https://github.com/Ostico/signet-first.git $DIR"
    return 1
  fi

  if [ "$HARNESS" = "opencode" ]; then
    register_opencode_plugin
  fi

  if [ "$HARNESS" = "codex" ]; then
    mkdir -p "$HOME/.agents/skills"
    ln -sf "$DIR" "$HOME/.agents/skills/signet-first"
    ok "Codex symlink created"
  fi

  if [ "$HARNESS" = "claude-code" ]; then
    echo ""
    warn "Claude Code requires manual plugin registration."
    echo "    Run these two commands in your Claude Code prompt:"
    echo "      /plugin marketplace add Ostico/signet-first"
    echo "      /plugin install signet-first@signet-first-dev"
    echo "    Then restart Claude Code."
  fi
}

register_opencode_plugin() {
  local CONFIG="$HOME/.config/opencode/opencode.json"
  local PLUGIN_ENTRY="signet-first@git+https://github.com/Ostico/signet-first.git"

  if [ ! -f "$CONFIG" ]; then
    warn "opencode.json not found — create it manually or restart OpenCode"
    return
  fi

  if grep -q "signet-first" "$CONFIG" 2>/dev/null; then
    ok "signet-first plugin already in opencode.json"
    return
  fi

  if command -v jq &> /dev/null; then
    local TMP="${CONFIG}.tmp"
    if jq -e '.plugin' "$CONFIG" > /dev/null 2>&1; then
      jq ".plugin += [\"$PLUGIN_ENTRY\"]" "$CONFIG" > "$TMP" && mv "$TMP" "$CONFIG"
    else
      jq ". + {\"plugin\": [\"$PLUGIN_ENTRY\"]}" "$CONFIG" > "$TMP" && mv "$TMP" "$CONFIG"
    fi
    ok "signet-first plugin added to opencode.json"
  else
    warn "jq not available — add this to opencode.json plugin array manually:"
    echo "    \"$PLUGIN_ENTRY\""
  fi
}

# ─── Summary ─────────────────────────────────────────────────────────────────

summary() {
  echo ""
  echo -e "${BOLD}━━━ Done ━━━${NC}"
  echo ""

  local ALL_OK=true

  if command -v signet &> /dev/null; then
    if signet status 2>&1 | grep -q "Daemon running"; then
      ok "Signet daemon running"
    else
      warn "Signet installed but daemon not running — run: signet daemon start"
      ALL_OK=false
    fi
  else
    warn "Signet not installed — run: npm install -g signetai && signet setup"
    ALL_OK=false
  fi

  local DIR
  DIR=$(skills_dir)
  if [ -f "$DIR/SKILL.md" ]; then
    ok "signet-first skill installed ($HARNESS)"
    if [ -d "$DIR/.git" ]; then
      ok "full repo cloned (hooks + plugin files included)"
    else
      warn "SKILL.md only — plugin auto-injection not available"
      echo "    For full plugin: git clone https://github.com/Ostico/signet-first.git $DIR"
    fi
  else
    fail "Skill not found at $DIR/SKILL.md"
    ALL_OK=false
  fi

  if [ "$HARNESS" = "opencode" ]; then
    local CONFIG="$HOME/.config/opencode/opencode.json"
    if [ -f "$CONFIG" ] && grep -q "signet-first" "$CONFIG"; then
      ok "signet-first plugin registered in opencode.json"
    else
      warn "Plugin not registered — auto-injection won't work until added to opencode.json"
    fi
  fi

  if [ "$HARNESS" = "claude-code" ]; then
    warn "Register the plugin in Claude Code:"
    echo "    /plugin marketplace add Ostico/signet-first"
    echo "    /plugin install signet-first@signet-first-dev"
  fi

  echo ""
  if [ "$ALL_OK" = true ]; then
    echo -e "  ${GREEN}${BOLD}Restart your agent session to activate the skill.${NC}"
  else
    echo -e "  ${YELLOW}Some components need attention — see warnings above.${NC}"
    echo -e "  Full setup guide: $REPO/SIGNET_SETUP.md"
  fi
  echo ""
}

# ─── Main ────────────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}signet-first installer${NC}"
echo "  https://github.com/ostico/signet-first"
echo ""

detect_harness
echo -e "  Harness: ${BOLD}$HARNESS${NC}"

check_node && install_signet || true
install_skill || true
summary
