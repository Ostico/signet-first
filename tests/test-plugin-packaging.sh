#!/usr/bin/env bash
# Tests for multi-platform plugin packaging — hook JSON output,
# version sync, frontmatter stripping, and file structure.
# Runs locally (no Docker needed). Included in run-all.sh.
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$TESTS_DIR")"

source "$TESTS_DIR/test-helpers.sh"
preflight_check

echo ""
echo -e "${BOLD}Plugin Packaging Tests${NC}"
echo -e "${BOLD}══════════════════════════════════════${NC}"

# ── Version drift ─────────────────────────────────────────────

test_start "version-bump --check detects no drift"
DRIFT_OUTPUT=$("$SKILL_DIR/scripts/bump-version.sh" --check 2>&1)
DRIFT_EXIT=$?
if [ "$DRIFT_EXIT" -eq 0 ]; then
    _pass "all version files in sync"
else
    _fail "version drift detected: $DRIFT_OUTPUT"
fi

test_start "all 5 platform configs declare same version"
VERSIONS=$(
    jq -r '.version' "$SKILL_DIR/package.json"
    jq -r '.version' "$SKILL_DIR/.claude-plugin/plugin.json"
    jq -r '.version' "$SKILL_DIR/.cursor-plugin/plugin.json"
    jq -r '.plugins[0].version' "$SKILL_DIR/.claude-plugin/marketplace.json"
    jq -r '.version' "$SKILL_DIR/gemini-extension.json"
)
UNIQUE=$(echo "$VERSIONS" | sort -u | wc -l | tr -d ' ')
if [ "$UNIQUE" -eq 1 ]; then
    VER=$(echo "$VERSIONS" | head -1)
    _pass "all 5 files at $VER"
else
    _fail "found $UNIQUE different versions"
fi

# ── Hook JSON output ──────────────────────────────────────────

test_start "hook: Claude Code JSON format"
CC_JSON=$(CLAUDE_PLUGIN_ROOT="$SKILL_DIR" bash "$SKILL_DIR/hooks/session-start" 2>&1)
if echo "$CC_JSON" | jq -e '.hookSpecificOutput.additionalContext' > /dev/null 2>&1; then
    _pass "hookSpecificOutput.additionalContext present"
else
    _fail "missing hookSpecificOutput.additionalContext"
fi

test_start "hook: Cursor JSON format"
CURSOR_JSON=$(CURSOR_PLUGIN_ROOT="$SKILL_DIR" bash "$SKILL_DIR/hooks/session-start" 2>&1)
if echo "$CURSOR_JSON" | jq -e '.additional_context' > /dev/null 2>&1; then
    _pass "additional_context present (snake_case)"
else
    _fail "missing additional_context"
fi

test_start "hook: Copilot CLI JSON format"
COPILOT_JSON=$(COPILOT_CLI=1 bash "$SKILL_DIR/hooks/session-start" 2>&1)
if echo "$COPILOT_JSON" | jq -e '.additionalContext' > /dev/null 2>&1; then
    _pass "additionalContext present (SDK standard)"
else
    _fail "missing additionalContext"
fi

# ── Frontmatter stripping ────────────────────────────────────

test_start "hook: YAML frontmatter stripped from output"
CONTENT=$(echo "$CC_JSON" | jq -r '.hookSpecificOutput.additionalContext')
if echo "$CONTENT" | grep -q "name: signet-first"; then
    _fail "frontmatter 'name:' leaked into output"
else
    _pass "no frontmatter leak"
fi

test_start "hook: skill content present after stripping"
if echo "$CONTENT" | grep -q "Signet-First Memory Protocol"; then
    _pass "skill content found"
else
    _fail "skill content missing"
fi

test_start "hook: mandatory header present"
if echo "$CONTENT" | grep -q "MANDATORY"; then
    _pass "MANDATORY header present"
else
    _fail "MANDATORY header missing"
fi

# ── File structure checks ────────────────────────────────────

test_start "required platform files exist"
MISSING=0
for f in \
    ".claude-plugin/plugin.json" \
    ".claude-plugin/marketplace.json" \
    ".cursor-plugin/plugin.json" \
    ".codex/INSTALL.md" \
    ".opencode/INSTALL.md" \
    ".opencode/plugins/signet-first-bootstrap.js" \
    "hooks/session-start" \
    "hooks/run-hook.cmd" \
    "hooks/hooks.json" \
    "hooks/hooks-cursor.json" \
    "gemini-extension.json" \
    "GEMINI.md" \
    "package.json" \
    ".version-bump.json" \
    "scripts/bump-version.sh"; do
    if [ ! -f "$SKILL_DIR/$f" ]; then
        _fail "missing: $f"
        MISSING=1
    fi
done
if [ "$MISSING" -eq 0 ]; then
    _pass "all 15 platform files present"
fi

test_start "session-start hook is executable"
if [ -x "$SKILL_DIR/hooks/session-start" ]; then
    _pass "executable bit set"
else
    _fail "not executable"
fi

test_start "GEMINI.md includes SKILL.md"
GEMINI_CONTENT=$(cat "$SKILL_DIR/GEMINI.md")
if echo "$GEMINI_CONTENT" | grep -q "@./SKILL.md"; then
    _pass "@./SKILL.md reference found"
else
    _fail "GEMINI.md does not include SKILL.md"
fi

test_start "package.json main points to OpenCode plugin"
PKG_MAIN=$(jq -r '.main' "$SKILL_DIR/package.json")
if [ "$PKG_MAIN" = ".opencode/plugins/signet-first-bootstrap.js" ]; then
    _pass "main = .opencode/plugins/signet-first-bootstrap.js"
else
    _fail "main = $PKG_MAIN (expected .opencode/plugins/signet-first-bootstrap.js)"
fi

test_start "hooks.json references run-hook.cmd"
if jq -e '.hooks.SessionStart[0].hooks[0].command' "$SKILL_DIR/hooks/hooks.json" | grep -q "run-hook.cmd"; then
    _pass "hooks.json → run-hook.cmd"
else
    _fail "hooks.json does not reference run-hook.cmd"
fi

# ── Summary ───────────────────────────────────────────────────

print_summary
