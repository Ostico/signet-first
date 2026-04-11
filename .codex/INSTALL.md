# Installing signet-first for Codex

## Prerequisites

- Git
- [Codex](https://github.com/openai/codex) installed

## Installation

1. **Run the installer:**
   ```bash
   curl -sL https://raw.githubusercontent.com/ostico/signet-first/master/install.sh | HARNESS=codex bash
   ```

   This installs Signet (if needed), clones the repository, and creates
   a symlink at `~/.agents/skills/signet-first`.

2. **Restart Codex** to discover the skill.

3. **Verify:**
   ```bash
   ls -la ~/.agents/skills/signet-first
   ```
   You should see a symlink pointing to the signet-first directory.

## Alternative: Manual Installation (Signet already installed)

```bash
git clone https://github.com/Ostico/signet-first.git ~/.codex/signet-first
mkdir -p ~/.agents/skills
ln -s ~/.codex/signet-first ~/.agents/skills/signet-first
```

**Windows (PowerShell):**
```powershell
git clone https://github.com/Ostico/signet-first.git "$env:USERPROFILE\.codex\signet-first"
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.agents\skills"
cmd /c mklink /J "$env:USERPROFILE\.agents\skills\signet-first" "$env:USERPROFILE\.codex\signet-first"
```

Note: manual installation does NOT install Signet. Install it separately.

## Updating

```bash
cd ~/.codex/signet-first && git pull
```

## Uninstalling

```bash
rm ~/.agents/skills/signet-first
rm -rf ~/.codex/signet-first
```

## Getting Help

- Issues: https://github.com/Ostico/signet-first/issues
