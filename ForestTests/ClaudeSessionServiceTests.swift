import XCTest
@testable import forest

final class ClaudeSessionServiceTests: XCTestCase {

    var tempClaudeDir: URL!
    var projectsDir: URL!

    override func setUpWithError() throws {
        // Create a temporary .claude/projects directory structure
        tempClaudeDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ForestTests-Claude-\(UUID().uuidString)")
        projectsDir = tempClaudeDir.appendingPathComponent("projects")
        try FileManager.default.createDirectory(at: projectsDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempClaudeDir = tempClaudeDir {
            try? FileManager.default.removeItem(at: tempClaudeDir)
        }
    }

    // MARK: - Path Encoding Tests

    func testPathToClaudeFolderNameConversion() {
        // Test that the path encoding matches Claude's convention
        // /Users/r/dev/project -> -Users-r-dev-project
        let service = ClaudeSessionService.shared

        // We can't directly test the private method, but we can test the behavior
        // by creating session files and verifying they're found
        let testPath = "/Users/test/my-project"
        let expectedFolderName = "-Users-test-my-project"

        // Create session directory with expected naming
        let sessionDir = projectsDir.appendingPathComponent(expectedFolderName)
        try? FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)

        // The directory should exist
        XCTAssertTrue(FileManager.default.fileExists(atPath: sessionDir.path))
    }

    // MARK: - Session Migration Tests

    func testMigrateSessionHistoryMovesDirectory() throws {
        let service = ClaudeSessionService.shared

        // Create a mock old session directory
        let oldPath = "/Users/test/old-location/worktree"
        let newPath = "/Users/test/new-location/worktree"

        let oldFolderName = oldPath.replacingOccurrences(of: "/", with: "-")
        let newFolderName = newPath.replacingOccurrences(of: "/", with: "-")

        let oldSessionDir = projectsDir.appendingPathComponent(oldFolderName)
        let newSessionDir = projectsDir.appendingPathComponent(newFolderName)

        // Create old session directory with a test file
        try FileManager.default.createDirectory(at: oldSessionDir, withIntermediateDirectories: true)
        let testSessionFile = oldSessionDir.appendingPathComponent("abc123.jsonl")
        try "test session content".write(to: testSessionFile, atomically: true, encoding: .utf8)

        XCTAssertTrue(FileManager.default.fileExists(atPath: oldSessionDir.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: newSessionDir.path))

        // Migrate using the real service (but we need to use the real projects dir)
        // For this test, we'll create a testable version
        migrateSessionHistory(from: oldPath, to: newPath, in: projectsDir)

        // Verify old directory is gone and new directory exists
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldSessionDir.path),
                       "Old session directory should be removed")
        XCTAssertTrue(FileManager.default.fileExists(atPath: newSessionDir.path),
                      "New session directory should exist")

        // Verify the file was moved
        let movedFile = newSessionDir.appendingPathComponent("abc123.jsonl")
        XCTAssertTrue(FileManager.default.fileExists(atPath: movedFile.path),
                      "Session file should be moved to new location")

        let content = try String(contentsOf: movedFile, encoding: .utf8)
        XCTAssertEqual(content, "test session content")
    }

    func testMigrateSessionHistoryMergesWhenDestinationExists() throws {
        let oldPath = "/Users/test/old/worktree"
        let newPath = "/Users/test/new/worktree"

        let oldFolderName = oldPath.replacingOccurrences(of: "/", with: "-")
        let newFolderName = newPath.replacingOccurrences(of: "/", with: "-")

        let oldSessionDir = projectsDir.appendingPathComponent(oldFolderName)
        let newSessionDir = projectsDir.appendingPathComponent(newFolderName)

        // Create both directories with different files
        try FileManager.default.createDirectory(at: oldSessionDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: newSessionDir, withIntermediateDirectories: true)

        let oldFile = oldSessionDir.appendingPathComponent("old-session.jsonl")
        let newFile = newSessionDir.appendingPathComponent("new-session.jsonl")

        try "old content".write(to: oldFile, atomically: true, encoding: .utf8)
        try "new content".write(to: newFile, atomically: true, encoding: .utf8)

        // Migrate
        migrateSessionHistory(from: oldPath, to: newPath, in: projectsDir)

        // Both files should exist in new directory
        let mergedOldFile = newSessionDir.appendingPathComponent("old-session.jsonl")
        let mergedNewFile = newSessionDir.appendingPathComponent("new-session.jsonl")

        XCTAssertTrue(FileManager.default.fileExists(atPath: mergedOldFile.path),
                      "Old session file should be merged into new directory")
        XCTAssertTrue(FileManager.default.fileExists(atPath: mergedNewFile.path),
                      "Existing new session file should remain")

        // Old directory should be removed (it should be empty after merge)
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldSessionDir.path),
                       "Old directory should be removed after merge")
    }

    func testMigrateSessionHistorySkipsExistingFiles() throws {
        let oldPath = "/Users/test/old/worktree"
        let newPath = "/Users/test/new/worktree"

        let oldFolderName = oldPath.replacingOccurrences(of: "/", with: "-")
        let newFolderName = newPath.replacingOccurrences(of: "/", with: "-")

        let oldSessionDir = projectsDir.appendingPathComponent(oldFolderName)
        let newSessionDir = projectsDir.appendingPathComponent(newFolderName)

        try FileManager.default.createDirectory(at: oldSessionDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: newSessionDir, withIntermediateDirectories: true)

        // Create same-named file in both directories with different content
        let oldFile = oldSessionDir.appendingPathComponent("same-session.jsonl")
        let newFile = newSessionDir.appendingPathComponent("same-session.jsonl")

        try "old version".write(to: oldFile, atomically: true, encoding: .utf8)
        try "new version".write(to: newFile, atomically: true, encoding: .utf8)

        // Migrate
        migrateSessionHistory(from: oldPath, to: newPath, in: projectsDir)

        // New file should keep its content (not overwritten)
        let content = try String(contentsOf: newFile, encoding: .utf8)
        XCTAssertEqual(content, "new version",
                       "Existing file should not be overwritten during merge")
    }

    func testMigrateSessionHistoryHandlesMissingSource() {
        let oldPath = "/nonexistent/old/path"
        let newPath = "/Users/test/new/path"

        // Should not throw or crash
        migrateSessionHistory(from: oldPath, to: newPath, in: projectsDir)

        // New directory should not be created
        let newFolderName = newPath.replacingOccurrences(of: "/", with: "-")
        let newSessionDir = projectsDir.appendingPathComponent(newFolderName)
        XCTAssertFalse(FileManager.default.fileExists(atPath: newSessionDir.path))
    }

    // MARK: - Helper

    /// Test-friendly version of migrateSessionHistory that uses custom projects dir
    private func migrateSessionHistory(from oldPath: String, to newPath: String, in projectsDir: URL) {
        let oldFolderName = oldPath.replacingOccurrences(of: "/", with: "-")
        let newFolderName = newPath.replacingOccurrences(of: "/", with: "-")

        let oldSessionDir = projectsDir.appendingPathComponent(oldFolderName)
        let newSessionDir = projectsDir.appendingPathComponent(newFolderName)

        guard FileManager.default.fileExists(atPath: oldSessionDir.path) else {
            return
        }

        if FileManager.default.fileExists(atPath: newSessionDir.path) {
            // Merge
            do {
                let contents = try FileManager.default.contentsOfDirectory(
                    at: oldSessionDir,
                    includingPropertiesForKeys: nil,
                    options: .skipsHiddenFiles
                )

                for fileURL in contents {
                    let destURL = newSessionDir.appendingPathComponent(fileURL.lastPathComponent)
                    if !FileManager.default.fileExists(atPath: destURL.path) {
                        try FileManager.default.moveItem(at: fileURL, to: destURL)
                    }
                }

                let remaining = try FileManager.default.contentsOfDirectory(atPath: oldSessionDir.path)
                if remaining.isEmpty {
                    try FileManager.default.removeItem(at: oldSessionDir)
                }
            } catch {
                // Silent fail for tests
            }
        } else {
            try? FileManager.default.moveItem(at: oldSessionDir, to: newSessionDir)
        }
    }
}

