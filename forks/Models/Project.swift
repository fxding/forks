import Foundation

struct Project: Identifiable, Hashable, Codable {
    let id: UUID
    let name: String       // Project name (directory name or user-defined)
    let path: String       // Absolute path to project root
    var addedDate: Date    // When project was added
    
    init(id: UUID = UUID(), name: String, path: String, addedDate: Date = Date()) {
        self.id = id
        self.name = name
        self.path = path
        self.addedDate = addedDate
    }
}
