import SwiftUI

struct InstalledSkillsView: View {
    @ObservedObject var skillService: SkillService
    @StateObject private var agentService = AgentService()
    
    @State private var searchText = ""
    @State private var selectedAgentFilter: String? = nil
    
    // Add Skill State
    @State private var showAddSkillDialog = false
    @State private var newRepoUrl: String = "vercel-labs/agent-skills"
    @State private var navigateToStore = false
    
    var filteredSkills: [InstalledSkill] {
        skillService.installedSkills.filter { skill in
            let matchesSearch = searchText.isEmpty || 
                skill.name.localizedCaseInsensitiveContains(searchText) || 
                (skill.description?.localizedCaseInsensitiveContains(searchText) ?? false)
            
            let matchesAgent = selectedAgentFilter == nil || skill.agents.contains(selectedAgentFilter!)
            
            return matchesSearch && matchesAgent
        }
    }
    
    var agentSkillCounts: [(agent: Agent, count: Int)] {
        let detected = agentService.agents.filter { $0.detected }
        return detected.map { agent in
            let count = skillService.installedSkills.filter { $0.agents.contains(agent.name) }.count
            return (agent, count)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Agent Filter Bar
                if !agentSkillCounts.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(
                                title: "All",
                                count: skillService.installedSkills.count,
                                isSelected: selectedAgentFilter == nil,
                                action: { selectedAgentFilter = nil }
                            )
                            
                            ForEach(agentSkillCounts, id: \.agent.name) { item in
                                FilterChip(
                                    title: item.agent.name,
                                    count: item.count,
                                    isSelected: selectedAgentFilter == item.agent.name,
                                    action: {
                                        if selectedAgentFilter == item.agent.name {
                                            selectedAgentFilter = nil
                                        } else {
                                            selectedAgentFilter = item.agent.name
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                    }
                    .background(Color(nsColor: .controlBackgroundColor))
                    .overlay(Divider(), alignment: .bottom)
                }
                
                List {
                    if filteredSkills.isEmpty {
                        ContentUnavailableView(
                            searchText.isEmpty ? "No Skills Installed" : "No Matches",
                            systemImage: searchText.isEmpty ? "star.slash" : "magnifyingglass",
                            description: Text(searchText.isEmpty ? "Install skills using the + button." : "Try a different search term or filter.")
                        )
                    } else {
                        ForEach(filteredSkills) { skill in
                            NavigationLink(destination: SkillDetailView(skillName: skill.name, skillService: skillService, agentService: agentService)) {
                                SkillRow(
                                    skill: skill,
                                    isExpanded: false, 
                                    detectedAgents: [], 
                                    onToggle: {},
                                    onInstallTo: { _ in },
                                    onUninstallFrom: { _ in }
                                )
                            }
                        }
                    }
                }
            }
            .navigationTitle("Skills")
            .searchable(text: $searchText, placement: .toolbar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showAddSkillDialog = true }) {
                        Label("Add Skill", systemImage: "plus")
                    }
                    .help("Install new skill")
                }
            }
            .sheet(isPresented: $showAddSkillDialog) {
                VStack(spacing: 24) {
                    Text("Add Skill Source")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enter a repository URL or select a local folder to add new capabilities to your agents.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Examples:")
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "globe")
                                    .font(.caption)
                                Text("vercel-labs/agent-skills")
                                    .font(.caption)
                                    .monospaced()
                            }
                            .foregroundColor(.secondary)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "folder")
                                    .font(.caption)
                                Text("/Users/username/my-skills")
                                    .font(.caption)
                                    .monospaced()
                            }
                            .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Repository URL or Local Path")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        HStack {
                            TextField("user/repo or /path/to/skills", text: $newRepoUrl)
                                .textFieldStyle(.roundedBorder)
                            
                            Button {
                                let openPanel = NSOpenPanel()
                                openPanel.canChooseFiles = false
                                openPanel.canChooseDirectories = true
                                openPanel.allowsMultipleSelection = false
                                openPanel.begin { response in
                                    if response == .OK, let url = openPanel.url {
                                        newRepoUrl = url.path
                                    }
                                }
                            } label: {
                                Image(systemName: "folder")
                            }
                        }
                    }
                    
                    HStack {
                        Button("Cancel") {
                            showAddSkillDialog = false
                        }
                        .keyboardShortcut(.cancelAction)
                        
                        Button("Browse Skills") {
                            showAddSkillDialog = false
                            navigateToStore = true
                        }
                        .keyboardShortcut(.defaultAction)
                        .disabled(newRepoUrl.isEmpty)
                    }
                    .padding(.top, 8)
                }
                .padding(24)
                .frame(width: 450)
            }
            .sheet(isPresented: $navigateToStore) {
                NavigationStack {
                    AvailableSkillsView(repoUrl: newRepoUrl)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { navigateToStore = false }
                            }
                        }
                }
                .frame(minWidth: 600, minHeight: 400)
            }
            .onAppear {
                skillService.getInstalledSkills()
                agentService.refreshAgents()
            }
        }
    }
}

struct FilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                Text("\(count)")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? Color.white.opacity(0.2) : Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue : Color(nsColor: .controlBackgroundColor)) // controlBackgroundColor or similar gray
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.blue : Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct SkillRow: View {
    let skill: InstalledSkill
    let isExpanded: Bool
    let detectedAgents: [Agent]
    let onToggle: () -> Void
    let onInstallTo: (String) -> Void
    let onUninstallFrom: (String) -> Void
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                // Skill name with update badge
                ZStack(alignment: .topTrailing) {
                    Text(skill.name)
                        .font(.headline)
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    
                    // Green dot badge for updates
                    if skill.updateAvailable {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 10, height: 10)
                            .offset(x: 5, y: -5)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.trailing, skill.updateAvailable ? 8 : 0)
                
                if let desc = skill.description {
                    Text(desc)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                }
            }
            
            Spacer()
            
            HStack {
                ForEach(skill.agents.prefix(3), id: \.self) { agentName in
                    AgentBadge(name: agentName)
                }
                if skill.agents.count > 3 {
                    Text("+\(skill.agents.count - 3)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .animation(.easeInOut(duration: 0.3), value: skill.updateAvailable)
    }
}

struct AgentBadge: View {
    let name: String
    
    var body: some View {
        Text(name)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.blue.opacity(0.1))
            .foregroundColor(.blue)
            .cornerRadius(4)
    }
}
