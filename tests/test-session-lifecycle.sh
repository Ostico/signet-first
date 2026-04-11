#!/usr/bin/env bash
# Tests: Session Lifecycle — daily-log, self-healing loop, session-start handoff
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/test-helpers.sh"

preflight_check
create_test_dbs
trap 'destroy_test_dbs' EXIT

echo -e "${BOLD}Session Lifecycle Tests${NC}"
echo "────────────────────────────────────"

# ── Test 1: end-of-session daily-log present ──────────────────

test_start "session ends with daily-log memory"
sid=$(inject_session "ses_with_dailylog")
mid=$(inject_message "$sid" "assistant" 12000000)
inject_tool_call "$sid" "$mid" "signet_memory_store" \
    '{"content":"Session summary: implemented fixture tests, fixed _SEQ bug","type":"daily-log","tags":"session-summary,signet-first","importance":0.6}' \
    "stored" 12000100
inject_memory "Session summary: implemented fixture tests, fixed _SEQ bug" \
    "daily-log" "signet-first" 0.6 0 "session-summary"

assert_memory_stored "fixture tests" "daily-log" "signet-first" \
    "daily-log stored at session end"

# ── Test 2: violation — session without daily-log ─────────────

test_start "violation: non-trivial session missing daily-log"
sid=$(inject_session "ses_no_dailylog")
mid=$(inject_message "$sid" "assistant" 13000000)
inject_tool_call "$sid" "$mid" "bash" '{"command":"npm run build"}' "success" 13000100
inject_tool_call "$sid" "$mid" "edit" '{"filePath":"src/app.ts"}' "edited" 13000200
inject_text "$sid" "$mid" "Build succeeded. Done." 13000300

count=$(sqlite3 "$SIGNET_DB" "
    SELECT COUNT(*) FROM memories
    WHERE is_deleted = 0 AND type = 'daily-log'
      AND content LIKE '%ses_no_dailylog%';
" 2>/dev/null)
if [ "$count" -eq 0 ]; then
    _pass "violation detected: non-trivial session has no daily-log"
else
    _fail "expected no daily-log for this session, found $count"
fi

# ── Test 3: self-healing — fallback triggers store ────────────

test_start "self-healing: fallback stores result for next time"

sid=$(inject_session "ses_selfheal_1")
mid=$(inject_message "$sid" "assistant" 14000000)
inject_tool_call "$sid" "$mid" "recall" '{"query":"redis config matecat"}' "" 14000100
inject_text "$sid" "$mid" "Memory returned no results for \"redis config\". Checking project files." 14000200
inject_tool_call "$sid" "$mid" "read" '{"filePath":"config/redis.yml"}' "host: 127.0.0.1, port: 6379" 14000300
inject_tool_call "$sid" "$mid" "signet_memory_store" \
    '{"content":"Matecat redis config: host=127.0.0.1 port=6379 db=0","type":"fact","scope":"matecat"}' \
    "stored" 14000400
inject_memory "Matecat redis config: host=127.0.0.1 port=6379 db=0" \
    "fact" "matecat" 0.7 0 "redis,config"

assert_memory_stored "redis config" "fact" "matecat" \
    "fallback result stored in Signet for next time"

sid2=$(inject_session "ses_selfheal_2")
mid2=$(inject_message "$sid2" "assistant" 15000000)
inject_tool_call "$sid2" "$mid2" "recall" '{"query":"redis config matecat"}' \
    "Matecat redis config: host=127.0.0.1 port=6379 db=0" 15000100

session_text=$(get_session_text "$sid2")
if echo "$session_text" | grep -qi "Memory returned no results"; then
    _fail "second session still falls back — self-heal did not work"
else
    _pass "second session answered from Signet — no fallback needed"
fi

# ── Test 4: session-start — daily-log searched first ──────────

test_start "session start: daily-log searched before file reads"
sid=$(inject_session "ses_start_compliant")
mid=$(inject_message "$sid" "assistant" 16000000)
inject_tool_call "$sid" "$mid" "signet_memory_search" \
    '{"query":"session summary matecat","type":"daily-log","limit":3}' \
    "Session summary: added caching layer to DaoCacheTrait" 16000100
inject_tool_call "$sid" "$mid" "bash" '{"command":"git status"}' "clean" 16000200

assert_tool_before "$sid" "recall" "bash" "daily-log searched before any action"

# ── Test 5: violation — session starts with file read ─────────

test_start "violation: session starts by reading MEMORY.md"
sid=$(inject_session "ses_start_violation")
mid=$(inject_message "$sid" "assistant" 17000000)
inject_tool_call "$sid" "$mid" "read" '{"filePath":"MEMORY.md"}' "memory content" 17000100
inject_tool_call "$sid" "$mid" "recall" '{"query":"previous work"}' "found" 17000200

ts_read=$(first_tool_timestamp "$sid" "read")
ts_recall=$(first_tool_timestamp "$sid" "recall")
if [ -n "$ts_read" ] && [ -n "$ts_recall" ] && [ "$ts_read" -lt "$ts_recall" ]; then
    _pass "violation detected: read MEMORY.md ($ts_read) before recall ($ts_recall)"
else
    _fail "expected read before recall but got read=$ts_read recall=$ts_recall"
fi

# ── Test 6: daily-log contains required fields ────────────────

test_start "daily-log has accomplishments and next steps"
inject_memory "Session summary: Refactored DaoCacheTrait to use XFetch. Next steps: add unit tests for cache invalidation. Blocker: Redis mock not configured." \
    "daily-log" "matecat" 0.6 0 "session-summary"

row=$(signet_find_memory "DaoCacheTrait")
content=$(echo "$row" | jq -r '.content')

has_accomplishment=0
has_next=0
echo "$content" | grep -qi "refactored\|implemented\|added\|fixed\|completed" && has_accomplishment=1
echo "$content" | grep -qi "next step\|blocker\|unfinished\|todo" && has_next=1

if [ "$has_accomplishment" -eq 1 ] && [ "$has_next" -eq 1 ]; then
    _pass "daily-log has accomplishments + next steps"
elif [ "$has_accomplishment" -eq 1 ]; then
    _fail "daily-log missing next steps or blockers"
elif [ "$has_next" -eq 1 ]; then
    _fail "daily-log missing accomplishments"
else
    _fail "daily-log missing both accomplishments and next steps"
fi

# ── Test 7: Rule 2 — continuation narrows to daily-log ───────

test_start "continuation request triggers daily-log search"
sid=$(inject_session "ses_continuation")
mid=$(inject_message "$sid" "assistant" 18000000)
inject_tool_call "$sid" "$mid" "signet_memory_search" \
    '{"query":"session summary matecat","type":"daily-log","limit":3}' \
    "Session summary: added caching layer" 18000100
inject_tool_call "$sid" "$mid" "bash" '{"command":"git status"}' "clean" 18000200

# Verify the search used type=daily-log (check input JSON)
input_json=$(sqlite3 "$OPENCODE_DB" "
    SELECT json_extract(p.data, '$.state.input')
    FROM part p
    WHERE p.session_id = '$sid'
      AND json_extract(p.data, '$.type') = 'tool'
      AND json_extract(p.data, '$.tool') = 'signet_memory_search'
    LIMIT 1;
" 2>/dev/null)
if echo "$input_json" | grep -q '"type":"daily-log"'; then
    _pass "search narrowed to type=daily-log"
else
    _fail "expected type=daily-log in search input, got: $input_json"
fi

print_summary
