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
                print("[AgentTerms] Status change: \(agent.taskDescription) \(agent.status) → \(newStatus)")
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
        case .codeBuddy:
            return detectCodeBuddyStatus(for: agent)
        case .codex:
            return detectCodexStatus(for: agent)
        default:
            return .unknown
        }
    }

    // MARK: - Claude Code Status Detection

    private func detectClaudeCodeStatus(for agent: Agent) -> AgentStatus {
        guard let sessionID = agent.sessionID, !sessionID.isEmpty else {
            // No session yet — agent hasn't started or waiting for first message
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

    // MARK: - CodeBuddy Status Detection

    private func detectCodeBuddyStatus(for agent: Agent) -> AgentStatus {
        guard let sessionID = agent.sessionID, !sessionID.isEmpty else {
            return .idle
        }

        // Use persisted projectPath if available, otherwise compute it
        let sessionFile: URL
        if let projectPath = agent.projectPath, !projectPath.isEmpty {
            sessionFile = URL(fileURLWithPath: projectPath)
                .appendingPathComponent("\(sessionID).jsonl")
        } else {
            let configBase = resolveConfigPath(for: .codeBuddy)
            // CodeBuddy encodes path by replacing / with - but keeps _
            let encodedDir = Self.encodeCodeBuddyProjectDirName(workingDirectory: agent.workingDirectory)
            sessionFile = URL(fileURLWithPath: configBase)
                .appendingPathComponent("projects")
                .appendingPathComponent(encodedDir)
                .appendingPathComponent("\(sessionID).jsonl")
        }

        guard FileManager.default.fileExists(atPath: sessionFile.path) else {
            return .running
        }

        return parseCodeBuddySessionFile(at: sessionFile)
    }

    /// Encode working directory for CodeBuddy's project dir format
    /// Strips leading /, replaces remaining / with -, keeps _
    static func encodeCodeBuddyProjectDirName(workingDirectory: String) -> String {
        var path = workingDirectory
        if path.hasPrefix("/") {
            path = String(path.dropFirst())
        }
        return path.replacingOccurrences(of: "/", with: "-")
    }

    private func parseCodeBuddySessionFile(at url: URL) -> AgentStatus {
        guard let fileHandle = try? FileHandle(forReadingFrom: url) else {
            return .unknown
        }
        defer { fileHandle.closeFile() }

        let fileSize = fileHandle.seekToEndOfFile()
        let readSize: UInt64 = min(fileSize, 8192)
        fileHandle.seek(toFileOffset: fileSize - readSize)
        guard let data = try? fileHandle.readToEnd(),
              let content = String(data: data, encoding: .utf8) else {
            return .unknown
        }

        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard !lines.isEmpty else { return .unknown }

        // CodeBuddy metadata types to skip
        let metadataTypes: Set<String> = ["file-history-snapshot", "ai-title"]
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
        case "message":
            // CodeBuddy uses type:"message" with role field
            let role = json["role"] as? String ?? ""
            if role == "user" {
                return elapsed > 60 ? .idle : .running
            } else if role == "assistant" {
                // Check for tool_use in content
                if let content = json["content"] as? [[String: Any]] {
                    for block in content {
                        if block["type"] as? String == "tool_use" {
                            let toolName = block["name"] as? String ?? ""
                            if toolName == "AskUserQuestion" || toolName == "TodoQuery" {
                                return .needsInput
                            }
                            return .running
                        }
                    }
                }
                return elapsed <= 5 ? .running : .idle
            }
            return elapsed <= 5 ? .running : .idle

        case "function_call":
            // Check if the tool is asking user a question
            let toolName = json["name"] as? String ?? ""
            if toolName == "AskUserQuestion" || toolName == "TodoQuery" {
                return .needsInput
            }
            // Agent is executing a tool — running
            return .running

        case "function_result":
            // Tool result received — agent is processing
            return elapsed > 30 ? .idle : .running

        case "error":
            return .error

        default:
            return elapsed > 10 ? .idle : .running
        }
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
        case .codeBuddy:
            return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codebuddy").path
        default:
            return ""
        }
    }

    // MARK: - JSONL Parsing

    private func parseSessionFile(at url: URL) -> AgentStatus {
        // Only read the last 8KB of the file for efficiency
        guard let fileHandle = try? FileHandle(forReadingFrom: url) else {
            return .unknown
        }
        defer { fileHandle.closeFile() }

        let fileSize = fileHandle.seekToEndOfFile()
        let readSize: UInt64 = min(fileSize, 8192)
        fileHandle.seek(toFileOffset: fileSize - readSize)
        guard let data = try? fileHandle.readToEnd(),
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
            // Check message content for tool_use blocks
            let msg = json["message"] as? [String: Any]
            let content = msg?["content"]
            if let blocks = content as? [[String: Any]] {
                for block in blocks {
                    if block["type"] as? String == "tool_use" {
                        let toolName = block["name"] as? String ?? ""
                        if toolName == "AskUserQuestion" || toolName == "TodoQuery" {
                            return .needsInput
                        }
                        // Agent is executing a tool (Bash, Agent, Read, etc.) — still running
                        return .running
                    }
                }
            }

            // Check for permission/confirmation subtype
            if let subtype = json["subtype"] as? String {
                if subtype == "permission_request" || subtype == "confirmation" {
                    return .needsInput
                }
            }

            if elapsed <= 5 {
                // File still being written — agent is actively responding
                return .running
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
            // Tool result received — agent is processing
            return elapsed > 30 ? .idle : .running

        case "error":
            return .error

        default:
            return elapsed > 10 ? .idle : .running
        }
    }
}
