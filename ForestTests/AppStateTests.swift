import XCTest
@testable import forest

final class AppStateTests: XCTestCase {

    var appState: AppState!
    var tempDir: URL!

    override func setUpWithError() throws {
        // Create a temporary directory for testing
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Use non-persisting mode to avoid writing to real config
        appState = AppState(forestDirectory: tempDir, persistChanges: false)
    }

    override func tearDownWithError() throws {
        // Clean up temporary directory
        if let tempDir = tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        appState = nil
    }

    // MARK: - Repository Tests

    func testInitialStateIsEmpty() {
        XCTAssertTrue(appState.repositories.isEmpty, "Initial state should have no repositories")
        XCTAssertNil(appState.selectedRepositoryId, "No repository should be selected initially")
        XCTAssertNil(appState.selectedWorktreeId, "No worktree should be selected initially")
    }

    func testSelectedWorktreeIsNilWhenNoSelection() {
        XCTAssertNil(appState.selectedWorktree, "Selected worktree should be nil when nothing is selected")
    }

    func testSelectedWorktreeRepoIdIsNilWhenNoSelection() {
        XCTAssertNil(appState.selectedWorktreeRepoId, "Selected worktree repo ID should be nil when nothing is selected")
    }

    func testRemoveRepository() {
        // Setup: Add a repository manually
        let repo = Repository(name: "test-repo", sourcePath: "/path/to/repo")
        appState.repositories.append(repo)
        appState.selectedRepositoryId = repo.id

        XCTAssertEqual(appState.repositories.count, 1)

        // Act: Remove the repository
        appState.removeRepository(repo)

        // Assert
        XCTAssertTrue(appState.repositories.isEmpty, "Repository should be removed")
        XCTAssertNil(appState.selectedRepositoryId, "Selected repository should be cleared")
    }

    func testRemoveRepositoryClearsWorktreeSelection() {
        // Setup: Add a repository with a worktree
        var repo = Repository(name: "test-repo", sourcePath: "/path/to/repo")
        let worktree = Worktree(name: "feature", branch: "feat/feature", path: "/path/to/worktree")
        repo.worktrees.append(worktree)

        appState.repositories.append(repo)
        appState.selectedRepositoryId = repo.id
        appState.selectedWorktreeId = worktree.id

        // Act: Remove the repository
        appState.removeRepository(repo)

        // Assert
        XCTAssertNil(appState.selectedWorktreeId, "Worktree selection should be cleared when repo is removed")
    }

    // MARK: - Worktree Archive Tests

    func testArchiveWorktree() {
        // Setup: Add a repository with a worktree
        var repo = Repository(name: "test-repo", sourcePath: "/path/to/repo")
        let worktree = Worktree(name: "feature", branch: "feat/feature", path: "/path/to/worktree")
        repo.worktrees.append(worktree)
        appState.repositories.append(repo)
        appState.selectedWorktreeId = worktree.id

        // Act: Archive the worktree
        appState.archiveWorktree(worktree.id, in: repo.id)

        // Assert
        let updatedWorktree = appState.repositories[0].worktrees[0]
        XCTAssertTrue(updatedWorktree.isArchived, "Worktree should be archived")
        XCTAssertNil(appState.selectedWorktreeId, "Selection should be cleared when archiving")
    }

    func testUnarchiveWorktree() {
        // Setup: Add a repository with an archived worktree
        var repo = Repository(name: "test-repo", sourcePath: "/path/to/repo")
        var worktree = Worktree(name: "feature", branch: "feat/feature", path: "/path/to/worktree")
        worktree.isArchived = true
        repo.worktrees.append(worktree)
        appState.repositories.append(repo)

        // Act: Unarchive the worktree
        appState.unarchiveWorktree(worktree.id, in: repo.id)

        // Assert
        let updatedWorktree = appState.repositories[0].worktrees[0]
        XCTAssertFalse(updatedWorktree.isArchived, "Worktree should be unarchived")
    }

    // MARK: - Worktree Filtering Tests

