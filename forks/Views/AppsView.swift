import SwiftUI

struct AppsView: View {
    @StateObject private var agentService = AgentService()
    @StateObject private var skillService = SkillService() // Need skill service to count skills
    
    var body: some View {
        NavigationStack {
            List {
                Section("Agents") {
                    ForEach(agentService.agents.filter { $0.detected }) { agent in
                        NavigationLink(destination: AgentDetailView(agentName: agent.name, skillService: skillService)) {
                            HStack(spacing: 16) {
                                // Icon
                                Image(systemName: "cpu.fill")
                                    .font(.title2)
                                    .padding(10)
                                    .background(agentColor(agent.name).opacity(0.1))
                                    .foregroundColor(agentColor(agent.name))
                                    .cornerRadius(8)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(agent.name)
                                        .font(.headline)
                                    
                                    HStack(spacing: 8) {
                                        Text(agent.cliName)
                                            .font(.caption)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 2)
                                            .background(Color.secondary.opacity(0.1))
                                            .cornerRadius(4)
                                            .foregroundColor(.secondary)
                                        
                                        Text(agent.globalPath)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                            .frame(maxWidth: 250, alignment: .leading)
                                    }
                                }
                                
                                Spacer()
                                
                                // Summary Info (Skills)
                                let agentSkills = skillService.installedSkills.filter { $0.agents.contains(agent.name) }
                                if !agentSkills.isEmpty {
                                    VStack(alignment: .trailing, spacing: 2) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "sparkles")
                                                .font(.caption)
                                            Text("\(agentSkills.count)")
                                                .font(.headline)
                                        }
                                        .foregroundColor(.blue)
                                        
                                        Text(summaryString(for: agentSkills))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                            .frame(maxWidth: 150, alignment: .trailing)
                                    }
                                } else {
                                    Text("—")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
            }
            .navigationTitle("Agents")
            .onAppear {
                agentService.refreshAgents()
                skillService.getInstalledSkills()
            }
        }
    }
    
    private func summaryString(for skills: [InstalledSkill]) -> String {
        let names = skills.map { $0.name }
        if names.count <= 2 {
            return names.joined(separator: ", ")
        } else {
            return "\(names.prefix(2).joined(separator: ", ")) +\(names.count - 2)"
        }
    }
    
    private func agentColor(_ name: String) -> Color {
        let colors: [Color] = [.blue, .purple, .orange, .pink, .green, .teal, .indigo]
        let hash = name.hashValue
        return colors[abs(hash) % colors.count]
    }
}
