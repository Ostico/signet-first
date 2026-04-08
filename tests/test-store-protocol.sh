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

print_summary
