import XCTest
@testable import forest

final class GitServiceTests: XCTestCase {

    var tempDir: URL!
    var repoPath: String!

    override func setUpWithError() throws {
        // Create a temporary directory with a git repo for testing
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ForestTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        repoPath = tempDir.appendingPathComponent("test-repo").path

        // Initialize a git repo
        try FileManager.default.createDirectory(atPath: repoPath, withIntermediateDirectories: true)
        runShell("git init", in: repoPath)
        runShell("git config user.email 'test@test.com'", in: repoPath)
        runShell("git config user.name 'Test'", in: repoPath)

        // Create an initial commit so we have a branch
        let testFile = URL(fileURLWithPath: repoPath).appendingPathComponent("README.md")
        try "# Test".write(to: testFile, atomically: true, encoding: .utf8)
        runShell("git add .", in: repoPath)
        runShell("git commit -m 'Initial commit'", in: repoPath)
    }

    override func tearDownWithError() throws {
        // Clean up
        if let tempDir = tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
    }

    // MARK: - Repository Detection Tests

    func testIsGitRepository() {
        XCTAssertTrue(GitService.shared.isGitRepository(at: repoPath))
    }

    func testIsNotGitRepository() {
        let nonRepoPath = tempDir.appendingPathComponent("not-a-repo").path
        try? FileManager.default.createDirectory(atPath: nonRepoPath, withIntermediateDirectories: true)

        XCTAssertFalse(GitService.shared.isGitRepository(at: nonRepoPath))
    }

    func testGetRepositoryName() {
        let name = GitService.shared.getRepositoryName(at: repoPath)
        XCTAssertEqual(name, "test-repo")
    }

    // MARK: - Branch Tests

    func testGetCurrentBranch() {
        let branch = GitService.shared.getCurrentBranch(at: repoPath)
        // Git default branch could be 'main' or 'master' depending on config
        XCTAssertNotNil(branch)
        XCTAssertFalse(branch!.isEmpty)
    }

    func testListBranches() {
        let branches = GitService.shared.listBranches(at: repoPath)
        XCTAssertFalse(branches.isEmpty, "Should have at least one branch")
    }

    func testListBranchesIncludesNewBranch() {
        // Create a new branch
        runShell("git branch test-feature", in: repoPath)

        let branches = GitService.shared.listBranches(at: repoPath)
        XCTAssertTrue(branches.contains("test-feature"), "Should include the new branch")
    }

    // MARK: - Worktree Tests

    func testAddWorktreeWithNewBranch() throws {
        let worktreePath = tempDir.appendingPathComponent("worktree-new").path

        try GitService.shared.addWorktree(
            repoPath: repoPath,
            worktreePath: worktreePath,
            branch: "feat/new-feature",
            createBranch: true
        )

        // Verify worktree was created
        XCTAssertTrue(FileManager.default.fileExists(atPath: worktreePath))
        XCTAssertTrue(GitService.shared.isGitRepository(at: worktreePath))
    }

    func testAddWorktreeWithExistingBranch() throws {
        // First create a branch
        runShell("git branch existing-branch", in: repoPath)

        let worktreePath = tempDir.appendingPathComponent("worktree-existing").path

        try GitService.shared.addWorktree(
            repoPath: repoPath,
            worktreePath: worktreePath,
            branch: "existing-branch",
            createBranch: false
        )

        // Verify worktree was created
        XCTAssertTrue(FileManager.default.fileExists(atPath: worktreePath))
    }

    func testRemoveWorktree() throws {
        // First create a worktree
        let worktreePath = tempDir.appendingPathComponent("worktree-to-remove").path

        try GitService.shared.addWorktree(
            repoPath: repoPath,
            worktreePath: worktreePath,
            branch: "feat/to-remove",
            createBranch: true
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: worktreePath))

        // Now remove it
        try GitService.shared.removeWorktree(repoPath: repoPath, worktreePath: worktreePath)

        XCTAssertFalse(FileManager.default.fileExists(atPath: worktreePath))
    }

    func testListWorktrees() throws {
        // Create a worktree
        let worktreePath = tempDir.appendingPathComponent("worktree-list").path

        try GitService.shared.addWorktree(
            repoPath: repoPath,
            worktreePath: worktreePath,
            branch: "feat/list-test",
            createBranch: true
        )

        let worktrees = GitService.shared.listWorktrees(repoPath: repoPath)

        // Should have at least 2 worktrees (main + new one)
        XCTAssertGreaterThanOrEqual(worktrees.count, 2)

        // Should include our new worktree (compare resolved paths to handle symlinks)
        let resolvedWorktreePath = URL(fileURLWithPath: worktreePath).standardizedFileURL.path
        let found = worktrees.contains { wt in
            let resolvedPath = URL(fileURLWithPath: wt.path).standardizedFileURL.path
            return resolvedPath == resolvedWorktreePath && wt.branch == "feat/list-test"
        }
        XCTAssertTrue(found, "Should find the created worktree in the list")
    }

    // MARK: - Branch Rename Tests

    func testRenameBranch() throws {
        // Create a worktree with a branch
        let worktreePath = tempDir.appendingPathComponent("worktree-rename").path

        try GitService.shared.addWorktree(
            repoPath: repoPath,
            worktreePath: worktreePath,
            branch: "feat/old-name",
            createBranch: true
        )

        // Rename the branch
        try GitService.shared.renameBranch(
            at: worktreePath,
            from: "feat/old-name",
            to: "feat/new-name"
        )

        // Verify the branch was renamed
        let currentBranch = GitService.shared.getCurrentBranch(at: worktreePath)
        XCTAssertEqual(currentBranch, "feat/new-name")
    }

    // MARK: - Error Handling Tests

    func testAddWorktreeFailsForInvalidPath() {
        XCTAssertThrowsError(try GitService.shared.addWorktree(
            repoPath: "/nonexistent/path",
            worktreePath: "/also/nonexistent",
            branch: "test",
            createBranch: true
        ))
    }

    func testRemoveWorktreeFailsForNonexistent() {
        XCTAssertThrowsError(try GitService.shared.removeWorktree(
            repoPath: repoPath,
            worktreePath: "/nonexistent/worktree"
        ))
    }

    // MARK: - Helpers

    @discardableResult
    private func runShell(_ command: String, in directory: String) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.currentDirectoryURL = URL(fileURLWithPath: directory)

        let devNull = FileHandle.nullDevice
        process.standardOutput = devNull
        process.standardError = devNull

        try? process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }
}

// MARK: - GitError Tests

final class GitErrorTests: XCTestCase {

    func testCommandFailedError() {
        let error = GitError.commandFailed("Something went wrong")
        XCTAssertEqual(error.errorDescription, "Something went wrong")
    }

    func testNotAGitRepositoryError() {
        let error = GitError.notAGitRepository
        XCTAssertEqual(error.errorDescription, "Not a git repository")
    }

    func testWorktreeExistsError() {
        let error = GitError.worktreeExists
        XCTAssertEqual(error.errorDescription, "Worktree already exists at this path")
    }

    func testBranchExistsError() {
        let error = GitError.branchExists
        XCTAssertEqual(error.errorDescription, "Branch already exists")
    }
}
