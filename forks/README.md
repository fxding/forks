# Forks

A beautiful native macOS application for managing skills across 25+ AI coding agents. Discover, install, update, and organize skills for Cursor, Claude Code, Windsurf, Cline, and many more.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-4.0+-green)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

## ✨ Features

### 🎯 Multi-Agent Support
- **25+ supported agents** including Cursor, Claude Code, Windsurf, Cline, Antigravity, and more
- Automatic agent detection on your system
- Install skills globally or per-project
- Manage skills across multiple agents simultaneously

### 📦 Skill Management
- **Browse and install** skills from GitHub repositories
- **Add custom sources** - Local folders or remote Git repositories
- **Update tracking** - Automatic update detection for installed skills
- **Registry management** - Organize your skill sources
- **Bulk operations** - Install, update, or remove skills across multiple agents

### 🗂️ Project Management
- **Track your coding projects** with skill installations
- **Project-level skills** - Install skills specific to individual projects
- **Quick overview** of which skills are used in each project

### 🔍 Smart Discovery
- **Search and filter** available skills
- **Agent-specific filtering** - See which skills work with which agents
- **Source management** - Track skills from multiple repositories

### 🎨 Modern macOS UI
- **Native SwiftUI interface** designed for macOS
- **Dark mode support**
- **Intuitive navigation** with sidebar and tabbed views
- **Real-time updates** and status indicators

## 📥 Installation

### Prerequisites
- macOS 13.0 (Ventura) or later
- Node.js and npm (required for skill installation)
  - Install via [nodejs.org](https://nodejs.org)
  - Or via Homebrew: `brew install node`

### Download
1. Download the latest release from [Releases](https://github.com/fxding/forks/releases)
2. Extract the `.app` file
3. Move to Applications folder
4. Open Forks

### Building from Source
```bash
# Clone the repository
git clone https://github.com/fxding/forks.git
cd forks/forks

# Open in Xcode
open forks.xcodeproj

# Build and run (⌘R)
```

## 🚀 Quick Start

### 1. First Launch
When you first open Forks, it will:
- Detect installed AI coding agents on your system
- Check for Node.js/npm availability
- Set up the local registry at `~/.forks`

### 2. Browse Skills
1. Go to **Registry** tab
2. Click **Add Source** to add a skill repository
3. Enter a GitHub repo (e.g., `user/repo`) or local path
4. Browse available skills from that source

### 3. Install Skills
1. Navigate to **Registry** → Select a source
2. Select skills you want to install
3. Click **Install**
4. Choose target agents (the agents where you want these skills)
5. Choose installation type:
   - **Global**: Available across all projects
   - **Project**: Only for a specific project

### 4. Manage Installed Skills
1. Go to **Skills** tab to see all installed skills
2. Click on a skill to see details
3. View which agents have this skill installed
4. Reinstall, update, or remove as needed

### 5. Manage Projects
1. Go to **Projects** tab
2. Add your coding projects
3. Install project-specific skills
4. Track which skills are used in each project

## 📖 User Guide

### Managing Sources

#### Add a Source
**Registry** → **Add Source** button
- Enter a GitHub repository (e.g., `username/repo`)
- Or select a local folder containing skills
- The source will be added to your registry

#### Delete a Source
**Registry** → Click the red trash icon or right-click → **Delete from App**
- **Local sources**: Removes from registry only, folder on disk remains
- **Remote repos**: Deletes the cloned repository from `~/.forks/repos/`

#### Update a Source
**Registry** → **Check for Updates** button
- Pulls latest changes from remote repositories
- Updates the list of available skills

### Managing Skills

#### Install a Skill
Multiple ways to install:
1. From **Registry** → Source → Select skills → **Install**
2. From **Skills Store** (if browsing available skills)
3. From **Projects** → Add Skill → Choose from registry

#### Update a Skill
**Skills** → Select skill → **Update All** button
- Updates the skill on all agents where it's installed
- Only available if an update is detected

#### Reinstall a Skill
**Skills** → Select skill → **Reinstall** button
- Useful if a skill installation was corrupted
- Re-downloads and reinstalls the skill

#### Remove a Skill
**Skills** → Select skill → **Remove All** button
- Removes the skill from all agents
- Or click the trash icon next to individual agents to remove from specific agents

### Understanding the Registry

The registry at `~/.forks` contains:
- **`repos/`** - Cloned Git repositories
- **`registry.json`** - Metadata about installed skills
- **`sources.json`** - List of tracked skill sources

## 🎨 Screenshots

### Dashboard
See an overview of your installed skills, detected agents, and recent activity.

### Skills View
Browse all your installed skills with details about which agents have them.

### Registry View
Manage skill sources (GitHub repos or local folders) and browse available skills.

### Agents View
See all detected AI coding agents on your system.

### Projects View
Track your coding projects and their skill installations.

## 🏗️ Architecture

### Tech Stack
- **SwiftUI** - Native macOS UI framework
- **AppKit** - macOS platform integration
- **Combine** - Reactive state management
- **FileManager** - File system operations
- **Process** - Shell command execution (git, npx)

### Key Components

#### Services
- **SkillService** - Manages skill installation, updates, registry
- **AgentService** - Detects and manages AI coding agents
- **ProjectService** - Tracks coding projects

#### Models
- **Skill** - Available and installed skills
- **Agent** - AI coding agent configuration
- **Project** - User coding projects
- **RegistrySource** - Skill repository sources

#### Views
- **DashboardView** - Overview and quick actions
- **InstalledSkillsView** - Table of installed skills
- **RegistryView** - Manage skill sources
- **AppsView** - Detected agents
- **ProjectListView** - Project management

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Adding Support for New Agents
To add a new agent:
1. Edit `Models/Agent.swift`
2. Add the agent to the `supportedAgents` array with:
   - Agent name
   - CLI name (for `npx add-skill --agent <cli-name>`)
   - Project path (local skill directory in projects)
   - Global path (user-level skill directory)
3. Submit a PR

### Reporting Issues
Please use the [GitHub Issues](https://github.com/fxding/forks/issues) page.

## 📋 Supported Agents

See [AGENTS.md](AGENTS.md) for the complete list of 25+ supported AI coding agents.

Popular agents include:
- Cursor
- Claude Code
- Windsurf
- Cline
- Antigravity
- Goose
- Roo Code
- And many more!

## 🗺️ Roadmap

- [ ] Skill marketplace/discovery
- [ ] Skill templates and creation wizard
- [ ] Import/export configurations
- [ ] Cloud sync for settings
- [ ] Command-line interface
- [ ] Automatic skill recommendations
- [ ] Skill statistics and analytics
- [ ] Custom skill categories and tagging

## ⚠️ Requirements

- **macOS**: 13.0 (Ventura) or later
- **Node.js**: Required for skill installation via `npx add-skill`
- **Git**: Required for cloning remote skill repositories

## 📄 License

MIT License - see LICENSE file for details

## 🙏 Acknowledgments

- [add-skill](https://github.com/vercel-labs/add-skill) - The skill management tool that powers Forks
- AI coding agent communities for their amazing tools
- The Swift and macOS developer community

## 📞 Contact

- GitHub: [@fxding](https://github.com/fxding)
- Issues: [GitHub Issues](https://github.com/fxding/forks/issues)

---

Made with ❤️ for the AI coding community
