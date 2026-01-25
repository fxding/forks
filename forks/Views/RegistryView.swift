import SwiftUI

struct RegistryView: View {
    @ObservedObject var skillService: SkillService
    @State private var sortOrder = [KeyPathComparator(\SkillService.RegistrySource.path)]
    @State private var selectedSourceId: String?
    @State private var showAddSourceSheet = false

    var body: some View {
        NavigationStack {
            VStack {
                if skillService.registrySources.isEmpty {
                    ContentUnavailableView("Registry Empty", systemImage: "externaldrive", description: Text("Install skills to populate the registry."))
                } else {
                    Table(skillService.registrySources, selection: $selectedSourceId, sortOrder: $sortOrder) {
                        TableColumn("Source", value: \.path) { source in
                                Text(source.path)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .font(.system(.body, design: .monospaced))

                            .help(source.path)
                        }
                        .width(min: 200, ideal: 400)

                        TableColumn("Type", value: \.type) { source in
                             Text(source.type)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(source.type == "Git" ? Color.blue.opacity(0.1) : Color.orange.opacity(0.1))
                                .foregroundColor(source.type == "Git" ? .blue : .orange)
                                .cornerRadius(4)
                        }
                        .width(60)

                        TableColumn("Last Checked") { source in
                            if let lastChecked = source.lastChecked {
                                Text(lastChecked.formatted(date: .numeric, time: .shortened))
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Never")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .width(120)

                        TableColumn("Skills") { source in
                            Text(source.skills.joined(separator: ", "))
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .foregroundColor(.secondary)
                        }
                        
                        TableColumn("") { source in
                            HStack {
                                // Open Repo/Folder
                                Button {
                                    if source.type == "Local" {
                                        NSWorkspace.shared.open(URL(fileURLWithPath: source.path))
                                    } else {
                                        var urlStr = source.path
                                        if !urlStr.lowercased().hasPrefix("http") && !urlStr.lowercased().hasPrefix("https") {
                                            if urlStr.hasPrefix("git@") {
                                                urlStr = urlStr.replacingOccurrences(of: ":", with: "/")
                                                urlStr = urlStr.replacingOccurrences(of: "git@", with: "https://")
                                            } else {
                                                urlStr = "https://github.com/\(urlStr)"
                                            }
                                        }
                                        if let url = URL(string: urlStr) {
                                            NSWorkspace.shared.open(url)
                                        }
                                    }
                                } label: {
                                    Image(systemName: source.type == "Git" ? "safari" : "folder")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("Open in \(source.type == "Git" ? "Browser" : "Finder")")
                                
                                // Navigation Chevron
                                NavigationLink(value: source) {
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .width(60)
                    }
                    .onChange(of: sortOrder) { newOrder in
                        var items = skillService.registrySources
                        items.sort(using: newOrder)
                        skillService.registrySources = items
                    }
                }
            }
            .navigationTitle("Registry")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        Task {
                            await skillService.refreshRegistry()
                        }
                    }) {
                        Label("Check for Updates", systemImage: "arrow.clockwise")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showAddSourceSheet = true }) {
                        Label("Add Source", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSourceSheet) {
                 AddSourceSheet(skillService: skillService)
            }
            .onAppear {
                 skillService.getInstalledSkills() // Refresh status
                 Task {
                     await skillService.refreshRegistry()
                 }
            }
            .navigationDestination(for: SkillService.RegistrySource.self) { source in
                RegistrySourceDetailView(source: source, skillService: skillService)
            }
        }
    }
}

struct AddSourceSheet: View {
    @ObservedObject var skillService: SkillService
    @Environment(\.dismiss) var dismiss
    
    @State private var sourceUrl = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Add Registry Source")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Enter a repository URL or select a local folder to add a new source to your registry.")
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
                    TextField("user/repo or /path/to/skills", text: $sourceUrl)
                        .textFieldStyle(.roundedBorder)
                    
                    Button {
                        let openPanel = NSOpenPanel()
                        openPanel.canChooseFiles = false
                        openPanel.canChooseDirectories = true
                        openPanel.allowsMultipleSelection = false
                        openPanel.begin { response in
                            if response == .OK, let url = openPanel.url {
                                sourceUrl = url.path
                            }
                        }
                    } label: {
                        Image(systemName: "folder")
                    }
                }
            }
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            if isProcessing {
                ProgressView()
                    .controlSize(.small)
            }
            
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                
                Button("Add") {
                    addSource()
                }
                .disabled(sourceUrl.isEmpty || isProcessing)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 8)
        }
        .padding(24)
        .frame(width: 450)
    }
    
    private func addSource() {
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                try await skillService.addRegistrySource(source: sourceUrl)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isProcessing = false
        }
    }
}

