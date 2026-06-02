import AppKit
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

// MARK: - Keyboard Shortcuts

enum ShortcutAction: String, Codable, CaseIterable {
    case prevWorkspace = "prev_workspace"
    case nextWorkspace = "next_workspace"
    case prevSnapshot = "prev_snapshot"
    case nextSnapshot = "next_snapshot"
    case jumpToAttention = "jump_to_attention"
    case newAgent = "new_agent"
    case newSnapshot = "new_snapshot"
    case closeAgent = "close_agent"

    var displayName: String {
        switch self {
        case .prevWorkspace: return L10n.prevWorkspace
        case .nextWorkspace: return L10n.nextWorkspace
        case .prevSnapshot: return L10n.prevSnapshot
        case .nextSnapshot: return L10n.nextSnapshot
        case .jumpToAttention: return L10n.jumpToAttention
        case .newAgent: return L10n.newAgentShortcut
        case .newSnapshot: return L10n.newSnapshotShortcut
        case .closeAgent: return L10n.closeAgentLabel
        }
    }

    static var defaults: [ShortcutAction: KeyBinding] {
        [
            .prevWorkspace: KeyBinding(key: "↑", modifiers: [.command]),
            .nextWorkspace: KeyBinding(key: "↓", modifiers: [.command]),
            .prevSnapshot: KeyBinding(key: "←", modifiers: [.command]),
            .nextSnapshot: KeyBinding(key: "→", modifiers: [.command]),
            .jumpToAttention: KeyBinding(key: "↩", modifiers: [.command]),
            .newAgent: KeyBinding(key: "n", modifiers: [.command]),
            .newSnapshot: KeyBinding(key: "n", modifiers: [.command, .shift]),
            .closeAgent: KeyBinding(key: "w", modifiers: [.command]),
        ]
    }
}

struct KeyBinding: Codable, Equatable {
    var key: String
    var modifiers: Set<KeyModifier>

    enum KeyModifier: String, Codable, CaseIterable {
        case command, shift, option, control

        var symbol: String {
            switch self {
            case .command: return "⌘"
            case .shift: return "⇧"
            case .option: return "⌥"
            case .control: return "⌃"
            }
        }

        var nsFlag: NSEvent.ModifierFlags {
            switch self {
            case .command: return .command
            case .shift: return .shift
            case .option: return .option
            case .control: return .control
            }
        }
    }

    var displayString: String {
        let mods = modifiers.sorted(by: { $0.rawValue < $1.rawValue }).map(\.symbol).joined()
        return mods + key
    }

    func matches(event: NSEvent) -> Bool {
        let requiredFlags: NSEvent.ModifierFlags = modifiers.reduce([]) { $0.union($1.nsFlag) }
        let eventMods = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard eventMods == requiredFlags else { return false }

        // Match special keys
        switch key {
        case "↑": return event.keyCode == 126
        case "↓": return event.keyCode == 125
        case "←": return event.keyCode == 123
        case "→": return event.keyCode == 124
        case "↩": return event.keyCode == 36
        default:
            return event.charactersIgnoringModifiers?.lowercased() == key.lowercased()
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
    var terminalTheme: TerminalTheme = .kittyLowContrast
    var terminalFontName: String = "Menlo" // empty = system monospace
    var terminalFontSize: CGFloat = 20
    var terminalCopyOnSelect: Bool = false
    var keyBindings: [ShortcutAction: KeyBinding] = ShortcutAction.defaults

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
            let data = try encoder.encode(SettingsData(
                toolConfigs: toolConfigs,
                language: language,
                terminalTheme: terminalTheme,
                terminalFontName: terminalFontName,
                terminalFontSize: terminalFontSize,
                terminalCopyOnSelect: terminalCopyOnSelect,
                keyBindings: keyBindings
            ))
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
            terminalCopyOnSelect = decoded.terminalCopyOnSelect
            keyBindings = decoded.keyBindings
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
    var terminalTheme: TerminalTheme = .kittyLowContrast
    var terminalFontName: String = "Menlo"
    var terminalFontSize: CGFloat = 20
    var terminalCopyOnSelect: Bool = false
    var keyBindings: [ShortcutAction: KeyBinding] = ShortcutAction.defaults

    enum CodingKeys: String, CodingKey {
        case toolConfigs, language, terminalTheme, terminalFontName, terminalFontSize, terminalCopyOnSelect, keyBindings
    }

    init(toolConfigs: [AgentTool: ToolConfig] = [:], language: AppLanguage = .zhHans, terminalTheme: TerminalTheme = .kittyLowContrast, terminalFontName: String = "Menlo", terminalFontSize: CGFloat = 20, terminalCopyOnSelect: Bool = false, keyBindings: [ShortcutAction: KeyBinding] = ShortcutAction.defaults) {
        self.toolConfigs = toolConfigs
        self.language = language
        self.terminalTheme = terminalTheme
        self.terminalFontName = terminalFontName
        self.terminalFontSize = terminalFontSize
        self.terminalCopyOnSelect = terminalCopyOnSelect
        self.keyBindings = keyBindings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        toolConfigs = try container.decodeIfPresent([AgentTool: ToolConfig].self, forKey: .toolConfigs) ?? [:]
        language = try container.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .zhHans
        terminalTheme = try container.decodeIfPresent(TerminalTheme.self, forKey: .terminalTheme) ?? .kittyLowContrast
        terminalFontName = try container.decodeIfPresent(String.self, forKey: .terminalFontName) ?? "Menlo"
        terminalFontSize = try container.decodeIfPresent(CGFloat.self, forKey: .terminalFontSize) ?? 20
        terminalCopyOnSelect = try container.decodeIfPresent(Bool.self, forKey: .terminalCopyOnSelect) ?? false
        keyBindings = try container.decodeIfPresent([ShortcutAction: KeyBinding].self, forKey: .keyBindings) ?? ShortcutAction.defaults
    }
}
