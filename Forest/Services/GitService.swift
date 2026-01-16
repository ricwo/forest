import Foundation

enum GitError: Error, LocalizedError {
    case commandFailed(String)
    case notAGitRepository
    case worktreeExists
    case branchExists

    var errorDescription: String? {
        switch self {
        case .commandFailed(let message):
            return message
        case .notAGitRepository:
            return "Not a git repository"
        case .worktreeExists:
            return "Worktree already exists at this path"
        case .branchExists:
            return "Branch already exists"
        }
    }
}

private struct GitResult {
    let output: String
    let error: String
    let exitCode: Int32
}

struct GitService {
    static let shared = GitService()

    private init() {}

    func isGitRepository(at path: String) -> Bool {
        let result = runGit(["rev-parse", "--git-dir"], in: path)
        return result.exitCode == 0
    }

    func getRepositoryName(at path: String) -> String {
        let url = URL(fileURLWithPath: path)
        return url.lastPathComponent
    }

    func getCurrentBranch(at path: String) -> String? {
        let result = runGit(["branch", "--show-current"], in: path)
        guard result.exitCode == 0 else { return nil }
        return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Async version of getCurrentBranch that runs off the main thread
    /// Use this from SwiftUI views to avoid blocking the main thread during UI updates
    func getCurrentBranchAsync(at path: String) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = self.getCurrentBranch(at: path)
                continuation.resume(returning: result)
            }
        }
    }

    func listBranches(at path: String) -> [String] {
        let result = runGit(["branch", "-a", "--format=%(refname:short)"], in: path)
        guard result.exitCode == 0 else { return [] }
        return result.output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    func addWorktree(repoPath: String, worktreePath: String, branch: String, createBranch: Bool) throws {
        var args = ["worktree", "add"]
        if createBranch {
            args.append("-b")
            args.append(branch)
        }
        args.append(worktreePath)
        if !createBranch {
            args.append(branch)
        }

        let result = runGit(args, in: repoPath)
        if result.exitCode != 0 {
            throw GitError.commandFailed(result.error.isEmpty ? result.output : result.error)
        }
    }

    func removeWorktree(repoPath: String, worktreePath: String) throws {
        let result = runGit(["worktree", "remove", worktreePath], in: repoPath)
        if result.exitCode != 0 {
            throw GitError.commandFailed(result.error.isEmpty ? result.output : result.error)
        }
    }

    func renameBranch(at worktreePath: String, from oldName: String, to newName: String) throws {
        let result = runGit(["branch", "-m", oldName, newName], in: worktreePath)
        if result.exitCode != 0 {
            throw GitError.commandFailed(result.error.isEmpty ? result.output : result.error)
        }
    }

    func repairWorktree(repoPath: String, worktreePath: String) throws {
        // After moving a worktree directory, git needs to update its internal references
        let result = runGit(["worktree", "repair", worktreePath], in: repoPath)
        if result.exitCode != 0 {
            throw GitError.commandFailed(result.error.isEmpty ? result.output : result.error)
        }
    }

    func listWorktrees(repoPath: String) -> [(path: String, branch: String)] {
        let result = runGit(["worktree", "list", "--porcelain"], in: repoPath)
        guard result.exitCode == 0 else { return [] }

        var worktrees: [(path: String, branch: String)] = []
        var currentPath: String?
        var currentBranch: String?

        for line in result.output.components(separatedBy: .newlines) {
            if line.hasPrefix("worktree ") {
                if let path = currentPath, let branch = currentBranch {
                    worktrees.append((path: path, branch: branch))
                }
                currentPath = String(line.dropFirst("worktree ".count))
                currentBranch = nil
            } else if line.hasPrefix("branch refs/heads/") {
                currentBranch = String(line.dropFirst("branch refs/heads/".count))
            }
        }

        if let path = currentPath, let branch = currentBranch {
            worktrees.append((path: path, branch: branch))
        }

        return worktrees
    }

    private func runGit(_ arguments: [String], in directory: String) -> GitResult {
        // Validate directory exists before running git command
        let directoryURL = URL(fileURLWithPath: directory)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return GitResult(output: "", error: "Directory does not exist: \(directory)", exitCode: -1)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = directoryURL

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            return GitResult(output: "", error: error.localizedDescription, exitCode: -1)
        }

        // Read output synchronously after process exits to avoid pipe buffer deadlock
        // We read pipes in background but wait for process first to ensure clean shutdown
        var outputData = Data()
        var errorData = Data()

        let group = DispatchGroup()

        group.enter()
        DispatchQueue.global().async {
            outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }

        group.enter()
        DispatchQueue.global().async {
            errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }

        // Wait for both reads to complete
        group.wait()

        // Now wait for process (should be done since pipes are closed)
        process.waitUntilExit()

        let output = String(data: outputData, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

        return GitResult(output: output, error: errorOutput, exitCode: process.terminationStatus)
    }
}
