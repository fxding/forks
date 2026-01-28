import SwiftUI



struct AddSkillToProjectSheet: View {
    let project: Project
    @ObservedObject var projectService: ProjectService
    @ObservedObject var skillService: SkillService
    var onSuccess: (() -> Void)?
    
    @Environment(\.dismiss) var dismiss
    @StateObject private var agentService = AgentService()
    
    @State private var selectedSource: SkillService.RegistrySource?
    @State private var selectedSkillNames: Set<String> = []
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
        VStack(spacing: 16) {
            Text("Add Skill to Project")
                .font(.headline)
            
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
                .labelsHidden()
                .onChange(of: selectedSource) { source in
                    if let source = source {
                        availableSkills = skillService.getSkillsInSource(source: source.path)
                    } else {
                        availableSkills = []
                    }
                    selectedSkillNames = []
                }
            }
            
            if selectedSource != nil {
                Divider()
                
                HStack(alignment: .top, spacing: 20) {
                    // Skill Selection Column
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Skills")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        if availableSkills.isEmpty {
                            Text("No skills found")
                                .foregroundColor(.secondary)
                                .font(.callout)
                        } else {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(availableSkills, id: \.name) { skill in
                                        Toggle(isOn: Binding(
                                            get: { selectedSkillNames.contains(skill.name) },
                                            set: { isSelected in
                                                if isSelected { selectedSkillNames.insert(skill.name) }
                                                else { selectedSkillNames.remove(skill.name) }
                                            }
                                        )) {
                                            Text(skill.name)
                                        }
                                        .toggleStyle(.checkbox)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    Divider()
                    
                    // Agent Selection Column
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Agents")
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
                                            HStack(spacing: 4) {
                                                Image(systemName: "cpu")
                                                    .font(.caption)
                                                Text(agent.name)
                                                if detectedProjectAgents.contains(where: { $0.name == agent.name }) {
                                                    Text("(in project)")
                                                        .font(.caption2)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                        }
                                        .toggleStyle(.checkbox)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(height: 200) // Fixed height for the selection row
            } else if skillService.registrySources.isEmpty {
                Text("No sources in registry. Add a source in the Registry tab.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Spacer()
                    .frame(height: 200)
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
                .disabled(selectedSkillNames.isEmpty || selectedAgents.isEmpty || isInstalling)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 8)
        }
        .padding(20)
        .frame(width: 550) // Slightly wider for two columns
        .onAppear {
            agentService.refreshAgents()
        }
    }
    
    private func installSkill() {
        guard !selectedSkillNames.isEmpty else { return }
        
        isInstalling = true
        errorMessage = nil
        
        guard let registrySource = selectedSource else { return }
        let source = registrySource.path
        
        Task {
            print("[DEBUG] AddSkillToProjectSheet: Install triggered for \(selectedSkillNames) from \(source)")
            do {
                // Install to project path (not global)
                let output = try await skillService.installSkillsToProject(
                    source: source,
                    skillNames: Array(selectedSkillNames),
                    agentCliNames: Array(selectedAgents),
                    projectPath: project.path
                )
                print("[DEBUG] AddSkillToProjectSheet: Install success. Output: \(output)")
                
                onSuccess?()
                dismiss()
            } catch {
                print("[DEBUG] AddSkillToProjectSheet: Install failed with error: \(error)")
                errorMessage = error.localizedDescription
            }
            isInstalling = false
        }
    }
}
