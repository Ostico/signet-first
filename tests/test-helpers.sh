#!/usr/bin/env bash
# signet-first skill test helpers
# Adapted from obra/superpowers test pattern for OpenCode
set -uo pipefail

# ── Configuration ─────────────────────────────────────────────
OPENCODE_DB="${OPENCODE_DB:-$HOME/.local/share/opencode/opencode.db}"
SIGNET_DB="${SIGNET_DB:-$HOME/.agents/memory/memories.db}"
TEST_TIMEOUT="${TEST_TIMEOUT:-120}"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$TEST_DIR")"

# Counters
_PASS=0
_FAIL=0
_SKIP=0
_TOTAL=0
_CURRENT_TEST=""
_SESSION_ID=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── Pre-flight ────────────────────────────────────────────────

preflight_check() {
    local missing=0
    for cmd in opencode sqlite3 jq; do
        if ! command -v "$cmd" &>/dev/null; then
            echo -e "${RED}MISSING: $cmd${NC}"
            missing=1
        fi
    done
    if [ ! -f "$OPENCODE_DB" ]; then
        echo -e "${RED}MISSING: OpenCode database at $OPENCODE_DB${NC}"
        missing=1
    fi
    if [ ! -f "$SIGNET_DB" ]; then
        echo -e "${YELLOW}WARNING: Signet database not found at $SIGNET_DB — memory store assertions will skip${NC}"
    fi
    if [ "$missing" -eq 1 ]; then
        echo -e "${RED}Pre-flight check failed. Install missing dependencies.${NC}"
        exit 1
    fi
}

# ── Session Management ────────────────────────────────────────

# Run an OpenCode session with a prompt, capture output and session ID.
# Usage: run_opencode "your prompt here" [timeout_seconds]
run_opencode() {
    local prompt="$1"
    local timeout="${2:-$TEST_TIMEOUT}"
    local output

    output=$(timeout "$timeout" opencode run "$prompt" \
        --format json \
        --title "signet-first-test-$(date +%s)" \
        --dir "$SKILL_DIR" \
        2>/dev/null) || true

    # Extract session ID from JSON output
    _SESSION_ID=$(echo "$output" | grep -oP '"sessionID"\s*:\s*"[^"]*"' | head -1 | grep -oP '"[^"]*"$' | tr -d '"')

    # If --format json didn't give us a session ID, try from the DB (most recent)
    if [ -z "$_SESSION_ID" ]; then
        _SESSION_ID=$(sqlite3 "$OPENCODE_DB" \
            "SELECT id FROM session ORDER BY time_created DESC LIMIT 1;" 2>/dev/null)
    fi

    # Return the text output (strip JSON framing for assertion readability)
    echo "$output"
}

# Get the session ID from the last run_opencode call
get_session_id() {
    echo "$_SESSION_ID"
}

# Extract all text output from a session (assistant messages only)
get_session_text() {
    local session_id="${1:-$_SESSION_ID}"
    sqlite3 "$OPENCODE_DB" "
        SELECT json_extract(p.data, '$.content')
        FROM part p
        JOIN message m ON p.message_id = m.id
        WHERE m.session_id = '$session_id'
          AND json_extract(m.data, '$.role') = 'assistant'
          AND json_extract(p.data, '$.type') = 'text'
        ORDER BY p.time_created ASC;
    " 2>/dev/null
}

# ── Tool Call Inspection ──────────────────────────────────────

# Get ordered list of tool calls from a session.
# Returns: tool_name\ttimestamp per line
get_tool_calls() {
    local session_id="${1:-$_SESSION_ID}"
    sqlite3 "$OPENCODE_DB" "
        SELECT
            json_extract(p.data, '$.tool'),
            p.time_created
        FROM part p
        JOIN message m ON p.message_id = m.id
        WHERE m.session_id = '$session_id'
          AND json_extract(p.data, '$.type') = 'tool'
          AND json_extract(p.data, '$.state.status') = 'completed'
        ORDER BY p.time_created ASC;
    " 2>/dev/null
}

