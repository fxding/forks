import SwiftUI
import Combine

class AgentService: ObservableObject {
    @Published var agents: [Agent] = []
    
    init() {
        self.agents = getAllAgents()
    }
    
    func getAllAgents() -> [Agent] {
        return Agent.supportedAgents.map { agent in
            var updatedAgent = agent
            let home = "/Users/\(NSUserName())"
            let expandedPath = agent.configPath.replacingOccurrences(of: "~", with: home)
            
            var isDir: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDir)
            if agent.name == "Cursor" || agent.name == "Antigravity" {
                print("Checking agent: \(agent.name)")
                print("Config path: \(agent.configPath)")
                print("Expanded path: \(expandedPath)")
                print("Exists: \(exists), IsDir: \(isDir.boolValue)")
            }
            
            if exists {
                updatedAgent.detected = isDir.boolValue
            } else {
                updatedAgent.detected = false
            }
            return updatedAgent
        }
    }
    
    func refreshAgents() {
        self.agents = getAllAgents()
    }
}
