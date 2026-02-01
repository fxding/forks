# Forks

A native macOS app for managing AI coding agent skills.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)

![Dashboard](screenshot/dashboard.png)

## Features

- **25+ Agents** — Cursor, Claude Code, Windsurf, Cline, Antigravity, Goose, and more.
- **Install Skills** — From GitHub repos or local folders
- **Registry** — Manage multiple skill sources with update detection
- **Projects** — Install skills globally or per-project
- **Search** — Find skills from skills.sh
- **Auto-Updates** — Built-in app updater via Sparkle

## Install

**Requirements:** macOS 13.0+, Node.js (`brew install node`)

1. Download from [Releases](https://github.com/fxding/forks/releases)
2. Move to Applications
3. If blocked: `xattr -cr /Applications/forks.app`

## Quick Start

1. Go to **Registry** → **Add Source** → Enter a GitHub repo (e.g., `user/skills-repo`)
2. Click the source → Select skills → **Install**
3. Choose agents and confirm

## Build from Source

```bash
git clone https://github.com/fxding/forks.git
cd forks
open forks.xcodeproj
```

## License

MIT
