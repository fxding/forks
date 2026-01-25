import Foundation

struct Agent: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let cliName: String
    let projectPath: String
    let globalPath: String
    var detected: Bool = false
    
    // Config from the Rust implementation
    static let supportedAgents: [Agent] = [
        Agent(name: "Amp", cliName: "amp", projectPath: ".agents/skills/", globalPath: "~/.config/agents/skills/"),
        Agent(name: "Antigravity", cliName: "antigravity", projectPath: ".agent/skills/", globalPath: "~/.gemini/antigravity/skills/"),
        Agent(name: "Claude Code", cliName: "claude-code", projectPath: ".claude/skills/", globalPath: "~/.claude/skills/"),
        Agent(name: "Clawdbot", cliName: "clawdbot", projectPath: "skills/", globalPath: "~/.clawdbot/skills/"),
        Agent(name: "Cline", cliName: "cline", projectPath: ".cline/skills/", globalPath: "~/.cline/skills/"),
        Agent(name: "Codex", cliName: "codex", projectPath: ".codex/skills/", globalPath: "~/.codex/skills/"),
        Agent(name: "Command Code", cliName: "command-code", projectPath: ".commandcode/skills/", globalPath: "~/.commandcode/skills/"),
        Agent(name: "Cursor", cliName: "cursor", projectPath: ".cursor/skills/", globalPath: "~/.cursor/skills/"),
        Agent(name: "Droid", cliName: "droid", projectPath: ".factory/skills/", globalPath: "~/.factory/skills/"),
        Agent(name: "Gemini CLI", cliName: "gemini-cli", projectPath: ".gemini/skills/", globalPath: "~/.gemini/skills/"),
        Agent(name: "GitHub Copilot", cliName: "github-copilot", projectPath: ".github/skills/", globalPath: "~/.copilot/skills/"),
        Agent(name: "Goose", cliName: "goose", projectPath: ".goose/skills/", globalPath: "~/.config/goose/skills/"),
        Agent(name: "Kilo Code", cliName: "kilo", projectPath: ".kilocode/skills/", globalPath: "~/.kilocode/skills/"),
        Agent(name: "Kiro CLI", cliName: "kiro-cli", projectPath: ".kiro/skills/", globalPath: "~/.kiro/skills/"),
        Agent(name: "MCPJam", cliName: "mcpjam", projectPath: ".mcpjam/skills/", globalPath: "~/.mcpjam/skills/"),
        Agent(name: "OpenCode", cliName: "opencode", projectPath: ".opencode/skills/", globalPath: "~/.config/opencode/skills/"),
        Agent(name: "OpenHands", cliName: "openhands", projectPath: ".openhands/skills/", globalPath: "~/.openhands/skills/"),
        Agent(name: "Pi", cliName: "pi", projectPath: ".pi/skills/", globalPath: "~/.pi/agent/skills/"),
        Agent(name: "Qoder", cliName: "qoder", projectPath: ".qoder/skills/", globalPath: "~/.qoder/skills/"),
        Agent(name: "Qwen Code", cliName: "qwen-code", projectPath: ".qwen/skills/", globalPath: "~/.qwen/skills/"),
        Agent(name: "Roo Code", cliName: "roo", projectPath: ".roo/skills/", globalPath: "~/.roo/skills/"),
        Agent(name: "Trae", cliName: "trae", projectPath: ".trae/skills/", globalPath: "~/.trae/skills/"),
        Agent(name: "Windsurf", cliName: "windsurf", projectPath: ".windsurf/skills/", globalPath: "~/.codeium/windsurf/skills/"),
        Agent(name: "Zencoder", cliName: "zencoder", projectPath: ".zencoder/skills/", globalPath: "~/.zencoder/skills/"),
        Agent(name: "Neovate", cliName: "neovate", projectPath: ".neovate/skills/", globalPath: "~/.neovate/skills/")
    ]
}
