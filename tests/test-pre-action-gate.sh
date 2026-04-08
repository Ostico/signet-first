#!/usr/bin/env bash
# Tests: Pre-Action Gate — recall BEFORE executing commands
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/test-helpers.sh"

echo -e "${BOLD}Pre-Action Gate Tests${NC}"
echo "────────────────────────────────────"

# ── Test 1: "run the tests" triggers recall before bash ───────

test_start "recall before bash on 'run the tests'"
output=$(run_opencode "Run the tests for this project." "$TEST_TIMEOUT")
session_id=$(get_session_id)

if [ -n "$session_id" ]; then
    assert_memory_searched "$session_id" \
        "searched memory for test command"

    if tool_was_called "$session_id" "bash"; then
        assert_tool_before "$session_id" "recall" "bash" \
            "recall called before bash execution"
    else
        _pass "no bash called — agent may have answered from memory only"
    fi
else
    _fail "no session ID captured"
fi

# ── Test 2: "commit these changes" triggers recall before bash ─

test_start "recall before bash on 'commit'"
output=$(run_opencode "Commit the current changes with an appropriate message." "$TEST_TIMEOUT")
session_id=$(get_session_id)

if [ -n "$session_id" ]; then
    assert_memory_searched "$session_id" \
        "searched memory for commit conventions"

    if tool_was_called "$session_id" "bash"; then
        assert_tool_before "$session_id" "recall" "bash" \
            "recall called before git commit"
    else
        _pass "no bash called — agent may have asked for clarification"
    fi
else
    _fail "no session ID captured"
fi

# ── Test 3: "what's the deploy procedure" is pure recall ──────

test_start "procedural query triggers recall without bash"
output=$(run_opencode "What is the deploy procedure for this project?" "$TEST_TIMEOUT")
session_id=$(get_session_id)

if [ -n "$session_id" ]; then
    assert_memory_searched "$session_id" \
        "searched memory for deploy procedure"

    # A pure procedural query should NOT trigger bash execution
    if tool_was_called "$session_id" "bash"; then
        _fail "bash called for a pure knowledge query — should use memory only"
    else
        _pass "no bash called for procedural query — correct"
    fi
else
    _fail "no session ID captured"
fi

print_summary
