import Foundation
import SwiftUI

@Observable
final class AppState {
    var workspaces: [Workspace] = []
    var selectedWorkspaceID: UUID?
    var selectedSnapshotID: UUID?
    var selectedAgentID: UUID?

    private let persistence = PersistenceService()
    private let statusMonitor = StatusMonitor()

    init() {
        loadState()
    }

    /// Call after Settings is available to start status monitoring
    func startMonitoring(settings: Settings) {
        statusMonitor.start(appState: self, settings: settings)
    }

    // MARK: - Computed Properties

    var selectedWorkspace: Workspace? {
        get { workspaces.first { $0.id == selectedWorkspaceID } }
        set {
            if let newValue, let idx = workspaces.firstIndex(where: { $0.id == newValue.id }) {
                workspaces[idx] = newValue
            }
        }
    }

    var selectedSnapshot: Snapshot? {
        guard let wsIdx = workspaces.firstIndex(where: { $0.id == selectedWorkspaceID }) else { return nil }
        return workspaces[wsIdx].snapshots.first { $0.id == selectedSnapshotID }
    }

    var allAgents: [Agent] {
        workspaces.flatMap { $0.snapshots.flatMap { $0.agents } }
    }

    var agentsNeedingAttention: Int {
        allAgents.filter { $0.status == .needsInput || $0.status == .error }.count
    }

    // MARK: - Workspace Operations

    func addWorkspace(repoPath: String, color: WorkspaceColor = .orange, name: String? = nil) {
        let wsName = name ?? (repoPath as NSString).lastPathComponent
        let workspace = Workspace(name: wsName, repoPath: repoPath, color: color)
        // Create worktree base directory
        let baseDir = workspace.worktreeBaseDir
        try? FileManager.default.createDirectory(atPath: baseDir, withIntermediateDirectories: true)
        workspaces.append(workspace)
        selectedWorkspaceID = workspace.id
        saveState()
    }

    func removeWorkspace(id: UUID) {
        workspaces.removeAll { $0.id == id }
        if selectedWorkspaceID == id {
            selectedWorkspaceID = workspaces.first?.id
            selectedSnapshotID = nil
        }
        saveState()
    }

    // MARK: - Snapshot Operations

    func addSnapshot(name: String, branch: String, isNewBranch: Bool, to workspaceID: UUID) throws {
        guard let idx = workspaces.firstIndex(where: { $0.id == workspaceID }) else { return }
        let workspace = workspaces[idx]

        // Use branch name for directory (replace / with -)
        let dirName = branch.replacingOccurrences(of: "/", with: "-")

        let worktreePath = "\(workspace.worktreeBaseDir)/\(dirName)"

        // Create git worktree
        try GitService.createWorktree(
            repoPath: workspace.repoPath,
            path: worktreePath,
            branch: branch,
            isNew: isNewBranch
        )

        let snapshot = Snapshot(name: name, branch: branch, worktreePath: worktreePath)
        workspaces[idx].snapshots.append(snapshot)
        selectedSnapshotID = snapshot.id
        saveState()
    }

    func removeSnapshot(id: UUID, from workspaceID: UUID, removeWorktree: Bool = true) {
        guard let wsIdx = workspaces.firstIndex(where: { $0.id == workspaceID }) else { return }
        if let snapshot = workspaces[wsIdx].snapshots.first(where: { $0.id == id }) {
            // Clean up all agent terminals
            for agent in snapshot.agents {
                TerminalManager.shared.remove(agentID: agent.id)
            }
            // Remove git worktree if requested
            if removeWorktree {
                try? GitService.removeWorktree(repoPath: workspaces[wsIdx].repoPath, path: snapshot.worktreePath)
            }
        }
        workspaces[wsIdx].snapshots.removeAll { $0.id == id }
        if selectedSnapshotID == id {
            selectedSnapshotID = workspaces[wsIdx].snapshots.first?.id
        }
        saveState()
    }

    // MARK: - Agent Operations

    func addAgent(tool: AgentTool, workingDirectory: String, taskDescription: String, toSnapshot snapshotID: UUID, inWorkspace workspaceID: UUID) {
        guard let wsIdx = workspaces.firstIndex(where: { $0.id == workspaceID }),
              let snapshotIdx = workspaces[wsIdx].snapshots.firstIndex(where: { $0.id == snapshotID }) else { return }
        let agent = Agent(tool: tool, workingDirectory: workingDirectory, taskDescription: taskDescription)
        workspaces[wsIdx].snapshots[snapshotIdx].agents.append(agent)
        selectedAgentID = agent.id
        saveState()
    }

    func removeAgent(id: UUID, fromSnapshot snapshotID: UUID, inWorkspace workspaceID: UUID) {
        guard let wsIdx = workspaces.firstIndex(where: { $0.id == workspaceID }),
              let snapshotIdx = workspaces[wsIdx].snapshots.firstIndex(where: { $0.id == snapshotID }) else { return }
        workspaces[wsIdx].snapshots[snapshotIdx].agents.removeAll { $0.id == id }
        saveState()
    }

    func bindSession(agentID: UUID, sessionID: String, projectPath: String? = nil) {
        for wsIdx in workspaces.indices {
            for snapshotIdx in workspaces[wsIdx].snapshots.indices {
                if let agentIdx = workspaces[wsIdx].snapshots[snapshotIdx].agents.firstIndex(where: { $0.id == agentID }) {
                    workspaces[wsIdx].snapshots[snapshotIdx].agents[agentIdx].sessionID = sessionID
                    if let projectPath {
                        workspaces[wsIdx].snapshots[snapshotIdx].agents[agentIdx].projectPath = projectPath
                    }
                    saveState()
                    return
                }
            }
        }
    }

    func updateAgentStatus(agentID: UUID, status: AgentStatus) {
        for wsIdx in workspaces.indices {
            for snapshotIdx in workspaces[wsIdx].snapshots.indices {
                if let agentIdx = workspaces[wsIdx].snapshots[snapshotIdx].agents.firstIndex(where: { $0.id == agentID }) {
                    let oldStatus = workspaces[wsIdx].snapshots[snapshotIdx].agents[agentIdx].status
                    workspaces[wsIdx].snapshots[snapshotIdx].agents[agentIdx].status = status

                    // Send notifications on status transitions
                    if oldStatus != status {
                        let agent = workspaces[wsIdx].snapshots[snapshotIdx].agents[agentIdx]
                        switch status {
                        case .needsInput:
                            NotificationService.shared.notifyNeedsInput(agent: agent)
                        case .error:
                            NotificationService.shared.notifyError(agent: agent)
                        default:
                            break
                        }
                    }
                    return
                }
            }
        }
    }

    // MARK: - Persistence

    func saveState() {
        persistence.save(workspaces: workspaces)
    }

    func loadState() {
        workspaces = persistence.load()
        selectedWorkspaceID = workspaces.first?.id
        selectedSnapshotID = workspaces.first?.snapshots.first?.id
    }
}
