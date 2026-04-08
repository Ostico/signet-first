# Changelog

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
