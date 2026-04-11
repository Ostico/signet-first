# Installing signet-first for GitHub Copilot CLI

## Prerequisites

- [GitHub Copilot CLI](https://docs.github.com/copilot/github-copilot-in-the-cli) installed
- Git

## Installation

### Option A: Install from GitHub (recommended)

```bash
copilot plugin install Ostico/signet-first
```

This clones the repository and registers it as a Copilot CLI plugin.

Note: this does NOT install Signet. After installing the plugin, install Signet:
```bash
npm install -g signetai && signet setup && signet daemon start
```

### Option B: Full installer (includes Signet)

```bash
curl -sL https://raw.githubusercontent.com/ostico/signet-first/master/install.sh | HARNESS=copilot bash
```

This installs Signet (if needed), clones to `~/.copilot/skills/signet-first`,
and symlinks it to `~/.copilot/installed-plugins/_direct/signet-first`.

### Verify

```bash
copilot plugin list
```

signet-first should appear in the installed plugins.

## How Copilot discovers the plugin

Copilot CLI reads `plugin.json` from `.plugin/` in the repository root.
The manifest declares skills and hooks that Copilot loads automatically.

## Updating

```bash
copilot plugin update signet-first
```

## Uninstalling

```bash
copilot plugin uninstall signet-first
```

## Getting Help

- Issues: https://github.com/Ostico/signet-first/issues
