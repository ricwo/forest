import Foundation

struct ClaudeSessionService {
    static let shared = ClaudeSessionService()

    private let projectsDir: URL

    private init() {
        projectsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude")
            .appendingPathComponent("projects")
    }

    /// Convert a repo/worktree path to Claude's folder naming convention
    /// e.g., /Users/r/dev/pq -> -Users-r-dev-pq
    private func pathToClaudeFolderName(_ path: String) -> String {
        path.replacingOccurrences(of: "/", with: "-")
    }

    /// Get sessions for a given repo or worktree path
    func getSessions(for path: String) -> [ClaudeSession] {
        let folderName = pathToClaudeFolderName(path)
        let sessionDir = projectsDir.appendingPathComponent(folderName)

        guard FileManager.default.fileExists(atPath: sessionDir.path) else {
            return []
        }

        var sessions: [ClaudeSession] = []

        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: sessionDir,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: .skipsHiddenFiles
            )

            for fileURL in contents {
                // Only process .jsonl files, skip agent-* files
                guard fileURL.pathExtension == "jsonl",
                      !fileURL.lastPathComponent.hasPrefix("agent-") else {
                    continue
                }

                if let session = parseSessionFile(fileURL) {
                    sessions.append(session)
                }
            }
        } catch {
            return []
        }

        // Sort by timestamp descending (most recent first)
        return sessions.sorted { $0.lastTimestamp > $1.lastTimestamp }
    }

    /// Parse a single JSONL session file
    private func parseSessionFile(_ fileURL: URL) -> ClaudeSession? {
        guard let data = FileManager.default.contents(atPath: fileURL.path),
              let content = String(data: data, encoding: .utf8) else {
            return nil
        }

        let lines = content.components(separatedBy: .newlines)

        var firstTimestamp: Date?
        var lastTimestamp: Date?
        var gitBranches = Set<String>()
        var realUserMessages: [String] = []
        var totalUserMessages = 0

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        for line in lines {
            guard !line.isEmpty,
                  let lineData = line.data(using: .utf8),
                  let record = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                continue
            }

            guard let recordType = record["type"] as? String, recordType == "user" else {
                continue
            }

            totalUserMessages += 1

            // Parse timestamp
            if let timestampStr = record["timestamp"] as? String,
               let timestamp = dateFormatter.date(from: timestampStr) {
                if firstTimestamp.map({ timestamp < $0 }) ?? true {
                    firstTimestamp = timestamp
                }
                if lastTimestamp.map({ timestamp > $0 }) ?? true {
                    lastTimestamp = timestamp
                }
            }

            // Collect git branch
            if let branch = record["gitBranch"] as? String {
                gitBranches.insert(branch)
            }

            // Extract message content
            let content = extractMessageContent(from: record)
            if isRealUserMessage(content) {
                realUserMessages.append(content)
            }
        }

        // Title is the first real user message
        guard let title = realUserMessages.first,
              let timestamp = lastTimestamp else {
            return nil
        }

        // Get first line, truncate
        let titleLine = String(title.split(separator: "\n").first ?? "")
        let truncatedTitle = String(titleLine.prefix(100))

        let sessionId = fileURL.deletingPathExtension().lastPathComponent

        return ClaudeSession(
            id: sessionId,
            title: truncatedTitle,
            lastTimestamp: timestamp,
            messageCount: totalUserMessages,
            gitBranches: Array(gitBranches)
        )
    }

    /// Extract text content from a message record
    private func extractMessageContent(from record: [String: Any]) -> String {
        guard let message = record["message"] as? [String: Any] else {
            return ""
        }

        if let content = message["content"] as? String {
            return content
        }

        // Handle content blocks (list of text/image blocks)
        if let contentBlocks = message["content"] as? [[String: Any]] {
            let textParts = contentBlocks.compactMap { block -> String? in
                guard block["type"] as? String == "text" else { return nil }
                return block["text"] as? String
            }
            return textParts.joined(separator: " ")
        }

        return ""
    }

    /// Check if a message is a real user message (not a system/command wrapper)
    private func isRealUserMessage(_ content: String) -> Bool {
        guard !content.isEmpty else { return false }

        // Filter out system/command wrapper messages
        if content.hasPrefix("<local-command-") { return false }
        if content.hasPrefix("<command-name>") { return false }

        return true
    }

    /// Migrate Claude session history from old path to new path
    /// This should be called when a worktree is moved to a new location
    func migrateSessionHistory(from oldPath: String, to newPath: String) {
        let oldFolderName = pathToClaudeFolderName(oldPath)
        let newFolderName = pathToClaudeFolderName(newPath)

        let oldSessionDir = projectsDir.appendingPathComponent(oldFolderName)
        let newSessionDir = projectsDir.appendingPathComponent(newFolderName)

        // Check if old session directory exists
        guard FileManager.default.fileExists(atPath: oldSessionDir.path) else {
            return
        }

        // If new directory already exists, merge instead of replace
        if FileManager.default.fileExists(atPath: newSessionDir.path) {
            // Move individual files from old to new
            do {
                let contents = try FileManager.default.contentsOfDirectory(
                    at: oldSessionDir,
                    includingPropertiesForKeys: nil,
                    options: .skipsHiddenFiles
                )

                for fileURL in contents {
                    let destURL = newSessionDir.appendingPathComponent(fileURL.lastPathComponent)
                    // Skip if file already exists at destination
                    if !FileManager.default.fileExists(atPath: destURL.path) {
                        try FileManager.default.moveItem(at: fileURL, to: destURL)
                    }
                }

                // Remove old directory if empty
                let remaining = try FileManager.default.contentsOfDirectory(atPath: oldSessionDir.path)
                if remaining.isEmpty {
                    try FileManager.default.removeItem(at: oldSessionDir)
                }
            } catch {
                print("Failed to merge session history: \(error)")
            }
        } else {
            // Simply move the entire directory
            do {
                try FileManager.default.moveItem(at: oldSessionDir, to: newSessionDir)
            } catch {
                print("Failed to migrate session history: \(error)")
            }
        }
    }
}
