import SwiftUI

struct InstallSheet: View {
    let skill: Skill
    let source: String
    @ObservedObject var agentService: AgentService
    @ObservedObject var skillService: SkillService
    
    @Environment(\.dismiss) var dismiss
    @State private var selectedAgents: Set<String> = []
    @State private var isInstalling = false
    @State private var installError: String?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Install \(skill.name)")
                .font(.title2)
                .padding(.top)
            
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
                .disabled(selectedAgents.isEmpty || isInstalling)
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
                _ = try await skillService.installSkills(
                    source: source,
                    skillNames: [skill.name],
                    agentCliNames: Array(selectedAgents),
                    global: true
                )
                dismiss()
            } catch {
                installError = error.localizedDescription
            }
            isInstalling = false
        }
    }
}
