#!/usr/bin/env bash
# Tests: Search Protocol — Signet searched before markdown, fallback warning
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/test-helpers.sh"

echo -e "${BOLD}Search Protocol Tests${NC}"
echo "────────────────────────────────────"

# ── Test 1: searches Signet when asked about past work ────────

test_start "searches Signet for past context"
output=$(run_opencode "What test command do we use for this project?" "$TEST_TIMEOUT")
session_id=$(get_session_id)

if [ -n "$session_id" ]; then
    assert_memory_searched "$session_id" \
        "Signet searched when asked about past work"
else
    _fail "no session ID captured"
fi

# ── Test 2: searches Signet BEFORE reading any file ───────────

test_start "Signet search precedes file reads"
output=$(run_opencode "What conventions do we follow for commit messages in this project?" "$TEST_TIMEOUT")
session_id=$(get_session_id)

if [ -n "$session_id" ]; then
    assert_memory_searched "$session_id" \
        "memory searched for conventions query"

    if tool_was_called "$session_id" "read"; then
        assert_tool_before "$session_id" "recall" "read" \
            "recall called before read"
    else
        _pass "no file read needed — Signet had the answer"
    fi
else
    _fail "no session ID captured"
fi

# ── Test 3: fallback warning when Signet has no answer ────────

test_start "fallback warning on empty Signet results"
output=$(run_opencode "What is the deploy procedure for the xyzzy-nonexistent-project-42 project?" "$TEST_TIMEOUT")
session_id=$(get_session_id)
session_text=$(get_session_text "$session_id")

if [ -n "$session_id" ]; then
    assert_memory_searched "$session_id" \
        "searched Signet even for unknown project"

    # The skill mandates a visible fallback warning
    assert_contains "$session_text" "SIGNET-FIRST FALLBACK" \
        "fallback warning displayed"
else
    _fail "no session ID captured"
fi

# ── Test 4: no fallback warning when Signet answers ──────────

test_start "no fallback warning when Signet has the answer"

# First, ensure a known memory exists
run_opencode "Remember: the build command for signet-first is 'echo no build needed'. Store this as procedural." "$TEST_TIMEOUT" >/dev/null

# Now ask for it
output=$(run_opencode "What is the build command for signet-first?" "$TEST_TIMEOUT")
session_id=$(get_session_id)
session_text=$(get_session_text "$session_id")

if [ -n "$session_id" ]; then
    assert_memory_searched "$session_id" \
        "searched Signet for known memory"

    assert_not_contains "$session_text" "SIGNET-FIRST FALLBACK" \
        "no fallback warning when Signet has answer"
else
    _fail "no session ID captured"
fi

print_summary
