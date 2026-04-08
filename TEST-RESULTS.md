# signet-first — Test Results

**Date:** 2026-04-08
**Environment:** OpenCode 1.3.17, Signet 0.98.0
**Memory DB:** ~/.agents/memory/memories.db (~80 memories at test time)

## Summary

8 tests, 8 passed, 0 failed.

Skill was tested across restart (session boundary) to verify cross-session persistence.

## Bug Found During Testing

**Traversal score inflation:** Signet's traversal engine returns high scores (80-140+)
for any query matching a known entity name (e.g. "Matecat"). This means threshold-based
fallback logic (`>=3 results AND score >=0.3`) would NEVER trigger for any query
mentioning a project entity — even when zero results actually answer the question.

**Fix applied:** Replaced threshold-based fallback with semantic relevance judgment.
The agent must evaluate whether result CONTENT addresses the specific query, not just
check score numbers.

## Test Matrix

| # | Query | Type | Expected Behavior | Result |
|---|---|---|---|---|
| 1 | `XFetch _shouldRecompute formula beta parameter` | Known, precise technical | Signet answers directly | ✅ PASS |
| 2 | `user rule about git commit and push authorization` | Known, user constraint | Signet answers directly | ✅ PASS |
| 3 | `UML-MCP installation diagramming capabilities` | Known, tool discovery | Signet answers directly | ✅ PASS |
| 4 | `Redis Sentinel failover configuration for matecat production` | Unknown, high-score noise | Fallback + warning | ✅ PASS |
| 5 | Store: fermat-mcp path change fact | Store protocol | Stored, embedded, entities linked | ✅ PASS |
| 6 | `fermat-mcp path change PycharmProjects to tools` | Round-trip retrieval | Found via entity graph | ✅ PASS |
| 7 | `signet-first skill testing traversal score inflation bug` | Cross-session recall | Memory from previous session found | ✅ PASS |
| 8 | `react useState hook for dark mode toggle component` | Unrelated domain, keyword overlap | Fallback + warning | ✅ PASS |

## Detailed Results

### Test 1 — Known precise technical query

**Query:** `XFetch _shouldRecompute formula beta parameter`
**Top result score:** 140.67 (traversal)
**Relevant results:** 3 — contained exact formula (`shouldRecompute = now >= storedAt + TTL - delta * beta * |log(rand())|`), XFETCH_BETA = 1.0, XFetchEnvelope class details, constants.
**Verdict:** Signet answered. No fallback needed.

### Test 2 — User constraint recall

**Query:** `user rule about git commit and push authorization`
**Top result score:** 145.76 (traversal)
**Relevant results:** 2 — `bb1a204d` listed all 21 user constraints including rule #3 ("Do NOT push without explicit user authorization — commit and push are two separate gates") and rule #4 (show-message-wait-authorize pattern).
**Verdict:** Signet answered. No fallback needed.

### Test 3 — Tool/infrastructure discovery

**Query:** `UML-MCP installation diagramming capabilities`
**Top result score:** 161.36 (traversal)
**Relevant results:** 2 — `d6275457` ("Installed UML-MCP at ~/tools/uml-mcp — 30+ diagram types via Kroki/PlantUML/Mermaid/D2"), `bf754798` ("UML-MCP at ~/tools/uml-mcp (Python 3.12, uv sync)").
**Verdict:** Signet answered. No fallback needed.

### Test 4 — Unknown topic with high-score noise

**Query:** `Redis Sentinel failover configuration for matecat production`
**Top result score:** 121.13 (traversal)
**Relevant results:** 0 — All high-scoring results were about Redis cache invalidation strategies (HSET/HDEL/DEL), NOT Sentinel, failover, or production deployment. Scores inflated by entity match on "Redis" and "Matecat".
**Verdict:** Fallback triggered. Warning printed:
```
⚠️ SIGNET-FIRST FALLBACK: Signet returned insufficient results for
"Redis Sentinel failover configuration for matecat production".
Falling back to markdown files.
```

### Test 5 — Store protocol

**Action:** Stored fermat-mcp path change as fact with importance 0.6
**Result:** Memory `842fb643` created, embedded=true, entities_linked=4, tags applied.
**Verdict:** Store protocol works.

### Test 6 — Round-trip retrieval of just-stored memory

**Query:** `fermat-mcp path change PycharmProjects to tools`
**Relevant results:** Knowledge graph entity "Fermat MCP" already showed `events: moved from ~/PycharmProjects/fermat-mcp to ~/tools/fermat-mcp`. Entity linking picked up the move automatically.
**Verdict:** Round-trip confirmed. Knowledge graph integration works.

### Test 7 — Cross-session recall (post-restart)

**Query:** `signet-first skill testing traversal score inflation bug`
**Top result score:** 141.93 (traversal)
**Relevant results:** 1 — `26c8916d` was the exact memory stored in the previous session about the traversal score inflation discovery.
**Verdict:** Cross-session persistence confirmed. Memory survives restart.

### Test 8 — Completely unrelated domain with keyword overlap

**Query:** `react useState hook for dark mode toggle component`
**Top result score:** 105.68 (traversal)
**Relevant results:** 0 — Top result mentioned "React hooks" but for BroadcastChannel context review messaging, NOT useState/dark mode. "React" and "hook" keywords caused false matches.
**Verdict:** Fallback triggered. Warning printed:
```
⚠️ SIGNET-FIRST FALLBACK: Signet returned insufficient results for
"react useState hook for dark mode toggle component".
Falling back to markdown files.
```

## Observations

1. **Traversal scores are not semantic relevance scores.** They reflect entity-graph proximity and importance weighting, not query-answer alignment. A result about "Redis cache invalidation" scores 121 for a "Redis Sentinel failover" query because both share the "Redis" entity.

2. **Keyword overlap causes false confidence.** Test 8 matched "React" and "hook" from context review code, not from the queried React useState pattern.

3. **Knowledge graph entity linking is fast.** Test 6 showed the just-stored memory was already linked to the "Fermat MCP" entity with an `events` aspect within seconds.

4. **Cross-session persistence works cleanly.** Test 7 confirmed that memories stored in one session are immediately retrievable after an OpenCode restart.

5. **The semantic judgment fix is critical.** Without it, tests 4 and 8 would have been false positives (skill would not have triggered fallback).
