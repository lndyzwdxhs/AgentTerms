import SwiftUI
import SwiftTerm

/// Full-screen terminal view for a single agent
struct TerminalFullView: View {
    @Environment(AppState.self) private var appState
    @Environment(Settings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    let agent: Agent
    @State private var selectedTheme: TerminalTheme = .dracula
    @State private var showThemePicker = false

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Button {
                    appState.selectedAgentID = nil
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text(L10n.back)
                    }
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: agent.status.icon)
                        .foregroundStyle(agent.status.color)
                    Text(agent.displayName)
                        .font(.headline)
                }

                Spacer()

                Button {
                    showThemePicker.toggle()
                } label: {
                    Image(systemName: "paintpalette")
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showThemePicker) {
                    ThemePickerView(selectedTheme: $selectedTheme)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)

            Divider()

            // Terminal — cached by TerminalManager, survives navigation
            TerminalSwitcherView(
                agentID: agent.id,
                theme: selectedTheme,
                command: settings.command(for: agent.tool),
                workingDirectory: agent.workingDirectory,
                configPath: settings.configPath(for: agent.tool),
                sessionID: agent.sessionID,
                resumeArg: settings.resumeArg(for: agent.tool),
                appState: appState,
                onProcessExit: {
                    appState.updateAgentStatus(agentID: agent.id, status: .idle)
                }
            )
        }
    }
}

struct ThemePickerView: View {
    @Binding var selectedTheme: TerminalTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.terminalTheme)
                .font(.headline)
                .padding(.bottom, 4)
            ForEach(TerminalTheme.allCases, id: \.self) { theme in
                Button {
                    selectedTheme = theme
                } label: {
                    HStack {
                        Circle()
                            .fill(Color(nsColor: theme.colors.background))
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle().stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                        Text(theme.rawValue)
                            .foregroundStyle(.primary)
                        Spacer()
                        if theme == selectedTheme {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 2)
            }
        }
        .padding(12)
        .frame(width: 200)
    }
}
