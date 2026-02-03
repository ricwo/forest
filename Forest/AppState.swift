import Foundation
import SwiftUI

struct DeleteError: Identifiable {
    let id = UUID()
    let worktreeName: String
    let worktreePath: String
    let message: String
}

struct DirtyWorktreeConfirmation: Identifiable {
    let id = UUID()
    let worktree: Worktree
    let repoId: UUID
    let repoSourcePath: String
}

enum Selection: Equatable {
    case repository(UUID)
    case worktree(UUID)
}

enum FetchStatus: Equatable {
    case idle
    case fetching
    case success
    case warning(String)
    case error(String)
}

@Observable
class AppState {
    var repositories: [Repository] = []
    var selection: Selection?
    var showArchived: Bool = false
    var fetchStatuses: [UUID: FetchStatus] = [:]
    var deleteError: DeleteError?
    var dirtyWorktreeConfirmation: DirtyWorktreeConfirmation?

    // Legacy compatibility - maps to selection
    var selectedRepositoryId: UUID? {
        get {
            if case .repository(let id) = selection {
                return id
            }
            return nil
        }
        set {
            if let id = newValue {
                selection = .repository(id)
            } else if case .repository = selection {
                selection = nil
            }
        }
    }

    var selectedWorktreeId: UUID? {
        get {
            if case .worktree(let id) = selection {
                return id
            }
            return nil
        }
        set {
            if let id = newValue {
                selection = .worktree(id)
            } else if case .worktree = selection {
                selection = nil
            }
        }
    }

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
        let dir = forestDirectory ?? SettingsService.shared.forestDirectory
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
        // Check if current selection is related to this repo
        let shouldClearSelection: Bool = {
            switch selection {
            case .repository(let id):
                return id == repo.id
            case .worktree(let worktreeId):
                return repo.worktrees.contains { $0.id == worktreeId }
            case nil:
                return false
            }
        }()

        repositories.removeAll { $0.id == repo.id }

