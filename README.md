# signet-first

A [Signet](https://github.com/Signet-AI/signetai) skill that forces AI agents to use Signet as their
primary memory system — storing session knowledge in the Signet database and searching it before
falling back to markdown files.

## What It Does

**Search before acting** — When the agent needs context from previous work, it searches
memory first (Signet when available, native memory otherwise). Only if no result answers
the query does it fall back to project files.

**Store durable knowledge** — After investigations, decisions, and discoveries, the agent
stores synthesized conclusions in memory for future sessions.

**Session continuity** — Each non-trivial session ends with a structured summary. The next
session searches for it before doing anything else, eliminating cold starts.

**Progressive enhancement** — All three behaviors work with any memory backend. Signet
users get scoped search, typed storage, and knowledge graph traversal. Non-Signet users
get memory discipline through their platform's native system. On platforms with no writable
memory, only the search-before-act discipline (checking project files before assuming)
applies.

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

- **MEMORY.md has a 5000 token hard cap** (configurable in `agent.yaml`, verified in
  `memory-head.ts`). With 20 projects, each gets ~250 tokens — roughly 2-3 memories per
  project. The daemon uses a rolling window: recent entries push older ones out, regardless
  of importance. There is no priority-based truncation — a trivial session note takes the
  same space as a critical architectural decision.

- **No project scoping.** MEMORY.md is global. Working on project A? It still contains
  memories about projects B through T. The Signet database supports a `scope` field per
  memory and queries can filter by it — but MEMORY.md doesn't use this. The agent starts
  every session reading cross-project noise.

- **Token waste on redundant exploration.** Without a search-first protocol, agents default
  to firing background explore/librarian agents for information already in the database.
  Each subagent receives the full prompt + tools + its own context window. In a real-world
  test, an agent fired 3 background agents (~3 minutes, full context each) to research a
  topic where Signet already held ~80% of the answer. A `signet_memory_search` call takes
  less than 2 seconds.

- **Cold start every session.** The agent doesn't know what was accomplished yesterday,
  what decisions were made, or what's still unfinished. Without a handoff mechanism, the
  first 5-10 minutes of every session are wasted re-discovering the project state.

- **Fixed token cost per session.** MEMORY.md + AGENTS.md + IDENTITY.md + SOUL.md +
  USER.md are injected every session start regardless of relevance (~550 tokens empty,
  ~6000-7000 tokens when filled across 20 projects). This is a fixed cost on every turn
  — the agent pays it whether the content is relevant or not.

### What this skill changes

signet-first teaches the agent to query the database directly instead of reading the
MEMORY.md dump — scoped to the current project, filtered by type, ranked by relevance.
Typical result: 500-2000 tokens of exactly what's needed, zero cross-project noise.

It adds three protocols:

- **Search-before-act** — the agent must search Signet before firing any explore/librarian
  agent, reading any file, or executing any command. This eliminates redundant exploration.
- **Session handoff** — each session ends with a structured `daily-log` memory. The next
  session reads it before doing anything else, eliminating cold starts.
- **Pre-action gate** — before running any build/test/deploy command, the agent searches
  Signet for the verified procedure instead of relying on its own recall.

## Installation

Installation differs by platform. The fastest path for all platforms:

### All platforms (one-liner — recommended)

Installs Signet + the skill + registers the plugin. Auto-detects your harness.

```bash
curl -sL https://raw.githubusercontent.com/ostico/signet-first/master/install.sh | bash
```

Options: `HARNESS=opencode|claude-code|codex|cursor|gemini|copilot`, `SKIP_SIGNET=1`, `SKILL_ONLY=1` (pass as env vars).

### Tell your agent

Paste the appropriate snippet into your agent chat. The agent will fetch the platform-specific
install guide and follow it:

**OpenCode:**
```
Install signet-first: fetch https://raw.githubusercontent.com/Ostico/signet-first/refs/heads/master/.opencode/INSTALL.md and follow the instructions.
```

**Claude Code:**
```
Install signet-first: fetch https://raw.githubusercontent.com/Ostico/signet-first/refs/heads/master/.claude-plugin/INSTALL.md and follow the instructions.
```

**Codex:**
```
Install signet-first: fetch https://raw.githubusercontent.com/Ostico/signet-first/refs/heads/master/.codex/INSTALL.md and follow the instructions.
```

**Cursor:**
```
Install signet-first: fetch https://raw.githubusercontent.com/Ostico/signet-first/refs/heads/master/.cursor-plugin/INSTALL.md and follow the instructions.
```

**GitHub Copilot CLI:**
```
Install signet-first: fetch https://raw.githubusercontent.com/Ostico/signet-first/refs/heads/master/.copilot/INSTALL.md and follow the instructions.
```

**Gemini CLI:**
```
Install signet-first: fetch https://raw.githubusercontent.com/Ostico/signet-first/refs/heads/master/.gemini/INSTALL.md and follow the instructions.
```

### OpenCode

**Detailed docs:** [.opencode/INSTALL.md](.opencode/INSTALL.md)

```bash
curl -sL https://raw.githubusercontent.com/ostico/signet-first/master/install.sh | HARNESS=opencode bash
```

Or add the plugin directly to `opencode.json`:
```json
{
  "plugin": ["signet-first@git+https://github.com/Ostico/signet-first.git"]
}
```

### Claude Code

**Detailed docs:** [.claude-plugin/INSTALL.md](.claude-plugin/INSTALL.md)

```bash
curl -sL https://raw.githubusercontent.com/ostico/signet-first/master/install.sh | HARNESS=claude-code bash
```

Then register the plugin (user must type these in Claude Code):
```
/plugin marketplace add Ostico/signet-first
/plugin install signet-first@signet-first-dev
```

### Cursor

**Detailed docs:** [.cursor-plugin/INSTALL.md](.cursor-plugin/INSTALL.md)

```bash
curl -sL https://raw.githubusercontent.com/ostico/signet-first/master/install.sh | HARNESS=cursor bash
```

### Codex

**Detailed docs:** [.codex/INSTALL.md](.codex/INSTALL.md)

```bash
curl -sL https://raw.githubusercontent.com/ostico/signet-first/master/install.sh | HARNESS=codex bash
```

### GitHub Copilot CLI

**Detailed docs:** [.copilot/INSTALL.md](.copilot/INSTALL.md)

```bash
copilot plugin install Ostico/signet-first
```

Or use the full installer:
```bash
curl -sL https://raw.githubusercontent.com/ostico/signet-first/master/install.sh | HARNESS=copilot bash
```

### Gemini CLI

**Detailed docs:** [.gemini/INSTALL.md](.gemini/INSTALL.md)

```bash
gemini extensions install https://github.com/Ostico/signet-first
```

Or use the full installer:
```bash
curl -sL https://raw.githubusercontent.com/ostico/signet-first/master/install.sh | HARNESS=gemini bash
```

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

# Git clone (any platform)
cd <skills-dir>/signet-first && git pull

# Gemini CLI
gemini extensions update signet-first

# Copilot CLI
copilot plugin update signet-first
```

Check [CHANGELOG.md](CHANGELOG.md) for what changed between versions.

## Scope

**IN scope:** Session knowledge — analysis results, decisions, conclusions, discoveries,
user preferences, codebase patterns, tool evaluations.

**OUT of scope:** Identity files (AGENTS.md, SOUL.md, USER.md), project documentation,
the Signet daemon's automatic extraction pipeline.

## Test Suite

5 suites, 48 assertions, zero API calls.

```bash
bash tests/run-all.sh
```

## License

[MIT](LICENSE.md)
