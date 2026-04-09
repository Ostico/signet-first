# Installing signet-first for Codex

## Prerequisites

- Git
- [Signet](https://github.com/Signet-AI/signetai) installed and running

## Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Ostico/signet-first.git ~/.codex/signet-first
   ```

2. **Create the skills symlink:**
   ```bash
   mkdir -p ~/.agents/skills
   ln -s ~/.codex/signet-first ~/.agents/skills/signet-first
   ```

   **Windows (PowerShell):**
   ```powershell
   New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.agents\skills"
   cmd /c mklink /J "$env:USERPROFILE\.agents\skills\signet-first" "$env:USERPROFILE\.codex\signet-first"
   ```

3. **Restart Codex** to discover the skill.

## Verify

```bash
ls -la ~/.agents/skills/signet-first
```

You should see a symlink pointing to your signet-first directory.

## Updating

```bash
cd ~/.codex/signet-first && git pull
```

## Uninstalling

```bash
rm ~/.agents/skills/signet-first
rm -rf ~/.codex/signet-first
```