# Get tool calls with their input parameters (JSON).
get_tool_calls_with_input() {
    local session_id="${1:-$_SESSION_ID}"
    sqlite3 "$OPENCODE_DB" "
        SELECT
            json_extract(p.data, '$.tool'),
            json_extract(p.data, '$.state.input')
        FROM part p
        JOIN message m ON p.message_id = m.id
        WHERE m.session_id = '$session_id'
          AND json_extract(p.data, '$.type') = 'tool'
          AND json_extract(p.data, '$.state.status') = 'completed'
        ORDER BY p.time_created ASC;
    " 2>/dev/null
}

# Check if a specific tool was called in a session.
tool_was_called() {
    local session_id="${1:-$_SESSION_ID}"
    local tool_name="$2"
    local count
    count=$(sqlite3 "$OPENCODE_DB" "
        SELECT COUNT(*)
        FROM part p
        JOIN message m ON p.message_id = m.id
        WHERE m.session_id = '$session_id'
          AND json_extract(p.data, '$.type') = 'tool'
          AND json_extract(p.data, '$.tool') = '$tool_name'
          AND json_extract(p.data, '$.state.status') = 'completed';
    " 2>/dev/null)
    [ "$count" -gt 0 ]
}

# Get the timestamp of the FIRST call to a specific tool in a session.
first_tool_timestamp() {
    local session_id="${1:-$_SESSION_ID}"
    local tool_name="$2"
    sqlite3 "$OPENCODE_DB" "
        SELECT MIN(p.time_created)
        FROM part p
        JOIN message m ON p.message_id = m.id
        WHERE m.session_id = '$session_id'
          AND json_extract(p.data, '$.type') = 'tool'
          AND json_extract(p.data, '$.tool') = '$tool_name'
          AND json_extract(p.data, '$.state.status') = 'completed';
    " 2>/dev/null
}

# ── Signet Memory Inspection ─────────────────────────────────

# Search Signet DB for a memory matching content pattern.
# Returns the full row as JSON.
signet_find_memory() {
    local content_pattern="$1"
    if [ ! -f "$SIGNET_DB" ]; then
        return 1
    fi
    sqlite3 "$SIGNET_DB" "
        SELECT json_object(
            'id', id,
            'content', content,
            'type', type,
            'scope', scope,
            'category', category,
            'importance', importance,
            'pinned', pinned,
            'tags', tags,
            'created_at', created_at
        )
        FROM memories
        WHERE is_deleted = 0
          AND content LIKE '%$content_pattern%'
        ORDER BY created_at DESC
        LIMIT 1;
    " 2>/dev/null
}

# Count memories matching a content pattern
signet_count_memories() {
    local content_pattern="$1"
    if [ ! -f "$SIGNET_DB" ]; then
        echo "0"
        return
    fi
    sqlite3 "$SIGNET_DB" "
        SELECT COUNT(*)
        FROM memories
        WHERE is_deleted = 0
          AND content LIKE '%$content_pattern%';
    " 2>/dev/null
}

# ── Assertion Functions ───────────────────────────────────────

# Begin a named test
test_start() {
    _CURRENT_TEST="$1"
    _TOTAL=$((_TOTAL + 1))
    echo -e "${CYAN}  TEST: ${_CURRENT_TEST}${NC}"
}

# Record pass
_pass() {
    local msg="${1:-$_CURRENT_TEST}"
    _PASS=$((_PASS + 1))
    echo -e "    ${GREEN}PASS${NC} $msg"
}

# Record fail
_fail() {
    local msg="${1:-$_CURRENT_TEST}"
    _FAIL=$((_FAIL + 1))
    echo -e "    ${RED}FAIL${NC} $msg"
}

# Record skip
_skip() {
    local msg="${1:-$_CURRENT_TEST}"
    _SKIP=$((_SKIP + 1))
    echo -e "    ${YELLOW}SKIP${NC} $msg"
}

# Assert that output text contains a pattern (case-insensitive).
# Usage: assert_contains "$output" "pattern" "description"
assert_contains() {
    local text="$1"
    local pattern="$2"
    local desc="${3:-contains '$pattern'}"
    if echo "$text" | grep -qi "$pattern"; then
        _pass "$desc"
        return 0
    else
        _fail "$desc — expected to find '$pattern'"
        return 1
    fi
}

# Assert that output text does NOT contain a pattern.
assert_not_contains() {
    local text="$1"
    local pattern="$2"
    local desc="${3:-does not contain '$pattern'}"
    if echo "$text" | grep -qi "$pattern"; then
        _fail "$desc — found '$pattern' (should be absent)"
        return 1
    else
        _pass "$desc"
        return 0
    fi
}

# Assert that pattern A appears before pattern B in text.
# Usage: assert_order "$text" "first_pattern" "second_pattern" "description"
assert_order() {
    local text="$1"
    local first="$2"
    local second="$3"
    local desc="${4:-'$first' before '$second'}"

    local pos_first pos_second
    pos_first=$(echo "$text" | grep -n -i "$first" | head -1 | cut -d: -f1)
    pos_second=$(echo "$text" | grep -n -i "$second" | head -1 | cut -d: -f1)

    if [ -z "$pos_first" ]; then
        _fail "$desc — '$first' not found in output"
        return 1
    fi
    if [ -z "$pos_second" ]; then
        _fail "$desc — '$second' not found in output"
        return 1
    fi
    if [ "$pos_first" -lt "$pos_second" ]; then
        _pass "$desc"
        return 0
    else
        _fail "$desc — '$first' (line $pos_first) should appear before '$second' (line $pos_second)"
        return 1
    fi
}

# Assert that tool A was called before tool B in a session.
# Uses millisecond timestamps from the DB for precision.
# Usage: assert_tool_before "session_id" "recall" "bash" "description"
assert_tool_before() {
    local session_id="$1"
    local tool_a="$2"
    local tool_b="$3"
    local desc="${4:-tool '$tool_a' before '$tool_b'}"

    local ts_a ts_b

    # For memory tools, check any of the aliases
    if [ "$tool_a" = "recall" ] || [ "$tool_a" = "memory_search" ]; then
        ts_a=$(sqlite3 "$OPENCODE_DB" "
            SELECT MIN(p.time_created)
            FROM part p
            JOIN message m ON p.message_id = m.id
            WHERE m.session_id = '$session_id'
              AND json_extract(p.data, '$.type') = 'tool'
              AND json_extract(p.data, '$.tool') IN ('recall','memory_search','signet_memory_search')
              AND json_extract(p.data, '$.state.status') = 'completed';
        " 2>/dev/null)
    else
        ts_a=$(first_tool_timestamp "$session_id" "$tool_a")
    fi

    ts_b=$(first_tool_timestamp "$session_id" "$tool_b")

    if [ -z "$ts_a" ] || [ "$ts_a" = "" ]; then
        _fail "$desc — '$tool_a' was never called"
        return 1
    fi
    if [ -z "$ts_b" ] || [ "$ts_b" = "" ]; then
        _fail "$desc — '$tool_b' was never called"
        return 1
    fi
    if [ "$ts_a" -lt "$ts_b" ]; then
        _pass "$desc"
        return 0
    else
        _fail "$desc — '$tool_a' ($ts_a) should be before '$tool_b' ($ts_b)"
        return 1
    fi
}

# Assert that a memory tool (recall/memory_search/signet_memory_search) was called.
assert_memory_searched() {
    local session_id="${1:-$_SESSION_ID}"
    local desc="${2:-memory was searched}"
    local count
    count=$(sqlite3 "$OPENCODE_DB" "
        SELECT COUNT(*)
        FROM part p
        JOIN message m ON p.message_id = m.id
        WHERE m.session_id = '$session_id'
          AND json_extract(p.data, '$.type') = 'tool'
          AND json_extract(p.data, '$.tool') IN ('recall','memory_search','signet_memory_search')
          AND json_extract(p.data, '$.state.status') = 'completed';
    " 2>/dev/null)
    if [ "$count" -gt 0 ]; then
        _pass "$desc (called $count times)"
        return 0
    else
        _fail "$desc — no memory search tool was called"
        return 1
    fi
}

# Assert that a memory was stored with specific field values.
# Usage: assert_memory_stored "content_pattern" "expected_type" "expected_scope" "description"
assert_memory_stored() {
    local content_pattern="$1"
    local expected_type="${2:-}"
    local expected_scope="${3:-}"
    local desc="${4:-memory stored matching '$content_pattern'}"

    if [ ! -f "$SIGNET_DB" ]; then
        _skip "$desc — Signet DB not found"
        return 0
    fi

    local row
    row=$(signet_find_memory "$content_pattern")

    if [ -z "$row" ]; then
        _fail "$desc — no memory found matching '$content_pattern'"
        return 1
    fi

    local actual_type actual_scope
    actual_type=$(echo "$row" | jq -r '.type')
    actual_scope=$(echo "$row" | jq -r '.scope')

    if [ -n "$expected_type" ] && [ "$actual_type" != "$expected_type" ]; then
        _fail "$desc — type: expected '$expected_type', got '$actual_type'"
        return 1
    fi

    if [ -n "$expected_scope" ] && [ "$actual_scope" != "$expected_scope" ]; then
        _fail "$desc — scope: expected '$expected_scope', got '$actual_scope'"
        return 1
    fi

    _pass "$desc (type=$actual_type, scope=$actual_scope)"
    return 0
}

# Assert that a memory is pinned.
assert_memory_pinned() {
    local content_pattern="$1"
    local desc="${2:-memory '$content_pattern' is pinned}"

    if [ ! -f "$SIGNET_DB" ]; then
        _skip "$desc — Signet DB not found"
        return 0
    fi

    local row
    row=$(signet_find_memory "$content_pattern")

    if [ -z "$row" ]; then
        _fail "$desc — no memory found matching '$content_pattern'"
        return 1
    fi

    local pinned
    pinned=$(echo "$row" | jq -r '.pinned')

    if [ "$pinned" = "1" ]; then
        _pass "$desc"
        return 0
    else
        _fail "$desc — pinned=$pinned (expected 1)"
        return 1
    fi
}

# ── Retrospective Assertions (on existing sessions) ──────────
# These work on already-completed sessions without running new ones.
# Useful for validating the skill against historical data.

# Find sessions where a specific tool was used.
find_sessions_with_tool() {
    local tool_name="$1"
    local limit="${2:-10}"
    sqlite3 "$OPENCODE_DB" "
        SELECT DISTINCT m.session_id
        FROM part p
        JOIN message m ON p.message_id = m.id
        WHERE json_extract(p.data, '$.type') = 'tool'
          AND json_extract(p.data, '$.tool') = '$tool_name'
        ORDER BY p.time_created DESC
        LIMIT $limit;
    " 2>/dev/null
}

# ── Summary ───────────────────────────────────────────────────

print_summary() {
    echo ""
    echo -e "${BOLD}══════════════════════════════════════${NC}"
    echo -e "${BOLD}  Test Summary${NC}"
    echo -e "${BOLD}══════════════════════════════════════${NC}"
    echo -e "  ${GREEN}PASS:${NC} $_PASS"
    echo -e "  ${RED}FAIL:${NC} $_FAIL"
    echo -e "  ${YELLOW}SKIP:${NC} $_SKIP"
    echo -e "  Total: $_TOTAL"
    echo -e "${BOLD}══════════════════════════════════════${NC}"

    if [ "$_FAIL" -gt 0 ]; then
        echo -e "  ${RED}RESULT: FAILED${NC}"
        return 1
    else
        echo -e "  ${GREEN}RESULT: PASSED${NC}"
        return 0
    fi
}
