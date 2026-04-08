#!/usr/bin/env bash
# Integration test: fresh install in Docker container.
# Requires: Docker daemon running.
# NOT included in run-all.sh (too slow). Run manually:
#   bash tests/test-install-docker.sh
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$TESTS_DIR")"
CONTAINER_NAME="signet-first-install-test-$$"
IMAGE="ubuntu:24.04"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

_PASS=0
_FAIL=0
_TOTAL=0

cleanup() {
    echo ""
    echo -e "${BOLD}Cleaning up...${NC}"
    docker rm -f "$CONTAINER_NAME" > /dev/null 2>&1
    echo -e "  ${GREEN}✓${NC} Container destroyed"
}
trap cleanup EXIT

_pass() {
    _PASS=$((_PASS + 1))
    echo -e "  ${GREEN}PASS${NC} $1"
}

_fail() {
    _FAIL=$((_FAIL + 1))
    echo -e "  ${RED}FAIL${NC} $1"
}

check() {
    local desc="$1"
    shift
    _TOTAL=$((_TOTAL + 1))
    if "$@" > /dev/null 2>&1; then
        _pass "$desc"
    else
        _fail "$desc"
    fi
}

dexec() {
    docker exec "$CONTAINER_NAME" bash -c "$1"
}

echo -e "${BOLD}╔══════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  Docker Install Integration Test     ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════╝${NC}"
echo ""

# ── Preflight ─────────────────────────────────────────────────

if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker not found. Skipping integration test.${NC}"
    exit 0
fi

if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}Docker daemon not running. Skipping integration test.${NC}"
    exit 0
fi

# ── Step 1: Create container ─────────────────────────────────

echo -e "${CYAN}[1/5] Creating container ($IMAGE)${NC}"
docker run -d --name "$CONTAINER_NAME" \
    -v "$SKILL_DIR:/mnt/signet-first:ro" \
    "$IMAGE" sleep 3600 > /dev/null 2>&1
check "container started" docker inspect "$CONTAINER_NAME"

# ── Step 2: Install system deps ──────────────────────────────

echo -e "${CYAN}[2/5] Installing system dependencies${NC}"
dexec 'apt-get update -qq > /dev/null 2>&1 && apt-get install -y -qq curl git jq bc sqlite3 unzip ca-certificates > /dev/null 2>&1'
check "curl available" dexec 'command -v curl'
check "git available" dexec 'command -v git'
check "sqlite3 available" dexec 'command -v sqlite3'
check "jq available" dexec 'command -v jq'
check "bc available" dexec 'command -v bc'

# ── Step 3: Install Node.js 22 + run install.sh ─────────────

echo -e "${CYAN}[3/5] Installing Node.js 22 + running install.sh${NC}"
dexec '
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh 2>/dev/null | bash > /dev/null 2>&1
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    nvm install 22 > /dev/null 2>&1
    bash /mnt/signet-first/install.sh > /tmp/install.log 2>&1
    echo $?
'
INSTALL_EXIT=$(dexec 'cat /tmp/install.log > /dev/null 2>&1; echo $?')

_TOTAL=$((_TOTAL + 1))
NODE_VER=$(dexec 'export NVM_DIR="$HOME/.nvm"; [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"; node --version 2>/dev/null' 2>/dev/null)
if [ -n "$NODE_VER" ]; then _pass "Node.js installed ($NODE_VER)"; else _fail "Node.js not found"; fi

_TOTAL=$((_TOTAL + 1))
SIGNET_VER=$(dexec 'export NVM_DIR="$HOME/.nvm"; [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"; signet --version 2>/dev/null' 2>/dev/null)
if [ -n "$SIGNET_VER" ]; then _pass "Signet installed ($SIGNET_VER)"; else _fail "Signet not found"; fi

