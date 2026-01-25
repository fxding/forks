import SwiftUI

enum NavigationItem: Hashable, CaseIterable, Identifiable {
    // "move installed skill up" -> Swap order
    case skills
    case agents
    
    var id: Self { self }
    
    var descriptor: (title: String, icon: String) {
        switch self {
        case .agents: return ("Agents", "cpu")
        case .skills: return ("Skills", "sparkles.rectangle.stack")
        }
    }
}

struct ContentView: View {
    @State private var selection: NavigationItem? = .skills // Default to skills if moved up? User didn't specify default, but naturally top item is default.
    
    // Global state for adding skills
    @State private var showAddSkillDialog = false
    @State private var newRepoUrl: String = "vercel-labs/agent-skills"
    @State private var navigateToStore = false
    
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
                    InstalledSkillsView()
                case .agents:
                    AppsView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showAddSkillDialog = true }) {
                        Label("Add Skill", systemImage: "plus")
                    }
                    .help("Install new skill")
                }
            }
        }
        .frame(minWidth: 900, minHeight: 600)
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
        // Global navigation destination for store
        // Note: NavigationDestination must be inside a NavigationStack. 
        // NavigationSplitView's detail usually contains a NavigationStack or IS one logic-wise in SwiftUI 4+?
        // Actually best is to ensure the detail views have stacks or we wrap content in one if needed.
        // But Views/InstalledSkillsView already has NavigationStack. AppsView too.
        // This causes issues with global toolbar item if the detail view also defines toolbar items or separate stacks.
        
        // BETTER APPROACH:
        // Inject the "add skill" action or state down? Or handle it here but note that destination needs to be valid.
        // "navigate to store" implies we push a view.
        // If we are in SplitView, we usually replace the detail view.
        // So `navigateToStore` should probably change the DETAIL view content to the store view.
        
        // Let's change the strategy:
        // 1. selection can handle a `.store` case that is hidden from sidebar?
        // 2. OR we show a Sheet for the store?
        // "open a new page" usually implies navigation stack push or detail replacement.
        // If we want "global on all pages", the toolbar item in `ContentView` is correct.
        // But for `AvailableSkillsView` to appear, we need a way to present it.
        // Sheet might be easiest for "global" access without messing up individual tab stacks.
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
    }
}
