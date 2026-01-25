import SwiftUI

struct AvailableSkillsView: View {
    let repoUrl: String
    @StateObject private var skillService = SkillService() // New instance for fetching
    @StateObject private var agentService = AgentService()
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedSkill: Skill?
    
    // Sort logic? 
    // Just list for now.
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Fetching skills from \(repoUrl)...")
            } else if let error = errorMessage {
                ContentUnavailableView("Error Fetching Skills", systemImage: "exclamationmark.triangle", description: Text(error))
                Button("Retry") { fetch() }
            } else if skillService.availableSkills.isEmpty {
                 ContentUnavailableView("No Skills Found", systemImage: "magnifyingglass", description: Text("Could not find any skills in this repository."))
            } else {
                List(skillService.availableSkills) { skill in
                    HStack {
                         VStack(alignment: .leading) {
                            Text(skill.name)
                                .font(.headline)
                            if let desc = skill.description {
                                Text(desc)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Button("Install") {
                            selectedSkill = skill
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                     }
                     .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Available Skills")
        .sheet(item: $selectedSkill) { skill in
            InstallSheet(skill: skill, source: repoUrl, agentService: agentService, skillService: skillService)
        }
        .onAppear {
            if skillService.availableSkills.isEmpty {
                fetch()
            }
        }
    }
    
    private func fetch() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await skillService.fetchSkills(source: repoUrl)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// Reusing InstallSheet here or importing it? 
// It was defined in SkillStoreView.swift. 
// I should probably move InstallSheet to a shared file or redefine it here.
// I'll redefine it for now to ensure self-contained.

// InstallSheet moved to separate file or kept in AvailableSkillsView if unique.
// Since error says redeclaration, it likely exists in SkillStoreView.swift which is still in the project?
// I will just remove it from here if I can't delete the other file easily via swift tools (I can run rm).
// Actually, the user report says redeclaration in AvailableSkillsView.swift:77:8.
// This means it was ALREADY defined, likely in SkillStoreView.swift
// Since we removed SkillStoreView from navigation, we should delete SkillStoreView.swift.
