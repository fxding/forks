import SwiftUI

enum SkillSourceType: String, CaseIterable {
    case registry = "From Registry"
    case remote = "From Repo/Local Path"
}

struct AddSkillToProjectSheet: View {
    let project: Project
    @ObservedObject var projectService: ProjectService
    @ObservedObject var skillService: SkillService
    var onSuccess: (() -> Void)?
    
    @Environment(\.dismiss) var dismiss
    @StateObject private var agentService = AgentService()
    
    @State private var sourceType: SkillSourceType = .registry
    @State private var selectedSource: SkillService.RegistrySource?
    @State private var selectedSkill: Skill?
    @State private var newSourceUrl = ""
    @State private var availableSkills: [Skill] = []
    @State private var selectedAgents: Set<String> = []
    @State private var isLoading = false
    @State private var isInstalling = false
    @State private var errorMessage: String?
    
    var detectedProjectAgents: [Agent] {
        projectService.getProjectAgents(project: project)
    }
    
    var allSupportedAgents: [Agent] {
        // Show agents that are either already in project or globally detected
        let projectAgentNames = Set(detectedProjectAgents.map { $0.name })
        let globallyDetected = agentService.agents.filter { $0.detected }
        
        var agents = detectedProjectAgents
        for agent in globallyDetected {
            if !projectAgentNames.contains(agent.name) {
                agents.append(agent)
            }
        }
        return agents.sorted { $0.name < $1.name }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add Skill to Project")
                .font(.headline)
            
            // Source Type Picker
            Picker("Source", selection: $sourceType) {
                ForEach(SkillSourceType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: sourceType) { _ in
                selectedSkill = nil
                availableSkills = []
                errorMessage = nil
            }
            
            if sourceType == .registry {
                registrySourceView
            } else {
                remoteSourceView
            }
            
            Divider()
            
            // Agent Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Install for Agents")
                    .font(.caption)
                    .fontWeight(.medium)
                
                if allSupportedAgents.isEmpty {
                    Text("No agents available")
                        .foregroundColor(.secondary)
                        .font(.callout)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(allSupportedAgents, id: \.name) { agent in
                                Toggle(isOn: Binding(
                                    get: { selectedAgents.contains(agent.cliName) },
                                    set: { isSelected in
                                        if isSelected { selectedAgents.insert(agent.cliName) }
                                        else { selectedAgents.remove(agent.cliName) }
                                    }
                                )) {
                                    HStack {
                                        Image(systemName: "cpu")
                                        Text(agent.name)
                                        if detectedProjectAgents.contains(where: { $0.name == agent.name }) {
                                            Text("(in project)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .toggleStyle(.checkbox)
                            }
                        }
                    }
                    .frame(maxHeight: 120)
                }
            }
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            if isLoading || isInstalling {
                ProgressView(isInstalling ? "Installing..." : "Loading...")
                    .controlSize(.small)
            }
            
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                
                Button("Install") {
                    installSkill()
                }
                .disabled(selectedSkill == nil || selectedAgents.isEmpty || isInstalling)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 8)
        }
        .padding(24)
        .frame(width: 500, height: 550)
        .onAppear {
            agentService.refreshAgents()
        }
    }
    
    private var registrySourceView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Source Picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Registry Source")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Picker("Source", selection: $selectedSource) {
                    Text("Select a source...").tag(nil as SkillService.RegistrySource?)
                    ForEach(skillService.registrySources, id: \.id) { source in
                        Text(source.path)
                            .lineLimit(1)
                            .tag(source as SkillService.RegistrySource?)
                    }
                }
                .onChange(of: selectedSource) { source in
                    if let source = source {
                        availableSkills = skillService.getSkillsInSource(source: source.path)
                    } else {
                        availableSkills = []
                    }
                    selectedSkill = nil
                }
            }
            
            // Skill Picker
            if selectedSource != nil {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Skill")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    if availableSkills.isEmpty {
                        Text("No skills found in this source")
                            .foregroundColor(.secondary)
                            .font(.callout)
                    } else {
                        Picker("Skill", selection: $selectedSkill) {
                            Text("Select a skill...").tag(nil as Skill?)
                            ForEach(availableSkills, id: \.name) { skill in
                                Text(skill.name).tag(skill as Skill?)
                            }
                        }
                    }
                }
            }
            
            if skillService.registrySources.isEmpty {
                Text("No sources in registry. Add a source in the Registry tab or use 'From Repo/Local Path'.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var remoteSourceView: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Repository URL or Local Path")
                    .font(.caption)
                    .fontWeight(.medium)
                
                HStack {
                    TextField("user/repo or /path/to/skills", text: $newSourceUrl)
                        .textFieldStyle(.roundedBorder)
                    
                    Button {
                        let openPanel = NSOpenPanel()
                        openPanel.canChooseFiles = false
                        openPanel.canChooseDirectories = true
                        openPanel.allowsMultipleSelection = false
                        openPanel.begin { response in
                            if response == .OK, let url = openPanel.url {
                                newSourceUrl = url.path
                            }
                        }
                    } label: {
                        Image(systemName: "folder")
                    }
                    
                    Button("Load") {
                        loadSkillsFromSource()
                    }
                    .disabled(newSourceUrl.isEmpty || isLoading)
                }
            }
            
            // Skill Selection
            if !availableSkills.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Skill")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Picker("Skill", selection: $selectedSkill) {
                        Text("Select a skill...").tag(nil as Skill?)
                        ForEach(availableSkills, id: \.name) { skill in
                            Text(skill.name).tag(skill as Skill?)
                        }
                    }
                }
            }
        }
    }
    
    private func loadSkillsFromSource() {
        guard !newSourceUrl.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await skillService.fetchSkills(source: newSourceUrl)
                availableSkills = skillService.availableSkills
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
    
    private func installSkill() {
        guard let skill = selectedSkill else { return }
        
        isInstalling = true
        errorMessage = nil
        
        let source: String
        if sourceType == .registry, let registrySource = selectedSource {
            source = registrySource.path
        } else {
            source = newSourceUrl
        }
        
        Task {
            do {
                // Install to project path (not global)
                _ = try await skillService.installSkillsToProject(
                    source: source,
                    skillNames: [skill.name],
                    agentCliNames: Array(selectedAgents),
                    projectPath: project.path
                )
                
                // If from remote, add to registry
                if sourceType == .remote && !newSourceUrl.isEmpty {
                    try await skillService.addRegistrySource(source: newSourceUrl)
                }
                
                onSuccess?()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isInstalling = false
        }
    }
}
