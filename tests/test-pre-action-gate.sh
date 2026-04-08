#!/usr/bin/env bash
# Tests: Pre-Action Gate — recall MUST happen BEFORE bash execution
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/test-helpers.sh"

preflight_check
create_test_dbs
trap 'destroy_test_dbs' EXIT

echo -e "${BOLD}Pre-Action Gate Tests${NC}"
echo "────────────────────────────────────"

# ── Test 1: compliant — recall before bash ────────────────────

test_start "compliant: recall before bash"
sid=$(inject_session "ses_gate_compliant")
mid=$(inject_message "$sid" "assistant" 7000000)
inject_tool_call "$sid" "$mid" "recall" '{"query":"phpunit test command matecat"}' "vendor/bin/phpunit --exclude-group=ExternalServices" 7000100
inject_tool_call "$sid" "$mid" "bash" '{"command":"vendor/bin/phpunit --exclude-group=ExternalServices --no-coverage"}' "OK" 7000200

assert_tool_before "$sid" "recall" "bash" "recall called before bash"

# ── Test 2: violation — bash before recall ────────────────────

test_start "violation: bash executed before recall"
sid=$(inject_session "ses_gate_violation")
mid=$(inject_message "$sid" "assistant" 8000000)
inject_tool_call "$sid" "$mid" "bash" '{"command":"git commit -a -m fix"}' "committed" 8000100
inject_tool_call "$sid" "$mid" "recall" '{"query":"commit conventions"}' "conventional-commit" 8000200

ts_recall=$(first_tool_timestamp "$sid" "recall")
ts_bash=$(first_tool_timestamp "$sid" "bash")
if [ "$ts_bash" -lt "$ts_recall" ]; then
    _pass "violation correctly detected: bash ($ts_bash) before recall ($ts_recall)"
else
    _fail "expected bash before recall but timestamps show otherwise"
fi

# ── Test 3: compliant — signet_memory_search counts as recall ─

test_start "signet_memory_search satisfies the gate"
sid=$(inject_session "ses_gate_signet_search")
mid=$(inject_message "$sid" "assistant" 9000000)
inject_tool_call "$sid" "$mid" "signet_memory_search" '{"query":"deploy steps"}' "found" 9000100
inject_tool_call "$sid" "$mid" "bash" '{"command":"./deploy.sh"}' "deployed" 9000200

assert_tool_before "$sid" "recall" "bash" "signet_memory_search accepted as recall"

# ── Test 4: pure knowledge query — no bash needed ─────────────

test_start "procedural query answered from memory only"
sid=$(inject_session "ses_gate_no_bash")
mid=$(inject_message "$sid" "assistant" 10000000)
inject_tool_call "$sid" "$mid" "memory_search" '{"query":"deploy procedure"}' "Step 1: ..." 10000100
inject_text "$sid" "$mid" "The deploy procedure is..." 10000200

assert_memory_searched "$sid" "memory searched for procedural query"
if tool_was_called "$sid" "bash"; then
    _fail "bash should NOT be called for a pure knowledge query"
else
    _pass "no bash called for procedural query"
fi

# ── Test 5: multiple recall aliases all satisfy the gate ──────

test_start "all memory tool aliases satisfy the gate"
for tool in recall memory_search signet_memory_search; do
    sid=$(inject_session "ses_gate_alias_$tool")
    mid=$(inject_message "$sid" "assistant" $((11000000 + _SEQ * 1000)))
    inject_tool_call "$sid" "$mid" "$tool" '{"query":"test"}' "found" $((11000000 + _SEQ * 1000 + 100))
    inject_tool_call "$sid" "$mid" "bash" '{"command":"echo ok"}' "ok" $((11000000 + _SEQ * 1000 + 200))
    assert_tool_before "$sid" "recall" "bash" "$tool satisfies the gate"
done

print_summary
