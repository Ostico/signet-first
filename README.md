# signet-first

A [Signet](https://github.com/Signet-AI/signetai) skill that forces AI agents to use Signet as their
primary memory system — storing session knowledge in the Signet database and searching it before
falling back to markdown files.

## Quick Start

One command installs Signet and the skill:

```bash
curl -sL https://raw.githubusercontent.com/ostico/signet-first/master/install.sh | bash
```

Already have Signet? Install just the skill:

```bash
curl -sL https://raw.githubusercontent.com/ostico/signet-first/master/install.sh | SKILL_ONLY=1 bash
```

Then restart your agent session.

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

Signet's SQLite database with knowledge graph entities, FTS5 keyword search, and structured
metadata is a better memory backend than flat markdown files. But agents default to reading
MEMORY.md and other markdown files because that's what gets loaded into context at session start.

This skill inverts the priority: Signet database first, markdown files as fallback only. Each
fallback warning makes gaps visible so you can track how often the agent still needs files.

## Requirements

- [Signet](https://github.com/Signet-AI/signetai) installed and running (`signet status` should show healthy)
- A Signet-compatible harness: [OpenCode](https://opencode.ai), Claude Code, or Codex

> No embedding provider required. The skill's keyword-rich queries with type/scope filters
> work fully with Signet's knowledge graph traversal + FTS5 keyword search.

> **New to Signet?** The [Quick Start](#quick-start) one-liner handles all of this.
> For step-by-step details, see [SETUP.md](SETUP.md).

## Installation

### One-liner (installs everything)

```bash
curl -sL https://raw.githubusercontent.com/ostico/signet-first/master/install.sh | bash
```

The installer auto-detects your harness (OpenCode, Claude Code, Codex) and installs
Signet + the skill. Skips anything already installed.

**Options:**

```bash
# Force a specific harness
curl -sL .../install.sh | HARNESS=claude-code bash

# Skip Signet (you already have it)
curl -sL .../install.sh | SKIP_SIGNET=1 bash

# Just the skill, nothing else
curl -sL .../install.sh | SKILL_ONLY=1 bash
```

### Alternative: Skills CLI

```bash
npx -y skills add ostico/signet-first --global --yes --copy
```

### Alternative: Manual copy

```bash
# OpenCode
mkdir -p ~/.config/opencode/skills/signet-first
curl -sL https://raw.githubusercontent.com/ostico/signet-first/master/SKILL.md \
  -o ~/.config/opencode/skills/signet-first/SKILL.md

# Claude Code
mkdir -p ~/.claude/skills/signet-first
curl -sL https://raw.githubusercontent.com/ostico/signet-first/master/SKILL.md \
  -o ~/.claude/skills/signet-first/SKILL.md

# Codex
mkdir -p ~/.agents/skills/signet-first
curl -sL https://raw.githubusercontent.com/ostico/signet-first/master/SKILL.md \
  -o ~/.agents/skills/signet-first/SKILL.md
```

### Alternative: Agent self-install

Ask your agent:

> Install the signet-first skill from `https://github.com/ostico/signet-first`

## Verification

After installation, ask your agent a question about something from a previous session. You should
see one of two behaviors:

1. **Signet answers** — The agent uses `signet_memory_search` and finds the answer without
   touching any markdown files.

2. **Fallback with warning** — The agent prints the `⚠️ SIGNET-FIRST FALLBACK` warning,
   reads the markdown file, and then stores the result in Signet for next time.

If the agent reads MEMORY.md or AGENTS.md *without* searching Signet first and *without*
printing a fallback warning, the skill is not loaded. Check that:

- The SKILL.md file is in the correct skills directory for your harness
- You restarted the session after installation
- Your harness loads skills from that directory

## Scope

**IN scope:** Session knowledge — analysis results, decisions, conclusions, discoveries,
user preferences, codebase patterns, tool evaluations.

**OUT of scope:** Identity files (AGENTS.md, SOUL.md, USER.md), project documentation
(specs, design docs), the Signet daemon's automatic extraction pipeline. This skill
supplements those systems, it doesn't replace them.

## Updating

```bash
# If installed via git clone
cd ~/.config/opencode/skills/signet-first && git pull

# If installed via curl (re-download SKILL.md)
curl -sL https://raw.githubusercontent.com/ostico/signet-first/master/install.sh | SKILL_ONLY=1 bash

# If installed via skills CLI
npx -y skills add ostico/signet-first --global --yes --copy
```

Check [CHANGELOG.md](CHANGELOG.md) for what changed between versions.

## Test Results

See [TEST-RESULTS.md](TEST-RESULTS.md) — 8/8 tests passed across session restart boundary.

Key finding: Signet's traversal engine inflates scores for broad entity matches. The skill
uses semantic relevance judgment instead of score thresholds to avoid false positives.

## License

MIT