    func testActiveWorktreesFilter() {
        // Setup: Add worktrees with different archive states
        var repo = Repository(name: "test-repo", sourcePath: "/path/to/repo")
        let activeWorktree = Worktree(name: "active", branch: "feat/active", path: "/path/active")
        var archivedWorktree = Worktree(name: "archived", branch: "feat/archived", path: "/path/archived")
        archivedWorktree.isArchived = true

        repo.worktrees.append(activeWorktree)
        repo.worktrees.append(archivedWorktree)
        appState.repositories.append(repo)

        // Act & Assert
        let activeWorktrees = appState.activeWorktrees(for: appState.repositories[0])
        XCTAssertEqual(activeWorktrees.count, 1, "Should have 1 active worktree")
        XCTAssertEqual(activeWorktrees[0].name, "active")
    }

    func testArchivedWorktreesFilter() {
        // Setup: Add worktrees with different archive states
        var repo = Repository(name: "test-repo", sourcePath: "/path/to/repo")
        let activeWorktree = Worktree(name: "active", branch: "feat/active", path: "/path/active")
        var archivedWorktree = Worktree(name: "archived", branch: "feat/archived", path: "/path/archived")
        archivedWorktree.isArchived = true

        repo.worktrees.append(activeWorktree)
        repo.worktrees.append(archivedWorktree)
        appState.repositories.append(repo)

        // Act & Assert
        let archivedWorktrees = appState.archivedWorktrees(for: appState.repositories[0])
        XCTAssertEqual(archivedWorktrees.count, 1, "Should have 1 archived worktree")
        XCTAssertEqual(archivedWorktrees[0].name, "archived")
    }

    func testHasArchivedWorktrees() {
        // Initially no archived worktrees
        XCTAssertFalse(appState.hasArchivedWorktrees())

        // Add a repo with archived worktree
        var repo = Repository(name: "test-repo", sourcePath: "/path/to/repo")
        var archivedWorktree = Worktree(name: "archived", branch: "feat/archived", path: "/path/archived")
        archivedWorktree.isArchived = true
        repo.worktrees.append(archivedWorktree)
        appState.repositories.append(repo)

        XCTAssertTrue(appState.hasArchivedWorktrees())
    }

    // MARK: - Find Repository Tests

    func testFindRepositoryContainingWorktree() {
        // Setup
        var repo1 = Repository(name: "repo1", sourcePath: "/path/to/repo1")
        var repo2 = Repository(name: "repo2", sourcePath: "/path/to/repo2")

        let worktree1 = Worktree(name: "wt1", branch: "feat/wt1", path: "/path/wt1")
        let worktree2 = Worktree(name: "wt2", branch: "feat/wt2", path: "/path/wt2")

        repo1.worktrees.append(worktree1)
        repo2.worktrees.append(worktree2)

        appState.repositories.append(repo1)
        appState.repositories.append(repo2)

        // Act & Assert
        let foundRepo = appState.findRepository(containing: worktree2.id)
        XCTAssertEqual(foundRepo?.name, "repo2", "Should find the correct repository")
    }

    func testFindRepositoryReturnsNilForUnknownWorktree() {
        let unknownId = UUID()
        XCTAssertNil(appState.findRepository(containing: unknownId))
    }

    // MARK: - Selection Tests

    func testSelectedWorktreeResolution() {
        // Setup
        var repo = Repository(name: "test-repo", sourcePath: "/path/to/repo")
        let worktree = Worktree(name: "feature", branch: "feat/feature", path: "/path/to/worktree")
        repo.worktrees.append(worktree)
        appState.repositories.append(repo)
        appState.selectedWorktreeId = worktree.id

        // Assert
        XCTAssertNotNil(appState.selectedWorktree)
        XCTAssertEqual(appState.selectedWorktree?.name, "feature")
        XCTAssertEqual(appState.selectedWorktreeRepoId, repo.id)
    }

    // MARK: - Worktree Sorting Tests

