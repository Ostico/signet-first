#!/usr/bin/env bash
# Tests: Search Protocol — Signet searched before file reads, fallback warning
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/test-helpers.sh"

preflight_check
create_test_dbs
trap 'destroy_test_dbs' EXIT

echo -e "${BOLD}Search Protocol Tests${NC}"
echo "────────────────────────────────────"

# ── Test 1: compliant session — recall called ─────────────────

test_start "compliant session has recall call"
sid=$(inject_session "ses_compliant_search")
mid=$(inject_message "$sid" "assistant" 2000000)
inject_tool_call "$sid" "$mid" "recall" '{"query":"test command"}' "found: phpunit" 2000100
inject_tool_call "$sid" "$mid" "bash" '{"command":"vendor/bin/phpunit"}' "OK" 2000200

assert_memory_searched "$sid" "recall was called in compliant session"

# ── Test 2: compliant session — recall BEFORE read ────────────

test_start "recall precedes file reads"
sid=$(inject_session "ses_recall_before_read")
mid=$(inject_message "$sid" "assistant" 3000000)
inject_tool_call "$sid" "$mid" "signet_memory_search" '{"query":"conventions"}' "found" 3000100
inject_tool_call "$sid" "$mid" "read" '{"filePath":"README.md"}' "content" 3000200

assert_tool_before "$sid" "recall" "read" "recall called before read"

# ── Test 3: violating session — NO recall at all ─────────────

test_start "violation: session with bash but no recall"
sid=$(inject_session "ses_no_recall")
mid=$(inject_message "$sid" "assistant" 4000000)
inject_tool_call "$sid" "$mid" "bash" '{"command":"git commit"}' "committed" 4000100

count=$(sqlite3 "$OPENCODE_DB" "
    SELECT COUNT(*) FROM part p
    WHERE p.session_id = '$sid'
      AND json_extract(p.data, '$.type') = 'tool'
      AND json_extract(p.data, '$.tool') IN ('recall','memory_search','signet_memory_search')
      AND json_extract(p.data, '$.state.status') = 'completed';
" 2>/dev/null)
if [ "$count" -eq 0 ]; then
    _pass "violation correctly detected: bash without recall"
else
    _fail "expected zero recall calls, found $count"
fi

# ── Test 4: fallback warning present in output ────────────────

test_start "fallback notice in assistant text"
sid=$(inject_session "ses_fallback_warning")
mid=$(inject_message "$sid" "assistant" 5000000)
inject_tool_call "$sid" "$mid" "recall" '{"query":"deploy xyzzy"}' "" 5000100
inject_text "$sid" "$mid" "Memory returned no results for \"deploy xyzzy\". Checking project files." 5000200

session_text=$(get_session_text "$sid")
assert_contains "$session_text" "Memory returned no results" "fallback notice displayed"

# ── Test 5: no fallback warning when Signet answers ───────────

test_start "no fallback notice when memory has the answer"
sid=$(inject_session "ses_no_fallback")
mid=$(inject_message "$sid" "assistant" 6000000)
inject_tool_call "$sid" "$mid" "recall" '{"query":"build command"}' "echo no build needed" 6000100
inject_text "$sid" "$mid" "The build command is: echo no build needed" 6000200

session_text=$(get_session_text "$sid")
assert_not_contains "$session_text" "Memory returned no results" "no false fallback notice"

print_summary
