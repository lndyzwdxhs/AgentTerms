import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @State private var showCreateWorkspace = false
    @State private var showCreateSnapshot = false
    @State private var searchText = ""

    var body: some View {
        @Bindable var state = appState

        VStack(spacing: 0) {
            // Search/filter bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Filter", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)

            // Section title
            HStack {
                Text(L10n.workspaces)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)

            // Workspace list
            List(selection: $state.selectedWorkspaceID) {
                ForEach(filteredWorkspaces) { workspace in
                    WorkspaceRow(workspace: workspace)
                        .tag(workspace.id)
                        .contextMenu {
                            Button {
                                appState.selectedWorkspaceID = workspace.id
                                showCreateSnapshot = true
                            } label: {
                                Label(L10n.newSnapshot, systemImage: "plus")
                            }
                            Divider()
                            Button(L10n.deleteWorkspace, role: .destructive) {
                                appState.removeWorkspace(id: workspace.id)
                            }
                        }
                }
            }
            .listStyle(.sidebar)

            Divider()

            // Bottom: Add workspace button
            Button {
                showCreateWorkspace = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.caption)
                    Text(L10n.newWorkspace)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showCreateWorkspace) {
            CreateWorkspaceSheet()
        }
        .sheet(isPresented: $showCreateSnapshot) {
            CreateSnapshotSheet()
        }
    }

    private var filteredWorkspaces: [Workspace] {
        if searchText.isEmpty { return appState.workspaces }
        return appState.workspaces.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.snapshots.contains { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
}

struct WorkspaceRow: View {
    let workspace: Workspace

    var body: some View {
        HStack(spacing: 10) {
            // Laptop icon with user-chosen color
            Image(systemName: "laptopcomputer")
                .font(.body)
                .foregroundStyle(colorForWorkspace)
                .frame(width: 24)

            // Name
            Text(workspace.name)
                .font(.body)
                .lineLimit(1)

            Spacer()

            // Notification badge (agents needing attention)
            let attentionCount = workspace.snapshots.flatMap(\.agents).filter { $0.status == .needsInput || $0.status == .error }.count
            if attentionCount > 0 {
                Text("\(attentionCount)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.red, in: Capsule())
            }

            // Snapshot count
            HStack(spacing: 3) {
                Image(systemName: "square.3.layers.3d")
                    .font(.caption2)
                Text("\(workspace.snapshots.count)")
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }

    private var colorForWorkspace: Color {
        switch workspace.color {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        }
    }
}
