import SwiftUI
import Combine

@MainActor
class SkillService: ObservableObject {
    @Published var availableSkills: [Skill] = []
    @Published var installedSkills: [InstalledSkill] = []
    
    private let forksDir = NSString(string: "~/.forks").expandingTildeInPath
    
    func getInstalledSkills() {
        var skillMap: [String: InstalledSkill] = [:]
        let agents = Agent.supportedAgents
        
        for agent in agents {
            let home = "/Users/\(NSUserName())"
            let expandedPath = agent.globalPath.replacingOccurrences(of: "~", with: home)
            guard FileManager.default.fileExists(atPath: expandedPath) else { continue }
            
            do {
                let items = try FileManager.default.contentsOfDirectory(atPath: expandedPath)
                for item in items {
                    let itemPath = (expandedPath as NSString).appendingPathComponent(item)
                    var isDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: itemPath, isDirectory: &isDir), isDir.boolValue {
                        let skillMdPath = (itemPath as NSString).appendingPathComponent("SKILL.md")
                        if FileManager.default.fileExists(atPath: skillMdPath) {
                            if let content = try? String(contentsOfFile: skillMdPath, encoding: .utf8),
                               let (name, description) = parseFrontmatter(content: content) {
                                
                                // Find source info from ~/.forks directory
                                let (source, installedDate, updateAvailable) = getSourceInfo(skillName: name)
                                
                                if var existing = skillMap[name] {
                                    if !existing.agents.contains(agent.name) {
                                        existing.agents.append(agent.name)
                                        // Keep source info from first lookup
                                        if existing.source == nil && source != nil {
                                            existing.source = source
                                            existing.installedDate = installedDate
                                            existing.updateAvailable = updateAvailable
                                        }
                                        skillMap[name] = existing
                                    }
                                } else {
                                    skillMap[name] = InstalledSkill(
                                        name: name,
                                        description: description,
                                        agents: [agent.name],
                                        source: source,
                                        installedDate: installedDate,
                                        lastCheckedForUpdates: nil,
                                        updateAvailable: updateAvailable
                                    )
                                }
                            }
                        }
                    }
                }
            } catch {
                print("Error reading directory \(expandedPath): \(error)")
            }
        }
        
