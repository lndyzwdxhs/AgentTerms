import SwiftUI

/// Keyboard shortcut commands for the app
struct KeyboardShortcutCommands: Commands {
    var appState: AppState

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Agent") {
                NotificationCenter.default.post(name: .createAgent, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.command])

            Button("New Floor") {
                NotificationCenter.default.post(name: .createFloor, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Divider()

            Button("Close Agent") {
                NotificationCenter.default.post(name: .closeAgent, object: nil)
            }
            .keyboardShortcut("w", modifiers: [.command])
        }

        CommandGroup(after: .toolbar) {
            // Agent switching: Cmd+1~9 activates Nth agent in current floor
            Button("Agent 1") { selectAgent(at: 0) }
                .keyboardShortcut("1", modifiers: [.command])
            Button("Agent 2") { selectAgent(at: 1) }
                .keyboardShortcut("2", modifiers: [.command])
            Button("Agent 3") { selectAgent(at: 2) }
                .keyboardShortcut("3", modifiers: [.command])
            Button("Agent 4") { selectAgent(at: 3) }
                .keyboardShortcut("4", modifiers: [.command])
            Button("Agent 5") { selectAgent(at: 4) }
                .keyboardShortcut("5", modifiers: [.command])
            Button("Agent 6") { selectAgent(at: 5) }
                .keyboardShortcut("6", modifiers: [.command])
            Button("Agent 7") { selectAgent(at: 6) }
                .keyboardShortcut("7", modifiers: [.command])
            Button("Agent 8") { selectAgent(at: 7) }
                .keyboardShortcut("8", modifiers: [.command])
            Button("Agent 9") { selectAgent(at: 8) }
                .keyboardShortcut("9", modifiers: [.command])

            Divider()

            // Workspace switching: Cmd+Shift+1~3
            Button("Workspace 1") { selectWorkspace(at: 0) }
                .keyboardShortcut("1", modifiers: [.command, .shift])
            Button("Workspace 2") { selectWorkspace(at: 1) }
                .keyboardShortcut("2", modifiers: [.command, .shift])
            Button("Workspace 3") { selectWorkspace(at: 2) }
                .keyboardShortcut("3", modifiers: [.command, .shift])

            Divider()

            Button("Jump to Needs Attention") {
                jumpToNeedsAttention()
            }
            .keyboardShortcut(.return, modifiers: [.command])

            Button("Previous Agent") {
                navigateAgent(direction: -1)
            }
            .keyboardShortcut(.upArrow, modifiers: [.command])

            Button("Next Agent") {
                navigateAgent(direction: 1)
            }
            .keyboardShortcut(.downArrow, modifiers: [.command])
        }
    }

    private func selectAgent(at index: Int) {
        let agents = appState.selectedFloor?.agents ?? []
        guard index < agents.count else { return }
        appState.selectedAgentID = agents[index].id
    }

    private func selectWorkspace(at index: Int) {
        guard index < appState.workspaces.count else { return }
        appState.selectedWorkspaceID = appState.workspaces[index].id
        appState.selectedFloorID = appState.workspaces[index].floors.first?.id
        appState.selectedAgentID = nil
    }

    private func jumpToNeedsAttention() {
        if let agent = appState.allAgents.first(where: { $0.status == .needsInput || $0.status == .error }) {
            appState.selectedAgentID = agent.id
        }
    }

    private func navigateAgent(direction: Int) {
        let agents = appState.selectedFloor?.agents ?? []
        guard !agents.isEmpty else { return }

        if let currentID = appState.selectedAgentID,
           let currentIdx = agents.firstIndex(where: { $0.id == currentID }) {
            let newIdx = (currentIdx + direction + agents.count) % agents.count
            appState.selectedAgentID = agents[newIdx].id
        } else {
            appState.selectedAgentID = agents.first?.id
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let createAgent = Notification.Name("com.agentterms.createAgent")
    static let createFloor = Notification.Name("com.agentterms.createFloor")
    static let closeAgent = Notification.Name("com.agentterms.closeAgent")
}
