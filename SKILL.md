---
name: signet-first
description: "Memory-first protocol for AI coding agents. Search memory before acting, store durable conclusions, maintain session continuity. Uses Signet when available, degrades to native memory systems."
---

# Memory-First Protocol

If `signet_memory_search` is available, use Signet as the memory backend. Otherwise, fall back to the platform's native memory system. The rules below apply regardless of which backend is active.

**Preferred tool names (Signet):** `signet_memory_search`, `signet_memory_store`, `signet_memory_modify`

**Fallback by platform:**
- **Claude Code** — `MEMORY.md` + auto memory
- **OpenCode** — `AGENTS.md` + instruction files
- **Other platforms** — use the platform's memory mechanism if available
- **No writable memory** — only Rules 1-2 apply (search project files for context)

## Rules

Each rule below applies unless a skip clause says otherwise. Skip clauses are exhaustive — if your situation is not listed, the rule applies.

### Rule 1: Search memory before running commands

Before executing any build, test, lint, deploy, or project-specific command, search memory for the verified procedure and use the stored version exactly.

**Skip for:**
- Single-line edits with no command execution.
- Commands the user provided verbatim in the current message.

### Rule 2: Search memory at session start

Search for recent session summaries and unfinished work before touching files or running commands.

**Skip for:**
- The user immediately gives a specific, self-contained task with full context (e.g., "fix the typo on line 42 of app.py").

**Narrow to daily-log search for:**
- Continuation requests ("keep going with the refactor," "pick up where we left off") — these need targeted `daily-log` lookup, not a full memory search.

### Rule 3: Store conclusions after investigations and decisions

After any multi-step investigation, architecture decision, debugging root-cause analysis, or discovery of a codebase pattern, store a synthesized conclusion in memory.

**Store conclusions, not transcripts.**
- Bad: "User said they want X and I looked at file Y and then checked Z."
- Good: "Project uses read-through caching with XFetch early recomputation in DaoCacheTrait."

When the conclusion is a user-stated hard constraint or critical procedure, pin it with `pinned: true`.

**Skip for:**
- Trivial Q&A (under 3 exchanges).
- Single lookups that surfaced no novel finding.
- Information already in memory (search first).

### Rule 4: Write a session summary before ending non-trivial sessions

Store a `daily-log` memory with: what was accomplished, decisions made, unfinished work, blockers.

**Skip for:**
- Sessions where no investigation, decision, or multi-file exploration occurred (quick question, single lookup, trivial fix).

### Rule 5: Search for duplicates before storing

Before every memory store call, search for existing memories on the same topic. If found and still accurate, do not store. If outdated, update the existing entry (prefer `signet_memory_modify`).

No skip clause. Always applies.

### Rule 6: Inform the user when memory returns no results

When memory search returns no relevant results and you fall back to project files, state in one sentence:

`Memory returned no results for "<query>". Checking project files.`

Do not apologize. Do not retry the same query. Do not treat it as an error.

After retrieving from files, store the result so the gap fills over time.

**Skip for:**
- The search was speculative (you did not expect results and immediately had a fallback plan).

### Rule 7: When memory conflicts with current code, trust the code

Code is the source of truth. Memory records are interpretations frozen at a point in time. Trust what you see now — then update or remove stale memory.

**Exception for decisions and rationale:** If the conflicting memory records a `decision` or `rationale` type, flag the conflict to the user before updating. The code may have diverged intentionally or accidentally — the decision record should not be silently overwritten.

No skip clause. Always applies.

### Rule 8: Use the correct memory type

Use `procedural` for commands, `decision` for choices, `preference` for user habits, `rationale` for the "why" behind decisions. Do not default everything to `fact`. See the Memory Types reference table below.

No skip clause. Always applies.

### Search Workflow

Applies to Rules 1, 2, and 5.

1. **Search:** `signet_memory_search(query, type, limit)` or native recall.
2. **Judge results:** High score does not mean relevant. Does the CONTENT answer your specific question?
3. **If answered**, use the result. Stop.
4. **If not answered**, refine: add a type filter, use more specific keywords. Try up to twice.
5. **If still not answered**, fall back to project files (Rule 6 applies).

## Judgment Guide

These principles guide behavior in ambiguous cases where no rule directly applies.

1. **Memory is a shared resource.** Store for your future self and other agents, not just the current task. A well-typed, well-scoped memory helps anyone working on this project next week.
2. **Prefer precision over completeness.** One accurate, well-typed memory is worth more than five vague ones. If you cannot synthesize a clear conclusion, do not store noise.
3. **Let knowledge decay naturally.** Not everything needs to be permanent. Pin only what is truly stable (hard constraints, verified procedures). Let discoveries, session events, and exploratory findings decay — they will be refreshed if they are still relevant.

## Reference: Memory Types

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

Use the most specific type that fits. Default to `fact` only when nothing else applies.

## Reference: Importance, Pinning, Scope

### Importance Guide

- **1.0** — User-stated hard constraint, critical procedure, pinned knowledge
- **0.7-0.9** — Architecture decision, significant finding
- **0.4-0.6** — Useful pattern, minor preference
- **0.1-0.3** — Trivia, ephemeral context

### Pinning

Memories decay at `0.95^days` by default. Some knowledge must never decay:

- User-stated hard constraints (commit rules, test commands, coding standards)
- Critical project procedures (deploy steps, release process)
- Identity-level preferences (communication style, tool choices)

For these, add `pinned: true` to the store call. Pinned memories are exempt from decay and rank higher in retrieval.

Do not pin everything. Only pin knowledge that is both critical and stable (unlikely to change). Discoveries, analysis results, and session events should not be pinned — let them decay naturally.

### Scope

Use `scope` to prevent cross-project contamination in search results:

- `scope: "matecat"` — Matecat PHP project knowledge
- `scope: "signet-first"` — signet-first skill/repo knowledge
- `scope: null` (or omit) — global knowledge applicable everywhere

When searching, prefer scoped queries when you know which project you are working in.

## Scope

**IN scope:** Session knowledge — analysis results, decisions, conclusions, discoveries, user preferences, codebase patterns, tool evaluations.

**OUT of scope:** Identity files (AGENTS.md, SOUL.md, USER.md), project documentation, the Signet daemon's automatic extraction pipeline.
