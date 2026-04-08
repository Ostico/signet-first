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
  type: "<see type guide below>",
  tags: ["comma", "separated", "relevant", "tags"],
  importance: <0.0-1.0>,
  scope: "<project-name or null for global>",
  category: "<optional grouping>"
)
```

### Type Guide (USE THE RIGHT TYPE — all 10 are available)

| Type         | When to Use                                           | Example                                                               |
|--------------|-------------------------------------------------------|-----------------------------------------------------------------------|
| `procedural` | **Commands, workflows, build/test/deploy procedures** | `vendor/bin/phpunit --exclude-group=ExternalServices --no-coverage`   |
| `fact`       | Objective truth about code, architecture, config      | "Signet DB uses SQLite with FTS5 + sqlite-vec in WAL mode"            |
| `decision`   | A choice that was made (by user or agent)             | "Chose read-through caching over write-through for DaoCacheTrait"     |
| `preference` | User preference, style choice, workflow habit         | "User prefers conventional-commit with emoji prefix"                  |
| `rationale`  | The WHY behind a decision                             | "Picked WAL mode because daemon needs concurrent reads during writes" |
| `discovery`  | New finding about codebase, tool, or library          | "FTS5 keyword search covers all skill queries without vector embeddings" |
| `episodic`   | Session-specific event worth remembering              | "Docker validation of install.sh passed all checks on Ubuntu 24.04"   |
| `semantic`   | General knowledge synthesized from multiple sources   | "OSS agent memory systems lack frequency-based auto-promotion"        |
| `daily-log`  | End-of-session summary of what was accomplished       | "Completed cross-platform setup recipe, 5 commits on signet-first"    |
| `system`     | Internal agent configuration or meta-knowledge        | "This project uses PHPUnit 12.4 with ExternalServices group excluded" |

**DEFAULT to `fact` only when no other type fits.** The most common mistake is storing everything as `fact` when
`procedural`, `decision`, or `preference` would enable more precise retrieval.

### Pinning (for non-decaying critical knowledge)

Memories decay at `0.95^days` by default. Some knowledge must NEVER decay:

- **User-stated hard constraints** (commit rules, test commands, coding standards)
- **Critical project procedures** (deploy steps, release process)
- **Identity-level preferences** (communication style, tool choices)

For these, add `pinned: true` to the store call. Pinned memories are exempt from decay and rank higher in retrieval.

```
# Pin critical constraints — they must never decay
signet_memory_store(
  content: "Matecat test command: vendor/bin/phpunit --exclude-group=ExternalServices --no-coverage",
  type: "procedural",
  tags: ["matecat", "phpunit", "test-command"],
  importance: 1.0,
  scope: "matecat",
  pinned: true
)
```

**Do NOT pin everything.** Only pin knowledge that is both critical AND stable (unlikely to change). Discoveries,
analysis results, and session events should NOT be pinned — let them decay naturally.

### Scope (for project isolation)

Use `scope` to prevent cross-project contamination in search results:

- `scope: "matecat"` — Matecat PHP project knowledge
- `scope: "signet-first"` — signet-first skill/repo knowledge
- `scope: null` (or omit) — global knowledge applicable everywhere

When searching, prefer scoped queries when you know which project you're working in.

### Importance Guide

- 1.0 — User-stated hard constraint, critical procedure, pinned knowledge
- 0.7-0.9 — Architecture decision, significant finding
- 0.4-0.6 — Useful pattern, minor preference
- 0.1-0.3 — Trivia, ephemeral context

**Store conclusions, not transcripts.** Bad: "User said they want X and I looked at file Y." Good: "Project uses
read-through caching with XFetch early recomputation in DaoCacheTrait."

### Deduplication (CHECK before every store)

Before storing, search Signet for existing memories on the same topic:

```
1. signet_memory_search(query: "<what you're about to store>", limit: 5)
2. IF a memory already covers this knowledge:
   - Same content, still accurate → SKIP (do not store a duplicate)
   - Content is outdated or wrong → UPDATE via signet_memory_modify (see below)
   - Related but different angle → STORE (the new memory is additive)
