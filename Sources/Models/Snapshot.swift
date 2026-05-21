import Foundation

struct Snapshot: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var branch: String
    var worktreePath: String
    var agents: [Agent]

    init(id: UUID = UUID(), name: String, branch: String, worktreePath: String, agents: [Agent] = []) {
        self.id = id
        self.name = name
        self.branch = branch
        self.worktreePath = worktreePath
        self.agents = agents
    }

    var aggregatedStatus: AgentStatus {
        if agents.isEmpty { return .idle }
        if agents.contains(where: { $0.status == .error }) { return .error }
        if agents.contains(where: { $0.status == .needsInput }) { return .needsInput }
        if agents.contains(where: { $0.status == .running }) { return .running }
        return .idle
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Snapshot, rhs: Snapshot) -> Bool {
        lhs.id == rhs.id
    }
}
