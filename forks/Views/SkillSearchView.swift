import SwiftUI
import Combine
import Foundation

@MainActor
class SkillSearchViewModel: ObservableObject {
    @Published var skills: [SearchSkill] = []
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var debounceTimer: Timer?
    private weak var skillService: SkillService?
    
    init(skillService: SkillService? = nil) {
        self.skillService = skillService
        if let service = skillService {
            self.searchText = service.globalSearchQuery
            self.skills = service.globalSearchResults
        }
    }
    
    func search(query: String) {
        // Sync to service
        skillService?.globalSearchQuery = query
        
        debounceTimer?.invalidate()
        
        guard query.count >= 2 else {
            skills = []
            skillService?.globalSearchResults = []
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.performSearch(query: query)
            }
        }
    }
    
    private func performSearch(query: String) async {
        guard let url = URL(string: "https://skills.sh/api/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&limit=10") else {
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let result = try JSONDecoder().decode(SearchResponse.self, from: data)
            self.skills = result.skills
            self.skillService?.globalSearchResults = result.skills
            self.isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }
}

struct SkillSearchView: View {
    @StateObject private var viewModel: SkillSearchViewModel
    @ObservedObject var skillService: SkillService
    @ObservedObject var projectService: ProjectService
    
    init(skillService: SkillService, projectService: ProjectService) {
        self.skillService = skillService
        self.projectService = projectService
        _viewModel = StateObject(wrappedValue: SkillSearchViewModel(skillService: skillService))
    }
    
    @StateObject private var agentService = AgentService()
    
    @State private var selectedSkillToInstall: SearchSkill?
    
    var body: some View {
        VStack {
            HStack {
                Image(systemName: "magnifyingglass")
                TextField("Search skills (min 2 chars)", text: $viewModel.searchText)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: viewModel.searchText) { newValue in
                        viewModel.search(query: newValue)
                    }
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                }
            }
            .padding()
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            }
            
            if viewModel.skills.isEmpty {
                if !viewModel.searchText.isEmpty && !viewModel.isLoading {
                    Text("No skills found")
                        .foregroundColor(.secondary)
                        .padding()
                } else if viewModel.searchText.isEmpty {
                     Text("Start typing to search available skills")
                        .foregroundColor(.secondary)
                        .padding()
                }
                Spacer()
            } else {
                List(viewModel.skills) { skill in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(skill.name)
                                .font(.headline)
                            Text(skill.source.isEmpty ? skill.id : skill.source)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        
                        Text("\(skill.installs) installs")
                            .font(.caption2)
                            .padding(4)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                        
                        Button("Install") {
                            selectedSkillToInstall = skill
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Search Skills")
        .sheet(item: $selectedSkillToInstall) { skill in
            InstallSheet(
                skillService: skillService,
                agentService: agentService,
                prefilledRepoUrl: skill.source.isEmpty ? skill.id : skill.source,
                prefilledSkills: [skill.name]
            )
        }
    }
}
