#!/usr/bin/env bash
# signet-first skill test helpers — fixture-based (no live API calls)
#
# Strategy: create temp SQLite DBs with injected fixtures,
# run assertions against them, destroy on exit.
set -uo pipefail

# ── Configuration ─────────────────────────────────────────────
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$TEST_DIR")"
_TEST_TMPDIR=""

OPENCODE_DB=""
SIGNET_DB=""

_PASS=0
_FAIL=0
_SKIP=0
_TOTAL=0
_CURRENT_TEST=""
_SESSION_ID=""
_SEQ=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── Pre-flight ────────────────────────────────────────────────

preflight_check() {
    local missing=0
    for cmd in sqlite3 jq bc; do
        if ! command -v "$cmd" &>/dev/null; then
            echo -e "${RED}MISSING: $cmd${NC}"
            missing=1
        fi
    done
    if [ "$missing" -eq 1 ]; then
        echo -e "${RED}Pre-flight check failed. Install missing dependencies.${NC}"
        exit 1
    fi
}

# ── Fixture DB Management ────────────────────────────────────

create_test_dbs() {
    _TEST_TMPDIR=$(mktemp -d "/tmp/signet-first-test.XXXXXX")
    OPENCODE_DB="$_TEST_TMPDIR/opencode.db"
    SIGNET_DB="$_TEST_TMPDIR/memories.db"

    sqlite3 "$OPENCODE_DB" "
        CREATE TABLE project (
            id TEXT PRIMARY KEY,
            worktree TEXT NOT NULL,
            vcs TEXT,
            name TEXT,
            time_created INTEGER NOT NULL,
            time_updated INTEGER NOT NULL,
            sandboxes TEXT NOT NULL DEFAULT '[]'
        );
        CREATE TABLE session (
            id TEXT PRIMARY KEY,
            project_id TEXT NOT NULL,
            slug TEXT NOT NULL DEFAULT '',
            directory TEXT NOT NULL DEFAULT '.',
            title TEXT NOT NULL DEFAULT 'test',
            version TEXT NOT NULL DEFAULT '1',
            time_created INTEGER NOT NULL,
            time_updated INTEGER NOT NULL,
            FOREIGN KEY (project_id) REFERENCES project(id)
        );
        CREATE TABLE message (
            id TEXT PRIMARY KEY,
            session_id TEXT NOT NULL,
            time_created INTEGER NOT NULL,
            time_updated INTEGER NOT NULL,
            data TEXT NOT NULL,
            FOREIGN KEY (session_id) REFERENCES session(id)
        );
        CREATE TABLE part (
            id TEXT PRIMARY KEY,
            message_id TEXT NOT NULL,
            session_id TEXT NOT NULL,
            time_created INTEGER NOT NULL,
            time_updated INTEGER NOT NULL,
            data TEXT NOT NULL,
            FOREIGN KEY (message_id) REFERENCES message(id)
        );
        INSERT INTO project (id, worktree, time_created, time_updated, sandboxes)
        VALUES ('test-project', '/tmp/test', 1000000, 1000000, '[]');
    "

    sqlite3 "$SIGNET_DB" "
        CREATE TABLE memories (
            id TEXT PRIMARY KEY,
            content TEXT NOT NULL,
            type TEXT DEFAULT 'fact',
            scope TEXT,
            category TEXT,
            importance REAL DEFAULT 0.5,
            pinned INTEGER DEFAULT 0,
            tags TEXT,
            agent_id TEXT DEFAULT 'default',
            is_deleted INTEGER DEFAULT 0,
            created_at TEXT DEFAULT (datetime('now')),
            access_count INTEGER DEFAULT 0,
            last_accessed TEXT,
            content_hash TEXT
        );
    "

    _SEQ=0
}

destroy_test_dbs() {
    if [ -n "$_TEST_TMPDIR" ] && [ -d "$_TEST_TMPDIR" ]; then
        rm -rf "$_TEST_TMPDIR"
    fi
    _TEST_TMPDIR=""
    OPENCODE_DB=""
    SIGNET_DB=""
}