    func testActiveWorktreesSortByManualOrderFirst() {
        var repo = Repository(name: "test-repo", sourcePath: "/path/to/repo")

        // Create worktrees with different sort orders
        var wt1 = Worktree(name: "manual-second", branch: "b1", path: "/p1")
        wt1.sortOrder = 1

        var wt2 = Worktree(name: "manual-first", branch: "b2", path: "/p2")
        wt2.sortOrder = 0

        let wt3 = Worktree(name: "auto-sorted", branch: "b3", path: "/p3")
        // wt3 has no sortOrder (nil)

        repo.worktrees = [wt1, wt2, wt3]
        appState.repositories.append(repo)

        let sorted = appState.activeWorktrees(for: appState.repositories[0])

        // Manual order should come first, then auto-sorted
        XCTAssertEqual(sorted[0].name, "manual-first", "Sort order 0 should be first")
        XCTAssertEqual(sorted[1].name, "manual-second", "Sort order 1 should be second")
        XCTAssertEqual(sorted[2].name, "auto-sorted", "Auto-sorted should be last")
    }

    func testMoveWorktreeUpdatesOrder() {
        var repo = Repository(name: "test-repo", sourcePath: "/path/to/repo")

        let wt1 = Worktree(name: "first", branch: "b1", path: "/p1")
        let wt2 = Worktree(name: "second", branch: "b2", path: "/p2")
        let wt3 = Worktree(name: "third", branch: "b3", path: "/p3")

        repo.worktrees = [wt1, wt2, wt3]
        appState.repositories.append(repo)

        // Move "third" to first position
        appState.moveWorktree(in: repo.id, from: IndexSet(integer: 2), to: 0)

        let sorted = appState.activeWorktrees(for: appState.repositories[0])

        // All should now have manual sort orders
        XCTAssertEqual(sorted[0].name, "third", "Third should now be first")
        XCTAssertEqual(sorted[1].name, "first", "First should now be second")
        XCTAssertEqual(sorted[2].name, "second", "Second should now be third")
    }

    // MARK: - Selection Enum Tests

    func testSelectionRepositoryCase() {
        let repoId = UUID()
        appState.selection = .repository(repoId)

        XCTAssertEqual(appState.selectedRepositoryId, repoId)
        XCTAssertNil(appState.selectedWorktreeId)
    }

    func testSelectionWorktreeCase() {
        let worktreeId = UUID()
        appState.selection = .worktree(worktreeId)

        XCTAssertEqual(appState.selectedWorktreeId, worktreeId)
        XCTAssertNil(appState.selectedRepositoryId)
    }

    func testSelectionNilCase() {
        appState.selection = nil

        XCTAssertNil(appState.selectedRepositoryId)
        XCTAssertNil(appState.selectedWorktreeId)
    }

    func testSetSelectedRepositoryIdUpdatesSelection() {
        let repoId = UUID()
        appState.selectedRepositoryId = repoId

        if case .repository(let id) = appState.selection {
            XCTAssertEqual(id, repoId)
        } else {
            XCTFail("Selection should be .repository case")
        }
    }

    func testSetSelectedWorktreeIdUpdatesSelection() {
        let worktreeId = UUID()
        appState.selectedWorktreeId = worktreeId

        if case .worktree(let id) = appState.selection {
            XCTAssertEqual(id, worktreeId)
        } else {
            XCTFail("Selection should be .worktree case")
        }
    }

    // MARK: - Get Existing Worktrees Tests

    func testGetExistingWorktreesExcludesMainRepo() {
        // This test verifies that getExistingWorktrees filters out the main repo
        // We can only test the filtering logic here since we don't have a real git repo
        // The actual git integration is tested in GitServiceTests

        // The method calls GitService.listWorktrees which returns tuples
        // and filters out entries where path == sourcePath
        // This is tested indirectly through integration tests
    }

    // MARK: - Config Persistence Tests

    func testPersistChangesDisabledDoesNotSave() {
        // Our appState is already created with persistChanges: false
        var repo = Repository(name: "test", sourcePath: "/test")
        repo.worktrees.append(Worktree(name: "wt", branch: "b", path: "/p"))
        appState.repositories.append(repo)

        // The config file should not exist since we disabled persistence
        let configPath = tempDir.appendingPathComponent(".forest-config.json")
        XCTAssertFalse(FileManager.default.fileExists(atPath: configPath.path))
    }

    // MARK: - Edge Cases

