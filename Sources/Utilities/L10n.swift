import Foundation

/// Localization keys for the app
enum L10n {
    // MARK: - General
    static var appName: String { "AgentTerms" }
    static var cancel: String { "cancel".localized }
    static var create: String { "create".localized }
    static var delete: String { "delete".localized }
    static var save: String { "save".localized }
    static var filter: String { "filter".localized }

    // MARK: - Workspace
    static var workspaces: String { "workspaces".localized }
    static var newWorkspace: String { "new_workspace".localized }
    static var newWorkspaceDesc: String { "new_workspace_desc".localized }
    static var validGitRepo: String { "valid_git_repo".localized }
    static var notGitRepo: String { "not_git_repo".localized }
    static var createWorkspace: String { "create_workspace".localized }
    static var deleteWorkspace: String { "delete_workspace".localized }
    static var browse: String { "browse".localized }
    static var repoPath: String { "repo_path".localized }

    // MARK: - Snapshot
    static var newSnapshot: String { "new_snapshot".localized }
    static var newSnapshotDesc: String { "new_snapshot_desc".localized }
    static var createSnapshot: String { "create_snapshot".localized }
    static var deleteSnapshot: String { "delete_snapshot".localized }
    static var noSnapshots: String { "no_snapshots".localized }
    static var selectBranch: String { "select_branch".localized }
    static var newBranch: String { "new_branch".localized }
    static var snapshotName: String { "snapshot_name".localized }
    static var branch: String { "branch".localized }
    static var snapshots: String { "snapshots".localized }

    // MARK: - Agent
    static var newAgent: String { "new_agent".localized }
    static var startAgent: String { "start_agent".localized }
    static var deleteAgent: String { "delete_agent".localized }
    static var openTerminal: String { "open_terminal".localized }
    static var noAgents: String { "no_agents".localized }
    static var taskDescription: String { "task_description".localized }
    static var agentName: String { "agent_name".localized }
    static var aiTool: String { "ai_tool".localized }

    // MARK: - Status
    static var running: String { "status_running".localized }
    static var needsInput: String { "status_needs_input".localized }
    static var idle: String { "status_idle".localized }
    static var error: String { "status_error".localized }
    static var unknown: String { "status_unknown".localized }

    // MARK: - Empty States
    static var welcomeTitle: String { "welcome_title".localized }
    static var welcomeSubtitle: String { "welcome_subtitle".localized }
    static var noSnapshotsTitle: String { "no_snapshots_title".localized }
    static var noSnapshotsSubtitle: String { "no_snapshots_subtitle".localized }
    static var noAgentsTitle: String { "no_agents_title".localized }
    static var noAgentsSubtitle: String { "no_agents_subtitle".localized }
    static var selectSnapshotTitle: String { "select_snapshot_title".localized }
    static var selectSnapshotSubtitle: String { "select_snapshot_subtitle".localized }

    // MARK: - Menu Bar
    static var agentsNeedAttention: String { "agents_need_attention".localized }
    static var allSmooth: String { "all_smooth".localized }
    static var quit: String { "quit".localized }

    // MARK: - Delete Snapshot
    static var deleteWorktree: String { "delete_worktree".localized }
    static var uncommittedWarning: String { "uncommitted_warning".localized }
    static var forceDeleteTitle: String { "force_delete_title".localized }
    static var forceDelete: String { "force_delete".localized }
    static var forceDeleteMessage: String { "force_delete_message".localized }

    // MARK: - Settings
    static var settings: String { "settings".localized }
    static var settingsGeneral: String { "settings_general".localized }
    static var settingsTools: String { "settings_tools".localized }
    static var settingsLanguageSection: String { "settings_language".localized }
    static var command: String { "command".localized }
    static var configPath: String { "config_path".localized }
    static var resumeArg: String { "resume_arg".localized }

    // MARK: - Terminal
    static var back: String { "back".localized }
    static var terminalTheme: String { "terminal_theme".localized }
    static var terminalFont: String { "terminal_font".localized }
    static var fontFamily: String { "font_family".localized }
    static var fontSize: String { "font_size".localized }
    static var systemDefault: String { "system_default".localized }
    static var copyOnSelect: String { "copy_on_select".localized }

    // MARK: - Notifications
    static var notifNeedsInput: String { "notif_needs_input".localized }
    static var notifError: String { "notif_error".localized }

    // MARK: - Shortcuts
    static var settingsShortcuts: String { "settings_shortcuts".localized }
    static var prevWorkspace: String { "prev_workspace_label".localized }
    static var nextWorkspace: String { "next_workspace_label".localized }
    static var prevSnapshot: String { "prev_snapshot_label".localized }
    static var nextSnapshot: String { "next_snapshot_label".localized }
    static var jumpToAttention: String { "jump_to_attention_label".localized }
    static var newAgentShortcut: String { "new_agent_label".localized }
    static var newSnapshotShortcut: String { "new_snapshot_label".localized }
    static var closeAgentLabel: String { "close_agent_label".localized }
    static var resetToDefault: String { "reset_to_default".localized }
    static var pressShortcut: String { "press_shortcut".localized }
}

extension String {
    var localized: String {
        // Determine preferred language
        let lang = UserDefaults.standard.stringArray(forKey: "AppleLanguages")?.first ?? "zh-Hans"
        let langCode = lang.hasPrefix("zh") ? "zh-hans" : "en"

        // Find the .lproj bundle for the language
        if let path = Bundle.module.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: langCode),
           let bundle = Bundle(url: URL(fileURLWithPath: path).deletingLastPathComponent()) {
            let value = NSLocalizedString(self, bundle: bundle, comment: "")
            if value != self { return value }
        }

        // Fallback: try direct lproj
        if let lprojPath = Bundle.module.path(forResource: langCode, ofType: "lproj"),
           let bundle = Bundle(path: lprojPath) {
            let value = NSLocalizedString(self, bundle: bundle, comment: "")
            if value != self { return value }
        }

        // Final fallback
        return NSLocalizedString(self, bundle: Bundle.module, comment: "")
    }
}
