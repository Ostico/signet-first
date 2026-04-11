# Installing signet-first for Gemini CLI

## Prerequisites

- [Gemini CLI](https://github.com/google-gemini/gemini-cli) installed
- Git

## Installation

### Option A: Install as extension (recommended)

```bash
gemini extensions install https://github.com/Ostico/signet-first
```

This clones the repository to `~/.gemini/extensions/signet-first` and
registers it as a Gemini CLI extension.

Note: this does NOT install Signet. After installing the extension, install Signet:
```bash
npm install -g signetai && signet setup && signet daemon start
```

### Option B: Full installer (includes Signet)

```bash
curl -sL https://raw.githubusercontent.com/ostico/signet-first/master/install.sh | HARNESS=gemini bash
```

This installs Signet (if needed), clones to `~/.gemini/signet-first`, and
symlinks it to `~/.gemini/extensions/signet-first`.

### Verify

```bash
gemini extensions list
```

signet-first should appear with its version and path.

## How Gemini discovers the extension

Gemini CLI reads `gemini-extension.json` from the extension directory.
The manifest declares the context file (`GEMINI.md`) and skills that
Gemini loads automatically every session.

## Updating

```bash
gemini extensions update signet-first
```

Or update all extensions:
```bash
gemini extensions update --all
```

## Uninstalling

```bash
gemini extensions uninstall signet-first
```

## Getting Help

- Issues: https://github.com/Ostico/signet-first/issues
