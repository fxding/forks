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

                    List {
                        ForEach(projectService.projects) { project in
                            NavigationLink(destination: ProjectDetailView(project: project, projectService: projectService, skillService: skillService)) {
                                HStack(spacing: 16) {
                                    // Icon
                                    Image(systemName: "folder.fill")
                                        .font(.title2)
                                        .padding(10)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(8)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(project.name)
                                            .font(.headline)
                                        
                                        Text(project.path)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                    
                                    Spacer()
                                    
                                    // Agents Summary
                                    let agents = projectService.getProjectAgents(project: project)
                                    if !agents.isEmpty {
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
                                    
                                    // Skills Count
                                    let count = projectService.getAllProjectSkillsCount(project: project)
                                    if count > 0 {
                                        HStack(spacing: 4) {
                                            Image(systemName: "sparkles")
                                                .font(.caption)
                                            Text("\(count)")
                                                .fontWeight(.medium)
                                        }
                                        .foregroundColor(.blue)
                                        .padding(.leading, 8)
                                    } else {
                                        Text("—")
                                            .foregroundColor(.secondary)
                                            .padding(.leading, 8)
                                    }
                                    
                                    // Actions
                                    HStack(spacing: 8) {
                                        Button {
                                            NSWorkspace.shared.open(URL(fileURLWithPath: project.path))
                                        } label: {
                                            Image(systemName: "folder")
                                                .foregroundColor(.secondary)
                                        }
                                        .buttonStyle(.borderless)
                                        .help("Open in Finder")
                                        .padding(.leading, 8)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    projectToDelete = project
                                } label: {
                                    Label("Remove Project", systemImage: "trash")
                                }
                                
                                Button {
                                    NSWorkspace.shared.open(URL(fileURLWithPath: project.path))
                                } label: {
                                    Label("Open in Finder", systemImage: "folder")
                                }
                            }
                        }
                    }
                    .listStyle(.inset)
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

