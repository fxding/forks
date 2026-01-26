# Supported AI Coding Agents

Forks supports managing skills for 25+ AI coding agents. Below is the complete list of supported agents with their CLI names and skill paths.

> **Note**: The agent list is maintained and defined by the [add-skill](https://github.com/vercel-labs/add-skill/blob/main/README.md) tool. For the most up-to-date list and agent configurations, please refer to the add-skill documentation.

## Agent List

| Agent | CLI Name | Project Path | Global Path |
|-------|----------|--------------|-------------|
| **Amp** | `amp` | `.agents/skills/` | `~/.config/agents/skills/` |
| **Antigravity** | `antigravity` | `.agent/skills/` | `~/.gemini/antigravity/skills/` |
| **Claude Code** | `claude-code` | `.claude/skills/` | `~/.claude/skills/` |
| **Clawdbot** | `clawdbot` | `skills/` | `~/.clawdbot/skills/` |
| **Cline** | `cline` | `.cline/skills/` | `~/.cline/skills/` |
| **Codex** | `codex` | `.codex/skills/` | `~/.codex/skills/` |
| **Command Code** | `command-code` | `.commandcode/skills/` | `~/.commandcode/skills/` |
| **Cursor** | `cursor` | `.cursor/skills/` | `~/.cursor/skills/` |
| **Droid** | `droid` | `.factory/skills/` | `~/.factory/skills/` |
| **Gemini CLI** | `gemini-cli` | `.gemini/skills/` | `~/.gemini/skills/` |
| **GitHub Copilot** | `github-copilot` | `.github/skills/` | `~/.copilot/skills/` |
| **Goose** | `goose` | `.goose/skills/` | `~/.config/goose/skills/` |
| **Kilo Code** | `kilo` | `.kilocode/skills/` | `~/.kilocode/skills/` |
| **Kiro CLI** | `kiro-cli` | `.kiro/skills/` | `~/.kiro/skills/` |
| **MCPJam** | `mcpjam` | `.mcpjam/skills/` | `~/.mcpjam/skills/` |
| **Neovate** | `neovate` | `.neovate/skills/` | `~/.neovate/skills/` |
| **OpenCode** | `opencode` | `.opencode/skills/` | `~/.config/opencode/skills/` |
| **OpenHands** | `openhands` | `.openhands/skills/` | `~/.openhands/skills/` |
| **Pi** | `pi` | `.pi/skills/` | `~/.pi/agent/skills/` |
| **Qoder** | `qoder` | `.qoder/skills/` | `~/.qoder/skills/` |
| **Qwen Code** | `qwen-code` | `.qwen/skills/` | `~/.qwen/skills/` |
| **Roo Code** | `roo` | `.roo/skills/` | `~/.roo/skills/` |
| **Trae** | `trae` | `.trae/skills/` | `~/.trae/skills/` |
| **Windsurf** | `windsurf` | `.windsurf/skills/` | `~/.codeium/windsurf/skills/` |
| **Zencoder** | `zencoder` | `.zencoder/skills/` | `~/.zencoder/skills/` |

## Installation Types

### Global Installation
Skills are installed to the agent's global skill directory (e.g., `~/.cursor/skills/`). These skills are available across all projects when using that agent.

### Project Installation
Skills are installed to the project's local skill directory (e.g., `.cursor/skills/` in your project). These skills are only available for that specific project.

## Agent Detection

Forks automatically detects which agents you have installed on your system by checking for:
- Agent configuration directories
- Installed executables
- Common installation paths

Only detected agents will be shown in the Agents view and will be available for skill installation.

## Adding Support for New Agents

To add support for a new agent, the agent must follow the standard skill directory structure and support the `npx add-skill` command. If your agent isn't listed but follows these conventions, please open an issue or submit a pull request.

## Agent-Specific Notes

### Cursor
One of the most popular agents with extensive skill ecosystem support.

### Windsurf
Uses the Codeium infrastructure with skills stored in `~/.codeium/windsurf/skills/`.

### Goose
Stores skills in the XDG config directory structure (`~/.config/goose/skills/`).

### Clawdbot
Uses a simple `skills/` directory in projects without a dot prefix.

## Resources

- [add-skill](https://github.com/vercel-labs/add-skill) - The CLI tool used by Forks for skill management
- Individual agent documentation links (coming soon)