3. IF no existing memory → STORE normally
```

Do NOT blindly store after every action. One search before each store prevents the database from filling with
near-identical entries that dilute retrieval quality.

### Memory Update (for stale or incorrect memories)

When you discover that a stored memory is outdated, wrong, or superseded:

```
signet_memory_modify(
  id: "<memory-id from search results>",
  content: "<corrected content>",
  reason: "<why this update is needed>"
)
```

Common triggers for updates:

- User corrects a previously stored preference or constraint
- A command, flag, or procedure has changed
- A decision has been revised or reversed
- A discovery turned out to be incomplete or wrong

**Prefer modify over store-new** when the old memory would conflict. Two contradictory memories on the same topic
degrade retrieval — update the existing one instead.

### When NOT to Store

- Raw file contents (Signet is not a file cache)
- Intermediate exploration steps that led nowhere
- Information already in Signet (search first — see Deduplication above)

## Search Protocol (MANDATORY)

BEFORE acting on any recalled knowledge — commands, constraints, conventions, decisions, procedures — you MUST search
Signet to verify. This applies whether you feel uncertain OR certain. **Certainty is the trigger, not uncertainty.** If
you think "I already know this," that is EXACTLY when you must search.

### Search Order

```
1. signet_memory_search(query: "<what you need>", limit: 10)
   — Add type filter when you know what kind of memory you need:
     type: "procedural" for commands, "decision" for past choices,
     "preference" for user habits, "fact" for architecture knowledge.
   — Include project name in query terms for implicit scope filtering.
2. JUDGE: Do any results actually answer the query?
   - Signet's traversal engine returns high scores for broad entity matches
     (e.g. any memory mentioning "Matecat" scores high for any Matecat query).
   - High score ≠ relevant. YOU must judge whether the CONTENT addresses
     the specific question, not just matches the project name.
3. IF at least 1 result directly answers the query → USE Signet results. STOP.
4. IF no result directly answers the query → FALLBACK to markdown files.
5. IF fallback occurred → WARN user (see below). THEN store what you found.
```

### Search Refinement (when results are noisy)

If the first search returns irrelevant or too many broad matches:

```
1. Re-query with a type filter:  type: "procedural" / "decision" / "preference"
2. Re-query with the project name in query terms for implicit scope filtering
3. Re-query with more specific keywords (e.g. "phpunit matecat" instead of "test command")
4. IF still noisy after 2 refinements → FALLBACK to files (with warning below)
```

Do NOT give up after one noisy search. Do NOT treat a high-score irrelevant result as an answer — Signet's traversal
engine inflates scores for broad entity matches. **You must judge content relevance, not score.**

### Fallback Warning (MANDATORY — NO EXCEPTIONS)

When falling back to markdown files, you MUST present this warning to the user BEFORE continuing:

```
⚠️ SIGNET-FIRST FALLBACK: Signet returned insufficient results for "<query>".
Falling back to markdown files. This may indicate missing memories — storing
results after retrieval.
```

This warning is NOT optional. It is NOT skippable. Every fallback = a visible warning.

After retrieving from markdown files, IMMEDIATELY store the synthesized result in Signet so the fallback won't repeat
for the same knowledge.

### Search Tools (in preference order)

1. `signet_memory_search` — knowledge graph traversal + FTS5 keyword search (preferred)
2. `memory_search` — alias for the above
3. `recall` — alias for the above

All three hit the same Signet database. Use whichever is available.

## Pre-Action Gate (MANDATORY)

Before executing ANY of the following, you MUST search Signet for the correct procedure:

- Build, test, lint, or CI commands
- Deployment or release commands
- Project-specific workflows (commit conventions, branch rules, test flags)
- Tool invocations with project-specific flags or arguments
- Any command you believe you "already know" from earlier in the conversation or a prior session

**The trigger is confidence, not doubt.** False confidence produces wrong commands; Signet holds the verified version.
DO NOT rely on your own recall of commands, flags, or arguments. Signet is the source of truth.

```
BEFORE running a command:
1. SEARCH Signet with type and scope hints:
   signet_memory_search(query: "<command/procedure>", type: "procedural", limit: 5)
   — If you know the project, add scope filtering in your query terms.
