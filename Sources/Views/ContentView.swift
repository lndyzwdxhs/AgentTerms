import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var showCreateSnapshot = false
    @State private var showCreateAgent = false
    @State private var showSnapshotSwitcher = false

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            ZStack {
                if appState.workspaces.isEmpty {
                    EmptyStateView(type: .noWorkspaces)
                } else if appState.selectedWorkspace != nil {
                    if appState.selectedSnapshot != nil {
                        AgentGridView()
                    } else {
                        EmptyStateView(type: .noSnapshots)
                    }
                } else {
                    EmptyStateView(type: .selectSnapshot)
                }

                // 3D Snapshot Switcher overlay (detail area only)
                if showSnapshotSwitcher {
                    SnapshotSwitcher3DView(
                        isPresented: $showSnapshotSwitcher,
                        showCreateSnapshot: $showCreateSnapshot
                    )
                    .transition(.opacity)
                }
            }
        }
            .navigationSplitViewStyle(.balanced)
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    SnapshotToolbarView(
                        showSnapshotSwitcher: $showSnapshotSwitcher,
                        showCreateSnapshot: $showCreateSnapshot
                    )
                }
                ToolbarItem(placement: .automatic) {
                    if let snapshot = appState.selectedSnapshot {
                        Button {
                            openInVSCode(path: snapshot.worktreePath)
                        } label: {
                            if let nsImage = loadBundleImage("vscode") {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .frame(width: 16, height: 16)
                            } else {
                                Image(systemName: "curlybraces")
                                    .font(.system(size: 13, weight: .medium))
                            }
                        }
                        .help("在 VS Code 中打开")
                    }
                }
            }
            .sheet(isPresented: $showCreateSnapshot) {
                CreateSnapshotSheet()
            }
            .sheet(isPresented: $showCreateAgent) {
                CreateAgentSheet()
            }
    }
    private func openInVSCode(path: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Visual Studio Code", path]
        try? process.run()
    }

    private func loadBundleImage(_ name: String) -> NSImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png") else {
            // Try resource bundle
            let bundleName = "AgentTerms_AgentTerms"
            if let resourceBundle = Bundle.main.url(forResource: bundleName, withExtension: "bundle"),
               let bundle = Bundle(url: resourceBundle),
               let imgURL = bundle.url(forResource: name, withExtension: "png") {
                return NSImage(contentsOf: imgURL)
            }
            return nil
        }
        return NSImage(contentsOf: url)
    }
}

/// Snapshot switcher displayed in the window titlebar
struct SnapshotToolbarView: View {
    @Environment(AppState.self) private var appState
    @Binding var showSnapshotSwitcher: Bool
    @Binding var showCreateSnapshot: Bool

    var body: some View {
        HStack(spacing: 10) {
            if let snapshot = appState.selectedSnapshot {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showSnapshotSwitcher = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.3.layers.3d")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(snapshot.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }
                }
                .buttonStyle(.plain)

                HStack(spacing: 3) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.caption2)
                    Text(snapshot.branch)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.quaternary, in: Capsule())

            } else if appState.selectedWorkspace != nil {
                Button {
                    showCreateSnapshot = true
                } label: {
                    HStack(spacing: 4) {
                        Text(L10n.noSnapshots)
                            .font(.body)
                            .foregroundStyle(.secondary)
                        Image(systemName: "plus.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

