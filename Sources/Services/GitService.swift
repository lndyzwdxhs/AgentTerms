import Foundation

struct GitService {
    enum GitError: Error, LocalizedError {
        case notAGitRepo(String)
        case worktreeCreationFailed(String)
        case worktreeRemovalFailed(String)
        case commandFailed(String)

        var errorDescription: String? {
            switch self {
            case .notAGitRepo(let path): return "Not a git repository: \(path)"
            case .worktreeCreationFailed(let msg): return "Failed to create worktree: \(msg)"
            case .worktreeRemovalFailed(let msg): return "Failed to remove worktree: \(msg)"
            case .commandFailed(let msg): return "Git command failed: \(msg)"
            }
        }
    }

    /// Check if a directory is a git repository
    static func isGitRepo(path: String) -> Bool {
        let (_, exitCode) = runGit(args: ["rev-parse", "--git-dir"], in: path)
        return exitCode == 0
    }

    /// Get current branch name
    static func currentBranch(repoPath: String) -> String {
        let (output, exitCode) = runGit(args: ["branch", "--show-current"], in: repoPath)
        guard exitCode == 0 else { return "main" }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// List all branches (local + remote, cleaned up)
    static func listBranches(repoPath: String) -> [String] {
        let (output, exitCode) = runGit(args: ["branch", "-a", "--format=%(refname:short)"], in: repoPath)
        guard exitCode == 0 else { return [] }

        let branches = output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.contains("HEAD") }
            .map { branch -> String in
                // Strip "origin/" prefix for remote branches
                if branch.hasPrefix("origin/") {
                    return String(branch.dropFirst("origin/".count))
                }
                return branch
            }

        // Deduplicate
        return Array(Set(branches)).sorted()
    }

    /// Create a git worktree
    /// - Parameters:
    ///   - repoPath: base repository path
    ///   - path: target worktree directory path
    ///   - branch: branch name
    ///   - isNew: if true, creates a new branch from current HEAD
    static func createWorktree(repoPath: String, path: String, branch: String, isNew: Bool) throws {
        let args: [String]
        if isNew {
            args = ["worktree", "add", "-b", branch, path]
        } else {
            args = ["worktree", "add", path, branch]
        }

        let (output, exitCode) = runGit(args: args, in: repoPath)
        if exitCode != 0 {
            throw GitError.worktreeCreationFailed(output)
        }
    }

    /// Remove a git worktree
    static func removeWorktree(repoPath: String, path: String) throws {
        let (output, exitCode) = runGit(args: ["worktree", "remove", path, "--force"], in: repoPath)
        if exitCode != 0 {
            throw GitError.worktreeRemovalFailed(output)
        }
    }

    /// Check if a worktree has uncommitted changes
    static func hasUncommittedChanges(worktreePath: String) -> Bool {
        let (output, exitCode) = runGit(args: ["status", "--porcelain"], in: worktreePath)
        guard exitCode == 0 else { return false }
        return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Private

    private static func runGit(args: [String], in directory: String) -> (output: String, exitCode: Int32) {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: directory)
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return (output, process.terminationStatus)
        } catch {
            return (error.localizedDescription, -1)
        }
    }
}
