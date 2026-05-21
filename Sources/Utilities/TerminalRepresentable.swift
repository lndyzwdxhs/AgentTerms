import SwiftUI
import SwiftTerm
import AppKit

/// A container NSView that holds and switches between cached terminal views.
/// This avoids SwiftUI destroying/recreating the terminal NSView on agent switch.
class TerminalContainerView: NSView {
    private var currentAgentID: UUID?
    private var currentTerminal: LocalProcessTerminalView?
    private let inset: CGFloat = 8
    private var fontSize: CGFloat = 13.0
    private var keyMonitor: Any?

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

        // Apply current font size
        terminal.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)

        currentTerminal = terminal
        currentAgentID = agentID

        // Focus the terminal so keyboard input goes to it
        DispatchQueue.main.async {
            terminal.window?.makeFirstResponder(terminal)
        }

        // Install key monitor for Cmd+/- font size shortcuts
        if keyMonitor == nil {
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self = self else { return event }
                if event.modifierFlags.contains(.command) {
                    let chars = event.charactersIgnoringModifiers ?? ""
                    if chars == "=" || chars == "+" {
                        self.adjustFontSize(delta: 1)
                        return nil // consume event
                    } else if chars == "-" {
                        self.adjustFontSize(delta: -1)
                        return nil // consume event
                    }
                }
                return event
            }
        }
    }

    private func adjustFontSize(delta: CGFloat) {
        fontSize = max(8, min(32, fontSize + delta))
        if let terminal = currentTerminal {
            terminal.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        }
        TerminalManager.shared.setFontSize(fontSize)
    }

    deinit {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
        }
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
