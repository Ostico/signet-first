# signet-first

A [Signet](https://github.com/signetai/signet) skill that forces AI agents to use Signet as their
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

Signet's SQLite database with vector embeddings, knowledge graph entities, and hybrid search is
a better memory backend than flat markdown files. But agents default to reading MEMORY.md and
other markdown files because that's what gets loaded into context at session start.

This skill inverts the priority: Signet database first, markdown files as fallback only. Each
fallback warning makes gaps visible so you can track how often the agent still needs files.

## Requirements

- [Signet](https://github.com/signetai/signet) installed and running (`signet status` should show healthy)
- An embedding provider configured (Ollama with `nomic-embed-text`, or OpenAI)
- A Signet-compatible harness: [OpenCode](https://opencode.ai), Claude Code, or Codex

> **New to Signet?** See [SETUP.md](SETUP.md) for a complete installation guide covering
> Signet, Ollama, and nomic-embed-text from scratch. An AI agent can follow it autonomously.

## Installation

### Option A — Manual (any harness)

Copy `SKILL.md` into your skills directory:

```bash
# For OpenCode
mkdir -p ~/.config/opencode/skills/signet-first
curl -sL https://raw.githubusercontent.com/ostico/signet-first/master/SKILL.md \
  -o ~/.config/opencode/skills/signet-first/SKILL.md

# For Claude Code
mkdir -p ~/.claude/skills/signet-first
curl -sL https://raw.githubusercontent.com/ostico/signet-first/master/SKILL.md \
  -o ~/.claude/skills/signet-first/SKILL.md

# For Codex / other harnesses using ~/.agents/skills/
mkdir -p ~/.agents/skills/signet-first
curl -sL https://raw.githubusercontent.com/ostico/signet-first/master/SKILL.md \
  -o ~/.agents/skills/signet-first/SKILL.md
```

Restart your agent session. The skill activates automatically on every session.

### Option B — Skills CLI

```bash
npx skills add ostico/signet-first
```

### Option C — Agent self-install

Ask your agent:

> Install the signet-first skill from `https://github.com/ostico/signet-first`

Or paste these instructions directly:

```
Download SKILL.md from https://raw.githubusercontent.com/ostico/signet-first/master/SKILL.md
and save it to ~/.config/opencode/skills/signet-first/SKILL.md (for OpenCode)
or ~/.claude/skills/signet-first/SKILL.md (for Claude Code).
Then restart the session.
```

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

## Test Results

See [TEST-RESULTS.md](TEST-RESULTS.md) — 8/8 tests passed across session restart boundary.

Key finding: Signet's traversal engine inflates scores for broad entity matches. The skill
uses semantic relevance judgment instead of score thresholds to avoid false positives.

## License

MIT
