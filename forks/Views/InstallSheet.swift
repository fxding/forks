import SwiftUI

struct InstallSheet: View {
    let skillNames: [String]
    let source: String
    @ObservedObject var agentService: AgentService
    @ObservedObject var skillService: SkillService
    
    var onSuccess: (() -> Void)?
    
    init(skill: Skill, source: String, agentService: AgentService, skillService: SkillService, onSuccess: (() -> Void)? = nil) {
        self.skillNames = [skill.name]
        self.source = source
        self.agentService = agentService
        self.skillService = skillService
        self.onSuccess = onSuccess
    }
    
    init(skillService: SkillService, agentService: AgentService, prefilledRepoUrl: String, prefilledSkills: [String], onSuccess: (() -> Void)? = nil) {
        self.skillService = skillService
        self.agentService = agentService
        self.source = prefilledRepoUrl
        self.skillNames = prefilledSkills
        self.onSuccess = onSuccess
    }
    
    @StateObject private var projectService = ProjectService()
    
    @Environment(\.dismiss) var dismiss
    @State private var selectedAgents: Set<String> = []
    @State private var isInstalling = false
    @State private var installError: String?
    @State private var installationMode: InstallationMode = .global
    @State private var selectedProject: Project?
    
    enum InstallationMode: String, CaseIterable, Identifiable {
        case global = "Global"
        case project = "Project"
        var id: String { rawValue }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text(skillNames.count == 1 ? "Install \(skillNames[0])" : "Install \(skillNames.count) Skills")
                .font(.title2)
                .padding(.top)
            
            if isInstalling {
                ProgressView("Installing...")
                    .controlSize(.regular)
                    .padding()
            } else {
                VStack(spacing: 20) {
                    Picker("", selection: $installationMode) {
                        ForEach(InstallationMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 200) // Center and fixed width
                    
                    VStack(alignment: .leading) {
                        if installationMode == .project {
                            Picker("Select Project", selection: $selectedProject) {
                                Text("Select a project...").tag(nil as Project?)
                                ForEach(projectService.projects) { project in
                                    Text(project.name).tag(project as Project?)
                                }
                            }
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, 10)
                        }
                    
                    Text("Select agents to install this skill for:")
                        .font(.subheadline)
                    
                    List {
                        ForEach(agentService.agents.filter { $0.detected }, id: \.name) { agent in
                            HStack {
                                Toggle(isOn: Binding(
                                    get: { selectedAgents.contains(agent.cliName) },
                                    set: { isSelected in
                                        if isSelected { selectedAgents.insert(agent.cliName) }
                                        else { selectedAgents.remove(agent.cliName) }
                                    }
                                )) {
                                    HStack {
                                        Image(systemName: "terminal")
                                        Text(agent.name)
                                    }
                                }
                                .toggleStyle(.checkbox)
                            }
                        }
                        if agentService.agents.filter({ $0.detected }).isEmpty {
                            Text("No agents detected locally.")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .listStyle(.bordered)
                    .frame(height: 200)
                }
            }
        }
            
            if let error = installError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Install") {
                    install()
                }
                .disabled(selectedAgents.isEmpty || isInstalling || (installationMode == .project && selectedProject == nil))
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(minWidth: 350)
        .padding()
        .onAppear {
            agentService.refreshAgents()
        }
    }
    
    private func install() {
        isInstalling = true
        installError = nil
        Task {
            do {
                if installationMode == .global {
                    _ = try await skillService.installSkills(
                        source: source,
                        skillNames: skillNames,
                        agentCliNames: Array(selectedAgents),
                        global: true
                    )
                } else if let project = selectedProject {
                    _ = try await skillService.installSkillsToProject(
                        source: source,
                        skillNames: skillNames,
                        agentCliNames: Array(selectedAgents),
                        projectPath: project.path
                    )
                }
                onSuccess?()
                dismiss()
            } catch {
                installError = error.localizedDescription
            }
            isInstalling = false
        }
    }
}
