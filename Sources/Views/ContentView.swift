import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var showCreateFloor = false
    @State private var showCreateAgent = false
    @State private var showFloorSwitcher = false

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            ZStack {
                if appState.workspaces.isEmpty {
                    EmptyStateView(type: .noWorkspaces)
                } else if appState.selectedWorkspace != nil {
                    if appState.selectedFloor != nil {
                        AgentGridView()
                    } else {
                        EmptyStateView(type: .noFloors)
                    }
                } else {
                    EmptyStateView(type: .selectFloor)
                }

                // 3D Floor Switcher overlay (detail area only)
                if showFloorSwitcher {
                    FloorSwitcher3DView(
                        isPresented: $showFloorSwitcher,
                        showCreateFloor: $showCreateFloor
                    )
                    .transition(.opacity)
                }
            }
        }
            .navigationSplitViewStyle(.balanced)
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    FloorToolbarView(
                        showFloorSwitcher: $showFloorSwitcher,
                        showCreateFloor: $showCreateFloor
                    )
                }
                ToolbarItem(placement: .automatic) {
                    if let floor = appState.selectedFloor {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.caption2)
                            Text(floor.branch)
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.quaternary, in: Capsule())
                    }
                }
            }
            .sheet(isPresented: $showCreateFloor) {
                CreateFloorSheet()
            }
            .sheet(isPresented: $showCreateAgent) {
                CreateAgentSheet()
            }
    }
}

/// Floor switcher displayed in the window titlebar
struct FloorToolbarView: View {
    @Environment(AppState.self) private var appState
    @Binding var showFloorSwitcher: Bool
    @Binding var showCreateFloor: Bool

    var body: some View {
        HStack(spacing: 10) {
            if let floor = appState.selectedFloor {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showFloorSwitcher = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.3.layers.3d")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(floor.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }
                }
                .buttonStyle(.plain)

            } else if appState.selectedWorkspace != nil {
                Button {
                    showCreateFloor = true
                } label: {
                    HStack(spacing: 4) {
                        Text(L10n.noFloors)
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

