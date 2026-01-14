import Foundation
import SwiftUI

@Observable
class AppState {
    var repositories: [Repository] = []
    var selectedRepositoryId: UUID?
    var selectedWorktreeId: UUID?
    var showArchived: Bool = false

    private let configURL: URL
    private let forestDirectory: URL
    private let persistChanges: Bool

    var selectedRepository: Repository? {
        repositories.first { $0.id == selectedRepositoryId }
    }

    var selectedWorktree: Worktree? {
        guard let worktreeId = selectedWorktreeId else { return nil }
        for repo in repositories {
            if let worktree = repo.worktrees.first(where: { $0.id == worktreeId }) {
                return worktree
            }
        }
        return nil
    }

    var selectedWorktreeRepoId: UUID? {
        guard let worktreeId = selectedWorktreeId else { return nil }
        return repositories.first { repo in
            repo.worktrees.contains { $0.id == worktreeId }
        }?.id
    }

    init(forestDirectory: URL? = nil, persistChanges: Bool = true) {
        let dir = forestDirectory ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("forest")
        self.forestDirectory = dir
        self.configURL = dir.appendingPathComponent(".forest-config.json")
        self.persistChanges = persistChanges

        if persistChanges {
            ensureForestDirectoryExists()
            loadConfig()
        }
    }

    private func ensureForestDirectoryExists() {
        try? FileManager.default.createDirectory(at: forestDirectory, withIntermediateDirectories: true)
    }

    private func loadConfig() {
        guard FileManager.default.fileExists(atPath: configURL.path) else { return }
        do {
            let data = try Data(contentsOf: configURL)
            repositories = try JSONDecoder().decode([Repository].self, from: data)
        } catch {
            print("Failed to load config: \(error)")
        }
    }

    func saveConfig() {
        guard persistChanges else { return }
        do {
            let data = try JSONEncoder().encode(repositories)
            try data.write(to: configURL)
        } catch {
            print("Failed to save config: \(error)")
        }
    }

    // MARK: - Repository Management

    func addRepository(from sourcePath: String) {
        let git = GitService.shared
        guard git.isGitRepository(at: sourcePath) else { return }

        let name = git.getRepositoryName(at: sourcePath)

        guard !repositories.contains(where: { $0.sourcePath == sourcePath }) else { return }

        let repo = Repository(name: name, sourcePath: sourcePath)
        repositories.append(repo)
        selectedRepositoryId = repo.id
        saveConfig()

        let repoDir = forestDirectory.appendingPathComponent(name)
        try? FileManager.default.createDirectory(at: repoDir, withIntermediateDirectories: true)
    }

    func removeRepository(_ repo: Repository) {
        repositories.removeAll { $0.id == repo.id }
        if selectedRepositoryId == repo.id {
            selectedRepositoryId = nil
            selectedWorktreeId = nil
        }
        saveConfig()
    }

    // MARK: - Worktree Management

    func createWorktree(in repoId: UUID, name: String, branch: String, createNewBranch: Bool) throws {
        guard let index = repositories.firstIndex(where: { $0.id == repoId }) else { return }
        let repo = repositories[index]

        let worktreePath = forestDirectory
            .appendingPathComponent(repo.name)
            .appendingPathComponent(name)
            .path

        try GitService.shared.addWorktree(
            repoPath: repo.sourcePath,
            worktreePath: worktreePath,
            branch: branch,
            createBranch: createNewBranch
        )

        let worktree = Worktree(name: name, branch: branch, path: worktreePath)
        repositories[index].worktrees.append(worktree)
        selectedWorktreeId = worktree.id
        saveConfig()
    }

    func deleteWorktree(_ worktree: Worktree, from repoId: UUID) throws {
        guard let repoIndex = repositories.firstIndex(where: { $0.id == repoId }) else { return }
        let repo = repositories[repoIndex]

        // Remove from git (this also removes the directory)
        try GitService.shared.removeWorktree(repoPath: repo.sourcePath, worktreePath: worktree.path)

        repositories[repoIndex].worktrees.removeAll { $0.id == worktree.id }
        if selectedWorktreeId == worktree.id {
            selectedWorktreeId = nil
        }
        saveConfig()
    }

    func archiveWorktree(_ worktreeId: UUID, in repoId: UUID) {
        guard let repoIndex = repositories.firstIndex(where: { $0.id == repoId }),
              let worktreeIndex = repositories[repoIndex].worktrees.firstIndex(where: { $0.id == worktreeId })
        else { return }

        repositories[repoIndex].worktrees[worktreeIndex].isArchived = true
        if selectedWorktreeId == worktreeId {
            selectedWorktreeId = nil
        }
        saveConfig()
    }

    func unarchiveWorktree(_ worktreeId: UUID, in repoId: UUID) {
        guard let repoIndex = repositories.firstIndex(where: { $0.id == repoId }),
              let worktreeIndex = repositories[repoIndex].worktrees.firstIndex(where: { $0.id == worktreeId })
        else { return }

        repositories[repoIndex].worktrees[worktreeIndex].isArchived = false
        saveConfig()
    }

    func renameWorktree(_ worktreeId: UUID, in repoId: UUID, newName: String) throws {
        guard let repoIndex = repositories.firstIndex(where: { $0.id == repoId }),
              let worktreeIndex = repositories[repoIndex].worktrees.firstIndex(where: { $0.id == worktreeId })
        else { return }

        let worktree = repositories[repoIndex].worktrees[worktreeIndex]
        let repo = repositories[repoIndex]

        // Calculate new path
        let oldURL = URL(fileURLWithPath: worktree.path)
        let newURL = oldURL.deletingLastPathComponent().appendingPathComponent(newName)

        // Rename the directory
        try FileManager.default.moveItem(at: oldURL, to: newURL)

        // Update git worktree to point to new location
        try GitService.shared.repairWorktree(repoPath: repo.sourcePath, worktreePath: newURL.path)

        // Update our records
        repositories[repoIndex].worktrees[worktreeIndex].name = newName
        repositories[repoIndex].worktrees[worktreeIndex].path = newURL.path
        saveConfig()
    }

    func renameBranch(_ worktreeId: UUID, in repoId: UUID, newBranch: String) throws {
        guard let repoIndex = repositories.firstIndex(where: { $0.id == repoId }),
              let worktreeIndex = repositories[repoIndex].worktrees.firstIndex(where: { $0.id == worktreeId })
        else { return }

        let worktree = repositories[repoIndex].worktrees[worktreeIndex]
        try GitService.shared.renameBranch(at: worktree.path, from: worktree.branch, to: newBranch)

        repositories[repoIndex].worktrees[worktreeIndex].branch = newBranch
        saveConfig()
    }

    // MARK: - Helpers

    func activeWorktrees(for repo: Repository) -> [Worktree] {
        repo.worktrees.filter { !$0.isArchived }
    }

    func archivedWorktrees(for repo: Repository) -> [Worktree] {
        repo.worktrees.filter { $0.isArchived }
    }

    func hasArchivedWorktrees() -> Bool {
        repositories.contains { repo in
            repo.worktrees.contains { $0.isArchived }
        }
    }

    func findRepository(containing worktreeId: UUID) -> Repository? {
        repositories.first { repo in
            repo.worktrees.contains { $0.id == worktreeId }
        }
    }
}