_TOTAL=$((_TOTAL + 1))
BUN_VER=$(dexec 'export PATH="$HOME/.bun/bin:$PATH"; bun --version 2>/dev/null' 2>/dev/null)
if [ -n "$BUN_VER" ]; then _pass "Bun installed ($BUN_VER)"; else _fail "Bun not found"; fi

# ── Step 4: Verify installation ──────────────────────────────

echo -e "${CYAN}[4/5] Verifying installation${NC}"

_TOTAL=$((_TOTAL + 1))
DAEMON_STATUS=$(dexec 'export NVM_DIR="$HOME/.nvm"; [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"; export PATH="$HOME/.bun/bin:$PATH"; signet status 2>&1')
if echo "$DAEMON_STATUS" | grep -q "Daemon running"; then
    _pass "Signet daemon running"
else
    _fail "Signet daemon not running"
fi

_TOTAL=$((_TOTAL + 1))
if dexec 'test -f $HOME/.config/opencode/skills/signet-first/SKILL.md' 2>/dev/null; then
    _pass "SKILL.md installed at correct path"
else
    _fail "SKILL.md not found"
fi

_TOTAL=$((_TOTAL + 1))
if dexec 'test -f $HOME/.agents/agent.yaml' 2>/dev/null; then
    _pass "agent.yaml exists"
else
    _fail "agent.yaml missing"
fi

_TOTAL=$((_TOTAL + 1))
if dexec 'test -f $HOME/.agents/memory/memories.db' 2>/dev/null; then
    _pass "memories.db exists"
else
    _fail "memories.db missing"
fi

_TOTAL=$((_TOTAL + 1))
SKILL_HEADER=$(dexec 'head -3 $HOME/.config/opencode/skills/signet-first/SKILL.md 2>/dev/null' 2>/dev/null)
if echo "$SKILL_HEADER" | grep -q "name: signet-first"; then
    _pass "SKILL.md has correct frontmatter"
else
    _fail "SKILL.md frontmatter incorrect"
fi

_TOTAL=$((_TOTAL + 1))
PGREP_OLLAMA=$(dexec 'pgrep -a ollama 2>/dev/null || echo "none"' 2>/dev/null)
if [ "$PGREP_OLLAMA" = "none" ]; then
    _pass "no Ollama process (correct — not required)"
else
    _fail "Ollama running unexpectedly: $PGREP_OLLAMA"
fi

# ── Step 5: Run fixture tests ────────────────────────────────

echo -e "${CYAN}[5/5] Running fixture test suite inside container${NC}"

FIXTURE_OUTPUT=$(dexec 'bash /mnt/signet-first/tests/run-all.sh 2>&1')
FIXTURE_EXIT=$?

_TOTAL=$((_TOTAL + 1))
if [ "$FIXTURE_EXIT" -eq 0 ]; then
    _pass "fixture test suite passed (exit 0)"
else
    _fail "fixture test suite failed (exit $FIXTURE_EXIT)"
    echo "$FIXTURE_OUTPUT" | tail -20
fi

_TOTAL=$((_TOTAL + 1))
if echo "$FIXTURE_OUTPUT" | grep -q "OVERALL: PASSED"; then
    _pass "fixture output confirms OVERALL: PASSED"
else
    _fail "fixture output does not show OVERALL: PASSED"
fi

# ── Summary ───────────────────────────────────────────────────

echo ""
echo -e "${BOLD}══════════════════════════════════════${NC}"
echo -e "${BOLD}  Integration Test Summary${NC}"
echo -e "${BOLD}══════════════════════════════════════${NC}"
echo -e "  ${GREEN}PASS:${NC} $_PASS"
echo -e "  ${RED}FAIL:${NC} $_FAIL"
echo -e "  Total: $_TOTAL"
echo -e "${BOLD}══════════════════════════════════════${NC}"

if [ "$_FAIL" -gt 0 ]; then
    echo -e "  ${RED}RESULT: FAILED${NC}"
    exit 1
else
    echo -e "  ${GREEN}RESULT: PASSED${NC}"
    exit 0
fi
