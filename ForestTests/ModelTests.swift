import XCTest
@testable import Forest

final class WorktreeTests: XCTestCase {

    func testWorktreeInitialization() {
        let worktree = Worktree(
            name: "feature-auth",
            branch: "feat/feature-auth",
            path: "/Users/test/forest/myrepo/feature-auth"
        )

        XCTAssertEqual(worktree.name, "feature-auth")
        XCTAssertEqual(worktree.branch, "feat/feature-auth")
        XCTAssertEqual(worktree.path, "/Users/test/forest/myrepo/feature-auth")
        XCTAssertFalse(worktree.isArchived, "New worktrees should not be archived by default")
        XCTAssertNotNil(worktree.id, "Worktree should have a UUID")
    }

    func testWorktreeWithCustomId() {
        let customId = UUID()
        let worktree = Worktree(
            id: customId,
            name: "test",
            branch: "test-branch",
            path: "/test/path"
        )

        XCTAssertEqual(worktree.id, customId)
    }

    func testWorktreeArchivedState() {
        var worktree = Worktree(
            name: "test",
            branch: "test-branch",
            path: "/test/path",
            isArchived: true
        )

        XCTAssertTrue(worktree.isArchived)

        worktree.isArchived = false
        XCTAssertFalse(worktree.isArchived)
    }

    func testWorktreeHashable() {
        let worktree1 = Worktree(name: "test", branch: "branch", path: "/path")
        let worktree2 = Worktree(name: "test", branch: "branch", path: "/path")

        // Different IDs means different hash
        XCTAssertNotEqual(worktree1.id, worktree2.id)

        // Same worktree should equal itself
        var set = Set<Worktree>()
        set.insert(worktree1)
        XCTAssertTrue(set.contains(worktree1))
        XCTAssertFalse(set.contains(worktree2))
    }

    func testWorktreeCodable() throws {
        let original = Worktree(
            name: "feature",
            branch: "feat/feature",
            path: "/path/to/feature",
            isArchived: true
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Worktree.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.branch, original.branch)
        XCTAssertEqual(decoded.path, original.path)
        XCTAssertEqual(decoded.isArchived, original.isArchived)
    }
}

final class RepositoryTests: XCTestCase {

    func testRepositoryInitialization() {
        let repo = Repository(name: "my-project", sourcePath: "/Users/test/projects/my-project")

        XCTAssertEqual(repo.name, "my-project")
        XCTAssertEqual(repo.sourcePath, "/Users/test/projects/my-project")
        XCTAssertTrue(repo.worktrees.isEmpty, "New repository should have no worktrees")
        XCTAssertNotNil(repo.id, "Repository should have a UUID")
    }

    func testRepositoryWithWorktrees() {
        var repo = Repository(name: "test", sourcePath: "/path")

        let worktree1 = Worktree(name: "feature1", branch: "feat/1", path: "/path/1")
        let worktree2 = Worktree(name: "feature2", branch: "feat/2", path: "/path/2")

        repo.worktrees.append(worktree1)
        repo.worktrees.append(worktree2)

        XCTAssertEqual(repo.worktrees.count, 2)
        XCTAssertEqual(repo.worktrees[0].name, "feature1")
        XCTAssertEqual(repo.worktrees[1].name, "feature2")
    }

    func testRepositoryCodable() throws {
        var original = Repository(name: "test-repo", sourcePath: "/path/to/repo")
        let worktree = Worktree(name: "feature", branch: "feat/test", path: "/worktree/path")
        original.worktrees.append(worktree)

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Repository.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.sourcePath, original.sourcePath)
        XCTAssertEqual(decoded.worktrees.count, 1)
        XCTAssertEqual(decoded.worktrees[0].name, "feature")
    }

    func testRepositoryIdentifiable() {
        let repo1 = Repository(name: "repo1", sourcePath: "/path1")
        let repo2 = Repository(name: "repo2", sourcePath: "/path2")

        XCTAssertNotEqual(repo1.id, repo2.id)
    }
}
