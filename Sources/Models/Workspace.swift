import Foundation

struct Workspace: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var repoPath: String
    var floors: [Floor]

    init(id: UUID = UUID(), name: String, repoPath: String, floors: [Floor] = []) {
        self.id = id
        self.name = name
        self.repoPath = repoPath
        self.floors = floors
    }

    /// Directory where all worktrees for this workspace are stored
    /// e.g. /root/repoA → /root/repoA-mast/
    var worktreeBaseDir: String {
        "\(repoPath)-mast"
    }

    var aggregatedStatus: AgentStatus {
        if floors.isEmpty { return .idle }
        let statuses = floors.map { $0.aggregatedStatus }
        if statuses.contains(.error) { return .error }
        if statuses.contains(.needsInput) { return .needsInput }
        if statuses.contains(.running) { return .running }
        return .idle
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Workspace, rhs: Workspace) -> Bool {
        lhs.id == rhs.id
    }
}
