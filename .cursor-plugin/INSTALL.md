# Installing signet-first for Cursor

## Prerequisites

- [Cursor](https://cursor.com) installed
- Git

## Installation

1. **Run the installer:**
   ```bash
   curl -sL https://raw.githubusercontent.com/ostico/signet-first/master/install.sh | HARNESS=cursor bash
   ```

   This installs Signet (if needed) and clones the repository to
   `~/.cursor/skills/signet-first`.

2. **Restart Cursor** to discover the plugin.

3. **Verify:**

   Open Cursor Settings > Rules and check that signet-first appears
   in the loaded plugins/skills list.

## Alternative: Install from Git URL

In Cursor chat, run:

```
/plugin install https://github.com/Ostico/signet-first
```

Note: this installs the plugin but does NOT install Signet. Install Signet separately:
```bash
npm install -g signetai && signet setup
```

## How Cursor discovers the plugin

Cursor reads `.cursor-plugin/plugin.json` from the cloned repository.
The plugin manifest declares hooks and skills that Cursor loads automatically.

## Updating

```bash
cd ~/.cursor/skills/signet-first && git pull
```

Then restart Cursor.

## Uninstalling

```bash
rm -rf ~/.cursor/skills/signet-first
```

## Getting Help

- Issues: https://github.com/Ostico/signet-first/issues