2. IF found → use the Signet version exactly
3. IF not found → check project files (Makefile, package.json, README, CI config)
4. IF still not found → ask the user
NEVER skip to execution because you "remember" the command.
```

### Pre-Action Search Examples

```
# Running tests → search for the procedural memory
recall("phpunit test command matecat")
# Found: "vendor/bin/phpunit --exclude-group=ExternalServices --no-coverage"
# → Use EXACTLY that. Do not add/remove flags from memory.

# Committing → search for commit conventions
recall("commit conventions matecat")
# Found: "conventional-commit with emoji, -a flag, show message, wait authorization"
# → Follow the procedure step by step.

# Deploying → search for deploy procedure
recall("deploy production steps")
# Not found → check Makefile, CI config, README → still not found → ASK USER.
```

## Session Start Protocol (MANDATORY)

At the start of every session, orient yourself from Signet before touching files:

```
1. IF working on a known project → search for recent session summaries:
   signet_memory_search(query: "session summary <project>", type: "daily-log", limit: 3)
2. IF continuing previous work → search for unfinished tasks and open decisions:
   signet_memory_search(query: "unfinished <project>", limit: 5)
3. USE the results to understand where the last session left off.
4. Do NOT read MEMORY.md or AGENTS.md for session context unless Signet
   returned nothing relevant (with fallback warning).
```

This replaces the habit of reading markdown files at session start. Signet's daily-log entries are the handoff mechanism
between sessions.

## End-of-Session Protocol (MANDATORY)

Before your final response in any non-trivial session (investigation, implementation, debugging, analysis), create a
`daily-log` summary:

```
signet_memory_store(
  content: "Session summary: <what was accomplished, key decisions made, unfinished work, blockers>",
  type: "daily-log",
  tags: ["session-summary", "<project-name>"],
  importance: 0.6,
  scope: "<project or null for cross-project work>"
)
```

**What to include in the summary:**

- What was accomplished (concrete: files changed, features added, bugs fixed)
- Key decisions made and their rationale
- Unfinished work or next steps
- Blockers or open questions

**When to skip:** Trivial sessions (single question, quick lookup) that produced no lasting knowledge.

This is the handoff mechanism. Without it, the next session starts blind.

## Red Flags — You Are Violating This Skill

- Reading MEMORY.md without searching Signet first
- Completing an investigation without storing conclusions
- Falling back to files without printing the warning
- Storing raw data instead of synthesized conclusions
- Saying "I'll remember this" without actually calling `signet_memory_store`
- Searching markdown files "just to be thorough" after Signet already answered
- Executing a command from memory without searching Signet first
- Thinking "I already know this" or "I remember the command" — that IS the trigger to search
- Storing everything as `type: "fact"` when `procedural`, `decision`, or `preference` fits better
- Storing a user-stated hard constraint without `pinned: true`
- Storing project-specific knowledge without `scope` — it will pollute other project searches
- Searching without type hints when you know the memory category (e.g. searching for a command without
  `type: "procedural"`)
- Storing a memory without checking for duplicates first — always search before store
- Storing a new memory that contradicts an existing one instead of using `signet_memory_modify`
- Ending a non-trivial session without a `daily-log` summary — the next session starts blind
- Starting a session by reading MEMORY.md instead of searching Signet for `daily-log` entries
- Giving up after one noisy search — refine with type filters and specific keywords before falling back

## Scope

**IN scope:** Session knowledge — analysis, decisions, conclusions, discoveries, preferences.

**OUT of scope:** Identity files (AGENTS.md, SOUL.md, USER.md), project documentation (specs, reviews), the daemon's
automatic extraction pipeline. This skill does not replace those systems.
