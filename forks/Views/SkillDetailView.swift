import SwiftUI

struct SkillDetailView: View {
    let skillName: String
    @ObservedObject var skillService: SkillService
    @ObservedObject var agentService: AgentService
    
    @State private var processingAgent: String?
    @State private var showConfirm = false
    @State private var agentToUninstall: String?
    @State private var showReinstallAllConfirm = false
    @State private var showRemoveAllConfirm = false
    @State private var isProcessingBulk = false
    
    var skill: InstalledSkill? {
        skillService.installedSkills.first { $0.name == skillName }
    }
    
    // Sort agents: Detected agents first, then others.
    // Also we want to show ALL detected agents so user can install to them.
    var displayAgents: [AgentStatus] {
        let detected = agentService.agents.filter { $0.detected }
        let installedAgentNames = skill?.agents ?? []
        
        return detected.map { agent in
            AgentStatus(
                agent: agent,
                isInstalled: installedAgentNames.contains(agent.name)
            )
        }.sorted { $0.isInstalled && !$1.isInstalled } // Installed first
    }
    
    struct AgentStatus: Identifiable {
        let agent: Agent
        let isInstalled: Bool
        var id: String { agent.name }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if let skill = skill {
                // Header
                HStack(alignment: .top, spacing: 16) {
                    Image(systemName: "sparkles.square.fill.on.square")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(skill.name)
                            .font(.title)
                            .bold()
                        if let desc = skill.description {
                            Text(desc)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        
                        // Source information
                        if let source = skill.source {
                            HStack(spacing: 4) {
                                Image(systemName: source.hasPrefix("/") ? "folder" : "globe")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(source)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            .padding(.top, 4)
                        }
                        
                        // Update status
                        if skill.updateAvailable {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                Text("Update available")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                            .padding(.top, 2)
                        } else if let lastChecked = skill.lastCheckedForUpdates {
                            Text("Up to date (checked \(timeAgo(lastChecked)))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 2)
                        }
                    }
                    Spacer()
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                
                // Bulk actions toolbar
                HStack {
                    if isProcessingBulk {
                        ProgressView().controlSize(.small)
                            .padding(.leading, 8)
                    }
                    
                    if skill.updateAvailable {
                        Button {
                            updateSkill()
                        } label: {
                            Label("Update All", systemImage: "arrow.down.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isProcessingBulk)
                    }
                    
                    Spacer()
                    
                    Button(action: { showReinstallAllConfirm = true }) {
                        Label("Reinstall", systemImage: "arrow.clockwise.circle")
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
                .padding(.vertical, 8)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                
                Divider()
                
                // Table
                Table(displayAgents) {
                    TableColumn("Agent") { status in
                        Text(status.agent.name)
                            .font(.headline)
                    }
                    .width(min: 150)
                    
                    TableColumn("CLI") { status in
                        Text(status.agent.cliName)
                            .font(.monospaced(.caption)())
                            .foregroundColor(.secondary)
                            .padding(4)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                    }
                    
                    TableColumn("Status") { status in
                        if status.isInstalled {
                            Label("Installed", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                        //    Label("Available", systemImage: "arrow.down.circle")
                           Text("—")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    TableColumn("Action") { status in
                        HStack {
                            if processingAgent == status.agent.name {
                                ProgressView().controlSize(.small)
                            } else if status.isInstalled {
                                Button(action: {
                                    agentToUninstall = status.agent.name
                                    showConfirm = true
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.borderless)
                                .help("Uninstall from \(status.agent.name)")
                                .disabled(isProcessingBulk)
                            } else {
                                Button(action: {
                                    install(to: status.agent.cliName, name: status.agent.name)
                                }) {
                                    Image(systemName: "arrow.down.circle")
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.borderless)
                                .help("Install to \(status.agent.name)")
                                .disabled(isProcessingBulk)
                            }
                        }
                    }
                    .width(80)
                }
                .confirmationDialog("Uninstall Skill?", isPresented: $showConfirm, presenting: agentToUninstall) { agentName in
                    Button("Uninstall from \(agentName)", role: .destructive) {
                        uninstall(from: agentName)
                    }
                    Button("Cancel", role: .cancel) {}
                } message: { agentName in
                    Text("Are you sure you want to remove \(skill.name) from \(agentName)?")
                }
                .confirmationDialog("Remove from All Agents?", isPresented: $showRemoveAllConfirm) {
                    Button("Remove All", role: .destructive) {
                        removeAll()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Are you sure you want to remove \"\(skill.name)\" from all \(skill.agents.count) agents? This cannot be undone.")
                }
                .confirmationDialog("Reinstall on All Agents?", isPresented: $showReinstallAllConfirm) {
                    Button("Reinstall") {
                        reinstallAll()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will reinstall \"\(skill.name)\" on all \(skill.agents.count) agents.")
                }
                
            } else {
                ContentUnavailableView("Skill Not Found", systemImage: "exclamationmark.triangle")
            }
        }
        .navigationTitle(skillName)
    }
    
    private func uninstall(from agentName: String) {
        processingAgent = agentName
        Task {
            do {
                try skillService.uninstallSkill(skillName: skillName, agentName: agentName)
                skillService.getInstalledSkills()
            } catch {
                print("Failed to uninstall: \(error)")
            }
            processingAgent = nil
        }
    }
    
    private func install(to agentCli: String, name: String) {
        processingAgent = name
        Task {
            do {
                let source = skill?.source ?? "vercel-labs/agent-skills"
                _ = try await skillService.installSkills(
                    source: source,
                    skillNames: [skillName],
                    agentCliNames: [agentCli],
                    global: true
                )
                skillService.getInstalledSkills()
            } catch {
                 print("Failed to install: \(error)")
            }
              processingAgent = nil
        }
    }
    
    private func updateSkill() {
        guard let skill = skill, let source = skill.source else { return }
        isProcessingBulk = true
        Task {
            for agentName in skill.agents {
                do {
                    try await skillService.updateSkill(skillName: skill.name, agentName: agentName, source: source)
                } catch {
                    print("Error updating \(agentName): \(error)")
                }
            }
            skillService.getInstalledSkills()
            isProcessingBulk = false
        }
    }
    
    private func reinstallAll() {
        guard let skill = skill, let source = skill.source else { return }
        isProcessingBulk = true
        Task {
            for agentName in skill.agents {
                do {
                    let agentObj = agentService.agents.first { $0.name == agentName }
                    if let agentCli = agentObj?.cliName {
                        _ = try await skillService.installSkills(
                            source: source,
                            skillNames: [skillName],
                            agentCliNames: [agentCli],
                            global: true
                        )
                    }
                } catch {
                    print("Error reinstalling on \(agentName): \(error)")
                }
            }
            skillService.getInstalledSkills()
            isProcessingBulk = false
        }
    }
    
    private func removeAll() {
        guard let skill = skill else { return }
        isProcessingBulk = true
        Task {
            for agentName in skill.agents {
                do {
                    try skillService.uninstallSkill(skillName: skillName, agentName: agentName)
                } catch {
                    print("Error removing from \(agentName): \(error)")
                }
            }
            skillService.getInstalledSkills()
            isProcessingBulk = false
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 {
            return "just now"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes)m ago"
        } else if seconds < 86400 {
            let hours = seconds / 3600
            return "\(hours)h ago"
        } else {
            let days = seconds / 86400
            return "\(days)d ago"
        }
    }
}
