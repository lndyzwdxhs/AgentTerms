import AppKit
import SwiftUI

/// Monitors keyboard events and dispatches configurable shortcut actions
final class KeyboardShortcutMonitor {
    private var monitor: Any?
    private weak var appState: AppState?
    private weak var settings: Settings?

    init(appState: AppState, settings: Settings) {
        self.appState = appState
        self.settings = settings
        install()
    }

    deinit { uninstall() }

    private func install() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleEvent(event) == true { return nil }
            return event
        }
    }

    private func uninstall() {
        if let m = monitor { NSEvent.removeMonitor(m) }
    }

    private func handleEvent(_ event: NSEvent) -> Bool {
        guard let settings, let appState else { return false }

        for (action, binding) in settings.keyBindings {
            if binding.matches(event: event) {
                perform(action: action, appState: appState)
                return true
            }
        }
        return false
    }

    private func perform(action: ShortcutAction, appState: AppState) {
        switch action {
        case .prevWorkspace:
            navigateWorkspace(direction: -1, appState: appState)
        case .nextWorkspace:
            navigateWorkspace(direction: 1, appState: appState)
        case .prevSnapshot:
            navigateSnapshot(direction: -1, appState: appState)
        case .nextSnapshot:
            navigateSnapshot(direction: 1, appState: appState)
        case .jumpToAttention:
            if let agent = appState.allAgents.first(where: { $0.status == .needsInput || $0.status == .error }) {
                appState.selectedAgentID = agent.id
            }
        case .newAgent:
            NotificationCenter.default.post(name: .createAgent, object: nil)
        case .newSnapshot:
            NotificationCenter.default.post(name: .createSnapshot, object: nil)
        case .closeAgent:
            NotificationCenter.default.post(name: .closeAgent, object: nil)
        }
    }

    private func navigateWorkspace(direction: Int, appState: AppState) {
        let workspaces = appState.workspaces
        guard !workspaces.isEmpty else { return }
        appState.rememberSnapshotSelection()
        if let currentID = appState.selectedWorkspaceID,
           let currentIdx = workspaces.firstIndex(where: { $0.id == currentID }) {
            let newIdx = (currentIdx + direction + workspaces.count) % workspaces.count
            let wsID = workspaces[newIdx].id
            appState.selectedWorkspaceID = wsID
            appState.restoreSnapshotSelection(for: wsID)
        }
    }

    private func navigateSnapshot(direction: Int, appState: AppState) {
        guard let ws = appState.selectedWorkspace else { return }
        let snapshots = ws.snapshots
        guard !snapshots.isEmpty else { return }
        appState.rememberAgentSelection()
        if let currentID = appState.selectedSnapshotID,
           let currentIdx = snapshots.firstIndex(where: { $0.id == currentID }) {
            let newIdx = (currentIdx + direction + snapshots.count) % snapshots.count
            appState.selectedSnapshotID = snapshots[newIdx].id
        } else {
            appState.selectedSnapshotID = snapshots.first?.id
        }
        if let snapshotID = appState.selectedSnapshotID {
            appState.restoreAgentSelection(for: snapshotID)
        }
    }
}

/// Static Commands for index-based shortcuts (Cmd+1~9, Cmd+Shift+1~3)
struct KeyboardShortcutCommands: Commands {
    var appState: AppState

    var body: some Commands {
        CommandGroup(after: .toolbar) {
            Button("Agent 1") { selectAgent(at: 0) }.keyboardShortcut("1", modifiers: [.command])
            Button("Agent 2") { selectAgent(at: 1) }.keyboardShortcut("2", modifiers: [.command])
            Button("Agent 3") { selectAgent(at: 2) }.keyboardShortcut("3", modifiers: [.command])
            Button("Agent 4") { selectAgent(at: 3) }.keyboardShortcut("4", modifiers: [.command])
            Button("Agent 5") { selectAgent(at: 4) }.keyboardShortcut("5", modifiers: [.command])
            Button("Agent 6") { selectAgent(at: 5) }.keyboardShortcut("6", modifiers: [.command])
            Button("Agent 7") { selectAgent(at: 6) }.keyboardShortcut("7", modifiers: [.command])
            Button("Agent 8") { selectAgent(at: 7) }.keyboardShortcut("8", modifiers: [.command])
            Button("Agent 9") { selectAgent(at: 8) }.keyboardShortcut("9", modifiers: [.command])
            Divider()
            Button("Workspace 1") { selectWorkspace(at: 0) }.keyboardShortcut("1", modifiers: [.command, .shift])
            Button("Workspace 2") { selectWorkspace(at: 1) }.keyboardShortcut("2", modifiers: [.command, .shift])
            Button("Workspace 3") { selectWorkspace(at: 2) }.keyboardShortcut("3", modifiers: [.command, .shift])
        }
    }

    private func selectAgent(at index: Int) {
        let agents = appState.selectedSnapshot?.agents ?? []
        guard index < agents.count else { return }
        appState.selectedAgentID = agents[index].id
    }

    private func selectWorkspace(at index: Int) {
        guard index < appState.workspaces.count else { return }
        appState.rememberSnapshotSelection()
        let wsID = appState.workspaces[index].id
        appState.selectedWorkspaceID = wsID
        appState.restoreSnapshotSelection(for: wsID)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let createAgent = Notification.Name("com.agentterms.createAgent")
    static let createSnapshot = Notification.Name("com.agentterms.createSnapshot")
    static let closeAgent = Notification.Name("com.agentterms.closeAgent")
}
