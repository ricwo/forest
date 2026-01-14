import Foundation

struct ClaudeSession: Identifiable, Hashable {
    let id: String  // Session UUID
    let title: String
    let lastTimestamp: Date
    let messageCount: Int
    let gitBranches: [String]

    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: lastTimestamp, relativeTo: Date())
    }

    var primaryBranch: String? {
        gitBranches.first
    }
}
