import Foundation
import SwiftUI
import AppKit
import Combine

class SkillService: ObservableObject {

    @Published var availableSkills: [Skill] = []
    @Published var installedSkills: [InstalledSkill] = []
    @Published var registrySources: [RegistrySource] = []
    @Published var logs: String = ""
    @Published var isCancelled: Bool = false
    
    // Global Search Persistence
    @Published var globalSearchQuery: String = ""
    @Published var globalSearchResults: [SearchSkill] = []
    
    // Source Detail Persistence
    @Published var sourceFilterText: String = ""
    
    private let forksDir = NSString(string: "~/.forks").expandingTildeInPath
    private var currentProcess: Process?
    
    private let SKIP_DIRS = ["node_modules", ".git", "dist", "build", "__pycache__", "DerivedData"]
    
    private func shouldInstallInternalSkills() -> Bool {
        let envVal = ProcessInfo.processInfo.environment["INSTALL_INTERNAL_SKILLS"]
        return envVal == "1" || envVal == "true"
    }
    
    private func getPrioritySearchDirs(searchPath: String) -> [String] {
        var paths: [String] = [
            searchPath,
            (searchPath as NSString).appendingPathComponent("skills"),
            (searchPath as NSString).appendingPathComponent("skills/.curated"),
            (searchPath as NSString).appendingPathComponent("skills/.experimental"),
            (searchPath as NSString).appendingPathComponent("skills/.system")
        ]
        
        // Add agent-specific paths from Agent model
        for agent in Agent.supportedAgents {
            let path = (searchPath as NSString).appendingPathComponent(agent.projectPath)
            if !paths.contains(path) {
                paths.append(path)
            }
        }
        
        return paths
    }


    
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
        guard !source.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw NSError(domain: "SkillService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Source cannot be empty"])
        }

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("forks-clones")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let id = UUID().uuidString
        let cloneDir = tempDir.appendingPathComponent("repo-\(id)")

        let searchPath: String
        let isLocal = !isRemoteSource(source)

        if isLocal {
            searchPath = source
        } else {
            let url = getGitUrl(for: source)
            try await runShellCommand(command: "git", args: ["clone", "--depth", "1", url, cloneDir.path])
            searchPath = cloneDir.path
        }

        let foundSkills = discoverSkills(in: searchPath)

        if !isLocal {
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

        let sortedSkills = Array(skillMap.values).sorted { $0.name < $1.name }
        await MainActor.run {
            self.availableSkills = sortedSkills
        }
    }

    private func discoverSkills(in searchPath: String) -> [Skill] {
        var foundSkills: [Skill] = []
        var seenNames = Set<String>()
        
        // 1. Direct check (if path is a skill)
        let rootSkillMd = (searchPath as NSString).appendingPathComponent("SKILL.md")
        if FileManager.default.fileExists(atPath: rootSkillMd) {
            if let content = try? String(contentsOfFile: rootSkillMd, encoding: .utf8),
               let skill = parseSkillMd(content: content, path: rootSkillMd) {
                foundSkills.append(skill)
                seenNames.insert(skill.name)
            }
        }
        
        // 2. Priority search
        let priorityDirs = getPrioritySearchDirs(searchPath: searchPath)
        for dir in priorityDirs {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: dir, isDirectory: &isDir), isDir.boolValue {
                if let items = try? FileManager.default.contentsOfDirectory(atPath: dir) {
                    for item in items {
                        let skillDir = (dir as NSString).appendingPathComponent(item)
                        var itemIsDir: ObjCBool = false
                        if FileManager.default.fileExists(atPath: skillDir, isDirectory: &itemIsDir), itemIsDir.boolValue {
                            let skillMdPath = (skillDir as NSString).appendingPathComponent("SKILL.md")
                            if FileManager.default.fileExists(atPath: skillMdPath) {
                                if let content = try? String(contentsOfFile: skillMdPath, encoding: .utf8),
                                   let skill = parseSkillMd(content: content, path: skillMdPath) {
                                    if !seenNames.contains(skill.name) {
                                        foundSkills.append(skill)
                                        seenNames.insert(skill.name)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // 3. Fallback recursive search
        if foundSkills.isEmpty {
            findSkillsInDir(dir: URL(fileURLWithPath: searchPath), skills: &foundSkills, baseDir: URL(fileURLWithPath: searchPath), seenNames: &seenNames)
        }
        
        return foundSkills
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
    private func findSkillsInDir(dir: URL, skills: inout [Skill], baseDir: URL, seenNames: inout Set<String>) {
        do {
            let items = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            for item in items {
                let itemPath = dir.appendingPathComponent(item.lastPathComponent)
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: itemPath.path, isDirectory: &isDir) {
                    if isDir.boolValue {
                        let name = item.lastPathComponent
                        if !name.hasPrefix(".") && !SKIP_DIRS.contains(name) {
                            findSkillsInDir(dir: itemPath, skills: &skills, baseDir: baseDir, seenNames: &seenNames)
                        }
                    } else if item.lastPathComponent == "SKILL.md" {
                        if let content = try? String(contentsOfFile: itemPath.path, encoding: .utf8),
                           let skill = parseSkillMd(content: content, path: itemPath.path) {
                            if !seenNames.contains(skill.name) {
                                skills.append(skill)
                                seenNames.insert(skill.name)
                            }
                        }
                    }
                }
            }
        } catch {
            print("Failed to read dir \(dir): \(error)")
        }
    }

    
    private func parseSkillMd(content: String, path: String) -> Skill? {
        guard let (name, description, metadata) = parseFrontmatterWithMetadata(content: content) else { return nil }
        
        let isInternal = (metadata["internal"] as? Bool) == true
        if isInternal && !shouldInstallInternalSkills() {
            return nil
        }
        
        let agent = detectAgentFromPath(path: path)
        return Skill(name: name, description: description, availableAgents: agent != nil ? [agent!] : [], metadata: metadata)
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


    private func parseFrontmatterWithMetadata(content: String) -> (name: String, description: String?, metadata: [String: AnyHashable])? {
        guard content.hasPrefix("---") else { return nil }
        let components = content.components(separatedBy: "---")
        guard components.count >= 3 else { return nil }
        
        let frontmatter = components[1]
        var name: String?
        var description: String?
        var metadata: [String: AnyHashable] = [:]
        
        var currentTopLevelKey: String?
        
        frontmatter.enumerateLines { line, _ in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { return }
            
            if trimmed.hasPrefix("name:") {
                name = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: .init(charactersIn: "\"'"))
            } else if trimmed.hasPrefix("description:") {
                description = String(trimmed.dropFirst(12)).trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: .init(charactersIn: "\"'"))
            } else if trimmed.hasPrefix("metadata:") {
                currentTopLevelKey = "metadata"
            } else if let keyPath = currentTopLevelKey, line.hasPrefix("  ") {
                // Simple nested parsing
                let subLine = line.trimmingCharacters(in: .whitespaces)
                let subParts = subLine.components(separatedBy: ":")
                if subParts.count >= 2 {
                    let k = subParts[0].trimmingCharacters(in: .whitespaces)
                    let v = subParts[1...].joined(separator: ":").trimmingCharacters(in: .whitespaces)
                    
                    if keyPath == "metadata" {
                        if v == "true" { metadata[k] = true }
                        else if v == "false" { metadata[k] = false }
                        else { metadata[k] = v.trimmingCharacters(in: .init(charactersIn: "\"'")) }
                    }
                }
            } else {
                currentTopLevelKey = nil
            }
        }
        
        if let name = name {
            return (name, description, metadata)
        }
        return nil
    }
    
    // Kept for backward compatibility if needed by other methods not yet updated
    private func parseFrontmatter(content: String) -> (name: String, description: String?)? {
        if let res = parseFrontmatterWithMetadata(content: content) {
            return (res.name, res.description)
        }
        return nil
    }

    
    // MARK: - Shell Execution

    private func runShellCommand(command: String, args: [String], environment: [String: String]? = nil, currentDirectory: String? = nil, updateLogs: Bool = false) async throws -> String {
        let commandLine = "\(command) \(args.joined(separator: " "))"
        print("[DEBUG] Executing: \(commandLine)")

        if updateLogs {
            await MainActor.run {
                if isCancelled { return }
                self.appendLog("$ \(commandLine)\n")
                if let cwd = currentDirectory { self.appendLog("  (in \(cwd))\n") }
            }
        }

        if updateLogs && isCancelled {
             throw NSError(domain: "SkillService", code: -999, userInfo: [NSLocalizedDescriptionKey: "Operation cancelled"])
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let task = Process()

                // Store process reference
                if updateLogs {
                    DispatchQueue.main.async { self?.currentProcess = task }
                }

                // Resolve executable
                let executablePaths = ["/usr/bin/", "/usr/local/bin/", "/opt/homebrew/bin/"]
                let launchPath = executablePaths.map { $0 + command }.first(where: { FileManager.default.fileExists(atPath: $0) }) ?? "/usr/bin/env"

                task.executableURL = URL(fileURLWithPath: launchPath)
                task.arguments = launchPath == "/usr/bin/env" ? [command] + args : args

                // Environment
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

                // Close stdin
                let inPipe = Pipe()
                task.standardInput = inPipe

                var outputData = Data()
                let group = DispatchGroup()
                group.enter()

                outPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if data.isEmpty {
                        outPipe.fileHandleForReading.readabilityHandler = nil
                        group.leave()
                    } else {
                        outputData.append(data)
                        if updateLogs, let str = String(data: data, encoding: .utf8) {
                            DispatchQueue.main.async { self?.logs += str }
                        }
                    }
                }

                do {
                    try task.run()
                    try? inPipe.fileHandleForWriting.close()
                    task.waitUntilExit()

                    if updateLogs {
                        DispatchQueue.main.async { self?.currentProcess = nil }
                    }

                    group.wait()
                    let output = String(data: outputData, encoding: .utf8) ?? ""

                    if task.terminationStatus == 0 {
                        if updateLogs {
                            DispatchQueue.main.async { self?.logs += "\n✅ Command completed successfully\n" }
                        }
                        continuation.resume(returning: output)
                    } else {
                        if updateLogs {
                            DispatchQueue.main.async { self?.logs += "\n❌ Command failed with exit code \(task.terminationStatus)\n" }
                        }
                        // Check for cancellation
                        if task.terminationStatus == 15 || (self?.isCancelled ?? false) {
                            continuation.resume(throwing: NSError(domain: "SkillService", code: -999, userInfo: [NSLocalizedDescriptionKey: "Operation cancelled"]))
                        } else {
                            continuation.resume(throwing: NSError(domain: "Shell", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: output]))
                        }
                    }
                } catch {
                    if updateLogs {
                        DispatchQueue.main.async {
                            self?.currentProcess = nil
                            self?.logs += "\n❌ Error: \(error.localizedDescription)\n"
                        }
                    }
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // Compatibility wrappers
    private func runShellCommand(command: String, args: [String], environment: [String: String]? = nil, currentDirectory: String? = nil) async throws -> String {
        try await runShellCommand(command: command, args: args, environment: environment, currentDirectory: currentDirectory, updateLogs: false)
    }

    private func runShellCommandWithLogs(command: String, args: [String], environment: [String: String]? = nil, currentDirectory: String? = nil) async throws -> String {
        try await runShellCommand(command: command, args: args, environment: environment, currentDirectory: currentDirectory, updateLogs: true)
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
        if isRemoteSource(source) {
            let safeSourceName = source.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
            let relativePath = "repos/\(safeSourceName)"
            let forkPath = (forksDir as NSString).appendingPathComponent(relativePath)

            if FileManager.default.fileExists(atPath: forkPath) {
                _ = try await runShellCommand(command: "git", args: ["-C", forkPath, "pull"])
            } else {
                let url = getGitUrl(for: source)
                _ = try await runShellCommand(command: "git", args: ["clone", url, forkPath])
            }
        } else {
            // Local folder: verify existence
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: source, isDirectory: &isDir), isDir.boolValue else {
                throw NSError(domain: "SkillService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Local source directory not found: \(source)"])
            }
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
        if FileManager.default.fileExists(atPath: forkPath) {
            return discoverSkills(in: forkPath).sorted { $0.name < $1.name }
        }
        return []
    }

    
    private func getForkPath(source: String) -> String {
        if isRemoteSource(source) {
            let safeSourceName = source.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
            let relativePath = "repos/\(safeSourceName)"
            return (forksDir as NSString).appendingPathComponent(relativePath)
        } else {
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
        guard !source.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw NSError(domain: "SkillService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Source cannot be empty"])
        }

        try FileManager.default.createDirectory(atPath: forksDir, withIntermediateDirectories: true)

        let forkPath: String
        let relativePath: String

        if isRemoteSource(source) {
            let safeSourceName = source.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
            relativePath = "repos/\(safeSourceName)"
            forkPath = (forksDir as NSString).appendingPathComponent(relativePath)

            if FileManager.default.fileExists(atPath: forkPath) {
                _ = try await runShellCommandWithLogs(command: "git", args: ["-C", forkPath, "pull"])
            } else {
                let url = getGitUrl(for: source)
                _ = try await runShellCommandWithLogs(command: "git", args: ["clone", url, forkPath])
            }
        } else {
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: source, isDirectory: &isDir), isDir.boolValue else {
                 throw NSError(domain: "SkillService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Local source directory not found: \(source)"])
            }
            relativePath = ""
            forkPath = source
        }

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

        var args = ["skills", "add", forkPath]
        for skill in skillNames {
            args.append(contentsOf: ["--skill", skill])
        }
        for agent in agentCliNames {
            args.append(contentsOf: ["--agent", agent])
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

        guard !source.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw NSError(domain: "SkillService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Source cannot be empty"])
        }

        try FileManager.default.createDirectory(atPath: forksDir, withIntermediateDirectories: true)

        let forkPath: String
        let relativePath: String

        if isRemoteSource(source) {
            let safeSourceName = source.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
            relativePath = "repos/\(safeSourceName)"
            forkPath = (forksDir as NSString).appendingPathComponent(relativePath)

            if FileManager.default.fileExists(atPath: forkPath) {
                print("[DEBUG] Updating existing repo at \(forkPath)")
                _ = try await runShellCommandWithLogs(command: "git", args: ["-C", forkPath, "pull"])
            } else {
                let url = getGitUrl(for: source)
                print("[DEBUG] Cloning new repo from \(url) to \(forkPath)")
                _ = try await runShellCommandWithLogs(command: "git", args: ["clone", url, forkPath])
            }
        } else {
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: source, isDirectory: &isDir), isDir.boolValue else {
                 throw NSError(domain: "SkillService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Local source directory not found: \(source)"])
            }
            relativePath = ""
            forkPath = source
        }

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

        var args = ["skills", "add", forkPath]
        for skill in skillNames {
            args.append(contentsOf: ["--skill", skill])
        }
        for agent in agentCliNames {
            args.append(contentsOf: ["--agent", agent])
        }
        args.append(contentsOf: ["--mode", "copy", "--yes"])

        return try await runShellCommandWithLogs(command: "npx", args: args, environment: ["PATH": "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"], currentDirectory: projectPath)
    }

    // MARK: - Helper Methods

    private func isRemoteSource(_ source: String) -> Bool {
        return source.contains("://") || source.hasPrefix("git@") || !FileManager.default.fileExists(atPath: source)
    }

    private func getGitUrl(for source: String) -> String {
        if source.isEmpty { return source }

        if source.contains("://") || source.hasPrefix("git@") {
            return source
        }

        // Handle explicit subdirectory in the source string (e.g. "owner/repo/subdir")
        // We only want to clone the repo part
        let components = source.split(separator: "/")
        if components.count >= 2 {
            let owner = components[0]
            var repo = String(components[1])

            // Avoid .git.git if source was "owner/repo.git/subdir"
            if repo.hasSuffix(".git") {
                repo = String(repo.dropLast(4))
            }

            return "https://github.com/\(owner)/\(repo).git"
        }

        // Handle "owner/repo" or "repo" shorthand
        var repo = source
        if repo.hasSuffix(".git") {
            repo = String(repo.dropLast(4))
        }
        return "https://github.com/\(repo).git"
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
    
    func updateAllSkillsInSource(source: String) async throws {
        print("[DEBUG] Updating all skills in source: \(source)")
        
        // 1. Refresh installed skills to ensure we have latest state
        await MainActor.run { self.getInstalledSkills() }
        
        // 2. Filter skills belonging to this source
        // We use the registry to find skills from this source
        var registry = getRegistry() // Var because we modify it
        let skillsKeysFromSource = registry.filter { $0.value.originalSource == source }.map { $0.key }
        
        // Find these in installedSkills to get their agents
        let targetSkills = installedSkills.filter { skillsKeysFromSource.contains($0.name) }
        
        // 3. Pull updates ONCE (Moved before empty check)
        let forkPath = getForkPath(source: source)
        
        // Check if it's a repo based on path format or registry info
        // We look at registry entries even if not installed to guess if it's a repo
        let isRemote = source.contains("://") || source.hasPrefix("git@")
        // Any registry entry has 'repos/'?
        let hasRepoEntry = skillsKeysFromSource.contains { registry[$0]?.relativeForkPath.hasPrefix("repos/") == true }
        
        if isRemote || hasRepoEntry {
             print("[DEBUG] Pulling latest changes for \(source) at \(forkPath)...")
             // We don't check for errors here strictly, just try to pull
             _ = try? await runShellCommand(command: "git", args: ["-C", forkPath, "pull"])
        }
        
        // 4. Update Registry Flags for ALL associated skills (installed or not)
        // This clears the "green dot" immediately
        let now = Date()
        for key in skillsKeysFromSource {
            if var entry = registry[key] {
                entry.updateAvailable = false
                entry.lastChecked = now
                registry[key] = entry
            }
        }
        saveRegistry(registry) // Save cleaned state
        
        if targetSkills.isEmpty {
            print("[DEBUG] No currently installed skills found for source \(source). Registry flags cleared.")
             // Continue to refresh UI
        } else {
            // 5. Update each INSTALLED skill
             for skill in targetSkills {
                for agent in skill.agents {
                    print("[DEBUG] Updating \(skill.name) for \(agent)...")
                    try await updateSkill(skillName: skill.name, agentName: agent, source: source, skipPull: true)
                }
            }
        }
        
        await MainActor.run {
            self.getInstalledSkills()
            // Properly refresh registry to clear update status on source
            Task {
                await self.refreshRegistry()
            }
        }
    }

    func updateSkill(skillName: String, agentName: String, source: String, skipPull: Bool = false) async throws {
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
        if !skipPull {
            if entry.relativeForkPath.hasPrefix("repos/") {
                try await runShellCommand(command: "git", args: ["-C", forkPath, "pull"])
            } else {
                // Local: verify existence
                 if !FileManager.default.fileExists(atPath: forkPath) {
                     throw NSError(domain: "SkillService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Local source missing"])
                 }
                 // No copy needed
            }
        }
        
        // 2. Re-install/Update
        // 2. Re-install/Update
        _ = try await uninstallSkill(skillName: skillName, agentName: agentName)
        
        // Get agent cli name
        let agentCli = Agent.supportedAgents.first(where: { $0.name == agentName })?.cliName ?? agentName.lowercased()
        
        let args = ["skills", "add", forkPath, "--skill", skillName, "--agent", agentCli, "--global", "--yes"]
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
            // Determine relativePath and type
            var relativePath = ""
            // Try to find from existing entry first
            if let firstName = skillNames.first, let entry = registry[firstName] {
                relativePath = entry.relativeForkPath
            } else {
                // Fallback for source with no installed skills
                 if source.contains("://") || source.hasPrefix("git@") {
                     let safeSourceName = source.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
                     relativePath = "repos/\(safeSourceName)"
                 }
            }
            
            print("INFO: Checking update for source: \(source)")
            
            do {
                let (updateAvailable, lastCheckedDate) = try await checkSourceStatus(originalSource: source, relativeForkPath: relativePath)
                
                if updateAvailable {
                    print("INFO: Update available for source: \(source)")
                }
                
                // Bulk update entries for installed skills
                for name in skillNames {
                    if var entry = registry[name] {
                        entry.updateAvailable = updateAvailable
                        entry.lastChecked = lastCheckedDate
                        registry[name] = entry
                    }
                }
                
                // If no skills are installed, we still want to persist the source status.
                // Currently RegistrySource is computed from RegistryEntry (installed skills).
                // If we want to show "Update Available" for a source with 0 skills, we need a place to store it.
                // However, `RegistrySource` struct in `getRegistrySources` is re-generated every time.
                // And `getRegistrySources` uses `registry` to find status.
                // If there are no registry entries for this source, we have nowhere to store the status!
                // FIX: We should probably add a "SourceStatus" dictionary or similar if we really care about empty sources.
                // BUT, for now, the user requirement implies "installed skills" context usually.
                // If I have a repo added but no skills, do I care if it has updates? Maybe.
                // But the current data model `RegistryEntry` is per-skill.
                // To support this without schema migration, we can't easily store it.
                // So we accept that only sources with >0 skills will show updates for now.
                
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
