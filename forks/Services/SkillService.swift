import SwiftUI
import Combine

@MainActor
class SkillService: ObservableObject {
    @Published var availableSkills: [Skill] = []
    @Published var installedSkills: [InstalledSkill] = []
    @Published var registrySources: [RegistrySource] = []
    @Published var logs: String = ""
    @Published var isCancelled: Bool = false
    
    private let forksDir = NSString(string: "~/.forks").expandingTildeInPath
    private var currentProcess: Process?
    
    func clearLogs() {
        logs = ""
        isCancelled = false
    }
    
    func cancelCurrentOperation() {
        isCancelled = true
        if let process = currentProcess, process.isRunning {
            process.terminate()
            logs += "\n⚠️ Operation cancelled by user\n"
        }
        currentProcess = nil
    }
    
    private func appendLog(_ message: String) {
        logs += message
    }
    
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
        self.registrySources = getRegistrySources()
    }
    
    func fetchSkills(source: String) async throws {
        // Validate source is not empty
        guard !source.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw NSError(domain: "SkillService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Source cannot be empty"])
        }
        
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("forks-clones")
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
    

    
    func uninstallSkill(skillName: String, agentName: String) async throws -> String {
        let agents = Agent.supportedAgents
        guard let agent = agents.first(where: { $0.name == agentName }) else {
             throw NSError(domain: "SkillService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unknown agent"])
        }
        
        // Use npx skills remove
        var args = ["skills", "remove", skillName]
        args.append(contentsOf: ["--agent", agent.cliName])
        args.append("--global")
        args.append("--yes")
        
        print("[DEBUG] Uninstalling \(skillName) from \(agentName) using npx")
        let output = try await runShellCommandWithLogs(command: "npx", args: args, environment: ["PATH": "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"])
        
        // Refresh logic will be handled by caller or we can do it here
        // But runShellCommandWithLogs runs on background thread mostly
        await MainActor.run {
            self.getInstalledSkills()
        }
        
        return output
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
                        let name = item.lastPathComponent
                        if !name.hasPrefix(".") && name != "node_modules" && name != "dist" && name != "build" && name != "DerivedData" {
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
    
    private func runShellCommand(command: String, args: [String], environment: [String: String]? = nil, currentDirectory: String? = nil) async throws -> String {
        print("[DEBUG] runShellCommand started: \(command) \(args.joined(separator: " "))")
        if let cwd = currentDirectory {
            print("[DEBUG] CWD: \(cwd)")
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let task = Process()
                
                // Resolve executable path
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
                
                // Prepare environment with non-interactive flags
                var finalEnv = environment ?? ProcessInfo.processInfo.environment
                finalEnv["npm_config_yes"] = "true"
                finalEnv["CI"] = "true"
                task.environment = finalEnv
                
                if let currentDirectory = currentDirectory {
                    task.currentDirectoryURL = URL(fileURLWithPath: currentDirectory)
                }
                
                let outPipe = Pipe()
                task.standardOutput = outPipe
                task.standardError = outPipe
                
                // Add stdin pipe to close it immediately to prevent interactive hangs
                let inPipe = Pipe()
                task.standardInput = inPipe
                
                var accumulatedData = Data()
                let group = DispatchGroup()
                group.enter()
                
                outPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if data.isEmpty {
                        // EOF
                        outPipe.fileHandleForReading.readabilityHandler = nil
                        group.leave()
                    } else {
                        accumulatedData.append(data)
                         if let str = String(data: data, encoding: .utf8) {
                            print("[DEBUG-STREAM] \(str.trimmingCharacters(in: .whitespacesAndNewlines))")
                        }
                    }
                }
                
                do {
                    print("[DEBUG] Launching process: \(launchPath)")
                    try task.run()
                    
                    // Close stdin immediately to fail any interactive prompts
                    try? inPipe.fileHandleForWriting.close()
                    
                    print("[DEBUG] Process running...")
                    task.waitUntilExit()
                    print("[DEBUG] Process exited with status: \(task.terminationStatus)")
                    
                    // Wait for all output to be read
                    group.wait()
                    
                    let output = String(data: accumulatedData, encoding: .utf8) ?? ""
                    
                    if task.terminationStatus == 0 {
                        print("[DEBUG] Command SUCCESS")
                        continuation.resume(returning: output)
                    } else {
                        print("[DEBUG] Command FAILED: \(output)")
                        continuation.resume(throwing: NSError(domain: "Shell", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: output]))
                    }
                } catch {
                    print("[DEBUG] Process Launch Error: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Streaming version of runShellCommand that updates the logs property for UI display
    private func runShellCommandWithLogs(command: String, args: [String], environment: [String: String]? = nil, currentDirectory: String? = nil) async throws -> String {
        // Check if already cancelled before starting
        if isCancelled {
            throw NSError(domain: "SkillService", code: -999, userInfo: [NSLocalizedDescriptionKey: "Operation cancelled"])
        }
        
        let commandLine = "\(command) \(args.joined(separator: " "))"
        print("[DEBUG] runShellCommandWithLogs started: \(commandLine)")
        
        await MainActor.run {
            self.appendLog("$ \(commandLine)\n")
        }
        
        if let cwd = currentDirectory {
            print("[DEBUG] CWD: \(cwd)")
            await MainActor.run {
                self.appendLog("  (in \(cwd))\n")
            }
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let task = Process()
                
                // Store process reference for cancellation
                DispatchQueue.main.async {
                    self?.currentProcess = task
                }
                
                // Resolve executable path
                var launchPath = "/usr/bin/" + command
                if !FileManager.default.fileExists(atPath: launchPath) {
                    launchPath = "/usr/local/bin/" + command
                }
                if !FileManager.default.fileExists(atPath: launchPath) {
                    launchPath = "/opt/homebrew/bin/" + command
                }
                
                task.executableURL = URL(fileURLWithPath: launchPath)
                task.arguments = args
                
                // Prepare environment with non-interactive flags
                var finalEnv = environment ?? ProcessInfo.processInfo.environment
                finalEnv["npm_config_yes"] = "true"
                finalEnv["CI"] = "true"
                task.environment = finalEnv
                
                if let currentDirectory = currentDirectory {
                    task.currentDirectoryURL = URL(fileURLWithPath: currentDirectory)
                }
                
                let outPipe = Pipe()
                task.standardOutput = outPipe
                task.standardError = outPipe
                
                // Add stdin pipe to close it immediately to prevent interactive hangs
                let inPipe = Pipe()
                task.standardInput = inPipe
                
                var accumulatedData = Data()
                let group = DispatchGroup()
                group.enter()
                
                outPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if data.isEmpty {
                        // EOF
                        outPipe.fileHandleForReading.readabilityHandler = nil
                        group.leave()
                    } else {
                        accumulatedData.append(data)
                        if let str = String(data: data, encoding: .utf8) {
                            print("[DEBUG-STREAM] \(str.trimmingCharacters(in: .whitespacesAndNewlines))")
                            // Update logs on main thread
                            DispatchQueue.main.async {
                                self?.logs += str
                            }
                        }
                    }
                }
                
                do {
                    print("[DEBUG] Launching process: \(launchPath)")
                    try task.run()
                    
                    // Close stdin immediately to fail any interactive prompts
                    try? inPipe.fileHandleForWriting.close()
                    
                    print("[DEBUG] Process running...")
                    task.waitUntilExit()
                    print("[DEBUG] Process exited with status: \(task.terminationStatus)")
                    
                    // Clear process reference
                    DispatchQueue.main.async {
                        self?.currentProcess = nil
                    }
                    
                    // Wait for all output to be read
                    group.wait()
                    
                    let output = String(data: accumulatedData, encoding: .utf8) ?? ""
                    
                    // Check if terminated due to cancellation (SIGTERM = 15)
                    if task.terminationStatus == 15 || (self?.isCancelled ?? false) {
                        continuation.resume(throwing: NSError(domain: "SkillService", code: -999, userInfo: [NSLocalizedDescriptionKey: "Operation cancelled"]))
                    } else if task.terminationStatus == 0 {
                        print("[DEBUG] Command SUCCESS")
                        DispatchQueue.main.async {
                            self?.logs += "\n✅ Command completed successfully\n"
                        }
                        continuation.resume(returning: output)
                    } else {
                        print("[DEBUG] Command FAILED: \(output)")
                        DispatchQueue.main.async {
                            self?.logs += "\n❌ Command failed with exit code \(task.terminationStatus)\n"
                        }
                        continuation.resume(throwing: NSError(domain: "Shell", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: output]))
                    }
                } catch {
                    print("[DEBUG] Process Launch Error: \(error)")
                    DispatchQueue.main.async {
                        self?.currentProcess = nil
                        self?.logs += "\n❌ Error: \(error.localizedDescription)\n"
                    }
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Forks & Registry Management
    
    private let registryPath = NSString(string: "~/.forks/registry.json").expandingTildeInPath
    private let sourcesRegistryPath = NSString(string: "~/.forks/sources.json").expandingTildeInPath
    
    struct RegistryEntry: Codable {
        let originalSource: String
        let relativeForkPath: String // Path inside ~/.forks
        let installedDate: Date
        var lastChecked: Date?
        var updateAvailable: Bool
    }
    
    public struct RegistrySource: Identifiable, Hashable {
        public let id: String
        public let type: String
        public let path: String
        public let updateAvailable: Bool
        public let lastChecked: Date?
        public let skills: [String]
    }
    
    func getRegistrySources() -> [RegistrySource] {
        let registry = getRegistry()
        let trackedSources = getTrackedSources()
        
        var uniqueSources = trackedSources
        for entry in registry.values {
            uniqueSources.insert(entry.originalSource)
        }
        
        return uniqueSources.map { source in
            let skills = getSkillsInSource(source: source).map { $0.name }.sorted()
            
            // Determine type and update status
            let type = (source.contains("://") || source.hasPrefix("git@") || !FileManager.default.fileExists(atPath: source)) ? "Git" : "Local"
            var updateAvailable = false
            var lastChecked: Date?
            
            // Check if any installed skill from this source has update available
            for (_, entry) in registry {
                if entry.originalSource == source {
                    if entry.updateAvailable {
                        updateAvailable = true
                    }
                    // Use the most recent check date
                    if let checked = entry.lastChecked {
                        if lastChecked == nil || checked > lastChecked! {
                            lastChecked = checked
                        }
                    }
                }
            }
            
            return RegistrySource(
                id: source,
                type: type,
                path: source,
                updateAvailable: updateAvailable,
                lastChecked: lastChecked,
                skills: skills
            )
        }.sorted { $0.path < $1.path }
    }
    
    // MARK: - Source Tracking Logic
    
    // Add a source manually without installing skills
    func addRegistrySource(source: String) async throws {
        // 1. Prepare ~/.forks
        try FileManager.default.createDirectory(atPath: forksDir, withIntermediateDirectories: true)
        
        // 2. Clone/Validate
        let relativePath: String
        let forkPath: String
        
         if source.contains("://") || source.hasPrefix("git@") || !FileManager.default.fileExists(atPath: source) {
            // It's a remote repo
             let safeSourceName = source.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
            relativePath = "repos/\(safeSourceName)"
            forkPath = (forksDir as NSString).appendingPathComponent(relativePath)
            
            if FileManager.default.fileExists(atPath: forkPath) {
                try await runShellCommand(command: "git", args: ["-C", forkPath, "pull"])
            } else {
                let url = (!source.contains("://") && !source.hasPrefix("git@")) ? "https://github.com/\(source).git" : source
                try await runShellCommand(command: "git", args: ["clone", url, forkPath])
            }
        } else {
            // Local folder: verify existence, do NOT copy
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: source, isDirectory: &isDir), isDir.boolValue else {
                throw NSError(domain: "SkillService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Local source directory not found: \(source)"])
            }
            relativePath = "" // Empty means local direct path
            forkPath = source
        }
        
        // 3. Save to tracked sources
        var tracked = getTrackedSources()
        tracked.insert(source)
        saveTrackedSources(tracked)
        
        // 4. Update UI
        await MainActor.run {
             self.registrySources = getRegistrySources()
        }
    }
    
    func removeRegistrySource(source: String) {
        var tracked = getTrackedSources()
        tracked.remove(source)
        saveTrackedSources(tracked)
        
        // Note: We do NOT remove the files from ~/.forks because installed skills might depend on them.
        // We only stop showing it as a tracked source if there are no skills.
        // The UI will still show it if skills are installed.
        
        self.registrySources = getRegistrySources()
    }
    
    // MARK: - Delete Operations
    
    /// Delete a source from the app
    /// - For local sources: Removes from registry only (keeps folder on disk)
    /// - For remote repos: Deletes the cloned repo from ~/.forks/repos/
    func deleteSource(source: String) throws {
        let isLocal = FileManager.default.fileExists(atPath: source) && source.hasPrefix("/")
        
        if isLocal {
            // Local source: Remove from registry only, don't touch the folder
            var tracked = getTrackedSources()
            tracked.remove(source)
            saveTrackedSources(tracked)
            
            // Remove all skills from this source from registry
            var registry = getRegistry()
            let skillsToRemove = registry.filter { $0.value.originalSource == source }.map { $0.key }
            for skillName in skillsToRemove {
                registry.removeValue(forKey: skillName)
            }
            saveRegistry(registry)
        } else {
            // Remote repo: Delete from disk
            let forkPath = getForkPath(source: source)
            
            // Check if the path exists
            guard FileManager.default.fileExists(atPath: forkPath) else {
                throw NSError(domain: "SkillService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Repository clone not found on disk"])
            }
            
            // Delete the directory
            try FileManager.default.removeItem(atPath: forkPath)
            
            // Remove from tracked sources
            var tracked = getTrackedSources()
            tracked.remove(source)
            saveTrackedSources(tracked)
            
            // Remove all skills from this source from registry
            var registry = getRegistry()
            let skillsToRemove = registry.filter { $0.value.originalSource == source }.map { $0.key }
            for skillName in skillsToRemove {
                registry.removeValue(forKey: skillName)
            }
            saveRegistry(registry)
        }
        
        // Refresh UI
        getInstalledSkills()
    }
    
    private func getTrackedSources() -> Set<String> {
        guard FileManager.default.fileExists(atPath: sourcesRegistryPath),
              let data = try? Data(contentsOf: URL(fileURLWithPath: sourcesRegistryPath)),
              let sources = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return Set(sources)
    }
    
    private func saveTrackedSources(_ sources: Set<String>) {
        try? FileManager.default.createDirectory(atPath: forksDir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(Array(sources)) {
            try? data.write(to: URL(fileURLWithPath: sourcesRegistryPath))
        }
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
    
    // MARK: - Source Content Discovery
    
    func getSkillsInSource(source: String) -> [Skill] {
        let forkPath = getForkPath(source: source)
        var foundSkills: [Skill] = []
        
        if FileManager.default.fileExists(atPath: forkPath) {
            findSkillsInDir(dir: URL(fileURLWithPath: forkPath), skills: &foundSkills, baseDir: URL(fileURLWithPath: forkPath))
        }
        
        return foundSkills.sorted { $0.name < $1.name }
    }
    
    private func getForkPath(source: String) -> String {
        if source.contains("://") || source.hasPrefix("git@") || !FileManager.default.fileExists(atPath: source) {
            let safeSourceName = source.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
            let relativePath = "repos/\(safeSourceName)"
            return (forksDir as NSString).appendingPathComponent(relativePath)
        } else {
             // Local: use source directly
            return source
        }
    }

    // MARK: - Helper
    
    func getSkillMarkdownPath(skillName: String) -> String? {
        // 1. Try to find it in the registry source first (most reliable for original content)
        if let entry = getRegistry()[skillName] {
            let forkPath = (forksDir as NSString).appendingPathComponent(entry.relativeForkPath)
            let path = (forkPath as NSString).appendingPathComponent("SKILL.md")
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
            
            // Check direct local source
            if FileManager.default.fileExists(atPath: entry.originalSource) {
                 let localPath = (entry.originalSource as NSString).appendingPathComponent("SKILL.md")
                 if FileManager.default.fileExists(atPath: localPath) {
                     return localPath
                 }
            }
        }
        
        // 2. Fallback: Search in installed agents
        for agent in Agent.supportedAgents {
            let home = "/Users/\(NSUserName())"
            let expandedPath = agent.globalPath.replacingOccurrences(of: "~", with: home)
            
            let skillDir = (expandedPath as NSString).appendingPathComponent(skillName) // Assuming skill name is dir name commonly
            let skillMd = (skillDir as NSString).appendingPathComponent("SKILL.md")
            
            if FileManager.default.fileExists(atPath: skillMd) {
                return skillMd
            }
            
            // Also try iterating if name != dir name
            if let items = try? FileManager.default.contentsOfDirectory(atPath: expandedPath) {
                for item in items {
                    let itemPath = (expandedPath as NSString).appendingPathComponent(item)
                    let mdPath = (itemPath as NSString).appendingPathComponent("SKILL.md")
                    if FileManager.default.fileExists(atPath: mdPath) {
                        if let content = try? String(contentsOfFile: mdPath, encoding: .utf8),
                           let (name, _) = parseFrontmatter(content: content),
                           name == skillName {
                            return mdPath
                        }
                    }
                }
            }
        }
        
        return nil
    }

    // MARK: - Installation
    
    func installSkills(source: String, skillNames: [String], agentCliNames: [String], global: Bool = true) async throws -> String {
        // Validate source is not empty
        guard !source.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw NSError(domain: "SkillService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Source cannot be empty"])
        }
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
                // Update cache
                try await runShellCommandWithLogs(command: "git", args: ["-C", forkPath, "pull"])
            } else {
                let url = (!source.contains("://") && !source.hasPrefix("git@")) ? "https://github.com/\(source).git" : source
                try await runShellCommandWithLogs(command: "git", args: ["clone", url, forkPath])
            }
        } else {
            // It's a local folder: Use directly
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: source, isDirectory: &isDir), isDir.boolValue else {
                 throw NSError(domain: "SkillService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Local source directory not found: \(source)"])
            }
            relativePath = "" // Empty means local direct path
            forkPath = source
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
        
        // 4. Install from the Fork/Local Path
        var args = ["skills", "add", forkPath]
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
        
        let output = try await runShellCommandWithLogs(command: "npx", args: args, environment: ["PATH": "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"])
        
        await MainActor.run {
             getInstalledSkills()
        }
        
        return output
    }
    
    // MARK: - Project Installation
    
    func installSkillsToProject(source: String, skillNames: [String], agentCliNames: [String], projectPath: String) async throws -> String {
        print("[DEBUG] installSkillsToProject: source=\(source), skills=\(skillNames)")
        
        // Validate source is not empty
        guard !source.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw NSError(domain: "SkillService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Source cannot be empty"])
        }
        // 1. Prepare ~/.forks
        try FileManager.default.createDirectory(atPath: forksDir, withIntermediateDirectories: true)
        
        let forkPath: String
        let relativePath: String
        
        // 2. Clone or use local source
        if source.contains("://") || source.hasPrefix("git@") || !FileManager.default.fileExists(atPath: source) {
            // It's a remote repo
            print("[DEBUG] Handling remote repo source")
            let safeSourceName = source.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
            relativePath = "repos/\(safeSourceName)"
            forkPath = (forksDir as NSString).appendingPathComponent(relativePath)
            
            if FileManager.default.fileExists(atPath: forkPath) {
                // Update cache
                print("[DEBUG] Updating existing repo at \(forkPath)")
                try await runShellCommandWithLogs(command: "git", args: ["-C", forkPath, "pull"])
            } else {
                let url = (!source.contains("://") && !source.hasPrefix("git@")) ? "https://github.com/\(source).git" : source
                print("[DEBUG] Cloning new repo from \(url) to \(forkPath)")
                try await runShellCommandWithLogs(command: "git", args: ["clone", url, forkPath])
            }
        } else {
            // It's a local folder: Use directly
            print("[DEBUG] Handling local folder source")
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: source, isDirectory: &isDir), isDir.boolValue else {
                 throw NSError(domain: "SkillService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Local source directory not found: \(source)"])
            }
            relativePath = "" // Empty means local direct path
            forkPath = source
        }
        
        // 3. Update Registry
        print("[DEBUG] Updating registry")
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
        
        // 4. Install to project path (run from project directory, not global)
        // skills add installs to project-level by default when run from a directory
        print("[DEBUG] Installing skill to project path: \(projectPath)")
        var args = ["skills", "add", forkPath]
        for skill in skillNames {
            args.append("--skill")
            args.append(skill)
        }
        for agent in agentCliNames {
            args.append("--agent")
            args.append(agent)
        }
        // Don't use --global, run from project directory instead
        args.append("--mode")
        args.append("copy")
        args.append("--yes")
        
        print("[DEBUG] Executing npx command")
        let output = try await runShellCommandWithLogs(command: "npx", args: args, environment: ["PATH": "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"], currentDirectory: projectPath)
        print("[DEBUG] Installation complete")
        
        return output
    }
    
    // MARK: - Update Logic
    
    private func checkSourceStatus(originalSource: String, relativeForkPath: String) async throws -> (Bool, Date?) {
        let forkPath = getForkPath(source: originalSource)

        if relativeForkPath.hasPrefix("repos/") {
            // Git Logic: Fetch and check status
            _ = try await runShellCommand(command: "git", args: ["-C", forkPath, "fetch"])
            // Check if behind
            let status = try await runShellCommand(command: "git", args: ["-C", forkPath, "status", "-uno"])
            return (status.contains("Your branch is behind"), Date())
        } else {
            // Local Logic: Check existance and modification dates
            var isDir: ObjCBool = false
            if !FileManager.default.fileExists(atPath: originalSource, isDirectory: &isDir) {
                throw NSError(domain: "SkillService", code: 404, userInfo: [NSLocalizedDescriptionKey: "SourceMissing"])
            }
            
            // Get modification date (directory or SKILL.md if exists for better precision?)
            // User just wants "last modification date/time". Directory mod time changes when content changes usually.
            // Let's check SKILL.md or the dir itself.
            let skillMdPath = (originalSource as NSString).appendingPathComponent("SKILL.md")
            let pathToStat = FileManager.default.fileExists(atPath: skillMdPath) ? skillMdPath : originalSource
            
            if let attr = try? FileManager.default.attributesOfItem(atPath: pathToStat),
               let date = attr[.modificationDate] as? Date {
                return (false, date)
            }
            
            return (false, Date())
        }
    }

    func checkForUpdates(skill: InstalledSkill, agentName: String) async throws -> Bool {
        var registry = getRegistry()
        guard let entry = registry[skill.name] else { return false }
        
        // This is single skill check, but logic is same
        let (updateAvailable, date) = try await checkSourceStatus(originalSource: entry.originalSource, relativeForkPath: entry.relativeForkPath)
        
        // Update registry
        registry[skill.name]?.lastChecked = date
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
        
        // Check if local source is missing?
        // If git, pull. If local, do nothing (we use it directly) but verify existence.
        
        let forkPath = getForkPath(source: entry.originalSource)
        
        // 1. Update the code
        if entry.relativeForkPath.hasPrefix("repos/") {
            try await runShellCommand(command: "git", args: ["-C", forkPath, "pull"])
        } else {
            // Local: verify existence
             if !FileManager.default.fileExists(atPath: forkPath) {
                 throw NSError(domain: "SkillService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Local source missing"])
             }
             // No copy needed
        }
        
        // 2. Re-install/Update
        // 2. Re-install/Update
        _ = try await uninstallSkill(skillName: skillName, agentName: agentName)
        
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
    
    // Moved to RegistryView, but keeping helper if needed or clean up later.
    // Assuming UI calls refreshRegistry directly now.
    
    func refreshRegistry() async {
        print("INFO: Refreshing registry...")
        var registry = getRegistry()
        var trackedSources = getTrackedSources()
        var sourcesToRemove: Set<String> = []
        
        // Group skills by source to minimize checks
        var skillsBySource: [String: [String]] = [:]
        for (name, entry) in registry {
            skillsBySource[entry.originalSource, default: []].append(name)
        }
        
        // Also include tracked sources that have no skills yet
        for source in trackedSources {
            if skillsBySource[source] == nil {
                skillsBySource[source] = []
            }
        }
        
        for (source, skillNames) in skillsBySource {
            // Get relative path if skill exists, otherwise look in tracked sources logic (might be new/empty)
            // If it's in trackedSources but not registry, we don't have relativeForkPath stored.
            // But we can deduce it.
            // Actually, registry items hold data. Tracked sources just holds the string.
            
            // If we have skills, use one entry. If not, determine typ.
            var relativePath = "unknown"
            if let firstName = skillNames.first, let entry = registry[firstName] {
                relativePath = entry.relativeForkPath
            } else {
                // Determine for empty source
                 if source.contains("://") || source.hasPrefix("git@") {
                     relativePath = "repos/..." // Doesnt matter for checkSourceStatus if we use getForkPath logic correctly?
                     // checkSourceStatus uses relativePath prefix to determine git vs local.
                     relativePath = "repos/placeholder"
                 } else {
                     relativePath = ""
                 }
            }
            
            print("INFO: Checking update for source: \(source)")
            
            do {
                let (updateAvailable, lastCheckedDate) = try await checkSourceStatus(originalSource: source, relativeForkPath: relativePath)
                
                if updateAvailable {
                    print("INFO: Update available for source: \(source)")
                }
                
                // Bulk update entries
                for name in skillNames {
                    if var entry = registry[name] {
                        entry.updateAvailable = updateAvailable
                        entry.lastChecked = lastCheckedDate
                        registry[name] = entry
                    }
                }
            } catch {
                let nsError = error as NSError
                if nsError.userInfo[NSLocalizedDescriptionKey] as? String == "SourceMissing" {
                    print("WARNING: Local source missing: \(source). Removing from registry.")
                    sourcesToRemove.insert(source)
                } else {
                    print("Error checking source \(source): \(error)")
                }
            }
        }
        
        // Remove missing sources
        for source in sourcesToRemove {
            // Remove skills
            let skillsToRemove = registry.filter { $0.value.originalSource == source }.map { $0.key }
            for skill in skillsToRemove {
                registry.removeValue(forKey: skill)
            }
            trackedSources.remove(source)
        }
        
        // Save
        saveRegistry(registry)
        saveTrackedSources(trackedSources)
        
        await MainActor.run {
            getInstalledSkills()
            self.registrySources = getRegistrySources()
        }
        print("INFO: Registry refresh complete")
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
