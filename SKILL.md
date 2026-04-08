---
name: signet-first
description: Use on EVERY session — forces Signet as primary memory system. Store all session knowledge (analysis, conclusions, decisions, investigation results) in Signet immediately. Search Signet before reading markdown files. Triggers on any work session, investigation, analysis, debugging, implementation, or research task.
---

# Signet-First Memory Protocol

Signet is the primary memory system. Markdown files are fallback only.

## Store Protocol (MANDATORY)

After completing ANY of the following, IMMEDIATELY call `signet_memory_store`:

- Investigation or exploration result
- Analysis conclusion
- Architecture or design decision
- Debugging finding (root cause, fix applied)
- User preference or constraint discovered in conversation
- Codebase pattern or convention identified
- Tool/library discovery or evaluation
- Any synthesized knowledge that would be useful in a future session

### Store Format

```
signet_memory_store(
  content: "<synthesized conclusion — NOT raw data>",
  type: "<fact|decision|preference|discovery|analysis>",
  tags: "comma,separated,relevant,tags",
  importance: <0.0-1.0>
)
```

**Importance guide:**
- 1.0 — User-stated hard constraint, critical decision
- 0.7-0.9 — Architecture decision, significant finding
- 0.4-0.6 — Useful pattern, minor preference
- 0.1-0.3 — Trivia, ephemeral context

**Store conclusions, not transcripts.** Bad: "User said they want X and I looked at file Y." Good: "Project uses read-through caching with XFetch early recomputation in DaoCacheTrait."

### When NOT to Store

- Raw file contents (Signet is not a file cache)
- Intermediate exploration steps that led nowhere
- Information already in Signet (search first to avoid duplicates)

## Search Protocol (MANDATORY)

When you need context from previous work — prior decisions, past analysis, user preferences, codebase patterns, tool evaluations — you MUST search Signet FIRST.

### Search Order

```
1. signet_memory_search(query: "<what you need>", limit: 10)
2. JUDGE: Do any results actually answer the query?
   - Signet's traversal engine returns high scores for broad entity matches
     (e.g. any memory mentioning "Matecat" scores high for any Matecat query).
   - High score ≠ relevant. YOU must judge whether the CONTENT addresses
     the specific question, not just matches the project name.
3. IF at least 1 result directly answers the query → USE Signet results. STOP.
4. IF no result directly answers the query → FALLBACK to markdown files.
5. IF fallback occurred → WARN user (see below). THEN store what you found.
```

### Fallback Warning (MANDATORY — NO EXCEPTIONS)

When falling back to markdown files, you MUST present this warning to the user BEFORE continuing:

```
⚠️ SIGNET-FIRST FALLBACK: Signet returned insufficient results for "<query>".
Falling back to markdown files. This may indicate missing memories — storing
results after retrieval.
```

This warning is NOT optional. It is NOT skippable. Every fallback = a visible warning.

After retrieving from markdown files, IMMEDIATELY store the synthesized result in Signet so the fallback won't repeat for the same knowledge.

### Search Tools (in preference order)

1. `signet_memory_search` — hybrid vector + keyword search (preferred)
2. `memory_search` — alias for the above
3. `recall` — alias for the above

All three hit the same Signet database. Use whichever is available.

## Red Flags — You Are Violating This Skill

- Reading MEMORY.md without searching Signet first
- Completing an investigation without storing conclusions
- Falling back to files without printing the warning
- Storing raw data instead of synthesized conclusions
- Saying "I'll remember this" without actually calling `signet_memory_store`
- Searching markdown files "just to be thorough" after Signet already answered

## Scope

**IN scope:** Session knowledge — analysis, decisions, conclusions, discoveries, preferences.

**OUT of scope:** Identity files (AGENTS.md, SOUL.md, USER.md), project documentation (specs, reviews), the daemon's automatic extraction pipeline. This skill does not replace those systems.
