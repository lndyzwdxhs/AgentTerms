import Foundation
import SwiftUI

@Observable
final class AppState {
    var workspaces: [Workspace] = []
    var selectedWorkspaceID: UUID?
    var selectedFloorID: UUID?
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

    var selectedFloor: Floor? {
        guard let wsIdx = workspaces.firstIndex(where: { $0.id == selectedWorkspaceID }) else { return nil }
        return workspaces[wsIdx].floors.first { $0.id == selectedFloorID }
    }

    var allAgents: [Agent] {
        workspaces.flatMap { $0.floors.flatMap { $0.agents } }
    }

    var agentsNeedingAttention: Int {
        allAgents.filter { $0.status == .needsInput || $0.status == .error }.count
    }

    // MARK: - Workspace Operations

    func addWorkspace(repoPath: String) {
        let name = (repoPath as NSString).lastPathComponent
        let workspace = Workspace(name: name, repoPath: repoPath)
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
            selectedFloorID = nil
        }
        saveState()
    }

    // MARK: - Floor Operations

    func addFloor(name: String, branch: String, isNewBranch: Bool, to workspaceID: UUID) throws {
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

        let floor = Floor(name: name, branch: branch, worktreePath: worktreePath)
        workspaces[idx].floors.append(floor)
        selectedFloorID = floor.id
        saveState()
    }

    func removeFloor(id: UUID, from workspaceID: UUID, removeWorktree: Bool = true) {
        guard let wsIdx = workspaces.firstIndex(where: { $0.id == workspaceID }) else { return }
        if let floor = workspaces[wsIdx].floors.first(where: { $0.id == id }) {
            // Clean up all agent terminals
            for agent in floor.agents {
                TerminalManager.shared.remove(agentID: agent.id)
            }
            // Remove git worktree if requested
            if removeWorktree {
                try? GitService.removeWorktree(repoPath: workspaces[wsIdx].repoPath, path: floor.worktreePath)
            }
        }
        workspaces[wsIdx].floors.removeAll { $0.id == id }
        if selectedFloorID == id {
            selectedFloorID = workspaces[wsIdx].floors.first?.id
        }
        saveState()
    }

    // MARK: - Agent Operations

    func addAgent(tool: AgentTool, workingDirectory: String, taskDescription: String, toFloor floorID: UUID, inWorkspace workspaceID: UUID) {
        guard let wsIdx = workspaces.firstIndex(where: { $0.id == workspaceID }),
              let floorIdx = workspaces[wsIdx].floors.firstIndex(where: { $0.id == floorID }) else { return }
        let agent = Agent(tool: tool, workingDirectory: workingDirectory, taskDescription: taskDescription)
        workspaces[wsIdx].floors[floorIdx].agents.append(agent)
        selectedAgentID = agent.id
        saveState()
    }

    func removeAgent(id: UUID, fromFloor floorID: UUID, inWorkspace workspaceID: UUID) {
        guard let wsIdx = workspaces.firstIndex(where: { $0.id == workspaceID }),
              let floorIdx = workspaces[wsIdx].floors.firstIndex(where: { $0.id == floorID }) else { return }
        workspaces[wsIdx].floors[floorIdx].agents.removeAll { $0.id == id }
        saveState()
    }

    func bindSession(agentID: UUID, sessionID: String, projectPath: String? = nil) {
        for wsIdx in workspaces.indices {
            for floorIdx in workspaces[wsIdx].floors.indices {
                if let agentIdx = workspaces[wsIdx].floors[floorIdx].agents.firstIndex(where: { $0.id == agentID }) {
                    workspaces[wsIdx].floors[floorIdx].agents[agentIdx].sessionID = sessionID
                    if let projectPath {
                        workspaces[wsIdx].floors[floorIdx].agents[agentIdx].projectPath = projectPath
                    }
                    saveState()
                    return
                }
            }
        }
    }

    func updateAgentStatus(agentID: UUID, status: AgentStatus) {
        for wsIdx in workspaces.indices {
            for floorIdx in workspaces[wsIdx].floors.indices {
                if let agentIdx = workspaces[wsIdx].floors[floorIdx].agents.firstIndex(where: { $0.id == agentID }) {
                    let oldStatus = workspaces[wsIdx].floors[floorIdx].agents[agentIdx].status
                    workspaces[wsIdx].floors[floorIdx].agents[agentIdx].status = status

                    // Send notifications on status transitions
                    if oldStatus != status {
                        let agent = workspaces[wsIdx].floors[floorIdx].agents[agentIdx]
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
        selectedFloorID = workspaces.first?.floors.first?.id
    }
}
