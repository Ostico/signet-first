# Signet-First Enforcement Rules
<!-- signet-first-version: 1.1.0 -->

These rules are mandatory. They are enforced by the signet-first plugin and must not be removed.

## 1. Search Signet Before Everything

- ALWAYS call `signet_memory_search` BEFORE reading files, firing agents, or taking any action.
- This includes session start: search for `daily-log` entries to orient, do NOT read MEMORY.md first.
- **Certainty is the trigger, not doubt.** If you think "I already know this," that is EXACTLY when you must search.

## 2. Pre-Action Gate

- Before running ANY build, test, lint, deploy, or project-specific command, search Signet for the verified procedure.
- Use the Signet version exactly. Do not add/remove flags from memory.
- If not found in Signet, check project files (Makefile, package.json, CI config). If still not found, ask the user.
- NEVER skip to execution because you "remember" the command.

## 3. Fallback Warning

When falling back to markdown files because Signet returned insufficient results, you MUST print:

```
SIGNET-FIRST FALLBACK: Signet returned insufficient results for "<query>".
Falling back to markdown files. This may indicate missing memories -- storing results after retrieval.
```

This warning is NOT optional. Every fallback = a visible warning.

## 4. Store Conclusions Immediately

- After any investigation, analysis, decision, debugging finding, or discovery, immediately call `signet_memory_store`.
- Store synthesized conclusions, NOT raw data or transcripts.
- Use the correct memory type (`procedural`, `decision`, `preference`, `fact`, etc.) -- not everything is a `fact`.
- Always search for duplicates before storing. Prefer `signet_memory_modify` over creating contradictory entries.

## 5. Session Lifecycle

- **Start**: Search Signet for `daily-log` and recent session summaries before touching files.
- **End**: Store a `daily-log` summary of what was accomplished, decisions made, and unfinished work.

---
<!-- Do not edit above this line -- managed by signet-first plugin -->
<!-- Add your project-specific rules below -->
