import SwiftUI

struct ProjectDetailView: View {
    let project: Project
    @ObservedObject var projectService: ProjectService
    @ObservedObject var skillService: SkillService
    
    @State private var showAddSkillSheet = false
    @State private var expandedAgents: Set<String> = []
    @State private var refreshTrigger = false
    
    var detectedAgents: [Agent] {
        projectService.getProjectAgents(project: project)
    }
    
    var body: some View {
        List {
            if detectedAgents.isEmpty {
                ContentUnavailableView(
                    "No Agents Found",
                    systemImage: "cpu",
                    description: Text("This project doesn't have any agent skill folders yet. Add a skill to create one.")
                )
            } else {
                ForEach(detectedAgents, id: \.name) { agent in
                    AgentSkillsSection(
                        agent: agent,
                        project: project,
                        projectService: projectService,
                        isExpanded: expandedAgents.contains(agent.name),
                        onToggle: {
                            if expandedAgents.contains(agent.name) {
                                expandedAgents.remove(agent.name)
                            } else {
                                expandedAgents.insert(agent.name)
                            }
                        },
                        onRefresh: { refreshTrigger.toggle() }
                    )
                }
            }
        }
        .id(refreshTrigger) // Force refresh when skills change
        .navigationTitle(project.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showAddSkillSheet = true }) {
                    Label("Add Skill", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSkillSheet) {
            AddSkillToProjectSheet(
                project: project,
                projectService: projectService,
                skillService: skillService,
                onSuccess: { refreshTrigger.toggle() }
            )
        }
        .onAppear {
            // Only expand agents that have skills
            expandedAgents = Set(detectedAgents.filter { agent in
                !projectService.getProjectSkills(project: project, agent: agent).isEmpty
            }.map { $0.name })
        }
    }
}

struct AgentSkillsSection: View {
    let agent: Agent
    let project: Project
    @ObservedObject var projectService: ProjectService
    let isExpanded: Bool
    let onToggle: () -> Void
    let onRefresh: () -> Void
    
    var skills: [InstalledSkill] {
        projectService.getProjectSkills(project: project, agent: agent)
    }
    
    var body: some View {
        Section {
            if isExpanded {
                if skills.isEmpty {
                    HStack {
                        Text("No skills installed")
                            .foregroundColor(.secondary)
                            .font(.callout)
                    }
                    .padding(.vertical, 4)
                } else {
                    ForEach(skills, id: \.name) { skill in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(skill.name)
                                    .font(.body)
                                if let desc = skill.description {
                                    Text(desc)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            
                            Spacer()
                            
                            Button(role: .destructive) {
                                removeSkill(skill)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                            .help("Remove skill")
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        } header: {
            Button(action: onToggle) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "cpu.fill")
                        .font(.title3)
                        .padding(6)
                        .background(agentColor(agent.name).opacity(0.1))
                        .foregroundColor(agentColor(agent.name))
                        .cornerRadius(6)
                    
                    Text(agent.name)
                        .font(.headline)
                    
                    Spacer()
                    
                    Text("\(skills.count) skill\(skills.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
    }
    
    private func removeSkill(_ skill: InstalledSkill) {
        do {
            try projectService.uninstallProjectSkill(
                skillName: skill.name,
                agentName: agent.name,
                projectPath: project.path
            )
            onRefresh()
        } catch {
            print("Error removing skill: \(error)")
        }
    }
    
    private func agentColor(_ name: String) -> Color {
        let colors: [Color] = [.blue, .purple, .orange, .pink, .green, .teal, .indigo]
        let hash = name.hashValue
        return colors[abs(hash) % colors.count]
    }
}
