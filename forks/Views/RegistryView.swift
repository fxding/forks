import SwiftUI

struct RegistryView: View {
    @ObservedObject var skillService: SkillService
    @State private var sortOrder = [KeyPathComparator(\SkillService.RegistrySource.path)]
    @State private var selectedSourceId: String?
    @State private var showAddSourceSheet = false
    @State private var isRefreshing = false
    @State private var showDeleteSourceConfirm: String? = nil

    var body: some View {
        NavigationStack {
            VStack {
                if skillService.registrySources.isEmpty {
                    ContentUnavailableView("Registry Empty", systemImage: "externaldrive", description: Text("Install skills to populate the registry."))
                } else {

                    List {
                        ForEach(skillService.registrySources) { source in
                            NavigationLink(value: source) {
                                RegistrySourceRow(
                                    source: source,
                                    onDelete: { showDeleteSourceConfirm = source.id },
                                    onOpen: {
                                        if source.type == "Local" {
                                            NSWorkspace.shared.open(URL(fileURLWithPath: source.path))
                                        } else {
                                            openWebLink(source: source.path)
                                        }
                                    }
                                )
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    showDeleteSourceConfirm = source.id
                                } label: {
                                    Label("Delete from App", systemImage: "trash")
                                }
                                
                                Button {
                                    if source.type == "Local" {
                                        NSWorkspace.shared.open(URL(fileURLWithPath: source.path))
                                    } else {
                                        openWebLink(source: source.path)
                                    }
                                } label: {
                                    Label("Open", systemImage: source.type == "Git" ? "safari" : "folder")
                                }
                            }
                        }
                    }
                    .listStyle(.inset)
                }
            }
            .navigationTitle("Registry")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.trailing, 8)
                    } else {
                        Button(action: {
                            isRefreshing = true
                            Task {
                                await skillService.refreshRegistry()
                                isRefreshing = false
                            }
                        }) {
                            Label("Check for Updates", systemImage: "arrow.clockwise")
                        }
                        .disabled(isRefreshing)
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
                 isRefreshing = true
                 Task {
                     await skillService.refreshRegistry()
                     isRefreshing = false
                 }
            }
            .navigationDestination(for: SkillService.RegistrySource.self) { source in
                RegistrySourceDetailView(sourceId: source.id, skillService: skillService)
            }
            .confirmationDialog("Delete from App?", isPresented: .init(
                get: { showDeleteSourceConfirm != nil },
                set: { if !$0 { showDeleteSourceConfirm = nil } }
            ), presenting: showDeleteSourceConfirm) { sourceId in
                Button("Delete", role: .destructive) {
                    deleteSource(sourceId: sourceId)
                }
                Button("Cancel", role: .cancel) {}
            } message: { sourceId in
                if let source = skillService.registrySources.first(where: { $0.id == sourceId }) {
                    if source.type == "Local" {
                        Text("This will remove this local source from the app. The folder on disk will not be deleted.")
                    } else {
                        Text("This will delete this repository from the app.")
                    }
                } else {
                    Text("This will delete this source from the app.")
                }
            }
        }
    }
    
    private func openWebLink(source: String) {
        var urlStr = source
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
    
    private func deleteSource(sourceId: String) {
        do {
            try skillService.deleteSource(source: sourceId)
        } catch {
            print("Error deleting source: \(error)")
            // TODO: Show error alert to user
        }
    }
}

private struct RegistrySourceRow: View {
    let source: SkillService.RegistrySource
    let onDelete: () -> Void
    let onOpen: () -> Void
    
    private var summaryText: String {
        let preview = source.skills.prefix(2).joined(separator: ", ")
        let extra = source.skills.count - 2
        if extra > 0 {
            return "\(preview) +\(extra)"
        }
        return preview
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: source.type == "Git" ? "globe" : "folder")
                .font(.title2)
                .padding(10)
                .background((source.type == "Git" ? Color.blue : Color.orange).opacity(0.1))
                .foregroundColor(source.type == "Git" ? .blue : .orange)
                .cornerRadius(8)
                .overlay(alignment: .topTrailing) {
                     if source.updateAvailable {
                         Circle()
                             .fill(Color.green)
                             .frame(width: 10, height: 10)
                             .offset(x: 3, y: -3)
                             .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                     }
                }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(source.path)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                HStack(spacing: 8) {
                    Text(source.type)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background((source.type == "Git" ? Color.blue : Color.orange).opacity(0.1))
                        .foregroundColor(source.type == "Git" ? .blue : .orange)
                        .cornerRadius(4)
                    
                    if let lastChecked = source.lastChecked {
                        Text("Checked \(lastChecked.formatted(date: .numeric, time: .shortened))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            if !source.skills.isEmpty {
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.caption)
                        Text("\(source.skills.count)")
                            .font(.headline)
                    }
                    .foregroundColor(.blue)
                    
                    Text(summaryText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: 150, alignment: .trailing)
                }
            } else {
                Text("—")
                    .foregroundStyle(.secondary)
            }
            
            HStack(spacing: 0) {
                Button(action: onDelete) {
                    Image(systemName: "trash.circle")
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
                .help("Delete from App")
                .padding(.leading, 8)
                
                Button(action: onOpen) {
                    Image(systemName: source.type == "Git" ? "safari" : "folder")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Open in \(source.type == "Git" ? "Browser" : "Finder")")
                .padding(.leading, 8)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddSourceSheet: View {
    @ObservedObject var skillService: SkillService
    @Environment(\.dismiss) var dismiss
    
    @State private var sourceUrl = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 16) {
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
                        Text("user/repo,https://github.com/user/repo")
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
                    TextField("https://github.com/user/repo or /path/to/skills", text: $sourceUrl)
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
        .padding(20)
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
