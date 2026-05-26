import Foundation
import SwiftUI

enum AgentTool: String, Codable, CaseIterable {
    case claudeCode = "Claude Code"
    case codeBuddy = "CodeBuddy"
    case codex = "Codex"
    case gemini = "Gemini"
    case other = "Other"

    var icon: String {
        switch self {
        case .claudeCode: return "brain"
        case .codeBuddy: return "hammer"
        case .codex: return "terminal"
        case .gemini: return "sparkles"
        case .other: return "command"
        }
    }

    /// Display name for watermark in card
    var displayName: String {
        switch self {
        case .claudeCode: return "Claude"
        case .codeBuddy: return "CodeBuddy"
        case .codex: return "Codex"
        case .gemini: return "Gemini"
        case .other: return "Other"
        }
    }
}

enum AgentStatus: String, Codable {
    case running
    case needsInput
    case idle
    case error
    case unknown

    var color: Color {
        switch self {
        case .running: return .green
        case .needsInput: return .orange
        case .idle: return .gray
        case .error: return .red
        case .unknown: return .secondary
        }
    }

    var label: String {
        switch self {
        case .running: return L10n.running
        case .needsInput: return L10n.needsInput
        case .idle: return L10n.idle
        case .error: return L10n.error
        case .unknown: return L10n.unknown
        }
    }

    var icon: String {
        switch self {
        case .running: return "circle.fill"
        case .needsInput: return "exclamationmark.circle.fill"
        case .idle: return "moon.circle.fill"
        case .error: return "xmark.circle.fill"
        case .unknown: return "questionmark.circle"
        }
    }
}

struct Agent: Identifiable, Codable, Hashable {
    let id: UUID
    var tool: AgentTool
    var workingDirectory: String
    var taskDescription: String
    var sessionID: String?
    var projectPath: String?  // e.g. ~/.claude-internal/projects/-Users-shuaizi-...

    // Runtime only — not persisted
    var status: AgentStatus = .idle

    enum CodingKeys: String, CodingKey {
        case id, tool, workingDirectory, taskDescription, sessionID, projectPath
    }

    init(
        id: UUID = UUID(),
        tool: AgentTool,
        workingDirectory: String,
        taskDescription: String,
        sessionID: String? = nil,
        projectPath: String? = nil
    ) {
        self.id = id
        self.tool = tool
        self.workingDirectory = workingDirectory
        self.taskDescription = taskDescription
        self.sessionID = sessionID
        self.projectPath = projectPath
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        tool = try container.decode(AgentTool.self, forKey: .tool)
        workingDirectory = try container.decode(String.self, forKey: .workingDirectory)
        taskDescription = try container.decode(String.self, forKey: .taskDescription)
        sessionID = try container.decodeIfPresent(String.self, forKey: .sessionID)
        projectPath = try container.decodeIfPresent(String.self, forKey: .projectPath)
        status = .idle
    }

    var displayName: String {
        let dir = (workingDirectory as NSString).lastPathComponent
        return "~/\(dir) - \(taskDescription)"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Agent, rhs: Agent) -> Bool {
        lhs.id == rhs.id
    }
}
