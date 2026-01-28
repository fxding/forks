import Foundation

struct Agent: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let cliName: String
    let projectPath: String
    let globalPath: String
    let configPath: String
    var detected: Bool = false
    
    // Config from the Rust implementation
    static let supportedAgents: [Agent] = [
        Agent(name: "Amp", cliName: "amp", projectPath: ".agents/skills/", globalPath: "~/.config/agents/skills/", configPath: "~/.config/amp/"),
        Agent(name: "Antigravity", cliName: "antigravity", projectPath: ".agent/skills/", globalPath: "~/.gemini/antigravity/skills/", configPath: "~/.gemini/antigravity/"),
        Agent(name: "Claude Code", cliName: "claude-code", projectPath: ".claude/skills/", globalPath: "~/.claude/skills/", configPath: "~/.claude/"),
        Agent(name: "Clawdbot", cliName: "clawdbot", projectPath: "skills/", globalPath: "~/.clawdbot/skills/", configPath: "~/.clawdbot/"),
        Agent(name: "Cline", cliName: "cline", projectPath: ".cline/skills/", globalPath: "~/.cline/skills/", configPath: "~/.cline/"),
        Agent(name: "CodeBuddy", cliName: "codebuddy", projectPath: ".codebuddy/skills/", globalPath: "~/.codebuddy/skills/", configPath: "~/.codebuddy/"),
        Agent(name: "Codex", cliName: "codex", projectPath: ".codex/skills/", globalPath: "~/.codex/skills/", configPath: "~/.codex/"),
        Agent(name: "Command Code", cliName: "command-code", projectPath: ".commandcode/skills/", globalPath: "~/.commandcode/skills/", configPath: "~/.commandcode/"),
        Agent(name: "Continue", cliName: "continue", projectPath: ".continue/skills/", globalPath: "~/.continue/skills/", configPath: "~/.continue/"),
        Agent(name: "Crush", cliName: "crush", projectPath: ".crush/skills/", globalPath: "~/.config/crush/skills/", configPath: "~/.config/crush/"),
        Agent(name: "Cursor", cliName: "cursor", projectPath: ".cursor/skills/", globalPath: "~/.cursor/skills/", configPath: "~/.cursor/"),
        Agent(name: "Droid", cliName: "droid", projectPath: ".factory/skills/", globalPath: "~/.factory/skills/", configPath: "~/.factory/"),
        Agent(name: "Gemini CLI", cliName: "gemini-cli", projectPath: ".gemini/skills/", globalPath: "~/.gemini/skills/", configPath: "~/.gemini/"),
        Agent(name: "GitHub Copilot", cliName: "github-copilot", projectPath: ".github/skills/", globalPath: "~/.copilot/skills/", configPath: "~/.copilot/"),
        Agent(name: "Goose", cliName: "goose", projectPath: ".goose/skills/", globalPath: "~/.config/goose/skills/", configPath: "~/.config/goose/"),
        Agent(name: "Junie", cliName: "junie", projectPath: ".junie/skills/", globalPath: "~/.junie/skills/", configPath: "~/.junie/"),
        Agent(name: "Kilo Code", cliName: "kilo", projectPath: ".kilocode/skills/", globalPath: "~/.kilocode/skills/", configPath: "~/.kilocode/"),
        Agent(name: "Kimi Code CLI", cliName: "kimi-cli", projectPath: ".agents/skills/", globalPath: "~/.config/agents/skills/", configPath: "~/.kimi/"),
        Agent(name: "Kiro CLI", cliName: "kiro-cli", projectPath: ".kiro/skills/", globalPath: "~/.kiro/skills/", configPath: "~/.kiro/"),
        Agent(name: "Kode", cliName: "kode", projectPath: ".kode/skills/", globalPath: "~/.kode/skills/", configPath: "~/.kode/"),
        Agent(name: "MCPJam", cliName: "mcpjam", projectPath: ".mcpjam/skills/", globalPath: "~/.mcpjam/skills/", configPath: "~/.mcpjam/"),
        Agent(name: "Mux", cliName: "mux", projectPath: ".mux/skills/", globalPath: "~/.mux/skills/", configPath: "~/.mux/"),
        Agent(name: "Neovate", cliName: "neovate", projectPath: ".neovate/skills/", globalPath: "~/.neovate/skills/", configPath: "~/.neovate/"),
        Agent(name: "OpenCode", cliName: "opencode", projectPath: ".opencode/skills/", globalPath: "~/.config/opencode/skills/", configPath: "~/.config/opencode/"),
        Agent(name: "OpenHands", cliName: "openhands", projectPath: ".openhands/skills/", globalPath: "~/.openhands/skills/", configPath: "~/.openhands/"),
        Agent(name: "Pi", cliName: "pi", projectPath: ".pi/skills/", globalPath: "~/.pi/agent/skills/", configPath: "~/.pi/agent/"),
        Agent(name: "Pochi", cliName: "pochi", projectPath: ".pochi/skills/", globalPath: "~/.pochi/skills/", configPath: "~/.pochi/"),
        Agent(name: "Qoder", cliName: "qoder", projectPath: ".qoder/skills/", globalPath: "~/.qoder/skills/", configPath: "~/.qoder/"),
        Agent(name: "Qwen Code", cliName: "qwen-code", projectPath: ".qwen/skills/", globalPath: "~/.qwen/skills/", configPath: "~/.qwen/"),
        Agent(name: "Roo Code", cliName: "roo", projectPath: ".roo/skills/", globalPath: "~/.roo/skills/", configPath: "~/.roo/"),
        Agent(name: "Trae", cliName: "trae", projectPath: ".trae/skills/", globalPath: "~/.trae/skills/", configPath: "~/.trae/"),
        Agent(name: "Windsurf", cliName: "windsurf", projectPath: ".windsurf/skills/", globalPath: "~/.codeium/windsurf/skills/", configPath: "~/.codeium/windsurf/"),
        Agent(name: "Zencoder", cliName: "zencoder", projectPath: ".zencoder/skills/", globalPath: "~/.zencoder/skills/", configPath: "~/.zencoder/")
    ]
}