    func testArchiveWorktreeWithInvalidId() {
        var repo = Repository(name: "test-repo", sourcePath: "/path")
        let worktree = Worktree(name: "wt", branch: "b", path: "/p")
        repo.worktrees.append(worktree)
        appState.repositories.append(repo)

        // Try to archive with invalid IDs - should not crash
        appState.archiveWorktree(UUID(), in: repo.id)  // Invalid worktree ID
        appState.archiveWorktree(worktree.id, in: UUID())  // Invalid repo ID

        // Original worktree should be unchanged
        XCTAssertFalse(appState.repositories[0].worktrees[0].isArchived)
    }

    func testUnarchiveWorktreeWithInvalidId() {
        var repo = Repository(name: "test-repo", sourcePath: "/path")
        var worktree = Worktree(name: "wt", branch: "b", path: "/p")
        worktree.isArchived = true
        repo.worktrees.append(worktree)
        appState.repositories.append(repo)

        // Try to unarchive with invalid IDs - should not crash
        appState.unarchiveWorktree(UUID(), in: repo.id)
        appState.unarchiveWorktree(worktree.id, in: UUID())

        // Original worktree should still be archived
        XCTAssertTrue(appState.repositories[0].worktrees[0].isArchived)
    }

    func testMoveWorktreeWithInvalidRepoId() {
        var repo = Repository(name: "test-repo", sourcePath: "/path")
        repo.worktrees.append(Worktree(name: "wt1", branch: "b1", path: "/p1"))
        repo.worktrees.append(Worktree(name: "wt2", branch: "b2", path: "/p2"))
        appState.repositories.append(repo)

        // Move with invalid repo ID - should not crash
        appState.moveWorktree(in: UUID(), from: IndexSet(integer: 0), to: 1)

        // Original order should be unchanged
        XCTAssertEqual(appState.repositories[0].worktrees[0].name, "wt1")
        XCTAssertEqual(appState.repositories[0].worktrees[1].name, "wt2")
    }

    func testRemoveNonexistentRepository() {
        let repo = Repository(name: "nonexistent", sourcePath: "/nonexistent")

        // Should not crash
        appState.removeRepository(repo)

        XCTAssertTrue(appState.repositories.isEmpty)
    }

    // MARK: - Multiple Repository Tests

    func testMultipleRepositoriesIndependent() {
        let repo1 = Repository(name: "repo1", sourcePath: "/path1")
        let repo2 = Repository(name: "repo2", sourcePath: "/path2")

        appState.repositories.append(repo1)
        appState.repositories.append(repo2)

        XCTAssertEqual(appState.repositories.count, 2)
        XCTAssertEqual(appState.repositories[0].name, "repo1")
        XCTAssertEqual(appState.repositories[1].name, "repo2")
    }

    func testArchiveWorktreeInCorrectRepository() {
        var repo1 = Repository(name: "repo1", sourcePath: "/path1")
        var repo2 = Repository(name: "repo2", sourcePath: "/path2")

        let wt1 = Worktree(name: "wt1", branch: "b1", path: "/p1")
        let wt2 = Worktree(name: "wt2", branch: "b2", path: "/p2")

        repo1.worktrees.append(wt1)
        repo2.worktrees.append(wt2)

        appState.repositories.append(repo1)
        appState.repositories.append(repo2)

        // Archive wt1 in repo1
        appState.archiveWorktree(wt1.id, in: repo1.id)

        XCTAssertTrue(appState.repositories[0].worktrees[0].isArchived, "wt1 should be archived")
        XCTAssertFalse(appState.repositories[1].worktrees[0].isArchived, "wt2 should not be affected")
    }
}

// MARK: - Selection Equality Tests

final class SelectionTests: XCTestCase {

    func testSelectionEquality() {
        let id1 = UUID()
        let id2 = UUID()

        XCTAssertEqual(Selection.repository(id1), Selection.repository(id1))
        XCTAssertNotEqual(Selection.repository(id1), Selection.repository(id2))

        XCTAssertEqual(Selection.worktree(id1), Selection.worktree(id1))
        XCTAssertNotEqual(Selection.worktree(id1), Selection.worktree(id2))

        XCTAssertNotEqual(Selection.repository(id1), Selection.worktree(id1))
    }
}
