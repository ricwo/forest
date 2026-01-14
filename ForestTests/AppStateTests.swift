import XCTest
@testable import Forest

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
}
