import SwiftUI

enum NavigationItem: Hashable, CaseIterable, Identifiable {
    // "move installed skill up" -> Swap order
    case skills
    case agents
    case registry
    
    var id: Self { self }
    
    var descriptor: (title: String, icon: String) {
        switch self {
        case .agents: return ("Agents", "cpu")
        case .skills: return ("Skills", "sparkles.rectangle.stack")
        case .registry: return ("Registry", "list.bullet.rectangle.portrait.fill")
        }
    }
}

struct ContentView: View {
    @State private var selection: NavigationItem? = .skills
    @StateObject private var skillService = SkillService() // Default to skills if moved up? User didn't specify default, but naturally top item is default.
    

    
    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(NavigationItem.allCases) { item in
                    Label(item.descriptor.title, systemImage: item.descriptor.icon)
                        .tag(item)
                }
            }
            .navigationTitle("Skill Man")
            .listStyle(.sidebar)
        } detail: {
            // We wrap detail in ZStack or Group to attach global toolbar
            Group {
                switch selection {
                case .skills, nil:
                    InstalledSkillsView(skillService: skillService)
                case .agents:
                    AppsView()
                case .registry:
                    RegistryView(skillService: skillService)
                }
            }
        .frame(minWidth: 900, minHeight: 600)
        }
        .onAppear {
            // Global app checks if any?
            // skillService.checkUpdatesOnAppStart() - Moved to RegistryView
        }
    }
}
