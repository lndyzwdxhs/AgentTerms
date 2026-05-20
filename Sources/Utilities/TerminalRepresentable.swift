import SwiftUI
import SwiftTerm
import AppKit

/// A container NSView that holds and switches between cached terminal views.
/// This avoids SwiftUI destroying/recreating the terminal NSView on agent switch.
class TerminalContainerView: NSView {
    private var currentAgentID: UUID?
    private var currentTerminal: LocalProcessTerminalView?
    private let inset: CGFloat = 8

    func showTerminal(for agentID: UUID, terminal: LocalProcessTerminalView) {
        if currentAgentID == agentID { return }

        // Remove old terminal from view hierarchy (but don't destroy it)
        currentTerminal?.removeFromSuperview()

        // Add new terminal with inset constraints
        terminal.translatesAutoresizingMaskIntoConstraints = false
        addSubview(terminal)
        NSLayoutConstraint.activate([
            terminal.topAnchor.constraint(equalTo: topAnchor, constant: inset),
            terminal.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -inset),
            terminal.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            terminal.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset)
        ])

        currentTerminal = terminal
        currentAgentID = agentID
    }
}

/// NSViewRepresentable that uses a persistent container to switch terminals without destroying them
struct TerminalSwitcherView: NSViewRepresentable {
    let agentID: UUID?
    let theme: TerminalTheme
    let command: String
    let workingDirectory: String
    let configPath: String
    let sessionID: String?
    let resumeArg: String
    let appState: AppState
    let onProcessExit: () -> Void

    func makeNSView(context: Context) -> TerminalContainerView {
        TerminalContainerView()
    }

    func updateNSView(_ containerView: TerminalContainerView, context: Context) {
        guard let agentID else { return }

        let terminal = TerminalManager.shared.terminal(
            for: agentID,
            theme: theme,
            command: command,
            workingDirectory: workingDirectory,
            configPath: configPath,
            sessionID: sessionID,
            resumeArg: resumeArg,
            appState: appState,
            onProcessExit: onProcessExit
        )

        containerView.showTerminal(for: agentID, terminal: terminal)
    }
}
