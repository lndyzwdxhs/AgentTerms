import Foundation

struct Snapshot: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var branch: String
    var worktreePath: String
    var agents: [Agent]
    var isCompleted: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, branch, worktreePath, agents, isCompleted
    }

    init(id: UUID = UUID(), name: String, branch: String, worktreePath: String, agents: [Agent] = [], isCompleted: Bool = false) {
        self.id = id
        self.name = name
        self.branch = branch
        self.worktreePath = worktreePath
        self.agents = agents
        self.isCompleted = isCompleted
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        branch = try container.decode(String.self, forKey: .branch)
        worktreePath = try container.decode(String.self, forKey: .worktreePath)
        agents = try container.decodeIfPresent([Agent].self, forKey: .agents) ?? []
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
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
