import Foundation

enum AppLanguage: String, Codable, CaseIterable {
    case zhHans = "zh-Hans"
    case en = "en"

    var displayName: String {
        switch self {
        case .zhHans: return "中文"
        case .en: return "English"
        }
    }
}

/// Global settings for tool commands and config paths
@Observable
final class Settings {
    var toolConfigs: [AgentTool: ToolConfig] = [:]
    var language: AppLanguage = .zhHans {
        didSet {
            applyLanguage()
        }
    }
    var terminalTheme: TerminalTheme = .dracula
    var terminalFontName: String = "" // empty = system monospace
    var terminalFontSize: CGFloat = 13

    private let settingsURL: URL = {
        PersistenceService.baseDir.appendingPathComponent("settings.json")
    }()

    init() {
        load()
        applyLanguage()
    }

    /// Get effective command for a tool (custom or default)
    func command(for tool: AgentTool) -> String {
        if let config = toolConfigs[tool], !config.command.isEmpty {
            return config.command
        }
        return PTYService.commandForTool(tool)
    }

    /// Get config path for a tool (empty if not set)
    func configPath(for tool: AgentTool) -> String {
        toolConfigs[tool]?.configPath ?? ""
    }

    /// Get resume argument for a tool (e.g. "--resume" for Claude Code)
    func resumeArg(for tool: AgentTool) -> String {
        if let config = toolConfigs[tool], !config.resumeArg.isEmpty {
            return config.resumeArg
        }
        // Defaults
        switch tool {
        case .claudeCode: return "--resume"
        case .codeBuddy: return "--resume="
        case .codex: return "resume"
        default: return ""
        }
    }

    func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(SettingsData(toolConfigs: toolConfigs, language: language, terminalTheme: terminalTheme, terminalFontName: terminalFontName, terminalFontSize: terminalFontSize))
            try data.write(to: settingsURL, options: .atomic)
        } catch {
            print("[AgentTerms] Failed to save settings: \(error)")
        }
    }

    func load() {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else { return }
        do {
            let data = try Data(contentsOf: settingsURL)
            let decoded = try JSONDecoder().decode(SettingsData.self, from: data)
            toolConfigs = decoded.toolConfigs
            language = decoded.language
            terminalTheme = decoded.terminalTheme
            terminalFontName = decoded.terminalFontName
            terminalFontSize = decoded.terminalFontSize
        } catch {
            // Try legacy format (just toolConfigs)
            if let data = try? Data(contentsOf: settingsURL),
               let legacy = try? JSONDecoder().decode([AgentTool: ToolConfig].self, from: data) {
                toolConfigs = legacy
            }
        }
    }

    private func applyLanguage() {
        UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")
    }
}

struct ToolConfig: Codable {
    var command: String = ""
    var configPath: String = ""
    var resumeArg: String = ""  // e.g. "--resume" for Claude Code, "resume" for Codex

    enum CodingKeys: String, CodingKey {
        case command, configPath, resumeArg
    }

    init(command: String = "", configPath: String = "", resumeArg: String = "") {
        self.command = command
        self.configPath = configPath
        self.resumeArg = resumeArg
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        command = try container.decodeIfPresent(String.self, forKey: .command) ?? ""
        configPath = try container.decodeIfPresent(String.self, forKey: .configPath) ?? ""
        resumeArg = try container.decodeIfPresent(String.self, forKey: .resumeArg) ?? ""
    }
}

private struct SettingsData: Codable {
    var toolConfigs: [AgentTool: ToolConfig] = [:]
    var language: AppLanguage = .zhHans
    var terminalTheme: TerminalTheme = .dracula
    var terminalFontName: String = ""
    var terminalFontSize: CGFloat = 13

    enum CodingKeys: String, CodingKey {
        case toolConfigs, language, terminalTheme, terminalFontName, terminalFontSize
    }

    init(toolConfigs: [AgentTool: ToolConfig] = [:], language: AppLanguage = .zhHans, terminalTheme: TerminalTheme = .dracula, terminalFontName: String = "", terminalFontSize: CGFloat = 13) {
        self.toolConfigs = toolConfigs
        self.language = language
        self.terminalTheme = terminalTheme
        self.terminalFontName = terminalFontName
        self.terminalFontSize = terminalFontSize
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        toolConfigs = try container.decodeIfPresent([AgentTool: ToolConfig].self, forKey: .toolConfigs) ?? [:]
        language = try container.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .zhHans
        terminalTheme = try container.decodeIfPresent(TerminalTheme.self, forKey: .terminalTheme) ?? .dracula
        terminalFontName = try container.decodeIfPresent(String.self, forKey: .terminalFontName) ?? ""
        terminalFontSize = try container.decodeIfPresent(CGFloat.self, forKey: .terminalFontSize) ?? 13
    }
}
