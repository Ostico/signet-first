# Installing signet-first for OpenCode

## Prerequisites

- [OpenCode.ai](https://opencode.ai) installed
- [Signet](https://github.com/Signet-AI/signetai) installed and running (`signet status` should show healthy)

## Installation (Plugin — Recommended)

Add signet-first to the `plugin` array in your `opencode.json` (global or project-level):

```json
{
  "plugin": ["signet-first@git+https://github.com/Ostico/signet-first.git"]
}
```

Restart OpenCode. The plugin auto-injects the signet-first memory protocol into every session and registers the skill for discovery.

### What the plugin does

1. **Auto-injects** the signet-first protocol into the first message of every session — the agent searches Signet memory before taking any action, guaranteed at the infrastructure level
2. **Auto-registers** the skill so it appears in `skill list` output

### Verify

Start a new session and ask something you discussed in a previous session. The agent should search Signet memory first, before firing background agents or reading files.

## Installation (Skill Only — Manual)

If you only want the skill without auto-injection:

```bash
mkdir -p ~/.config/opencode/skills/signet-first
curl -sL https://raw.githubusercontent.com/Ostico/signet-first/master/SKILL.md \
  -o ~/.config/opencode/skills/signet-first/SKILL.md
```

With manual install, the agent must choose to load the skill each session. The plugin install removes this dependency.

## Migrating from manual install to plugin

If you previously installed signet-first as a manual skill:

```bash
# Remove the manual copy (the plugin handles everything)
rm -rf ~/.config/opencode/skills/signet-first
```

Then add the plugin line to `opencode.json` as shown above.

## Updating

The plugin updates automatically when you restart OpenCode.

To pin a specific version:

```json
{
  "plugin": ["signet-first@git+https://github.com/Ostico/signet-first.git#v1.0.0"]
}
```

## Troubleshooting

### Plugin not loading

1. Check logs: `opencode run --print-logs "hello" 2>&1 | grep -i signet-first`
2. Verify the plugin line in your `opencode.json`
3. Ensure Signet daemon is running: `signet status`

### Agent not searching memory first

If the agent skips Signet and goes straight to file reads or background agents, verify the plugin is loaded by checking for `SIGNET_FIRST_PROTOCOL` in the session's first message context.

## Getting Help

- Issues: https://github.com/Ostico/signet-first/issues
