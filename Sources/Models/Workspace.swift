import Foundation

enum WorkspaceColor: String, Codable, CaseIterable {
    case red, orange, yellow, green, blue, purple, pink
}

struct Workspace: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var repoPath: String
    var floors: [Floor]
    var color: WorkspaceColor

    init(id: UUID = UUID(), name: String, repoPath: String, floors: [Floor] = [], color: WorkspaceColor = .orange) {
        self.id = id
        self.name = name
        self.repoPath = repoPath
        self.floors = floors
        self.color = color
    }

    // Custom decoder to handle missing 'color' field in old config files
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        repoPath = try container.decode(String.self, forKey: .repoPath)
        floors = try container.decode([Floor].self, forKey: .floors)
        color = try container.decodeIfPresent(WorkspaceColor.self, forKey: .color) ?? .orange
    }

    /// Directory where all worktrees for this workspace are stored
    /// e.g. /root/repoA → /root/repoA-at/
    var worktreeBaseDir: String {
        "\(repoPath)-at"
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
