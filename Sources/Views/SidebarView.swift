import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @State private var showCreateWorkspace = false
    @State private var showCreateSnapshot = false
    @State private var searchText = ""
    @State private var currentBranch: String = ""
    @State private var branches: [String] = []
    @State private var showBranchPicker = false

    var body: some View {
        @Bindable var state = appState

        let workspaceBinding = Binding<UUID?>(
            get: { appState.selectedWorkspaceID },
            set: { newID in
                let oldID = appState.selectedWorkspaceID
                guard newID != oldID else { return }
                // Remember before switching
                if oldID != nil {
                    appState.rememberSnapshotSelection()
                }
                appState.selectedWorkspaceID = newID
                // Restore after switching
                if let newID {
                    appState.restoreSnapshotSelection(for: newID)
                }
            }
        )

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
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)

            // Workspace list
            List(selection: workspaceBinding) {
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

            // Branch status bar
            if let workspace = appState.selectedWorkspace {
                HStack(spacing: 4) {
                    Text("Base Branch:")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)

                    Button {
                        showBranchPicker = true
                    } label: {
                        Text(currentBranch.isEmpty ? "..." : currentBranch)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.green)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showBranchPicker, arrowEdge: .top) {
                        BranchPickerView(
                            branches: branches,
                            currentBranch: currentBranch,
                            onSelect: { branch in
                                showBranchPicker = false
                                switchBranch(to: branch, in: workspace)
                            }
                        )
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .onAppear { refreshBranch(for: workspace) }
                .onChange(of: appState.selectedWorkspaceID) { _, _ in
                    if let ws = appState.selectedWorkspace {
                        refreshBranch(for: ws)
                    }
                }

                Divider()
            }

            // Bottom: Add workspace button
            Button {
                showCreateWorkspace = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 13))
                    Text(L10n.newWorkspace)
                        .font(.system(size: 13))
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

    private func refreshBranch(for workspace: Workspace) {
        DispatchQueue.global(qos: .userInitiated).async {
            let branch = GitService.currentBranch(repoPath: workspace.repoPath)
            let allBranches = GitService.listBranches(repoPath: workspace.repoPath)
            DispatchQueue.main.async {
                currentBranch = branch
                branches = allBranches
            }
        }
    }

    private func switchBranch(to branch: String, in workspace: Workspace) {
        guard branch != currentBranch else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try GitService.checkout(repoPath: workspace.repoPath, branch: branch)
                DispatchQueue.main.async {
                    currentBranch = branch
                }
            } catch {
                print("[AgentTerms] Branch switch failed: \(error)")
            }
        }
    }
}

struct WorkspaceRow: View {
    let workspace: Workspace

    var body: some View {
        HStack(spacing: 10) {
            // Laptop icon with user-chosen color
            Image(systemName: "laptopcomputer")
                .font(.system(size: 17))
                .foregroundStyle(colorForWorkspace)
                .frame(width: 26)

            // Name
            Text(workspace.name)
                .font(.system(size: 15))
                .lineLimit(1)

            Spacer()

            // Notification badge (agents needing attention)
            let attentionCount = workspace.snapshots.flatMap(\.agents).filter { $0.status == .needsInput || $0.status == .error }.count
            if attentionCount > 0 {
                Text("\(attentionCount)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.red, in: Capsule())
            }

            // Snapshot count
            HStack(spacing: 3) {
                Image(systemName: "square.3.layers.3d")
                    .font(.system(size: 12))
                Text("\(workspace.snapshots.count)")
                    .font(.system(size: 12))
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

// MARK: - Branch Picker with Search

struct BranchPickerView: View {
    let branches: [String]
    let currentBranch: String
    let onSelect: (String) -> Void
    @State private var searchText = ""

    private var filteredBranches: [String] {
        if searchText.isEmpty { return branches }
        return branches.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                TextField("Search branch...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Branch list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(filteredBranches, id: \.self) { branch in
                        Button {
                            onSelect(branch)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: branch == currentBranch ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 11))
                                    .foregroundStyle(branch == currentBranch ? .green : .secondary)
                                Text(branch)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background(branch == currentBranch ? Color.green.opacity(0.08) : Color.clear)
                    }
                }
            }
        }
        .frame(width: 240, height: min(CGFloat(branches.count) * 28 + 44, 300))
    }
}
