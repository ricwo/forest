import Foundation

struct Repository: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    let sourcePath: String
    var worktrees: [Worktree]

    // Per-project settings (nil = use global default)
    var defaultTerminal: Terminal?
    var claudeCommand: String?  // e.g., "claude", "claude-personal", "claude-work"

    init(id: UUID = UUID(), name: String, sourcePath: String, worktrees: [Worktree] = [], defaultTerminal: Terminal? = nil, claudeCommand: String? = nil) {
        self.id = id
        self.name = name
        self.sourcePath = sourcePath
        self.worktrees = worktrees
        self.defaultTerminal = defaultTerminal
        self.claudeCommand = claudeCommand
    }
}
