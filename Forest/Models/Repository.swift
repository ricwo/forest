import Foundation

struct Repository: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    let sourcePath: String
    var worktrees: [Worktree]
    var sortOrder: Int?  // nil = use automatic sorting, set value = manual position

    // Per-project settings (nil = use global default)
    var defaultTerminal: Terminal?
    var claudeCommand: String?  // e.g., "claude", "claude-personal", "claude-work"

    init(id: UUID = UUID(), name: String, sourcePath: String, worktrees: [Worktree] = [], sortOrder: Int? = nil, defaultTerminal: Terminal? = nil, claudeCommand: String? = nil) {
        self.id = id
        self.name = name
        self.sourcePath = sourcePath
        self.worktrees = worktrees
        self.sortOrder = sortOrder
        self.defaultTerminal = defaultTerminal
        self.claudeCommand = claudeCommand
    }
}
