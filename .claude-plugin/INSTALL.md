# Installing signet-first for Claude Code

## Prerequisites

- Git
- [Signet](https://github.com/Signet-AI/signetai) installed and running (`signet status` should show healthy)

## Installation

1. **Run the installer:**
   ```bash
   curl -sL https://raw.githubusercontent.com/ostico/signet-first/master/install.sh | HARNESS=claude-code bash
   ```

   This clones the repository to `~/.claude/skills/signet-first` and installs
   Signet if needed.

2. **Tell the user to register the plugin:**

   The agent cannot execute `/plugin` slash commands — only the user can type
   them. After running the installer, tell the user:

   > Run these two commands in your Claude Code prompt:
   >
   > ```
   > /plugin marketplace add Ostico/signet-first
   > /plugin install signet-first@signet-first-dev
   > ```
   >
   > Then restart Claude Code.

3. **Verify:**

   Start a new session and ask something discussed in a previous session.
   The agent should search Signet memory first, before firing background
   agents or reading files.

## Alternative: Skill-Only (no plugin auto-injection)

If plugin registration is not possible, the installer still places SKILL.md
at `~/.claude/skills/signet-first/SKILL.md`. The skill will be discoverable
but the agent must choose to load it each session — there is no automatic
injection without plugin registration.

## Updating

```bash
cd ~/.claude/skills/signet-first && git pull
```

Then re-run the plugin install to pick up any hook changes:
```
/plugin install signet-first@signet-first-dev
```

## Uninstalling

```
/plugin uninstall signet-first
```

Then optionally:
```bash
rm -rf ~/.claude/skills/signet-first
```
