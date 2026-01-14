import Foundation

struct Worktree: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var branch: String
    var path: String
    var isArchived: Bool
    var sortOrder: Int?  // nil = use automatic sorting, set value = manual position

    init(id: UUID = UUID(), name: String, branch: String, path: String, isArchived: Bool = false, sortOrder: Int? = nil) {
        self.id = id
        self.name = name
        self.branch = branch
        self.path = path
        self.isArchived = isArchived
        self.sortOrder = sortOrder
    }

    /// Get the last modified time of the worktree directory
    var lastModified: Date {
        let url = URL(fileURLWithPath: path)
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        return values?.contentModificationDate ?? .distantPast
    }
}
