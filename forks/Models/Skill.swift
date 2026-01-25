import Foundation

struct Skill: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let description: String?
    var availableAgents: [String] = [] // List of agent names that support this skill (found in repo)
}

struct InstalledSkill: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let description: String?
    var agents: [String] // Agents that have this skill installed
    var source: String? // Original source (GitHub repo or local path)
    var installedDate: Date? // When the skill was installed
    var lastCheckedForUpdates: Date? // Last time updates were checked
    var updateAvailable: Bool = false // Whether an update is available
}

struct SkillMetadata: Codable {
    let source: String
    let installedDate: String // ISO 8601 format
    var lastCheckedForUpdates: String? // ISO 8601 format
    var updateAvailable: Bool
    let version: String
}