# ── Fixture Injection ────────────────────────────────────────

_next_id() {
    local prefix="${1:-id}"
    local seq_file="$_TEST_TMPDIR/.seq"
    _SEQ=$(cat "$seq_file" 2>/dev/null || echo 0)
    _SEQ=$((_SEQ + 1))
    echo "$_SEQ" > "$seq_file"
    printf '%s_%05d' "$prefix" "$_SEQ"
}

# Create a session and return its ID.
# Usage: session_id=$(inject_session "my-session")
inject_session() {
    local session_id="${1:-ses_test_$(_next_id ses)}"
    local ts="${2:-$(( 1000000 + _SEQ * 1000 ))}"

    sqlite3 "$OPENCODE_DB" "
        INSERT INTO session (id, project_id, slug, directory, title, version, time_created, time_updated)
        VALUES ('$session_id', 'test-project', '$session_id', '.', 'test', '1', $ts, $ts);
    "
    _SESSION_ID="$session_id"
    echo "$session_id"
}

# Inject a message into a session. Returns message ID.
# Usage: msg_id=$(inject_message "$session_id" "assistant" [timestamp])
inject_message() {
    local session_id="$1"
    local role="${2:-assistant}"
    local ts="${3:-$(( 1000000 + _SEQ * 1000 ))}"
    local msg_id=$(_next_id msg)

    sqlite3 "$OPENCODE_DB" "
        INSERT INTO message (id, session_id, time_created, time_updated, data)
        VALUES ('$msg_id', '$session_id', $ts, $ts,
            json_object('role', '$role', 'parentID', ''));
    "
    echo "$msg_id"
}

# Inject a tool call part. The key fixture function.
# Usage: inject_tool_call "$session_id" "$msg_id" "recall" '{"query":"test"}' "result" [timestamp]
inject_tool_call() {
    local session_id="$1"
    local msg_id="$2"
    local tool_name="$3"
    local input_json="${4:-'{}'}"
    local output="${5:-}"
    local ts="${6:-$(( 1000000 + _SEQ * 1000 ))}"
    local part_id=$(_next_id prt)

    local escaped_output
    escaped_output=$(echo "$output" | sed "s/'/''/g")

    sqlite3 "$OPENCODE_DB" "
        INSERT INTO part (id, message_id, session_id, time_created, time_updated, data)
        VALUES ('$part_id', '$msg_id', '$session_id', $ts, $ts,
            json_object(
                'type', 'tool',
                'tool', '$tool_name',
                'callID', 'call_$part_id',
                'state', json_object(
                    'status', 'completed',
                    'input', json('$input_json'),
                    'output', '$escaped_output',
                    'time', json_object('start', $ts, 'end', $(($ts + 100)))
                )
            )
        );
    "
}

# Inject a text part (assistant output).
# Usage: inject_text "$session_id" "$msg_id" "response text" [timestamp]
inject_text() {
    local session_id="$1"
    local msg_id="$2"
    local text="$3"
    local ts="${4:-$(( 1000000 + _SEQ * 1000 ))}"
    local part_id=$(_next_id prt)

    local escaped_text
    escaped_text=$(echo "$text" | sed "s/'/''/g")

    sqlite3 "$OPENCODE_DB" "
        INSERT INTO part (id, message_id, session_id, time_created, time_updated, data)
        VALUES ('$part_id', '$msg_id', '$session_id', $ts, $ts,
            json_object('type', 'text', 'text', '$escaped_text',
                'time', json_object('start', $ts, 'end', $ts))
        );
    "
}

# Inject a memory into the Signet DB.
# Usage: inject_memory "content" "type" "scope" importance pinned "tags"
inject_memory() {
    local content="$1"
    local mem_type="${2:-fact}"
    local scope="${3:-}"
    local importance="${4:-0.5}"
    local pinned="${5:-0}"
    local tags="${6:-}"
    local mem_id=$(_next_id mem)

    local escaped_content
    escaped_content=$(echo "$content" | sed "s/'/''/g")

    sqlite3 "$SIGNET_DB" "
        INSERT INTO memories (id, content, type, scope, importance, pinned, tags, is_deleted)
        VALUES ('$mem_id', '$escaped_content', '$mem_type', $([ -n "$scope" ] && echo "'$scope'" || echo "NULL"), $importance, $pinned, '$tags', 0);
    "
}

