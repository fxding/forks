import SwiftUI
import Combine

@MainActor
class ProjectService: ObservableObject {
    @Published var projects: [Project] = []
    
    private let forksDir = NSString(string: "~/.forks").expandingTildeInPath
    private var projectsPath: String {
        (forksDir as NSString).appendingPathComponent("projects.json")
    }
    
    init() {
        loadProjects()
    }
    
    // MARK: - Project Management
    
    func addProject(path: String) throws {
        // Validate path exists and is a directory
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
            throw NSError(domain: "ProjectService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Directory not found: \(path)"])
        }
        
        // Check if already added
        if projects.contains(where: { $0.path == path }) {
            throw NSError(domain: "ProjectService", code: 409, userInfo: [NSLocalizedDescriptionKey: "Project already added"])
        }
        
        // Use directory name as project name
        let name = (path as NSString).lastPathComponent
        
        let project = Project(name: name, path: path)
        projects.append(project)
        saveProjects()
    }
    
    func removeProject(id: UUID) {
        projects.removeAll { $0.id == id }
        saveProjects()
    }
    
    // MARK: - Project Detection
    
    func getProjectAgents(project: Project) -> [Agent] {
        var detectedAgents: [Agent] = []
        
        for agent in Agent.supportedAgents {
            let agentSkillsPath = (project.path as NSString).appendingPathComponent(agent.projectPath)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: agentSkillsPath, isDirectory: &isDir), isDir.boolValue {
                var detectedAgent = agent
                detectedAgent.detected = true
                detectedAgents.append(detectedAgent)
            }
        }
        
        return detectedAgents
    }
    
    func getProjectSkills(project: Project, agent: Agent) -> [InstalledSkill] {
        var skills: [InstalledSkill] = []
        
        let agentSkillsPath = (project.path as NSString).appendingPathComponent(agent.projectPath)
        
        guard FileManager.default.fileExists(atPath: agentSkillsPath) else {
            return skills
        }
        
        do {
            let items = try FileManager.default.contentsOfDirectory(atPath: agentSkillsPath)
            for item in items {
                let itemPath = (agentSkillsPath as NSString).appendingPathComponent(item)
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: itemPath, isDirectory: &isDir), isDir.boolValue {
                    let skillMdPath = (itemPath as NSString).appendingPathComponent("SKILL.md")
                    if FileManager.default.fileExists(atPath: skillMdPath) {
                        if let content = try? String(contentsOfFile: skillMdPath, encoding: .utf8),
                           let (name, description) = parseFrontmatter(content: content) {
                            skills.append(InstalledSkill(
                                name: name,
                                description: description,
                                agents: [agent.name],
                                source: nil,
                                installedDate: nil,
                                lastCheckedForUpdates: nil,
                                updateAvailable: false
                            ))
                        }
                    }
                }
            }
        } catch {
            print("Error reading project skills directory \(agentSkillsPath): \(error)")
        }
        
        return skills.sorted { $0.name < $1.name }
    }
    
    func getAllProjectSkillsCount(project: Project) -> Int {
        var count = 0
        let agents = getProjectAgents(project: project)
        for agent in agents {
            count += getProjectSkills(project: project, agent: agent).count
        }
        return count
    }
    
    // MARK: - Skill Management
    
    func uninstallProjectSkill(skillName: String, agentName: String, projectPath: String) throws {
        guard let agent = Agent.supportedAgents.first(where: { $0.name == agentName }) else {
            throw NSError(domain: "ProjectService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unknown agent"])
        }
        
        let agentSkillsPath = (projectPath as NSString).appendingPathComponent(agent.projectPath)
        
        let items = try FileManager.default.contentsOfDirectory(atPath: agentSkillsPath)
        for item in items {
            let itemPath = (agentSkillsPath as NSString).appendingPathComponent(item)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: itemPath, isDirectory: &isDir), isDir.boolValue {
                let skillMdPath = (itemPath as NSString).appendingPathComponent("SKILL.md")
                if FileManager.default.fileExists(atPath: skillMdPath) {
                    if let content = try? String(contentsOfFile: skillMdPath, encoding: .utf8),
                       let (name, _) = parseFrontmatter(content: content) {
                        if name == skillName {
                            try FileManager.default.removeItem(atPath: itemPath)
                            return
                        }
                    }
                }
            }
        }
        
        throw NSError(domain: "ProjectService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Skill not found"])
    }
    
    // MARK: - Persistence
    
    private func loadProjects() {
        guard FileManager.default.fileExists(atPath: projectsPath),
              let data = try? Data(contentsOf: URL(fileURLWithPath: projectsPath)),
              let loaded = try? JSONDecoder().decode([Project].self, from: data) else {
            projects = []
            return
        }
        
        // Filter out projects whose paths no longer exist
        projects = loaded.filter { project in
            var isDir: ObjCBool = false
            return FileManager.default.fileExists(atPath: project.path, isDirectory: &isDir) && isDir.boolValue
        }
        
        // Save if we filtered any out
        if projects.count != loaded.count {
            saveProjects()
        }
    }
    
    private func saveProjects() {
        try? FileManager.default.createDirectory(atPath: forksDir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(projects) {
            try? data.write(to: URL(fileURLWithPath: projectsPath))
        }
    }
    
    // MARK: - Helpers
    
    private func parseFrontmatter(content: String) -> (name: String, description: String?)? {
        guard content.hasPrefix("---") else { return nil }
        let components = content.components(separatedBy: "---")
        guard components.count >= 3 else { return nil }
        
        let frontmatter = components[1]
        var name: String?
        var description: String?
        
        frontmatter.enumerateLines { line, _ in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("name:") {
                name = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("description:") {
                description = String(trimmed.dropFirst(12)).trimmingCharacters(in: .whitespaces)
            }
        }
        
        if let name = name {
            return (name, description)
        }
        return nil
    }
}
