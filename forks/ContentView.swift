import SwiftUI

enum NavigationItem: Hashable, CaseIterable, Identifiable {
    case dashboard
    case skills
    case projects
    case agents
    case registry
    
    var id: Self { self }
    
    var descriptor: (title: String, icon: String) {
        switch self {
        case .dashboard: return ("Dashboard", "square.grid.2x2.fill")
        case .agents: return ("Agents", "cpu")
        case .skills: return ("Skills", "sparkles.rectangle.stack")
        case .projects: return ("Projects", "folder.badge.gearshape")
        case .registry: return ("Registry", "list.bullet.rectangle.portrait.fill")
        }
    }
}

struct ContentView: View {
    @State private var selection: NavigationItem? = .dashboard
    @StateObject private var skillService = SkillService() // Default to skills if moved up? User didn't specify default, but naturally top item is default.
    @StateObject private var projectService = ProjectService()
    

    
    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(NavigationItem.allCases) { item in
                    Label(item.descriptor.title, systemImage: item.descriptor.icon)
                        .tag(item)
                }
            }
            .navigationTitle("Forks")
            .listStyle(.sidebar)
        } detail: {
            NavigationStack {
                Group {
                    switch selection {
                    case .dashboard:
                        DashboardView(selection: $selection, skillService: skillService, projectService: projectService)
                    case .skills, nil:
                        InstalledSkillsView(skillService: skillService)
                    case .projects:
                        ProjectListView(projectService: projectService, skillService: skillService)
                    case .agents:
                        AppsView()
                    case .registry:
                        RegistryView(skillService: skillService)
                    }
                }
                .frame(minWidth: 900, minHeight: 600)
            }
        }
        .onAppear {
            // Global app checks if any?
            // skillService.checkUpdatesOnAppStart() - Moved to RegistryView
        }
    }
}

