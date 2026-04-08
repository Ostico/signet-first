# Prerequisites Setup — Signet + Ollama + nomic-embed-text

> **Audience:** AI agents performing automated installation, or humans following along.  
> **Target:** Ubuntu 24.04 LTS (Debian-based Linux) / macOS 14+ (Sonoma/Sequoia)  
> **Windows:** Not officially supported by Signet yet — use WSL (see note below)  
> **Time:** ~10 minutes  
> **Tested:** Signet 0.98.0, Ollama 0.20.3, Node 22, nomic-embed-text 274 MB

This document covers installing everything the `signet-first` skill needs to run.
If you already have Signet and Ollama with nomic-embed-text, skip to [Verification](#verification).

---

## Overview

```
signet-first skill
    │
    ├── Signet daemon (memory storage + search)
    │       └── SQLite + sqlite-vec + FTS5
    │
    └── Ollama (embedding provider)
            └── nomic-embed-text (768-dim vectors)
```

The skill needs two services running:

1. **Signet** — stores and retrieves memories via MCP tools
2. **Ollama + nomic-embed-text** — converts text into vectors for semantic search

---

## Step 1 — Node.js (if not installed)

Signet requires Node.js 20+. We recommend Node 22 via nvm.

```bash
# Install nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash

# Load nvm (Linux: ~/.bashrc, macOS: ~/.zshrc)
source ~/."${SHELL##*/}rc"

# Install Node 22
nvm install 22
nvm use 22
nvm alias default 22
```

**Verify:**

```bash
node --version   # Expected: v22.x.x
npm --version    # Expected: 10.x.x
```

> **Agent note:** If `node --version` returns v20+ or v22+, skip this step entirely.

---

## Step 2 — Install Ollama + nomic-embed-text

Ollama runs embedding models locally. No data leaves your machine.

```bash
# Install Ollama (works on both Linux and macOS — the script detects your OS)
curl -fsSL https://ollama.com/install.sh | sh

# Start the service (if not auto-started)
# Linux:
systemctl --user start ollama 2>/dev/null || ollama serve &
# macOS: the installer launches Ollama.app automatically.
# If it didn't start: open -a Ollama

# Wait for startup
sleep 5

# Pull the embedding model (274 MB download)
ollama pull nomic-embed-text
```

**Verify:**

```bash
ollama --version                                    # Expected: ollama version 0.x.x
ollama list                                         # Should show: nomic-embed-text:latest
curl -s http://localhost:11434/api/tags | grep nomic # Should return JSON with model info
```

> **What's nomic-embed-text?** A 768-dimensional embedding model that converts text into
> vectors for semantic search. "Cache management in PHP" will find memories about "DaoCacheTrait
> architecture" even though the words don't match literally. Runs entirely local — 274 MB on disk,
> minimal RAM footprint.

### Alternative: OpenAI Embeddings

If you prefer cloud-based embeddings instead of local Ollama:

```bash
export OPENAI_API_KEY="sk-your-key-here"
```

Then during Signet setup (Step 3), choose `openai` as the embedding provider and
`text-embedding-3-small` as the model. Skip the Ollama installation above.

---

## Step 3 — Install Signet

The Signet daemon requires [Bun](https://bun.sh) as its runtime:

```bash
curl -fsSL https://bun.sh/install | bash
source ~/."${SHELL##*/}rc"
```

Then install Signet:

```bash
npm install -g signetai
```

**Verify:**

```bash
bun --version      # Expected: 1.x.x
signet --version   # Expected: 0.98.0 (or newer)
which signet       # Expected: ~/.nvm/versions/node/v22.x.x/bin/signet
which signet-mcp   # Expected: same bin directory
```

### Run the Setup Wizard

```bash
signet setup
```

The wizard asks ~12 questions. Recommended answers:

| Question               | Answer                            |
|------------------------|-----------------------------------|
| Agent Name             | `Smart-Agent` (or your own name)  |
| Harnesses              | Select your harness (e.g. **opencode**, **claude-code**) |
| Description            | `Personal AI assistant`           |
| Deployment context     | `local`                           |
| Embedding Provider     | `ollama`                          |
| Embedding Model        | `nomic-embed-text`                |
| Search Balance (alpha) | `0.7` (70% semantic, 30% keyword) |
| Advanced Settings      | Accept defaults                   |
| Import                 | Skip                              |
| Git                    | Yes (recommended)                 |
| Launch Dashboard       | Optional                          |

Or run non-interactively:

```bash
signet setup --non-interactive \
  --name "Smart-Agent" \
  --description "Personal AI assistant" \
  --harness opencode \
  --deployment-type local \
  --embedding-provider ollama \
  --embedding-model nomic-embed-text
```

> **Agent note:** Replace `--harness opencode` with `claude-code` or `codex` as appropriate.

### Sync the Harness Plugin

After setup, always run:

```bash
signet sync
```

This writes the session plugin to your harness's plugin directory (e.g. `signet.mjs` for
OpenCode) and registers lifecycle hooks. You should see:

```
✓ hooks re-registered for opencode
```

**Verify the plugin:**

```bash
# For OpenCode
ls -la ~/.config/opencode/plugins/signet.mjs

# For Claude Code — check your harness's plugin location
```

If the plugin file is missing, run `signet sync` again. If it still doesn't appear,
run `signet doctor` for diagnostics.

---

## Step 4 — Verify the Memory Pipeline

Check `~/.agents/agent.yaml` and ensure these sections are correct:

```yaml
embedding:
  provider: ollama
  model: nomic-embed-text

memory:
  pipelineV2:
    enabled: true
    extraction:
      provider: opencode                          # or your harness name
      model: anthropic/claude-haiku-4-5-20251001  # cheap model for extraction
    synthesis:
      enabled: true
    graph:
      enabled: true
    reranker:
      enabled: true
    autonomous:
      enabled: true
      maintenanceMode: execute
```

If `embedding.provider` is not `ollama` or `extraction.provider` is wrong, edit the file:

```bash
nano ~/.agents/agent.yaml
# or: vim ~/.agents/agent.yaml
```

After any edit, restart the daemon:

```bash
signet daemon restart
```

---

## Step 5 — Register Signet MCP in Your Harness

The signet-first skill uses Signet's MCP tools (`signet_memory_search`, `signet_memory_store`,
etc.). Your harness must have the Signet MCP server registered.

