# signet-first -- Test Results

**Date:** 2026-04-11
**Version:** 2.0.1
**Environment:** Claude Code + Signet
**Method:** Fixture-based SQLite injection (zero API calls, <1s)

## Summary

5 suites, 48 assertions, 0 failures.

## Test Suites

### test-plugin-packaging (15 assertions)

| # | Test | Asserts |
|---|------|---------|
| 1 | version-bump --check detects no drift | exit code 0 |
| 2 | All 5 platform configs declare same version | unique count = 1 |
| 3 | Hook: Claude Code JSON format | hookSpecificOutput.additionalContext present |
| 4 | Hook: Cursor JSON format | additional_context present |
| 5 | Hook: Copilot CLI JSON format | additionalContext present |
| 6 | Hook: YAML frontmatter stripped from output | no frontmatter leak |
| 7 | Hook: skill content present after stripping | content found |
| 8 | Hook: Rules section present | section found |
| 9 | Required platform files exist | all 15 files present |
| 10 | session-start hook is executable | executable bit set |
| 11 | GEMINI.md includes SKILL.md | @./SKILL.md reference found |
| 12 | package.json main points to OpenCode plugin | correct path |
| 13 | hooks.json references run-hook.cmd | reference found |
| 14 | templates/CLAUDE.md version matches package.json | versions match |
| 15 | templates/CLAUDE.md exists | file present |

### test-pre-action-gate (8 assertions)

| # | Test | Asserts |
|---|------|---------|
| 1 | Compliant: recall before bash | timestamp order |
| 2 | Violation: bash executed before recall | violation detected |
| 3 | signet_memory_search satisfies the gate | alias accepted |
| 4 | Procedural query answered from memory only | search called, no bash |
| 5 | All memory tool aliases satisfy the gate | recall, memory_search, signet_memory_search (3 assertions) |

### test-search-protocol (5 assertions)

| # | Test | Asserts |
|---|------|---------|
| 1 | Compliant session has recall call | tool called |
| 2 | Recall precedes file reads | timestamp order |
| 3 | Violation: session with bash but no recall | no recall detected |
| 4 | Fallback notice in assistant text | notice present |
| 5 | No fallback notice when Signet has the answer | no false notice |

### test-session-lifecycle (8 assertions)

| # | Test | Asserts |
|---|------|---------|
| 1 | Session ends with daily-log memory | type=daily-log stored |
| 2 | Violation: non-trivial session missing daily-log | no daily-log detected |
| 3 | Self-healing: fallback stores result for next time | stored + no second fallback (2 assertions) |
| 4 | Session start: daily-log searched before file reads | timestamp order |
| 5 | Violation: session starts by reading MEMORY.md | read before recall detected |
| 6 | Daily-log has accomplishments and next steps | content fields present |
| 7 | Continuation request triggers daily-log search | type=daily-log in search input |

### test-store-protocol (12 assertions)

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
| 11 | Decision memory conflict flagged to user | conflict flagged, no silent overwrite (2 assertions) |

## Architecture

Tests use temporary SQLite databases (OpenCode schema + Signet schema) with injected
fixtures. Each test file creates its own DBs via `create_test_dbs` and destroys them
on exit via `trap 'destroy_test_dbs' EXIT`. No network calls, no API keys, no running
services required.

## Running

```bash
bash tests/run-all.sh
```