        if shouldClearSelection {
            selection = nil
        }
        saveConfig()
    }

    // MARK: - Worktree Management

    func createWorktree(in repoId: UUID, name: String, branch: String, createNewBranch: Bool) throws {
        guard let index = repositories.firstIndex(where: { $0.id == repoId }) else { return }
        let repo = repositories[index]

        // Validate repo source path exists
        guard FileManager.default.fileExists(atPath: repo.sourcePath) else {
            throw NSError(domain: "Forest", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Repository source path no longer exists: \(repo.sourcePath)"
            ])
        }

        // Ensure parent directory exists
        let repoDir = forestDirectory.appendingPathComponent(repo.name)
        try FileManager.default.createDirectory(at: repoDir, withIntermediateDirectories: true)

        let worktreePath = repoDir
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

    func deleteWorktree(_ worktree: Worktree, from repoId: UUID) {
        guard let repo = repositories.first(where: { $0.id == repoId }) else { return }

        Task {
            let isDirty = await GitService.shared.worktreeHasChangesAsync(at: worktree.path)
            await MainActor.run {
                if isDirty {
                    self.dirtyWorktreeConfirmation = DirtyWorktreeConfirmation(
                        worktree: worktree, repoId: repoId, repoSourcePath: repo.sourcePath
                    )
                } else {
                    self.performDeleteWorktree(worktree, from: repoId, repoSourcePath: repo.sourcePath, force: false)
                }
            }
        }
    }

    func confirmDeleteDirtyWorktree() {
        guard let confirmation = dirtyWorktreeConfirmation else { return }
        dirtyWorktreeConfirmation = nil
        performDeleteWorktree(
            confirmation.worktree, from: confirmation.repoId,
            repoSourcePath: confirmation.repoSourcePath, force: true
        )
    }

    private func performDeleteWorktree(_ worktree: Worktree, from repoId: UUID, repoSourcePath: String, force: Bool) {
        guard let repoIndex = repositories.firstIndex(where: { $0.id == repoId }) else { return }
        let worktreePath = worktree.path
        let worktreeName = worktree.name

        // Phase 1: Optimistic UI update (instant)
        repositories[repoIndex].worktrees.removeAll { $0.id == worktree.id }
        if selectedWorktreeId == worktree.id {
            selectedWorktreeId = nil
        }
        saveConfig()

        // Phase 2: Background git removal
        Task {
            let error = await GitService.shared.removeWorktreeAsync(
                repoPath: repoSourcePath, worktreePath: worktreePath, force: force
            )
            if let error {
                await MainActor.run {
                    self.deleteError = DeleteError(
                        worktreeName: worktreeName,
                        worktreePath: worktreePath,
                        message: error
                    )
                }
            }
        }
    }

    /// Remove a worktree from Forest's config without running git commands.
    /// Use this for worktrees that no longer exist or are invalid.
    func forgetWorktree(_ worktree: Worktree, from repoId: UUID) {
        guard let repoIndex = repositories.firstIndex(where: { $0.id == repoId }) else { return }

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

        // Migrate Claude session history from old path to new path
        ClaudeSessionService.shared.migrateSessionHistory(from: oldURL.path, to: newURL.path)

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

    func importExistingWorktrees(for repoId: UUID) throws {
        guard let repoIndex = repositories.firstIndex(where: { $0.id == repoId }) else { return }
        let repo = repositories[repoIndex]

        // Get all worktrees from git
        let allWorktrees = GitService.shared.listWorktrees(repoPath: repo.sourcePath)

        // Filter out the main repo (first entry is usually the main working tree)
        let externalWorktrees = allWorktrees.filter { $0.path != repo.sourcePath }

        guard !externalWorktrees.isEmpty else { return }

        let repoDir = forestDirectory.appendingPathComponent(repo.name)
        try? FileManager.default.createDirectory(at: repoDir, withIntermediateDirectories: true)

        for worktreeInfo in externalWorktrees {
            let oldURL = URL(fileURLWithPath: worktreeInfo.path)
            let worktreeName = oldURL.lastPathComponent
            let newURL = repoDir.appendingPathComponent(worktreeName)

            // Skip if already in forest directory
            if worktreeInfo.path.hasPrefix(repoDir.path) {
                // Already in forest, just add to our records if not already tracked
                if !repositories[repoIndex].worktrees.contains(where: { $0.path == worktreeInfo.path }) {
                    let worktree = Worktree(name: worktreeName, branch: worktreeInfo.branch, path: worktreeInfo.path)
                    repositories[repoIndex].worktrees.append(worktree)
                }
                continue
            }

            // Skip if destination already exists
            if FileManager.default.fileExists(atPath: newURL.path) {
                continue
            }

            // Move the worktree directory
            try FileManager.default.moveItem(at: oldURL, to: newURL)

            // Repair git references to point to new location
            try GitService.shared.repairWorktree(repoPath: repo.sourcePath, worktreePath: newURL.path)

            // Migrate Claude session history from old path to new path
            ClaudeSessionService.shared.migrateSessionHistory(from: oldURL.path, to: newURL.path)

            // Add to our records
            let worktree = Worktree(name: worktreeName, branch: worktreeInfo.branch, path: newURL.path)
            repositories[repoIndex].worktrees.append(worktree)
        }

        saveConfig()
    }

    func getExistingWorktrees(for sourcePath: String) -> [(path: String, branch: String)] {
        let allWorktrees = GitService.shared.listWorktrees(repoPath: sourcePath)
        // Filter out the main repo
        return allWorktrees.filter { $0.path != sourcePath }
    }

    // MARK: - Per-Project Settings

    /// Returns the effective terminal for a repository (project setting or global fallback)
    func getEffectiveTerminal(for repoId: UUID) -> Terminal {
        if let repo = repositories.first(where: { $0.id == repoId }),
           let projectTerminal = repo.defaultTerminal {
            return projectTerminal
        }
        return SettingsService.shared.defaultTerminal
    }

    /// Updates the default terminal for a repository (nil = use global)
    func setDefaultTerminal(_ terminal: Terminal?, for repoId: UUID) {
        guard let index = repositories.firstIndex(where: { $0.id == repoId }) else { return }
        repositories[index].defaultTerminal = terminal
        saveConfig()
    }

    /// Returns the effective Claude command for a repository (project setting or "claude")
    func getEffectiveClaudeCommand(for repoId: UUID) -> String {
        if let repo = repositories.first(where: { $0.id == repoId }),
           let command = repo.claudeCommand, !command.isEmpty {
            return command
        }
        return "claude"
    }

    /// Updates the Claude command for a repository (nil or empty = use default "claude")
    func setClaudeCommand(_ command: String?, for repoId: UUID) {
        guard let index = repositories.firstIndex(where: { $0.id == repoId }) else { return }
        repositories[index].claudeCommand = command
        saveConfig()
    }

    // MARK: - Fetch

    func fetchStatus(for repoId: UUID) -> FetchStatus {
        fetchStatuses[repoId] ?? .idle
    }

    func fetchRepository(_ repoId: UUID) async {
        guard fetchStatus(for: repoId) != .fetching else { return }
        guard let repo = repositories.first(where: { $0.id == repoId }) else { return }

        fetchStatuses[repoId] = .fetching

        let result = await GitService.shared.fetchRepositoryAsync(at: repo.sourcePath)

        if result.isFullSuccess {
            fetchStatuses[repoId] = .success
            // Auto-clear success after 3 seconds
            let id = repoId
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if self.fetchStatuses[id] == .success {
                    self.fetchStatuses[id] = .idle
                }
            }
        } else if !result.fetchSucceeded {
            fetchStatuses[repoId] = .error(result.summaryMessage)
        } else {
            // Fetch succeeded but pull had issues — that's a warning
            fetchStatuses[repoId] = .warning(result.summaryMessage)
        }
    }

    // MARK: - Helpers

    func activeWorktrees(for repo: Repository) -> [Worktree] {
        repo.worktrees
            .filter { !$0.isArchived }
            .sorted { w1, w2 in
                // If both have manual sort order, use that
                if let o1 = w1.sortOrder, let o2 = w2.sortOrder {
                    return o1 < o2
                }
                // Manual order comes first
                if w1.sortOrder != nil { return true }
                if w2.sortOrder != nil { return false }
                // Otherwise sort by recency (most recent first)
                return w1.lastModified > w2.lastModified
            }
    }

    func archivedWorktrees(for repo: Repository) -> [Worktree] {
        repo.worktrees
            .filter { $0.isArchived }
            .sorted { $0.lastModified > $1.lastModified }
    }

    func moveWorktree(in repoId: UUID, from source: IndexSet, to destination: Int) {
        guard let repoIndex = repositories.firstIndex(where: { $0.id == repoId }) else { return }

        // Get current sorted active worktrees
        var sorted = activeWorktrees(for: repositories[repoIndex])
        sorted.move(fromOffsets: source, toOffset: destination)

        // Update sort orders based on new positions
        for (index, worktree) in sorted.enumerated() {
            if let wtIndex = repositories[repoIndex].worktrees.firstIndex(where: { $0.id == worktree.id }) {
                repositories[repoIndex].worktrees[wtIndex].sortOrder = index
            }
        }

        saveConfig()
    }

    func moveRepository(from source: IndexSet, to destination: Int) {
        // Get current sorted repositories
        var sorted = sortedRepositories
        sorted.move(fromOffsets: source, toOffset: destination)

        // Update sort orders based on new positions
        for (index, repo) in sorted.enumerated() {
            if let repoIndex = repositories.firstIndex(where: { $0.id == repo.id }) {
                repositories[repoIndex].sortOrder = index
            }
        }

        saveConfig()
    }

    var sortedRepositories: [Repository] {
        repositories.sorted { r1, r2 in
            // If both have manual sort order, use that
            if let o1 = r1.sortOrder, let o2 = r2.sortOrder {
                return o1 < o2
            }
            // Manual order comes first
            if r1.sortOrder != nil { return true }
            if r2.sortOrder != nil { return false }
            // Otherwise sort alphabetically by name
            return r1.name.localizedCaseInsensitiveCompare(r2.name) == .orderedAscending
        }
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
