# Forks

A native macOS app for managing AI coding agent skills. Install, update, and organize skills for Cursor, Claude Code, Windsurf, Cline, and 25+ other agents.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)

## Features

- **Multi-Agent Support** - Works with 25+ AI coding agents
- **Skill Management** - Install from GitHub repos or local folders
- **Project Management** - Track project-specific skills
- **Update Detection** - Know when skills have updates available
- **Native UI** - Beautiful SwiftUI interface with dark mode

## Installation

### Requirements
- macOS 13.0+
- Node.js (`brew install node`)

### Download
1. Download from [Releases](https://github.com/fxding/forks/releases)
2. Extract and move to Applications
3. Right-click → Open (first launch only)

### Build from Source
```bash
git clone https://github.com/fxding/forks.git
cd forks
open forks.xcodeproj
# Build with ⌘R
```

## Quick Start

1. **Add a source** - Go to Registry → Add Source → Enter a GitHub repo (e.g., `user/skills-repo`)
2. **Install skills** - Select skills → Choose agents → Install
3. **Manage skills** - View installed skills in the Skills tab

## Supported Agents

Cursor, Claude Code, Windsurf, Cline, Antigravity, Goose, Roo Code, and [many more](AGENTS.md).

## License

MIT
