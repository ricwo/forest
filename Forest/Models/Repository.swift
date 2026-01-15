import Foundation

struct Repository: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    let sourcePath: String
    var worktrees: [Worktree]
    var sortOrder: Int?  // nil = use automatic sorting, set value = manual position

    init(id: UUID = UUID(), name: String, sourcePath: String, worktrees: [Worktree] = [], sortOrder: Int? = nil) {
        self.id = id
        self.name = name
        self.sourcePath = sourcePath
        self.worktrees = worktrees
        self.sortOrder = sortOrder
    }
}
