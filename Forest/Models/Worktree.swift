import Foundation

struct Worktree: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var branch: String
    var path: String
    var isArchived: Bool

    init(id: UUID = UUID(), name: String, branch: String, path: String, isArchived: Bool = false) {
        self.id = id
        self.name = name
        self.branch = branch
        self.path = path
        self.isArchived = isArchived
    }
}
