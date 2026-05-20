import SwiftUI
import AppKit

@main
struct AgentTermsApp: App {
    @State private var appState = AppState()
    @State private var settings = Settings()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(settings)
                .frame(minWidth: 800, minHeight: 600)
                .onAppear {
                    appState.startMonitoring(settings: settings)
                }
        }
        .windowResizability(.contentMinSize)
        .commands {
            KeyboardShortcutCommands(appState: appState)
        }

        SwiftUI.Settings {
            SettingsView()
                .environment(settings)
        }

        MenuBarExtra {
            MenuBarView()
                .environment(appState)
        } label: {
            let count = appState.agentsNeedingAttention
            if count > 0 {
                Label("\(count)", systemImage: "exclamationmark.circle.fill")
            } else {
                Label("AgentTerms", systemImage: "rectangle.grid.2x2")
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Activate app and bring window to front
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false // Keep running in menu bar
    }
}

struct MenuBarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if appState.agentsNeedingAttention > 0 {
                Text("\(appState.agentsNeedingAttention) \(L10n.agentsNeedAttention)")
                    .font(.headline)
                Divider()
            } else {
                Text(L10n.allSmooth)
                    .font(.headline)
                Divider()
            }

            ForEach(appState.allAgents.filter { $0.status == .needsInput || $0.status == .error }) { agent in
                HStack {
                    Circle()
                        .fill(agent.status.color)
                        .frame(width: 8, height: 8)
                    Text(agent.taskDescription)
                        .lineLimit(1)
                }
            }

            Divider()
            Button(L10n.quit) {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(8)
    }
}
