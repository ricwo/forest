import Foundation

struct Worktree: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var branch: String
    var path: String
    var isArchived: Bool
    var sortOrder: Int?  // nil = use automatic sorting, set value = manual position
    var createdAt: Date

    init(id: UUID = UUID(), name: String, branch: String, path: String, isArchived: Bool = false, sortOrder: Int? = nil, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.branch = branch
        self.path = path
        self.isArchived = isArchived
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        branch = try container.decode(String.self, forKey: .branch)
        path = try container.decode(String.self, forKey: .path)
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .distantPast
    }

    func relativeCreatedTime(now: Date = Date()) -> String {
        guard createdAt != .distantPast else { return "" }
        if now.timeIntervalSince(createdAt) < 5 { return "just now" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: now)
    }

    /// Get the last modified time of the worktree directory
    var lastModified: Date {
        let url = URL(fileURLWithPath: path)
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        return values?.contentModificationDate ?? .distantPast
    }
}
