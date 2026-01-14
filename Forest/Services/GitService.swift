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

    private func runGit(_ arguments: [String], in directory: String) -> (output: String, error: String, exitCode: Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: directory)

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ("", error.localizedDescription, -1)
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        let output = String(data: outputData, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

        return (output, errorOutput, process.terminationStatus)
    }
}
