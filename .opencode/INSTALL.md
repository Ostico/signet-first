# Installing signet-first for OpenCode

## Prerequisites

- [OpenCode.ai](https://opencode.ai) installed
- Git

## Installation

1. **Run the installer:**
   ```bash
   curl -sL https://raw.githubusercontent.com/ostico/signet-first/master/install.sh | HARNESS=opencode bash
   ```

   This installs Signet (if needed), clones the repository to `~/.config/opencode/skills/signet-first`,
   and registers the plugin in `opencode.json`.

2. **Restart OpenCode** to activate the plugin.

3. **Verify:**

   Start a new session and ask something discussed in a previous session.
   The agent should search Signet memory first, before firing background
   agents or reading files.

## What the installer does

1. Checks Node.js ≥ 20 (needed for Signet)
2. Installs Bun + Signet via `npm install -g signetai`
3. Runs `signet setup` (non-interactive)
4. Clones signet-first to `~/.config/opencode/skills/signet-first`
5. Adds `signet-first` to the `plugin` array in `opencode.json`

## Alternative: Plugin Only (Signet already installed)

If Signet is already installed and running:

```bash
curl -sL https://raw.githubusercontent.com/ostico/signet-first/master/install.sh | HARNESS=opencode SKIP_SIGNET=1 bash
```

## Alternative: Manual Plugin Registration

If you prefer not to run the installer, add this to your `opencode.json`:

```json
{
  "plugin": ["signet-first@git+https://github.com/Ostico/signet-first.git"]
}
```

Note: this does NOT install Signet. You must install it separately.

## Updating

The plugin updates automatically when you restart OpenCode.

## Troubleshooting

### Plugin not loading

1. Check logs: `opencode run --print-logs "hello" 2>&1 | grep -i signet-first`
2. Verify the plugin line in your `opencode.json`
3. Ensure Signet daemon is running: `signet status`

### Agent not searching memory first

Verify the plugin is loaded by checking for `SIGNET_FIRST_PROTOCOL` in the session's first message context.

## Getting Help

- Issues: https://github.com/Ostico/signet-first/issues
