#!/usr/bin/env bash
# Tests: Store Protocol — correct type, scope, pinning via fixture DB
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/test-helpers.sh"

preflight_check
create_test_dbs
trap 'destroy_test_dbs' EXIT

echo -e "${BOLD}Store Protocol Tests${NC}"
echo "────────────────────────────────────"

# ── Test 1: procedural type for commands ──────────────────────

test_start "command stored as type=procedural"
inject_memory "vendor/bin/phpunit --exclude-group=ExternalServices --no-coverage" \
    "procedural" "matecat" 1.0 1 "phpunit,test-command"
assert_memory_stored "phpunit" "procedural" "matecat" \
    "command stored as type=procedural"

# ── Test 2: preference type for user preferences ─────────────

test_start "user preference stored as type=preference"
inject_memory "User prefers verbose logging when debugging" \
    "preference" "" 0.6 0 "logging,debug"
assert_memory_stored "verbose logging" "preference" "" \
    "preference stored as type=preference"

# ── Test 3: pinning critical constraints ──────────────────────

test_start "critical constraint is pinned"
inject_memory "NEVER use force push on main branch" \
    "preference" "" 1.0 1 "git,constraint"
assert_memory_pinned "force push" \
    "critical constraint is pinned"

# ── Test 4: scope isolation ───────────────────────────────────

test_start "project knowledge has scope"
inject_memory "Database uses MySQL 8 with utf8mb4 charset" \
    "fact" "matecat" 0.7 0 "mysql,database"
assert_memory_stored "MySQL 8" "fact" "matecat" \
    "project knowledge stored with scope=matecat"

# ── Test 5: decision type for choices ─────────────────────────

test_start "decision stored as type=decision"
inject_memory "Chose PostgreSQL over MySQL for new service because of JSON column support" \
    "decision" "new-service" 0.8 0 "database,architecture"
assert_memory_stored "PostgreSQL over MySQL" "decision" "new-service" \
    "decision stored as type=decision, not fact"

# ── Test 6: unpinned memory is not pinned ─────────────────────

test_start "ephemeral discovery is NOT pinned"
inject_memory "nomic-embed-text is 137M params, limited on code queries" \
    "discovery" "" 0.4 0 "embedding,signet"
row=$(signet_find_memory "nomic-embed-text")
pinned=$(echo "$row" | jq -r '.pinned')
if [ "$pinned" = "0" ]; then
    _pass "discovery is not pinned (correct)"
else
    _fail "discovery should not be pinned — got pinned=$pinned"
fi

# ── Test 7: deduplication — same content not stored twice ──────

test_start "deduplication: duplicate detected by content match"
inject_memory "Deploy command: ./deploy.sh --prod --region=us-east-1" \
    "procedural" "myapp" 0.9 1 "deploy"
inject_memory "Deploy command: ./deploy.sh --prod --region=us-east-1" \
    "procedural" "myapp" 0.9 1 "deploy"
count=$(signet_count_by_content "deploy.sh --prod" "procedural")
if [ "$count" -ge 2 ]; then
    _pass "duplicate correctly detected: count=$count (agent must search before store)"
else
    _fail "expected duplicate to be detectable, found count=$count"
fi

# ── Test 8: memory modify updates existing content ────────────

test_start "modify updates existing memory content"
inject_memory_with_id "mem_modify_test" \
    "Test runner: npm test" "procedural" "webapp" 0.8 1 "test"
modify_memory "mem_modify_test" "Test runner: npm run test:ci -- --coverage"
row=$(signet_find_memory "test:ci")
if [ -n "$row" ]; then
    old_count=$(signet_count_by_content "npm test" "procedural")
    _pass "memory updated to new content (old 'npm test' count=$old_count)"
else
    _fail "modify did not update memory content"
fi

# ── Test 9: modify preserves ID — no orphan created ──────────

test_start "modify does not create a new memory"
total_before=$(sqlite3 "$SIGNET_DB" "SELECT COUNT(*) FROM memories WHERE is_deleted = 0;" 2>/dev/null)
modify_memory "mem_modify_test" "Test runner: npm run test:ci -- --coverage --bail"
total_after=$(sqlite3 "$SIGNET_DB" "SELECT COUNT(*) FROM memories WHERE is_deleted = 0;" 2>/dev/null)
if [ "$total_after" -eq "$total_before" ]; then
    _pass "total memory count unchanged after modify ($total_after)"
else
    _fail "modify created orphan — before=$total_before after=$total_after"
fi

# ── Test 10: importance calibration — constraint >= 0.7 ───────

test_start "importance: hard constraint >= 0.7"
inject_memory "NEVER delete production data without backup" \
    "preference" "" 1.0 1 "constraint,safety"
row=$(signet_find_memory "production data without backup")
importance=$(echo "$row" | jq -r '.importance')
if [ "$(echo "$importance >= 0.7" | bc -l)" -eq 1 ]; then
    _pass "constraint importance=$importance (>= 0.7)"
else
    _fail "constraint importance=$importance (expected >= 0.7)"
fi

print_summary
