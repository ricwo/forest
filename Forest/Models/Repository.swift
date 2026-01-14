import Foundation

struct Repository: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    let sourcePath: String
    var worktrees: [Worktree]

    init(id: UUID = UUID(), name: String, sourcePath: String, worktrees: [Worktree] = []) {
        self.id = id
        self.name = name
        self.sourcePath = sourcePath
        self.worktrees = worktrees
    }
}
