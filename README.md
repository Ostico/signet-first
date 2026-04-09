# signet-first

A [Signet](https://github.com/Signet-AI/signetai) skill that forces AI agents to use Signet as their
primary memory system — storing session knowledge in the Signet database and searching it before
falling back to markdown files.

## What It Does

**Store protocol** — After every investigation, analysis, decision, or discovery, the agent
immediately stores a synthesized conclusion in Signet via `signet_memory_store`.

**Search protocol** — When the agent needs context from previous work, it searches Signet first.
Only if no result directly answers the query does it fall back to markdown files.

**Fallback warning** — Every fallback to markdown files triggers a mandatory visible warning:
```
⚠️ SIGNET-FIRST FALLBACK: Signet returned insufficient results for "<query>".
Falling back to markdown files. This may indicate missing memories — storing
results after retrieval.
```

**Self-healing** — After any fallback, the agent stores the retrieved information in Signet so
the same fallback won't repeat.

## Why

### The problem: coding agents have no memory

AI coding agents (Claude Code, OpenCode, Cursor, Codex) have no built-in cross-session memory.
Each session starts blank — the agent reads a static instruction file (`CLAUDE.md`,
`AGENTS.md`, `.cursorrules`) and nothing else. Yesterday's decisions, last week's architecture
analysis, the test command you corrected three sessions ago — all gone.

### Signet adds memory, but consumption is a bottleneck

[Signet](https://github.com/Signet-AI/signetai) solves the storage side: a SQLite database
with knowledge graph entities, FTS5 keyword search, 10 typed memory categories, and structured
metadata. But the default way agents consume this memory is through MEMORY.md — a flat
markdown file the daemon auto-generates and injects into the system prompt every session.

This breaks at scale:

- **5000 token hard cap.** With 20 projects, each gets ~250 tokens — roughly 2-3 memories
  per project. The daemon uses a rolling window: recent entries push older ones out, even if
  the older ones matter more for the current project.
- **No project scoping.** Working on project A? MEMORY.md still contains memories about
  projects B through T. The agent starts every session reading cross-project noise.
- **Token waste on redundant exploration.** Without a search-first protocol, agents fire
  background explore/librarian agents for information already in the database. These agents
  take minutes and consume full context windows. A Signet query takes <2 seconds.
- **Cold start every session.** Without a handoff mechanism, the agent doesn't know what was
  accomplished yesterday, what decisions were made, or what's still unfinished.

### What this skill changes

signet-first teaches the agent to query the database directly instead of reading the
MEMORY.md dump — scoped to the current project, filtered by type, ranked by relevance.
Typical result: 500-2000 tokens of exactly what's needed, zero cross-project noise.

It also adds a session handoff protocol: each session ends with a structured `daily-log`
memory, and the next session reads it before doing anything else.

## Installation

**Note:** Installation differs by platform. Claude Code and Cursor have built-in plugin
marketplaces. Codex and OpenCode can be told to self-install.

### Claude Code

```bash
/plugin marketplace add Ostico/signet-first
/plugin install signet-first@signet-first-dev
```

### Cursor

In Cursor Agent chat:

```text
/add-plugin signet-first
```

Or search for "signet-first" in the plugin marketplace.

### OpenCode

Tell OpenCode:

```
Fetch and follow instructions from https://raw.githubusercontent.com/Ostico/signet-first/refs/heads/master/.opencode/INSTALL.md
```

**Detailed docs:** [docs/README.opencode.md](docs/README.opencode.md)

### Codex

Tell Codex:

```
Fetch and follow instructions from https://raw.githubusercontent.com/Ostico/signet-first/refs/heads/master/.codex/INSTALL.md
```

**Detailed docs:** [docs/README.codex.md](docs/README.codex.md)

### GitHub Copilot CLI

```bash
copilot plugin marketplace add Ostico/signet-first
copilot plugin install signet-first@signet-first-dev
```

### Gemini CLI

```bash
gemini extensions install https://github.com/Ostico/signet-first
```

### All platforms (one-liner)

Installs Signet + the skill + registers the plugin. Auto-detects your harness.

```bash
curl -sL https://raw.githubusercontent.com/ostico/signet-first/master/install.sh | bash
```

Options: `HARNESS=claude-code`, `SKIP_SIGNET=1`, `SKILL_ONLY=1` (pass as env vars).

### Verify Installation

Start a new session and ask something you discussed in a previous session. The agent should
search Signet memory first, before firing background agents or reading files.

## Requirements

- [Signet](https://github.com/Signet-AI/signetai) installed and running (`signet status` should show healthy)
- One of: [OpenCode](https://opencode.ai), Claude Code, Cursor, Codex, Gemini CLI, or Copilot CLI

No embedding provider required. Signet's knowledge graph traversal + FTS5 keyword search
covers all queries. For Signet setup details, see [SIGNET_SETUP.md](SIGNET_SETUP.md).

## Updating

```bash
# OpenCode plugin — updates automatically on restart

# Git clone
cd ~/.config/opencode/skills/signet-first && git pull

# Gemini CLI
gemini extensions update signet-first
```

Check [CHANGELOG.md](CHANGELOG.md) for what changed between versions.

## Scope

**IN scope:** Session knowledge — analysis results, decisions, conclusions, discoveries,
user preferences, codebase patterns, tool evaluations.

**OUT of scope:** Identity files (AGENTS.md, SOUL.md, USER.md), project documentation,
the Signet daemon's automatic extraction pipeline.

## Test Suite

5 suites, 43 assertions, zero API calls.

```bash
bash tests/run-all.sh
```

## License

MIT
