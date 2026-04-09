# signet-first for OpenCode

signet-first is a plugin for OpenCode that ensures your agent always searches Signet memory before taking any action. This enforces memory-first behavior at the infrastructure level.

## Installation

Add the plugin to your `opencode.json`:

```json
{
  "plugins": [
    "signet-first@git+https://github.com/Ostico/signet-first.git"
  ]
}
```

Then restart OpenCode. The plugin will automatically:
- Inject the memory protocol into your chat message pipeline
- Register the signet-first skill for interactive use

Verify installation by checking that your agent searches Signet before any action.

## Migrating from Manual Installation

If you previously installed signet-first manually (by copying `SKILL.md`):

1. Remove the manual skill copy from `~/.agents/skills/`
2. Add the plugin line to `opencode.json` (see Installation above)
3. Restart OpenCode

The plugin install is cleaner and keeps you automatically updated.

## How It Works

signet-first operates as an OpenCode plugin that injects into the `experimental.chat.messages.transform` hook. This ensures that before the agent processes any user message, it first searches Signet memory and prepends relevant context.

The injection is guarded by the `SIGNET_FIRST_PROTOCOL` marker to prevent duplicate processing. This protocol coexists independently from superpowers' `EXTREMELY_IMPORTANT` protocol — both can be active simultaneously.

## Updating

Updates are automatic on OpenCode restart. To pin to a specific version:

```json
{
  "plugins": [
    "signet-first@git+https://github.com/Ostico/signet-first.git#v1.0.0"
  ]
}
```

Replace `v1.0.0` with your desired version tag.

## Troubleshooting

**Plugin not loading?**
- Check OpenCode logs for errors
- Verify your `opencode.json` syntax is valid
- Ensure the plugin URL is accessible

**Skill not found in skill list?**
- Restart OpenCode to trigger skill registration
- Check that the plugin is listed in `opencode.json`

**Memory bootstrap not appearing?**
- Verify Signet daemon is running
- Check `~/.agents/memory/` directory exists
- Review OpenCode logs for bootstrap injection errors

## Getting Help

For issues or questions, visit: https://github.com/Ostico/signet-first/issues
