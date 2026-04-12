# Changelog

## 2.0.3

### Behavioral Changes

- **Rule 2 — Context-aware session start** — Before firing an explicit memory search at session start, the agent now checks whether memory context is already available in the session (injected system prompt, instruction files, or prior tool output). If the available context covers recent summaries and project-relevant notes, the explicit search is skipped. Explicit search is reserved for: continuation requests (daily-log by project scope), project-specific recall not covered by available context, or when no memory context is available. Platform-agnostic — works regardless of how memory context arrives.
- **Rule 4 — Structured session handoff** — Renamed from "session summary" to "structured session handoff." Now specifies a 4-item structure: accomplishments, decisions, unfinished work, blockers. Added skip clause for sessions under 3 exchanges. Platform-agnostic — describes what the agent produces, not what any backend does automatically.
- **Test 5 updated** — Replaced the "MEMORY.md read before recall is a violation" test with a test validating the new Rule 2 semantics: sessions with injected memory context should not fire redundant explicit searches.

## 2.0.2

### Behavioral Changes

- **Rule 3 — Store-before-answer** — Restructured from "store conclusions after investigations" to "store conclusions BEFORE composing your answer." Makes memory storage a prerequisite to responding, not an afterthought. Adds an explicit 4-step sequence: investigate → synthesize → store → answer. Includes a self-interrupt clause: "If you find yourself writing a response that contains a novel conclusion and have not yet stored it — stop, store it, then continue." This addresses the observed failure mode where LLMs optimize for answering the user and skip the storage step when it comes after the response.

## 2.0.1

### Clarifications

- **Rule 6** — Added "memory gaps are normal" framing and explicit anti-over-search guidance (do not retry with minor variations, do not distrust memory after empty results). Addresses behavioral pattern where agents cascade from one empty result into skipping memory entirely.
- **Rule 7** — Replaced "source of truth" language with artifact-vs-commentary mental model ("Code is the artifact. Memory is commentary on the artifact."). Gives agents a reasoning framework for the decision/rationale exception case.

Both changes are clarifications of existing v2.0 rules, not behavioral changes. No test updates required.

## 2.0.0

### Breaking Changes

- **SKILL.md rewritten** — single-layer structure of 8 concrete rules with explicit skip clauses replaces the previous 5 mandatory sections + 17 red flags.
- **Fallback warning changed** — `SIGNET-FIRST FALLBACK: ...` (alarming) → `Memory returned no results for "...". Checking project files.` (informational). Agents or tests checking for the old string need updating.
- **Progressive enhancement** — all rules degrade gracefully for non-Signet users. SKILL.md and templates/CLAUDE.md detect Signet availability and fall back to native memory systems.

### Features

- **Proportional enforcement** — each rule has explicit "Skip for:" clauses. Trivial edits, direct user instructions, and short sessions skip the overhead.
- **Rule 7 decision/rationale exception** — memory conflicts on `decision` or `rationale` types are flagged to the user instead of silently overwritten.
- **Rule 2 narrow clause** — continuation requests trigger targeted daily-log searches instead of full memory searches.
- **templates/CLAUDE.md auto-deployment** — SessionStart hook creates or updates project-level CLAUDE.md, preserving user content below the managed section.
- **Judgment Guide** — 3 principles for ambiguous cases (shared resource, precision over completeness, natural decay).
- Version consistency test ensures templates/CLAUDE.md version matches package.json.

## Unreleased

- Added "Updating" section to README
- Added this CHANGELOG

## 2026-04-08 — Remove Ollama dependency

- Removed Ollama from installer, setup docs, and all references
- Vector search proven unnecessary — knowledge graph traversal + FTS5 keyword search cover all skill patterns
- Simplified install from 4 steps to 3
- Simplified SKILL.md — removed "Embedding Provider" section

## 2026-04-08 — Session lifecycle, dedup, search refinement

- Added session start protocol (search daily-log before reading files)
- Added end-of-session protocol (mandatory daily-log summary)
- Added deduplication check-before-store pattern
- Added memory update via `signet_memory_modify` for stale memories
- Added search refinement guidance (type filters, re-query before fallback)
- Added 5 new red flags
- Test suite: 4 suites, 30 assertions, 0 failures

## 2026-04-08 — Fixture-based test suite

- Rewrote test suite from live-API calls to fixture-based SQLite injection
- Zero API calls, runs in <1s
- Fixed `_SEQ` subshell counter bug with file-based persistence

## 2026-04-07 — Type guide, pinning, scoping

- Added all 10 Signet memory types with usage guide
- Added pinning for non-decaying critical knowledge
- Added project scope for cross-project isolation
- Added pre-action gate to prevent command execution from faulty recall

## 2026-04-07 — Cross-platform support

- macOS compatibility (Homebrew, zshrc, launchd)
- Windows disclaimer (WSL recommended)
- Full end-to-end installer script

## 2026-04-07 — Initial release

- Signet-first memory protocol (store + search + fallback warning)
- Prerequisites setup guide
- One-liner installer
