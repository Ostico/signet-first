# signet-first — Test Results

**Date:** 2026-04-08
**Environment:** OpenCode 1.3.17, Signet 0.98.0
**Method:** Fixture-based SQLite injection (zero API calls, <1s)

## Summary

4 suites, 30 assertions, 0 failures.

## Test Suites

### test-store-protocol (10 assertions)

| # | Test | Asserts |
|---|------|---------|
| 1 | Command stored as type=procedural | type, scope |
| 2 | User preference stored as type=preference | type |
| 3 | Critical constraint is pinned | pinned=1 |
| 4 | Project knowledge has scope | scope=matecat |
| 5 | Decision stored as type=decision | type |
| 6 | Ephemeral discovery is NOT pinned | pinned=0 |
| 7 | Deduplication: duplicate detected by content match | count >= 2 |
| 8 | Modify updates existing memory content | content changed |
| 9 | Modify does not create orphan | total count unchanged |
| 10 | Importance: hard constraint >= 0.7 | importance >= 0.7 |

### test-search-protocol (5 assertions)

| # | Test | Asserts |
|---|------|---------|
| 1 | Compliant session has recall call | tool called |
| 2 | Recall precedes file reads | timestamp order |
| 3 | Violation: session with bash but no recall | no recall detected |
| 4 | Fallback warning in assistant text | warning present |
| 5 | No fallback warning when Signet has the answer | no false warning |

### test-pre-action-gate (8 assertions)

| # | Test | Asserts |
|---|------|---------|
| 1 | Compliant: recall before bash | timestamp order |
| 2 | Violation: bash executed before recall | violation detected |
| 3 | signet_memory_search satisfies the gate | alias accepted |
| 4 | Procedural query answered from memory only | search called, no bash |
| 5 | All memory tool aliases satisfy the gate | recall, memory_search, signet_memory_search |

### test-session-lifecycle (7 assertions)

| # | Test | Asserts |
|---|------|---------|
| 1 | Session ends with daily-log memory | type=daily-log stored |
| 2 | Violation: non-trivial session missing daily-log | no daily-log detected |
| 3 | Self-healing: fallback stores result for next time | stored + no second fallback |
| 4 | Session start: daily-log searched before file reads | timestamp order |
| 5 | Violation: session starts by reading MEMORY.md | read before recall detected |
| 6 | Daily-log has accomplishments and next steps | content fields present |

## Architecture

Tests use temporary SQLite databases (OpenCode schema + Signet schema) with injected
fixtures. Each test file creates its own DBs via `create_test_dbs` and destroys them
on exit via `trap 'destroy_test_dbs' EXIT`. No network calls, no API keys, no running
services required.

## Running

```bash
bash tests/run-all.sh
```
