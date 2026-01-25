import SwiftUI

struct AgentDetailView: View {
    let agentName: String
    @ObservedObject var skillService: SkillService
    @Environment(\.dismiss) var dismiss
    
    @State private var removingSkill: String?
    @State private var showConfirm = false
    @State private var skillToUninstall: String?
    
    var agentSkills: [InstalledSkill] {
        skillService.installedSkills.filter { $0.agents.contains(agentName) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: "cpu.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .padding()
                    .background(agentColor(agentName).opacity(0.1))
                    .foregroundColor(agentColor(agentName))
                    .cornerRadius(16)
                
                VStack(alignment: .leading) {
                    Text(agentName)
                        .font(.largeTitle)
                        .bold()
                    Text("\(agentSkills.count) skill\(agentSkills.count != 1 ? "s" : "") installed")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Skills Table
            Table(agentSkills) {
                TableColumn("Skill") { skill in
                        Text(skill.name)
                            .font(.headline)
                }
                .width(min: 150)
                
                TableColumn("Description") { skill in
                    if let desc = skill.description {
                        Text(desc)
                            .foregroundColor(.secondary)
                    } else {
                        Text("—")
                            .foregroundColor(.secondary)
                    }
                }
                
                TableColumn("Action") { skill in
                    if removingSkill == skill.name {
                        ProgressView().controlSize(.small)
                    } else {
                        Button(action: {
                            skillToUninstall = skill.name
                            showConfirm = true
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.borderless) // Clean icon button style
                    }
                }
                .width(50)
            }
            .confirmationDialog("Uninstall Skill?", isPresented: $showConfirm, presenting: skillToUninstall) { skillName in
                Button("Uninstall \(skillName)", role: .destructive) {
                    uninstall(skill: skillName)
                }
                Button("Cancel", role: .cancel) {}
            } message: { skillName in
                Text("Are you sure you want to remove \(skillName) from \(agentName)?")
            }
            
            // Danger Zone (Footer)
            if !agentSkills.isEmpty {
                 Divider()
                 HStack {
                    Spacer()
                    Button("Remove All Skills", role: .destructive) {
                        removeAll()
                    }
                    .padding()
                }
                .background(Color.red.opacity(0.05))
            }
        }
        .navigationTitle(agentName)
    }
    
    private func uninstall(skill: String) {
        removingSkill = skill
        Task {
             do {
                try skillService.uninstallSkill(skillName: skill, agentName: agentName)
                skillService.getInstalledSkills()
            } catch {
                print("Failed to uninstall: \(error)")
            }
            removingSkill = nil
        }
    }
    
    private func removeAll() {
        // Full implementation would show another confirmation
        Task {
            for skill in agentSkills {
                uninstall(skill: skill.name)
            }
        }
    }
    
    private func agentColor(_ name: String) -> Color {
        let colors: [Color] = [.blue, .purple, .orange, .pink, .green, .teal, .indigo]
        let hash = name.hashValue
        return colors[abs(hash) % colors.count]
    }
}
