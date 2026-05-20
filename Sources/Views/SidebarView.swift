import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @State private var showCreateWorkspace = false
    @State private var showCreateFloor = false
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
                                showCreateFloor = true
                            } label: {
                                Label("Add Floor", systemImage: "plus")
                            }
                            Divider()
                            Button("Delete Workspace", role: .destructive) {
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
        .sheet(isPresented: $showCreateFloor) {
            CreateFloorSheet()
        }
    }

    private var filteredWorkspaces: [Workspace] {
        if searchText.isEmpty { return appState.workspaces }
        return appState.workspaces.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.floors.contains { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
}

struct WorkspaceRow: View {
    let workspace: Workspace

    var body: some View {
        HStack(spacing: 10) {
            // Colored icon
            Image(systemName: "terminal.fill")
                .font(.body)
                .foregroundStyle(workspaceColor)
                .frame(width: 24)

            // Name
            Text(workspace.name)
                .font(.body)
                .lineLimit(1)

            Spacer()

            // Notification badge (agents needing attention)
            let attentionCount = workspace.floors.flatMap(\.agents).filter { $0.status == .needsInput || $0.status == .error }.count
            if attentionCount > 0 {
                Text("\(attentionCount)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.red, in: Capsule())
            }

            // Floor/agent count
            let agentCount = workspace.floors.flatMap(\.agents).count
            HStack(spacing: 2) {
                Image(systemName: "square.stack.3d.up")
                    .font(.caption2)
                Text("\(agentCount)")
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }

    private var workspaceColor: Color {
        switch workspace.aggregatedStatus {
        case .needsInput, .error: return .red
        case .running: return .green
        default: return .secondary
        }
    }
}
