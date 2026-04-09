# signet-first for Codex

signet-first is a skill for Codex that ensures your agent always searches Signet memory before taking any action. It enforces memory-first behavior through native skill discovery.

## Quick Install

Tell Codex:

```
Fetch and follow instructions from https://raw.githubusercontent.com/Ostico/signet-first/refs/heads/master/.codex/INSTALL.md
```

Codex will download and execute the installation script.

## Manual Installation

If you prefer manual setup:

```bash
# Clone the repository
git clone https://github.com/Ostico/signet-first.git ~/.codex/signet-first

# Create symlink to skills directory
ln -s ~/.codex/signet-first ~/.agents/skills/signet-first
```

**On Windows (PowerShell):**

```powershell
# Clone the repository
git clone https://github.com/Ostico/signet-first.git $env:USERPROFILE\.codex\signet-first

# Create junction (equivalent to symlink)
New-Item -ItemType Junction -Path "$env:USERPROFILE\.agents\skills\signet-first" -Target "$env:USERPROFILE\.codex\signet-first"
```

## How It Works

Codex has native skill discovery that scans `~/.agents/skills/` at startup. The symlink allows Codex to find and load signet-first automatically.

**Important Note:** Unlike OpenCode, Codex has no plugin injection mechanism. The skill is discovered and available, but the agent must actively choose to load or invoke it. For infrastructure-level enforcement (ensuring memory is always searched before any action), you'll need to use OpenCode or Claude Code where plugin injection is available.

## Updating

To update signet-first:

```bash
cd ~/.codex/signet-first
git pull
```

Then restart Codex.

## Uninstalling

```bash
# Remove symlink
rm ~/.agents/skills/signet-first

# Optionally remove cloned repository
rm -rf ~/.codex/signet-first
```

## Troubleshooting

**Skills not showing up in Codex?**
- Verify the symlink exists: `ls -la ~/.agents/skills/signet-first`
- Check that the symlink target is correct
- Restart Codex to trigger skill discovery

**Symlink broken?**
- Recreate it: `ln -s ~/.codex/signet-first ~/.agents/skills/signet-first`
- Verify the target repository still exists

## Getting Help

For issues or questions, visit: https://github.com/Ostico/signet-first/issues