### OpenCode

Add to `~/.config/opencode/opencode.json`:

```json
{
  "mcp": {
    "signet": {
      "command": ["signet-mcp"],
      "enabled": true
    }
  }
}
```

### Claude Code

Add to your MCP configuration (check Claude Code docs for the exact location):

```json
{
  "mcpServers": {
    "signet": {
      "command": "signet-mcp"
    }
  }
}
```

> **Agent note:** If the harness config already has a `signet` MCP entry, skip this step.

---

## Verification

Run all checks. Every line must pass.

```bash
echo "=== 1. Ollama ==="
ollama --version
ollama list | grep nomic-embed-text && echo "OK: nomic-embed-text installed" || echo "FAIL: run 'ollama pull nomic-embed-text'"

echo ""
echo "=== 2. Signet CLI ==="
signet --version && echo "OK" || echo "FAIL: run 'npm install -g signetai'"

echo ""
echo "=== 3. Signet Daemon ==="
signet status

echo ""
echo "=== 4. Signet MCP ==="
which signet-mcp && echo "OK: signet-mcp found" || echo "FAIL: signet-mcp not in PATH"

echo ""
echo "=== 5. Embeddings ==="
signet embed gaps
# Expected: "0 memories missing embeddings"

echo ""
echo "=== 6. Memory Round-Trip ==="
signet remember "signet-first setup verification test"
sleep 2
signet recall "setup verification" | head -5
echo "(should show the test memory above)"
```

Expected output:

```
=== 1. Ollama ===
ollama version is 0.20.3
OK: nomic-embed-text installed

=== 2. Signet CLI ===
0.98.0
OK

=== 3. Signet Daemon ===
● Daemon running v0.98.0

=== 4. Signet MCP ===
OK: signet-mcp found

=== 5. Embeddings ===
0 memories missing embeddings

=== 6. Memory Round-Trip ===
(your test memory should appear here)
```

---

## After This

Install the signet-first skill itself. See [README.md](README.md) for three installation
methods (manual copy, CLI, or agent self-install).

---

## Troubleshooting

| Problem                            | Solution                                                    |
|------------------------------------|-------------------------------------------------------------|
| `ollama: command not found`        | Re-run `curl -fsSL https://ollama.com/install.sh \| sh`     |
| Ollama not responding on :11434    | Linux: `systemctl --user start ollama` or `ollama serve &`; macOS: `open -a Ollama` |
| `nomic-embed-text` not in list     | `ollama pull nomic-embed-text`                              |
| `signet: command not found`        | `npm install -g signetai` then `source ~/."${SHELL##*/}rc"` |
| Signet daemon not running          | `signet daemon start`                                       |
| `signet.mjs` missing in plugins    | `signet sync` then restart your harness                     |
| Embedding gaps after storing       | `signet embed backfill`                                     |
| `signet-mcp` not found             | Should be installed with `signetai` — check `npm list -g`   |
| Pipeline extraction failing        | Check `~/.agents/agent.yaml` — `extraction.provider` must match your harness |
| Dashboard not loading              | `signet dashboard` or visit `http://localhost:3850`         |

---

## Quick Reference

```bash
# Ollama
ollama list                      # Show installed models
ollama pull nomic-embed-text     # Install/update embedding model
ollama serve                     # Start Ollama (Linux; macOS: open -a Ollama)

# Signet
signet status                    # Check daemon health
signet daemon start              # Start the daemon
signet daemon restart            # Restart after config changes
signet sync                      # Re-register harness plugins + hooks
signet doctor                    # Full diagnostics
signet embed gaps                # Check embedding coverage
signet embed backfill            # Re-embed memories with gaps
signet dashboard                 # Web UI at localhost:3850
signet remember "some fact"      # Store a memory from CLI
signet recall "search query"     # Search memories from CLI
```

---

---

## Windows (Not Officially Supported)

> ⚠️ **Untested.** Signet does not officially support native Windows yet (Windows support is
> planned). The recommended approach for Windows users is **WSL** (Windows Subsystem for Linux),
> where all Linux instructions above work as-is.

If you want to try native Windows without WSL, the individual tools have Windows installers:

| Tool      | Native Windows Install                                              |
|-----------|---------------------------------------------------------------------|
| Node.js   | Use [nvm-windows](https://github.com/coreybutler/nvm-windows) (separate project from nvm) |
| Ollama    | PowerShell: `irm https://ollama.com/install.ps1 \| iex` or download `OllamaSetup.exe` |
| Bun       | PowerShell: `powershell -c "irm bun.sh/install.ps1\|iex"`          |
| Signet    | **Not supported on native Windows** — use WSL                       |

---

*Extracted from a running Ubuntu 24.04 workstation with Signet 0.98.0, Ollama 0.20.3, and
nomic-embed-text. macOS compatibility verified from official docs. All commands, paths, and
configurations verified against a live installation.*
