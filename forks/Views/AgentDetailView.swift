import SwiftUI

struct AgentDetailView: View {
    let agentName: String
    @ObservedObject var skillService: SkillService
    @Environment(\.dismiss) var dismiss
    
    @State private var removingSkill: String?
    @State private var showConfirm = false
    @State private var skillToUninstall: String?
    @State private var showRemoveAllConfirm = false
    @State private var showReinstallAllConfirm = false
    @State private var isProcessingBulk = false
    
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
            
            // Sub-header Actions
            if !agentSkills.isEmpty {
                HStack {
                    if isProcessingBulk {
                        ProgressView().controlSize(.small)
                            .padding(.leading, 8)
                    }
                    
                    Spacer()
                    
                    Button(action: { showReinstallAllConfirm = true }) {
                        Label("Reinstall All", systemImage: "arrow.clockwise.circle")
                    }
                    .buttonStyle(.bordered)
                    .disabled(isProcessingBulk)
                    
                    Button(role: .destructive, action: { showRemoveAllConfirm = true }) {
                        Label("Remove All", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                    .disabled(isProcessingBulk)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                
                Divider()
            }
            
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
                        .disabled(isProcessingBulk)
                    }
                }
                .width(50)
            }
        }
        .confirmationDialog("Uninstall Skill?", isPresented: $showConfirm, presenting: skillToUninstall) { skillName in
            Button("Uninstall \(skillName)", role: .destructive) {
                uninstall(skill: skillName)
            }
            Button("Cancel", role: .cancel) {}
        } message: { skillName in
            Text("Are you sure you want to remove \(skillName) from \(agentName)?")
        }
        .confirmationDialog("Remove All Skills?", isPresented: $showRemoveAllConfirm) {
            Button("Remove All \(agentSkills.count) Skills", role: .destructive) {
                removeAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to remove all \(agentSkills.count) skills from \(agentName)? This cannot be undone.")
        }
        .confirmationDialog("Reinstall All Skills?", isPresented: $showReinstallAllConfirm) {
            Button("Reinstall All") {
                reinstallAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will reinstall all \(agentSkills.count) skills for \(agentName).")
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
    
    private func reinstallAll() {
        isProcessingBulk = true
        Task {
            for skill in agentSkills {
                do {
                    let agentObj = AgentService().agents.first { $0.name == agentName }
                    if let agentCli = agentObj?.cliName {
                        _ = try await skillService.installSkills(
                            source: skill.source ?? "vercel-labs/agent-skills",
                            skillNames: [skill.name],
                            agentCliNames: [agentCli],
                            global: true
                        )
                    }
                } catch {
                    print("Failed to reinstall \(skill.name): \(error)")
                }
            }
            skillService.getInstalledSkills()
            isProcessingBulk = false
        }
    }
    
    private func removeAll() {
        isProcessingBulk = true
        Task {
            for skill in agentSkills {
                do {
                    try skillService.uninstallSkill(skillName: skill.name, agentName: agentName)
                } catch {
                    print("Failed to uninstall \(skill.name): \(error)")
                }
            }
            skillService.getInstalledSkills()
            isProcessingBulk = false
        }
    }
    
    private func agentColor(_ name: String) -> Color {
        let colors: [Color] = [.blue, .purple, .orange, .pink, .green, .teal, .indigo]
        let hash = name.hashValue
        return colors[abs(hash) % colors.count]
    }
}