        self.installedSkills = Array(skillMap.values).sorted { $0.name < $1.name }
    }
    
    func fetchSkills(source: String = "vercel-labs/agent-skills") async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("skill-man-clones")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        let id = UUID().uuidString
        let cloneDir = tempDir.appendingPathComponent("repo-\(id)")
        
        let url: String
        if !source.contains("://") && !source.hasPrefix("git@") {
            url = "https://github.com/\(source).git"
        } else {
            url = source
        }
        
        var foundSkills: [Skill] = []
        
        if FileManager.default.fileExists(atPath: url) {
             print("Loading skills from local path: \(url)")
             findSkillsInDir(dir: URL(fileURLWithPath: url), skills: &foundSkills, baseDir: URL(fileURLWithPath: url))
             
             if foundSkills.isEmpty {
                 throw NSError(domain: "SkillService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No skills found in local path"])
             }
        } else {
            // Git clone
            try await runShellCommand(command: "git", args: ["clone", "--depth", "1", url, cloneDir.path])
            
            findSkillsInDir(dir: cloneDir, skills: &foundSkills, baseDir: cloneDir)
            
            // Cleanup
            try? FileManager.default.removeItem(at: cloneDir)
        }
        
        if foundSkills.isEmpty {
            throw NSError(domain: "SkillService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No skills found"])
        }
        
        // Merge duplicates
        var skillMap: [String: Skill] = [:]
        for skill in foundSkills {
            if var existing = skillMap[skill.name] {
                for agent in skill.availableAgents {
                    if !existing.availableAgents.contains(agent) {
                        existing.availableAgents.append(agent)
                    }
                }
                skillMap[skill.name] = existing
            } else {
                skillMap[skill.name] = skill
            }
        }
        
        self.availableSkills = Array(skillMap.values).sorted { $0.name < $1.name }
    }
    

    
    func uninstallSkill(skillName: String, agentName: String) throws {
        let agents = Agent.supportedAgents
        guard let agent = agents.first(where: { $0.name == agentName }) else {
             throw NSError(domain: "SkillService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unknown agent"])
        }
        
        let expandedPath = NSString(string: agent.globalPath).expandingTildeInPath
        let skillsDir = expandedPath
        
        let items = try FileManager.default.contentsOfDirectory(atPath: skillsDir)
        for item in items {
            let itemPath = (skillsDir as NSString).appendingPathComponent(item)
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
        
        throw NSError(domain: "SkillService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Skill not found"])
    }
    
    // Wrapper to ensure UI update
    func uninstallSkillWithRefresh(skillName: String, agentName: String) {
        try? uninstallSkill(skillName: skillName, agentName: agentName)
        getInstalledSkills()
    }
    
    // Check recursively
    private func findSkillsInDir(dir: URL, skills: inout [Skill], baseDir: URL) {
        guard let enumerator = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: [.isDirectoryKey, .nameKey], options: [.skipsHiddenFiles]) else { return }
        
        // Swift's enumerator is recursive by default but let's do manual recursion if needed or use this
        // Actually, let's implement the Rust-like logic manually to be safe about depth and specific structure if needed.
        // But Rust's logic was recursive.
        
        do {
            let items = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            for item in items {
                let itemPath = dir.appendingPathComponent(item.lastPathComponent)
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: itemPath.path, isDirectory: &isDir) {
                    if isDir.boolValue {
                        if item.lastPathComponent != ".git" {
                            findSkillsInDir(dir: itemPath, skills: &skills, baseDir: baseDir)
                        }
                    } else if item.lastPathComponent == "SKILL.md" {
                        if let content = try? String(contentsOf: itemPath, encoding: .utf8),
                           let (name, description) = parseFrontmatter(content: content) {
                            let agent = detectAgentFromPath(path: itemPath.path)
                            skills.append(Skill(name: name, description: description, availableAgents: agent != nil ? [agent!] : []))
                        }
                    }
                }
            }
        } catch {
            print("Failed to read dir \(dir): \(error)")
        }
    }
    
    private func detectAgentFromPath(path: String) -> String? {
        let pathLower = path.lowercased()
        
        for agent in Agent.supportedAgents {
            // Check project path match first (e.g. .cursor/skills/)
            let dirPattern = agent.projectPath.trimmingCharacters(in: .init(charactersIn: "/"))
            if pathLower.contains(dirPattern.lowercased()) {
                return agent.name
            }
        }
        
        for agent in Agent.supportedAgents {
            let pattern1 = "/\(agent.cliName)/"
            let pattern2 = "/\(agent.name.lowercased().replacingOccurrences(of: " ", with: "-"))/"
            let pattern3 = "/\(agent.name.lowercased().replacingOccurrences(of: " ", with: "_"))/"
            
            if pathLower.contains(pattern1) || pathLower.contains(pattern2) || pathLower.contains(pattern3) {
                return agent.name
            }
        }
        
        return nil
    }
    
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
    
    private func runShellCommand(command: String, args: [String], environment: [String: String]? = nil) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let task = Process()
            
            // Resolve executable path
            // We use /usr/bin/env to find the command or manual search
            // For now, let's try assuming standard paths
            var launchPath = "/usr/bin/" + command
            if !FileManager.default.fileExists(atPath: launchPath) {
                launchPath = "/usr/local/bin/" + command
            }
             if !FileManager.default.fileExists(atPath: launchPath) {
                launchPath = "/opt/homebrew/bin/" + command
            }
            // Fallback for git/npx
            if command == "npx" && !FileManager.default.fileExists(atPath: launchPath) {
                 // Try looking into path
            }

            task.executableURL = URL(fileURLWithPath: launchPath)
            task.arguments = args
            
            if let environment = environment {
                task.environment = environment
            }
            
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe
            
            do {
                try task.run()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                task.waitUntilExit()
                
                 let output = String(data: data, encoding: .utf8) ?? ""
                
                if task.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    continuation.resume(throwing: NSError(domain: "Shell", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: output]))
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    // MARK: - Forks & Registry Management
    
    private let registryPath = NSString(string: "~/.forks/registry.json").expandingTildeInPath
    
    struct RegistryEntry: Codable {
        let originalSource: String
        let relativeForkPath: String // Path inside ~/.forks
        let installedDate: Date
        var lastChecked: Date?
        var updateAvailable: Bool
    }
    
    private func getRegistry() -> [String: RegistryEntry] {
        guard FileManager.default.fileExists(atPath: registryPath),
              let data = try? Data(contentsOf: URL(fileURLWithPath: registryPath)),
              let registry = try? JSONDecoder().decode([String: RegistryEntry].self, from: data) else {
            return [:]
        }
        return registry
    }
    
    private func saveRegistry(_ registry: [String: RegistryEntry]) {
        try? FileManager.default.createDirectory(atPath: forksDir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(registry) {
            try? data.write(to: URL(fileURLWithPath: registryPath))
        }
    }
    
    private func getSourceInfo(skillName: String) -> (source: String?, installedDate: Date?, updateAvailable: Bool) {
        let registry = getRegistry()
        if let entry = registry[skillName] {
            return (entry.originalSource, entry.installedDate, entry.updateAvailable)
        }
        return (nil, nil, false)
    }
    
    // MARK: - Installation
    
    func installSkills(source: String = "vercel-labs/agent-skills", skillNames: [String], agentCliNames: [String], global: Bool = true) async throws -> String {
        // 1. Prepare ~/.forks
        try FileManager.default.createDirectory(atPath: forksDir, withIntermediateDirectories: true)
        
        let forkPath: String
        let relativePath: String
        
        // 2. Clone or Copy to ~/.forks
        if source.contains("://") || source.hasPrefix("git@") || !FileManager.default.fileExists(atPath: source) {
            // It's a remote repo
            let repoName = source.components(separatedBy: "/").last?.replacingOccurrences(of: ".git", with: "") ?? "unknown-\(UUID().uuidString)"
            let safeSourceName = source.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
            relativePath = "repos/\(safeSourceName)"
            forkPath = (forksDir as NSString).appendingPathComponent(relativePath)
            
            if FileManager.default.fileExists(atPath: forkPath) {
                // Already exists, just ensure it's clean or pull? 
                // User said "use git fetch", but for install we probably want the latest state or just use what we have?
                // For a fresh install call, let's try to pull or fetch/reset to be safe, ensuring we install the latest intended.
                // But for "install", we might assume the cache is okay OR we should update it.
                // Let's do a quick pull to be helpful, or at least fetch.
                // Actually, if it exists, let's treat it as "update cache"
                try await runShellCommand(command: "git", args: ["-C", forkPath, "pull"])
            } else {
                let url = (!source.contains("://") && !source.hasPrefix("git@")) ? "https://github.com/\(source).git" : source
                try await runShellCommand(command: "git", args: ["clone", url, forkPath])
            }
        } else {
            // It's a local folder
            let folderName = (source as NSString).lastPathComponent
            relativePath = "local/\(folderName)"
            forkPath = (forksDir as NSString).appendingPathComponent(relativePath)
            
            // Remove existing copy if any to ensure fresh copy
            if FileManager.default.fileExists(atPath: forkPath) {
                try FileManager.default.removeItem(atPath: forkPath)
            }
            try FileManager.default.createDirectory(atPath: (forkPath as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
            try FileManager.default.copyItem(atPath: source, toPath: forkPath)
        }
        
        // 3. Update Registry
        var registry = getRegistry()
        let now = Date()
        for name in skillNames {
            registry[name] = RegistryEntry(
                originalSource: source,
                relativeForkPath: relativePath,
                installedDate: now,
                lastChecked: now,
                updateAvailable: false
            )
        }
        saveRegistry(registry)
        
        // 4. Install from the Fork
        var args = ["add-skill", forkPath]
        for skill in skillNames {
            args.append("--skill")
            args.append(skill)
        }
        for agent in agentCliNames {
            args.append("--agent")
            args.append(agent)
        }
        if global {
            args.append("--global")
        }
        args.append("--yes")
        
        let output = try await runShellCommand(command: "npx", args: args, environment: ["PATH": "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"])
        
        await MainActor.run {
             getInstalledSkills()
        }
        
        return output
    }
    
    // MARK: - Update Logic
    
    func checkForUpdates(skill: InstalledSkill, agentName: String) async throws -> Bool {
        var registry = getRegistry()
        guard let entry = registry[skill.name] else { return false }
        
        let forkPath = (forksDir as NSString).appendingPathComponent(entry.relativeForkPath)
        var updateAvailable = false
        
        if entry.relativeForkPath.hasPrefix("repos/") {
            // Git Repo: git fetch and check status
            // git fetch origin
            _ = try await runShellCommand(command: "git", args: ["-C", forkPath, "fetch"])
            
            // Check if behind
            // git rev-list HEAD...origin/main --count
            // We need to know the default branch. 
            // git symbolic-ref refs/remotes/origin/HEAD
            
            let status = try await runShellCommand(command: "git", args: ["-C", forkPath, "status", "-uno"])
            if status.contains("Your branch is behind") {
                updateAvailable = true
            }
        } else {
            // Local folder: Check modified date of original source vs fork
            if FileManager.default.fileExists(atPath: entry.originalSource) {
                let originalAttr = try FileManager.default.attributesOfItem(atPath: entry.originalSource)
                let forkAttr = try FileManager.default.attributesOfItem(atPath: forkPath)
                
                if let orgDate = originalAttr[.modificationDate] as? Date,
                   let forkDate = forkAttr[.modificationDate] as? Date {
                    // If original is newer than our copy
                    if orgDate > forkDate {
                        updateAvailable = true
                    }
                }
            }
        }
        
        // Update registry
        registry[skill.name]?.lastChecked = Date()
        registry[skill.name]?.updateAvailable = updateAvailable
        saveRegistry(registry)
        
        return updateAvailable
    }
    
    func updateSkill(skillName: String, agentName: String, source: String) async throws {
        var registry = getRegistry()
        guard let entry = registry[skillName] else {
            // Fallback to normal install if not in registry
             _ = try await installSkills(source: source, skillNames: [skillName], agentCliNames: [agentName.lowercased()], global: true)
             return
        }
        
        let forkPath = (forksDir as NSString).appendingPathComponent(entry.relativeForkPath)
        
        // 1. Update the code in ~/.forks
        if entry.relativeForkPath.hasPrefix("repos/") {
            try await runShellCommand(command: "git", args: ["-C", forkPath, "pull"])
        } else {
            // Re-copy local folder
            if FileManager.default.fileExists(atPath: entry.originalSource) {
                if FileManager.default.fileExists(atPath: forkPath) {
                    try FileManager.default.removeItem(atPath: forkPath)
                }
                try FileManager.default.copyItem(atPath: entry.originalSource, toPath: forkPath)
            }
        }
        
        // 2. Re-install/Update using the updated fork (forcing overwrite usually handled by agent tool logic, assuming add-skill handles it)
        // 2. Re-install/Update using the updated fork
        try uninstallSkill(skillName: skillName, agentName: agentName)
        
        // Get agent cli name
        let agentCli = Agent.supportedAgents.first(where: { $0.name == agentName })?.cliName ?? agentName.lowercased()
        
        var args = ["add-skill", forkPath, "--skill", skillName, "--agent", agentCli, "--global", "--yes"]
        _ = try await runShellCommand(command: "npx", args: args, environment: ["PATH": "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"])
        
        // 3. Update Registry
        registry[skillName]?.updateAvailable = false
        registry[skillName]?.lastChecked = Date()
        saveRegistry(registry)
    }
    
    // MARK: - Background Update
    
    private var updateCheckTask: Task<Void, Never>?
    
    func startPeriodicUpdateChecks() {
        updateCheckTask?.cancel()
        updateCheckTask = Task {
            try? await Task.sleep(nanoseconds: 5 * 60 * 1_000_000_000) // 5 min delay
            guard !Task.isCancelled else { return }
            
            let registry = getRegistry()
            let skillNames = Array(registry.keys)
            
            for name in skillNames {
                guard !Task.isCancelled else { return }
                guard let entry = registry[name] else { continue }
                
                // Throttle: 1 hour
                if let last = entry.lastChecked, Date().timeIntervalSince(last) < 3600 {
                    continue
                }
                
                // We need dummy skill/agent objects to call checkForUpdates, or refactor it.
                // Refactoring checkForUpdates to take just name is better, but it relies on finding the path currently?
                // Actually my new checkForUpdates uses registry info mostly, but signature takes InstalledSkill.
                // Let's overload it or construct a dummy.
                
                let dummySkill = InstalledSkill(name: name, description: nil, agents: [], source: entry.originalSource)
                // agentName is unused in the new logic except for signature compatibility?
                // Wait, old logic needed agent to find path. New logic uses registry.
                // So agentName is ignored!
                
                do {
                    let hasUpdate = try await checkForUpdates(skill: dummySkill, agentName: "")
                    if hasUpdate {
                        await MainActor.run { getInstalledSkills() }
                    }
                } catch {
                    print("BG Update check failed for \(name): \(error)")
                }
                
                try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)
            }
        }
    }
    
    func stopPeriodicUpdateChecks() {
        updateCheckTask?.cancel()
    }

    // Keep helpers
    private func findSkillPath(in directory: String, skillName: String) throws -> String {
        // ... (keep existing implementation or simplify if needed)
        // This is still needed for uninstall logic
        let items = try FileManager.default.contentsOfDirectory(atPath: directory)
        for item in items {
            let itemPath = (directory as NSString).appendingPathComponent(item)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: itemPath, isDirectory: &isDir), isDir.boolValue {
                let skillMdPath = (itemPath as NSString).appendingPathComponent("SKILL.md")
                if FileManager.default.fileExists(atPath: skillMdPath) {
                    if let content = try? String(contentsOfFile: skillMdPath, encoding: .utf8),
                       let (name, _) = parseFrontmatter(content: content), name == skillName {
                        return itemPath
                    }
                }
            }
        }
        throw NSError(domain: "SkillService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Skill not found"])
    }
    
    private func findLocalSkillPath(in directory: String, skillName: String) -> String? {
         try? findSkillPath(in: directory, skillName: skillName)
    }
    
}
