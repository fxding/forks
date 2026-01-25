import SwiftUI

struct DashboardView: View {
    @Binding var selection: NavigationItem?
    @ObservedObject var skillService: SkillService
    @ObservedObject var projectService: ProjectService
    @StateObject private var agentService = AgentService()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                // Stats Grid
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 24),
                    GridItem(.flexible(), spacing: 24),
                    GridItem(.flexible(), spacing: 24)
                ], spacing: 24) {
                    StatCard(
                        title: "Installed Skills",
                        value: "\(skillService.installedSkills.count)",
                        icon: "sparkles",
                        color: .blue,
                        subtitle: "across all agents"
                    ) {
                        selection = .skills
                    }
                    
                    StatCard(
                        title: "Detected Agents",
                        value: "\(agentService.agents.filter { $0.detected }.count)",
                        icon: "cpu",
                        color: .purple,
                        subtitle: "of \(agentService.agents.count) supported"
                    ) {
                        selection = .agents
                    }
                    
                    StatCard(
                        title: "Active Projects",
                        value: "\(projectService.projects.count)",
                        icon: "folder.fill",
                        color: .orange,
                        subtitle: "managed locations"
                    ) {
                        selection = .projects
                    }
                }
                
                // Secondary Section: Success / Registry
                HStack(spacing: 24) {
                    StatCard(
                        title: "Registry Sources",
                        value: "\(skillService.registrySources.count)",
                        icon: "list.bullet.rectangle.portrait.fill",
                        color: .green,
                        subtitle: "skill repositories"
                    ) {
                        selection = .registry
                    }
                    .frame(maxWidth: 320)
                    
                    let updatesCount = skillService.installedSkills.filter { $0.updateAvailable }.count
                    if updatesCount > 0 {
                        UpdateAlertCard(count: updatesCount) {
                            selection = .registry
                        }
                        .frame(maxWidth: 500)
                    }
                    
                    Spacer()
                }
                
                // Agents (Providers) Section
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 8) {
                        Image(systemName: "cpu")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Agents")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    
                    FlowLayout(agentService.agents.filter { $0.detected }, spacing: 12) { agent in
                        NavigationLink(destination: AgentDetailView(agentName: agent.name, skillService: skillService)) {
                            AgentChip(agent: agent, skillCount: getSkillCount(for: agent))
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Spacer()
            }
            .padding(40)
        }
        .navigationTitle("Dashboard")
        .onAppear {
            skillService.getInstalledSkills()
            agentService.refreshAgents()
        }
    }
    
    private func getSkillCount(for agent: Agent) -> Int {
        skillService.installedSkills.filter { $0.agents.contains(agent.name) }.count
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let subtitle: String
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                // Top row: Icon and Title (OUTSIDE the main card background)
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                    
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                    
                    Spacer()
                }
                .foregroundColor(color)
                .padding(.leading, 8) // Slight offset to align with card content
                
                // The Card Area
                VStack(alignment: .leading, spacing: 4) {
                    Text(value)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(color)
                    
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isHovered ? color.opacity(0.3) : Color.primary.opacity(0.05), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(isHovered ? 0.04 : 0.01), radius: 8, x: 0, y: 4)
            }
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct AgentChip: View {
    let agent: Agent
    let skillCount: Int
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 8) {
            if agent.detected {
                // Custom icon or system icon
                Image(systemName: "cpu")
                    .font(.caption)
                
                Text(agent.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if skillCount > 0 {
                    Text("x\(skillCount)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.1))
                        .cornerRadius(4)
                }
            } else {
                Image(systemName: "plus.circle")
                    .font(.caption)
                
                Text(agent.name)
                    .font(.subheadline)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Group {
                if agent.detected {
                    getAgentColor(agent.name).opacity(isHovered ? 0.25 : 0.15)
                } else {
                    Color.secondary.opacity(isHovered ? 0.15 : 0.08)
                }
            }
        )
        .foregroundColor(agent.detected ? getAgentColor(agent.name) : .secondary)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(agent.detected ? getAgentColor(agent.name).opacity(0.2) : Color.clear, lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private func getAgentColor(_ name: String) -> Color {
        switch name {
        case "Antigravity": return .pink
        case "Codex": return .green
        case "Gemini": return .blue
        case "Claude": return .orange
        case "Cursor": return .blue
        case "Windsurf": return .purple
        default: return .blue
        }
    }
}

struct UpdateAlertCard: View {
    let count: Int
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(count) Updates Available")
                        .font(.headline)
                    Text("Go to Registry to update your skills.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(24)
            .background(isHovered ? Color.blue.opacity(0.08) : Color.blue.opacity(0.04))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.blue.opacity(0.1), lineWidth: 1)
            )
            .scaleEffect(isHovered ? 1.01 : 1.0)
            .animation(.easeOut(duration: 0.2), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// Helper view for flow layout of chips
struct FlowLayout: View {
    var spacing: CGFloat
    var content: [AnyView]
    
    init<Data: RandomAccessCollection, Content: View>(
        _ data: Data,
        spacing: CGFloat = 8,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.spacing = spacing
        self.content = data.map { AnyView(content($0)) }
    }
    
    @State private var totalHeight = CGFloat.zero

    var body: some View {
        VStack {
            GeometryReader { geometry in
                self.generateContent(in: geometry)
            }
        }
        .frame(height: totalHeight)
    }

    private func generateContent(in g: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero

        return ZStack(alignment: .topLeading) {
            ForEach(0..<content.count, id: \.self) { index in
                self.content[index]
                    .padding([.horizontal, .vertical], spacing / 2)
                    .alignmentGuide(.leading, computeValue: { d in
                        if (abs(width - d.width) > g.size.width) {
                            width = 0
                            height -= d.height
                        }
                        let result = width
                        if index == self.content.count - 1 {
                            width = 0 // last item
                        } else {
                            width -= d.width
                        }
                        return result
                    })
                    .alignmentGuide(.top, computeValue: { d in
                        let result = height
                        if index == self.content.count - 1 {
                            height = 0 // last item
                        }
                        return result
                    })
            }
        }.background(viewHeightReader($totalHeight))
    }

    private func viewHeightReader(_ binding: Binding<CGFloat>) -> some View {
        return GeometryReader { geometry -> Color in
            let rect = geometry.frame(in: .local)
            DispatchQueue.main.async {
                binding.wrappedValue = rect.size.height
            }
            return .clear
        }
    }
}


struct RegistryStatusCard: View {
    let sources: [SkillService.RegistrySource]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Registry Health")
                .font(.headline)
            
            HStack(spacing: 12) {
                let gitCount = sources.filter { $0.type == "Git" }.count
                let localCount = sources.filter { $0.type == "Local" }.count
                
                Label("\(gitCount) Git", systemImage: "globe")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(6)
                
                Label("\(localCount) Local", systemImage: "folder")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .foregroundColor(.orange)
                    .cornerRadius(6)
            }
        }
        .padding(20)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
}
