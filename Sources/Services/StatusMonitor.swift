import Foundation

/// Monitors AI tool status files via filesystem events.
/// Uses agent.sessionID to precisely locate the correct JSONL file.
@Observable
final class StatusMonitor {
    private var timer: Timer?
    private weak var appState: AppState?
    private var settings: Settings?

    init() {}

    func start(appState: AppState, settings: Settings) {
        self.appState = appState
        self.settings = settings
        startPolling()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Public Helpers

    /// Encode a working directory path to Claude Code's project directory name format
    /// Replaces / and _ with -
    static func encodeProjectDirName(workingDirectory: String) -> String {
        return workingDirectory
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "_", with: "-")
    }

    // MARK: - Polling

    private func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkAllAgentStatuses()
        }
    }

    private func checkAllAgentStatuses() {
        guard let appState else { return }

        for agent in appState.allAgents {
            let newStatus = detectStatus(for: agent)
            if newStatus != agent.status && newStatus != .unknown {
                DispatchQueue.main.async {
                    appState.updateAgentStatus(agentID: agent.id, status: newStatus)
                }
            }
        }
    }

    // MARK: - Status Detection

    func detectStatus(for agent: Agent) -> AgentStatus {
        switch agent.tool {
        case .claudeCode:
            return detectClaudeCodeStatus(for: agent)
        case .codex:
            return detectCodexStatus(for: agent)
        default:
            return .unknown
        }
    }

    // MARK: - Claude Code Status Detection

    private func detectClaudeCodeStatus(for agent: Agent) -> AgentStatus {
        // No terminal running — agent is idle
        guard TerminalManager.shared.hasTerminal(for: agent.id) else {
            return .idle
        }

        guard let sessionID = agent.sessionID, !sessionID.isEmpty else {
            // Terminal started but no session yet — waiting for user's first message
            return .idle
        }

        // Use persisted projectPath if available, otherwise compute it
        let sessionFile: URL
        if let projectPath = agent.projectPath, !projectPath.isEmpty {
            sessionFile = URL(fileURLWithPath: projectPath)
                .appendingPathComponent("\(sessionID).jsonl")
        } else {
            let configBase = resolveConfigPath(for: .claudeCode)
            let encodedDir = Self.encodeProjectDirName(workingDirectory: agent.workingDirectory)
            sessionFile = URL(fileURLWithPath: configBase)
                .appendingPathComponent("projects")
                .appendingPathComponent(encodedDir)
                .appendingPathComponent("\(sessionID).jsonl")
        }

        guard FileManager.default.fileExists(atPath: sessionFile.path) else {
            // File not yet created by Claude Code
            return .running
        }

        return parseSessionFile(at: sessionFile)
    }

    // MARK: - Codex Status Detection

    private func detectCodexStatus(for agent: Agent) -> AgentStatus {
        // TODO: implement when Codex file format is confirmed
        return .unknown
    }

    // MARK: - Config Path Resolution

    private func resolveConfigPath(for tool: AgentTool) -> String {
        if let settings, !settings.configPath(for: tool).isEmpty {
            let path = settings.configPath(for: tool)
            if path.hasPrefix("~") {
                return (path as NSString).expandingTildeInPath
            }
            return path
        }
        // Default fallback
        switch tool {
        case .claudeCode:
            return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude").path
        default:
            return ""
        }
    }

    // MARK: - JSONL Parsing

    private func parseSessionFile(at url: URL) -> AgentStatus {
        guard let data = try? Data(contentsOf: url),
              let content = String(data: data, encoding: .utf8) else {
            return .unknown
        }

        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard !lines.isEmpty else { return .unknown }

        // Find the last meaningful message line (skip metadata types)
        let metadataTypes: Set<String> = ["permission-mode", "last-prompt", "file-history-snapshot", "attachment"]
        var lastMessageJson: [String: Any]?

        for line in lines.reversed() {
            guard let jsonData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let type = json["type"] as? String else { continue }

            if !metadataTypes.contains(type) {
                lastMessageJson = json
                break
            }
        }

        guard let json = lastMessageJson,
              let type = json["type"] as? String else {
            return .unknown
        }

        // Get file modification time for staleness check
        let elapsed: TimeInterval = {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let modDate = attrs[.modificationDate] as? Date {
                return Date().timeIntervalSince(modDate)
            }
            return 999
        }()

        switch type {
        case "assistant":
            if elapsed <= 5 {
                // File still being written — agent is actively responding
                return .running
            }

            // File is stale — check if assistant is asking a question (needs user action)
            let msg = json["message"] as? [String: Any]
            let content = msg?["content"]
            if let blocks = content as? [[String: Any]] {
                for block in blocks {
                    if block["type"] as? String == "tool_use" {
                        let toolName = block["name"] as? String ?? ""
                        // AskUserQuestion, permission requests, etc. — agent is blocked
                        if toolName == "AskUserQuestion" || toolName == "TodoQuery" {
                            return .needsInput
                        }
                    }
                }
            }

            // Check for permission/confirmation subtype
            if let subtype = json["subtype"] as? String {
                if subtype == "permission_request" || subtype == "confirmation" {
                    return .needsInput
                }
            }

            // Agent finished responding, waiting for next user instruction
            return .idle

        case "user":
            // User sent input — agent is processing
            return elapsed > 60 ? .idle : .running

        case "system":
            // Session ended or summarized
            return .idle

        case "result":
            return .idle

        case "error":
            return .error

        default:
            return elapsed > 10 ? .idle : .running
        }
    }
}
