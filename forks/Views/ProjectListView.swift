import SwiftUI

struct ProjectListView: View {
    @ObservedObject var projectService: ProjectService
    @ObservedObject var skillService: SkillService
    
    @State private var selectedProjectId: UUID?
    @State private var errorMessage: String?
    @State private var projectToDelete: Project?
    
    var body: some View {
        NavigationStack {
            VStack {
                if projectService.projects.isEmpty {
                    ContentUnavailableView(
                        "No Projects",
                        systemImage: "folder.badge.plus",
                        description: Text("Add a project to manage its local skills.")
                    )
                } else {
                    Table(projectService.projects, selection: $selectedProjectId) {
                        TableColumn("Name") { project in
                            HStack(spacing: 10) {
                                Image(systemName: "folder.fill")
                                    .foregroundColor(.blue)
                                Text(project.name)
                                    .font(.headline)
                            }
                        }
                        .width(min: 150, ideal: 200)
                        
                        TableColumn("Path") { project in
                            Text(project.path)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        .width(min: 200, ideal: 400)
                        
                        TableColumn("Agents") { project in
                            let agents = projectService.getProjectAgents(project: project)
                            if agents.isEmpty {
                                Text("—")
                                    .foregroundColor(.secondary)
                            } else {
                                HStack(spacing: 4) {
                                    ForEach(agents.prefix(3), id: \.name) { agent in
                                        Text(agent.name)
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(agentColor(agent.name).opacity(0.1))
                                            .foregroundColor(agentColor(agent.name))
                                            .cornerRadius(4)
                                    }
                                    if agents.count > 3 {
                                        Text("+\(agents.count - 3)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .width(min: 100, ideal: 180)
                        
                        TableColumn("Skills") { project in
                            let count = projectService.getAllProjectSkillsCount(project: project)
                            if count > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "sparkles")
                                        .font(.caption)
                                    Text("\(count)")
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.blue)
                            } else {
                                Text("—")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .width(60)
                        
                        TableColumn("") { project in
                            HStack(spacing: 8) {
                                Button {
                                    NSWorkspace.shared.open(URL(fileURLWithPath: project.path))
                                } label: {
                                    Image(systemName: "folder")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("Open in Finder")
                                
                                Button {
                                    projectToDelete = project
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                                .help("Remove Project")
                                
                                NavigationLink(value: project) {
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .width(90)
                    }
                    .contextMenu(forSelectionType: UUID.self) { ids in
                        if let id = ids.first {
                            Button("Remove Project", role: .destructive) {
                                if let project = projectService.projects.first(where: { $0.id == id }) {
                                    projectToDelete = project
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Projects")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { addProject() }) {
                        Label("Add Project", systemImage: "plus")
                    }
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .alert("Remove Project?", isPresented: .constant(projectToDelete != nil)) {
                Button("Cancel", role: .cancel) {
                    projectToDelete = nil
                }
                Button("Remove", role: .destructive) {
                    if let project = projectToDelete {
                        projectService.removeProject(id: project.id)
                    }
                    projectToDelete = nil
                }
            } message: {
                if let project = projectToDelete {
                    Text("Are you sure you want to remove \"\(project.name)\" from your projects list? This won't delete any files.")
                }
            }
            .navigationDestination(for: Project.self) { project in
                ProjectDetailView(project: project, projectService: projectService, skillService: skillService)
            }
        }
    }
    
    private func addProject() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.message = "Select a project folder"
        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                do {
                    try projectService.addProject(path: url.path)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func agentColor(_ name: String) -> Color {
        let colors: [Color] = [.blue, .purple, .orange, .pink, .green, .teal, .indigo]
        let hash = name.hashValue
        return colors[abs(hash) % colors.count]
    }
}

