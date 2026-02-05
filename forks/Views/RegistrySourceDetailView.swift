import SwiftUI

struct RegistrySourceDetailView: View {
    // We iterate over sources in parent, so we passing it here as a value might be stale if parent doesn't redraw correctly?
    // Actually we probably want to look it up from service to be sure.
    let sourceId: String
    @ObservedObject var skillService: SkillService
    
    var source: SkillService.RegistrySource {
        skillService.registrySources.first(where: { $0.id == sourceId }) ?? SkillService.RegistrySource(id: "unknown", type: "Unknown", path: "Unknown", updateAvailable: false, lastChecked: nil, skills: [])
    }
    
    @State private var availableSkills: [Skill] = []
    @State private var selectedSkillNames: Set<String> = []
    @State private var searchText = ""
    @State private var showInstallSheet = false
    @State private var isLoadingSkills = false
    @State private var isUpdating = false
    @State private var showUpdateCompleteAlert = false
    
    var filteredSkills: [Skill] {
        if searchText.isEmpty {
            return availableSkills
        } else {
            return availableSkills.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                ($0.description?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(source.path)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    HStack {
                        Label(source.type, systemImage: source.type == "Git" ? "globe" : "folder")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                        
                        if source.updateAvailable {
                            Label("Update Available", systemImage: "arrow.down.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else {
                            Text("Up to date")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Spacer()
                
                HStack(spacing: 12) {
                    if source.updateAvailable {
                        Button("Update All") {
                            // Update all skills logic
                            isUpdating = true
                            Task {
                                do {
                                    try await skillService.updateAllSkillsInSource(source: source.path)
                                    showUpdateCompleteAlert = true
                                } catch {
                                    print("Failed to update all: \(error)")
                                    isUpdating = false // Dismiss only on error
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.green)
                        .disabled(isUpdating)
                    }
                    
                    Button(selectedSkillNames.count == filteredSkills.count && !filteredSkills.isEmpty ? "Deselect All" : "Select All") {
                        if selectedSkillNames.count == filteredSkills.count {
                            selectedSkillNames.removeAll()
                        } else {
                            selectedSkillNames = Set(filteredSkills.map { $0.name })
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                    .disabled(filteredSkills.isEmpty)
                    
                    Button("Install") {
                        showInstallSheet = true
                    }
                    .disabled(selectedSkillNames.isEmpty)
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .overlay(Divider(), alignment: .bottom)
            
            // Skills List
            if isLoadingSkills {
                VStack {
                    Spacer()
                    ProgressView("Loading skills...")
                    Spacer()
                }
            } else if availableSkills.isEmpty {
                ContentUnavailableView("No Skills Found", systemImage: "sparkles", description: Text("No skills found in this source."))
            } else {
                List {
                    ForEach(filteredSkills, id: \.name) { skill in
                        SkillSelectionRow(
                            skill: skill,
                            isSelected: selectedSkillNames.contains(skill.name),
                            isInstalled: isInstalled(skill.name),
                            onToggle: {
                                if selectedSkillNames.contains(skill.name) {
                                    selectedSkillNames.remove(skill.name)
                                } else {
                                    selectedSkillNames.insert(skill.name)
                                }
                            }
                        )
                    }
                }

            }
        }
        .navigationTitle("Source Details")
        .searchable(text: $searchText)
        .onAppear {
            loadSkills()
        }
        .sheet(isPresented: $showInstallSheet) {
            InstallSheet(
                skillService: skillService,
                agentService: AgentService(), 
                prefilledRepoUrl: source.path,
                prefilledSkills: Array(selectedSkillNames),
                onSuccess: {
                    selectedSkillNames.removeAll()
                }
            )
        }

        .sheet(isPresented: $isUpdating) {
            VStack(spacing: 20) {
                if showUpdateCompleteAlert {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("Update Complete")
                        .font(.headline)
                    Text("All installed skills have been updated.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    
                    Button("OK") {
                        showUpdateCompleteAlert = false
                        isUpdating = false
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 10)
                } else {
                    ProgressView()
                        .controlSize(.large)
                    Text("Updating, please wait...")
                        .font(.headline)
                }
            }
            .padding(40)
            .frame(width: 300, height: 250)
        }
    }
    
    private func loadSkills() {
        isLoadingSkills = true
        Task {
            let skills = await Task.detached {
                await MainActor.run { skillService.getSkillsInSource(source: source.path) }
            }.value
            await MainActor.run {
                self.availableSkills = skills
                self.isLoadingSkills = false
            }
        }
    }
    
    private func isInstalled(_ skillName: String) -> Bool {
        skillService.installedSkills.contains { $0.name == skillName }
    }
}

struct SkillSelectionRow: View {
    let skill: Skill
    let isSelected: Bool
    let isInstalled: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(skill.name)
                            .font(.headline)
                    }
                    
                    if let desc = skill.description {
                        Text(desc)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
