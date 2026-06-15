import Foundation
import SwiftTerm

/// Manages PTY processes for all agents.
/// In the current single-process MVP, PTY lifecycle is tied to the TerminalRepresentable view.
/// This service provides utility methods for agent tool commands.
final class PTYService {

    /// Get the command string for a given agent tool
    static func commandForTool(_ tool: AgentTool) -> String {
        switch tool {
        case .claudeCode: return "claude"
        case .codeBuddy: return "codebuddy"
        case .codex: return "codex"
        case .gemini: return "gemini"
        case .notes: return "" // Notes is not a terminal tool
        case .other: return ""
        }
    }

    /// Check if a tool CLI is installed
    static func isToolInstalled(_ tool: AgentTool) -> Bool {
        let command = commandForTool(tool)
        guard !command.isEmpty else { return true } // "other" always passes
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [command]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