# Inject a memory with explicit ID (for update/modify tests).
# Usage: inject_memory_with_id "mem_001" "content" "type" "scope" importance pinned "tags"
inject_memory_with_id() {
    local mem_id="$1"
    local content="$2"
    local mem_type="${3:-fact}"
    local scope="${4:-}"
    local importance="${5:-0.5}"
    local pinned="${6:-0}"
    local tags="${7:-}"

    local escaped_content
    escaped_content=$(echo "$content" | sed "s/'/''/g")

    sqlite3 "$SIGNET_DB" "
        INSERT INTO memories (id, content, type, scope, importance, pinned, tags, is_deleted)
        VALUES ('$mem_id', '$escaped_content', '$mem_type', $([ -n "$scope" ] && echo "'$scope'" || echo "NULL"), $importance, $pinned, '$tags', 0);
    "
}

# Simulate signet_memory_modify — update an existing memory's content.
# Usage: modify_memory "mem_001" "new content"
modify_memory() {
    local mem_id="$1"
    local new_content="$2"

    local escaped_content
    escaped_content=$(echo "$new_content" | sed "s/'/''/g")

    sqlite3 "$SIGNET_DB" "
        UPDATE memories SET content = '$escaped_content' WHERE id = '$mem_id';
    "
}

# Count memories matching a content pattern (for dedup checks).
# Usage: count=$(signet_count_by_content "pattern")
signet_count_by_content() {
    local content_pattern="$1"
    local mem_type="${2:-}"
    local where="is_deleted = 0 AND content LIKE '%$content_pattern%'"
    [ -n "$mem_type" ] && where="$where AND type = '$mem_type'"
    sqlite3 "$SIGNET_DB" "SELECT COUNT(*) FROM memories WHERE $where;" 2>/dev/null
}

# ── Tool Call Inspection ──────────────────────────────────────

get_tool_calls() {
    local session_id="${1:-$_SESSION_ID}"
    sqlite3 "$OPENCODE_DB" "
        SELECT json_extract(p.data, '$.tool'), p.time_created
        FROM part p
        WHERE p.session_id = '$session_id'
          AND json_extract(p.data, '$.type') = 'tool'
          AND json_extract(p.data, '$.state.status') = 'completed'
        ORDER BY p.time_created ASC;
    " 2>/dev/null
}

