#!/usr/bin/env bash
# Tests: Store Protocol — correct type, scope, pinning, importance
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/test-helpers.sh"

echo -e "${BOLD}Store Protocol Tests${NC}"
echo "────────────────────────────────────"

# ── Test 1: procedural type for commands ──────────────────────

test_start "stores command as type=procedural"
output=$(run_opencode "Remember this test command for the signet-first project: npm run lint -- --fix" "$TEST_TIMEOUT")
session_id=$(get_session_id)

if [ -n "$session_id" ]; then
    assert_memory_stored "npm run lint" "procedural" "" \
        "command stored as type=procedural"
else
    _fail "no session ID captured"
fi

# ── Test 2: preference type for user preferences ─────────────

test_start "stores user preference as type=preference"
output=$(run_opencode "Remember my preference: I always want verbose logging when debugging." "$TEST_TIMEOUT")
session_id=$(get_session_id)

if [ -n "$session_id" ]; then
    assert_memory_stored "verbose logging" "preference" "" \
        "preference stored as type=preference"
else
    _fail "no session ID captured"
fi

# ── Test 3: pinning critical constraints ──────────────────────

test_start "pins critical user constraint"
output=$(run_opencode "This is a hard constraint: NEVER use force push on main branch. Remember this permanently." "$TEST_TIMEOUT")
session_id=$(get_session_id)

if [ -n "$session_id" ]; then
    assert_memory_pinned "force push" \
        "critical constraint is pinned"
else
    _fail "no session ID captured"
fi

# ── Test 4: scope isolation ───────────────────────────────────

test_start "stores project-specific knowledge with scope"
output=$(run_opencode "Remember for the matecat project: the database uses MySQL 8 with utf8mb4 charset." "$TEST_TIMEOUT")
session_id=$(get_session_id)

if [ -n "$session_id" ]; then
    assert_memory_stored "MySQL 8" "" "matecat" \
        "project knowledge stored with scope=matecat"
else
    _fail "no session ID captured"
fi

# ── Test 5: does not default to fact ──────────────────────────

test_start "avoids defaulting to type=fact for non-facts"
output=$(run_opencode "Remember this decision we made: we chose PostgreSQL over MySQL for the new service because of JSON column support." "$TEST_TIMEOUT")
session_id=$(get_session_id)

if [ -n "$session_id" ]; then
    assert_memory_stored "PostgreSQL over MySQL" "decision" "" \
        "decision stored as type=decision, not fact"
else
    _fail "no session ID captured"
fi

print_summary