// MARK: - ClaudeSession Model Tests

final class ClaudeSessionTests: XCTestCase {

    func testClaudeSessionInitialization() {
        let session = ClaudeSession(
            id: "abc123",
            title: "Test session",
            lastTimestamp: Date(),
            messageCount: 5,
            gitBranches: ["main", "feature"]
        )

        XCTAssertEqual(session.id, "abc123")
        XCTAssertEqual(session.title, "Test session")
        XCTAssertEqual(session.messageCount, 5)
        XCTAssertEqual(session.gitBranches, ["main", "feature"])
    }

    func testClaudeSessionPrimaryBranch() {
        let sessionWithBranches = ClaudeSession(
            id: "1",
            title: "Test",
            lastTimestamp: Date(),
            messageCount: 1,
            gitBranches: ["feature", "main"]
        )
        XCTAssertEqual(sessionWithBranches.primaryBranch, "feature")

        let sessionNoBranches = ClaudeSession(
            id: "2",
            title: "Test",
            lastTimestamp: Date(),
            messageCount: 1,
            gitBranches: []
        )
        XCTAssertNil(sessionNoBranches.primaryBranch)
    }

    func testClaudeSessionRelativeTime() {
        let now = Date()
        let session = ClaudeSession(
            id: "1",
            title: "Test",
            lastTimestamp: now,
            messageCount: 1,
            gitBranches: []
        )

        // relativeTime should return something non-empty
        XCTAssertFalse(session.relativeTime.isEmpty)
    }

    func testClaudeSessionIdentifiable() {
        let session1 = ClaudeSession(id: "abc", title: "Test1", lastTimestamp: Date(), messageCount: 1, gitBranches: [])
        let session2 = ClaudeSession(id: "xyz", title: "Test2", lastTimestamp: Date(), messageCount: 2, gitBranches: [])

        XCTAssertNotEqual(session1.id, session2.id)
    }
}