tool_was_called() {
    local session_id="${1:-$_SESSION_ID}"
    local tool_name="$2"
    local count
    count=$(sqlite3 "$OPENCODE_DB" "
        SELECT COUNT(*)
        FROM part p
        WHERE p.session_id = '$session_id'
          AND json_extract(p.data, '$.type') = 'tool'
          AND json_extract(p.data, '$.tool') = '$tool_name'
          AND json_extract(p.data, '$.state.status') = 'completed';
    " 2>/dev/null)
    [ "$count" -gt 0 ]
}

first_tool_timestamp() {
    local session_id="${1:-$_SESSION_ID}"
    local tool_name="$2"
    sqlite3 "$OPENCODE_DB" "
        SELECT MIN(p.time_created)
        FROM part p
        WHERE p.session_id = '$session_id'
          AND json_extract(p.data, '$.type') = 'tool'
          AND json_extract(p.data, '$.tool') = '$tool_name'
          AND json_extract(p.data, '$.state.status') = 'completed';
    " 2>/dev/null
}

get_session_text() {
    local session_id="${1:-$_SESSION_ID}"
    sqlite3 "$OPENCODE_DB" "
        SELECT json_extract(p.data, '$.text')
        FROM part p
        WHERE p.session_id = '$session_id'
          AND json_extract(p.data, '$.type') = 'text'
        ORDER BY p.time_created ASC;
    " 2>/dev/null
}

# ── Signet Memory Inspection ─────────────────────────────────

signet_find_memory() {
    local content_pattern="$1"
    if [ ! -f "$SIGNET_DB" ]; then
        return 1
    fi
    sqlite3 "$SIGNET_DB" "
        SELECT json_object(
            'id', id, 'content', content, 'type', type,
            'scope', scope, 'category', category,
            'importance', importance, 'pinned', pinned, 'tags', tags
        )
        FROM memories
        WHERE is_deleted = 0 AND content LIKE '%$content_pattern%'
        ORDER BY created_at DESC LIMIT 1;
    " 2>/dev/null
}

signet_count_memories() {
    local content_pattern="$1"
    if [ ! -f "$SIGNET_DB" ]; then
        echo "0"
        return
    fi
    sqlite3 "$SIGNET_DB" "
        SELECT COUNT(*) FROM memories
        WHERE is_deleted = 0 AND content LIKE '%$content_pattern%';
    " 2>/dev/null
}

# ── Assertion Functions ───────────────────────────────────────

test_start() {
    _CURRENT_TEST="$1"
    _TOTAL=$((_TOTAL + 1))
    echo -e "${CYAN}  TEST: ${_CURRENT_TEST}${NC}"
}

_pass() {
    local msg="${1:-$_CURRENT_TEST}"
    _PASS=$((_PASS + 1))
    echo -e "    ${GREEN}PASS${NC} $msg"
}

_fail() {
    local msg="${1:-$_CURRENT_TEST}"
    _FAIL=$((_FAIL + 1))
    echo -e "    ${RED}FAIL${NC} $msg"
}

_skip() {
    local msg="${1:-$_CURRENT_TEST}"
    _SKIP=$((_SKIP + 1))
    echo -e "    ${YELLOW}SKIP${NC} $msg"
}

assert_contains() {
    local text="$1"
    local pattern="$2"
    local desc="${3:-contains '$pattern'}"
    if echo "$text" | grep -qi "$pattern"; then
        _pass "$desc"
    else
        _fail "$desc — expected to find '$pattern'"
    fi
}

assert_not_contains() {
    local text="$1"
    local pattern="$2"
    local desc="${3:-does not contain '$pattern'}"
    if echo "$text" | grep -qi "$pattern"; then
        _fail "$desc — found '$pattern' (should be absent)"
    else
        _pass "$desc"
    fi
}

assert_tool_before() {
    local session_id="$1"
    local tool_a="$2"
    local tool_b="$3"
    local desc="${4:-tool '$tool_a' before '$tool_b'}"

    local ts_a ts_b

    if [ "$tool_a" = "recall" ] || [ "$tool_a" = "memory_search" ]; then
        ts_a=$(sqlite3 "$OPENCODE_DB" "
            SELECT MIN(p.time_created) FROM part p
            WHERE p.session_id = '$session_id'
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
    else
        _fail "$desc — '$tool_a' ($ts_a) should be before '$tool_b' ($ts_b)"
    fi
}

assert_memory_searched() {
    local session_id="${1:-$_SESSION_ID}"
    local desc="${2:-memory was searched}"
    local count
    count=$(sqlite3 "$OPENCODE_DB" "
        SELECT COUNT(*) FROM part p
        WHERE p.session_id = '$session_id'
          AND json_extract(p.data, '$.type') = 'tool'
          AND json_extract(p.data, '$.tool') IN ('recall','memory_search','signet_memory_search')
          AND json_extract(p.data, '$.state.status') = 'completed';
    " 2>/dev/null)
    if [ "$count" -gt 0 ]; then
        _pass "$desc (called $count times)"
    else
        _fail "$desc — no memory search tool was called"
    fi
}

assert_memory_stored() {
    local content_pattern="$1"
    local expected_type="${2:-}"
    local expected_scope="${3:-}"
    local desc="${4:-memory stored matching '$content_pattern'}"

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
}

assert_memory_pinned() {
    local content_pattern="$1"
    local desc="${2:-memory '$content_pattern' is pinned}"

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
    else
        _fail "$desc — pinned=$pinned (expected 1)"
    fi
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
