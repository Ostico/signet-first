# signet-first

A [Signet](https://github.com/Signet-AI/signetai) skill that forces AI agents to use Signet as their
primary memory system — storing session knowledge in the Signet database and searching it before
falling back to markdown files.

## Quick Start

### OpenCode (Recommended)

Add to `opencode.json`:

```json
{
  "plugin": ["signet-first@git+https://github.com/Ostico/signet-first.git"]
}
```

Restart OpenCode. The plugin auto-injects the memory protocol into every session — the agent
searches Signet before taking any action, guaranteed at the infrastructure level.

### All Platforms (one-liner)

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

### OpenCode Plugin (Recommended)

Add signet-first to the `plugin` array in your `opencode.json`:

```json
{
  "plugin": ["signet-first@git+https://github.com/Ostico/signet-first.git"]
}
```

Restart OpenCode. The plugin:

1. **Auto-injects** the signet-first protocol into every session's first message — the agent
   searches Signet memory before taking any action, enforced at the infrastructure level
2. **Auto-registers** the skill so it appears in `skill list` output

This is the recommended install because it removes the dependency on the agent choosing to
load the skill. The protocol is in context before the agent's first reasoning step.

To pin a specific version:

```json
{
  "plugin": ["signet-first@git+https://github.com/Ostico/signet-first.git#v1.0.0"]
}
```

### Claude Code Official Marketplace

```bash
/plugin marketplace add Ostico/signet-first
/plugin install signet-first@signet-first-dev
```

### Cursor (via Plugin Marketplace)

In Cursor Agent chat:

```text
/add-plugin signet-first
```

Or search for "signet-first" in the plugin marketplace.

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

### One-liner (all platforms)

```bash
curl -sL https://raw.githubusercontent.com/ostico/signet-first/master/install.sh | bash
```

The installer auto-detects your harness, installs Signet + the skill + registers the plugin.
Skips anything already installed.

**Options:**

```bash
curl -sL .../install.sh | HARNESS=claude-code bash   # Force harness
curl -sL .../install.sh | SKIP_SIGNET=1 bash          # Skip Signet
curl -sL .../install.sh | SKILL_ONLY=1 bash            # Just the skill
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

- **Plugin install**: the `signet-first` entry is in your `opencode.json` plugin array and
  you restarted OpenCode
- **Manual install**: the SKILL.md file is in the correct skills directory for your harness
  and you restarted the session

## Scope

**IN scope:** Session knowledge — analysis results, decisions, conclusions, discoveries,
user preferences, codebase patterns, tool evaluations.

**OUT of scope:** Identity files (AGENTS.md, SOUL.md, USER.md), project documentation
(specs, design docs), the Signet daemon's automatic extraction pipeline. This skill
supplements those systems, it doesn't replace them.

## Updating

```bash
# If installed via OpenCode plugin — updates automatically on restart

# If installed via git clone
cd ~/.config/opencode/skills/signet-first && git pull

# If installed via curl (re-download SKILL.md)
curl -sL https://raw.githubusercontent.com/ostico/signet-first/master/install.sh | SKILL_ONLY=1 bash

# If installed via skills CLI
npx -y skills add ostico/signet-first --global --yes --copy
```

Check [CHANGELOG.md](CHANGELOG.md) for what changed between versions.

## Test Suite

4 suites, 30 fixture-based assertions, 0 failures, <1s execution, zero API calls.

```bash
bash tests/run-all.sh
```

## License

MIT
