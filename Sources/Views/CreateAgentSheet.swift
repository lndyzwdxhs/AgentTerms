import SwiftUI
import AppKit

struct CreateWorkspaceSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selectedPath = ""
    @State private var isValidRepo = false
    @State private var errorMessage = ""
    @State private var selectedColor: WorkspaceColor = .blue

    var body: some View {
        VStack(spacing: 20) {
            Text(L10n.newWorkspace)
                .font(.title2)
                .fontWeight(.bold)

            // Workspace name
            TextField("", text: $name, prompt: Text("工作区名称").foregroundColor(Color.secondary.opacity(0.5)))
                .textFieldStyle(.roundedBorder)
                .frame(width: 320)

            // Color picker
            VStack(alignment: .leading, spacing: 8) {
                Text("颜色")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    ForEach(WorkspaceColor.allCases, id: \.self) { color in
                        Circle()
                            .fill(colorValue(color))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary.opacity(0.8), lineWidth: selectedColor == color ? 2.5 : 0)
                                    .padding(-3)
                            )
                            .onTapGesture { selectedColor = color }
                    }
                }
            }
            .frame(width: 320, alignment: .leading)

            // Workspace directory
            VStack(alignment: .leading, spacing: 8) {
                Text("工作区目录")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack {
                    Text(selectedPath.isEmpty ? "~" : selectedPath)
                        .font(.callout)
                        .foregroundStyle(selectedPath.isEmpty ? .tertiary : .primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button(L10n.browse) {
                        openDirectoryPicker()
                    }
                }
            }
            .frame(width: 320, alignment: .leading)

            if !selectedPath.isEmpty {
                HStack(spacing: 6) {
                    if isValidRepo {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(L10n.validGitRepo)
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                        Text(L10n.notGitRepo)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }

            Divider()
                .frame(width: 320)

            // Buttons
            HStack(spacing: 16) {
                Button(L10n.cancel) { dismiss() }
                    .keyboardShortcut(.escape)
                Button(L10n.createWorkspace) {
                    let wsName = name.isEmpty ? (selectedPath as NSString).lastPathComponent : name
                    appState.addWorkspace(repoPath: selectedPath, color: selectedColor, name: wsName)
                    dismiss()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(!isValidRepo)
            }
        }
        .padding(28)
        .frame(width: 400)
    }

    private func colorValue(_ c: WorkspaceColor) -> Color {
        switch c {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        }
    }

    private func openDirectoryPicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = L10n.newWorkspaceDesc

        if panel.runModal() == .OK, let url = panel.url {
            selectedPath = url.path
            if name.isEmpty {
                name = (selectedPath as NSString).lastPathComponent
            }
            validateRepo()
        }
    }

    private func validateRepo() {
        if GitService.isGitRepo(path: selectedPath) {
            isValidRepo = true
            errorMessage = ""
        } else {
            isValidRepo = false
            errorMessage = L10n.notGitRepo
        }
    }
}

struct CreateSnapshotSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var branch = ""
    @State private var branches: [String] = []
    @State private var filteredBranches: [String] = []
    @State private var newBranchName = ""
    @State private var searchText = ""
    @State private var errorMessage = ""
    @FocusState private var isNameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.newSnapshot)
                    .font(.title2)
                    .fontWeight(.bold)
                Text(L10n.newSnapshotDesc)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            // Snapshot name
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.snapshotName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("", text: $name, prompt: Text(L10n.snapshotName).foregroundColor(Color.secondary.opacity(0.5)))
                    .textFieldStyle(.roundedBorder)
                    .focused($isNameFocused)
            }

            // Branch section
            VStack(alignment: .leading, spacing: 8) {
                Text("创建新分支或使用已有分支")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Search field
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.tertiary)
                        .font(.caption)
                    TextField("", text: $searchText, prompt: Text("搜索分支...").foregroundColor(Color.secondary.opacity(0.5)))
                        .textFieldStyle(.plain)
                        .font(.callout)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )

                // Branch list
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(filteredBranches, id: \.self) { b in
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.triangle.branch")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(b)
                                    .font(.callout)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(branch == b ? Color.accentColor.opacity(0.1) : Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                branch = b
                            }

                            if b != filteredBranches.last {
                                Divider()
                                    .padding(.leading, 30)
                            }
                        }
                    }
                }
                .frame(height: 160)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // New branch input
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(.blue)
                        .font(.callout)
                    TextField("", text: $newBranchName, prompt: Text("新分支名称").foregroundColor(Color.secondary.opacity(0.5)))
                        .textFieldStyle(.plain)
                        .font(.callout)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            // Bottom buttons
            HStack {
                Button(L10n.cancel) { dismiss() }
                    .keyboardShortcut(.escape)
                Spacer()
                Button(L10n.createSnapshot) {
                    createSnapshot()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(effectiveBranch.isEmpty)
            }
            .padding(.top, 4)
        }
        .padding(24)
        .frame(width: 400)
        .onAppear {
            loadBranches()
        }
        .onChange(of: searchText) { _, newValue in
            filterBranches(query: newValue)
        }
    }

    private var effectiveBranch: String {
        if !newBranchName.isEmpty {
            return newBranchName
        }
        return branch
    }

    private var effectiveName: String {
        if name.isEmpty {
            let b = effectiveBranch
            guard !b.isEmpty else { return "" }
            return b
                .replacingOccurrences(of: "feature/", with: "")
                .replacingOccurrences(of: "fix/", with: "")
                .replacingOccurrences(of: "hotfix/", with: "")
        }
        return name
    }

    private func loadBranches() {
        guard let wsID = appState.selectedWorkspaceID,
              let workspace = appState.workspaces.first(where: { $0.id == wsID }) else { return }
        branches = GitService.listBranches(repoPath: workspace.repoPath)
        filteredBranches = branches
    }

    private func filterBranches(query: String) {
        if query.isEmpty {
            filteredBranches = branches
        } else {
            filteredBranches = branches.filter { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    private func createSnapshot() {
        guard let wsID = appState.selectedWorkspaceID else { return }

        let snapshotName = effectiveName
        let branchToUse = effectiveBranch
        let isNew = !newBranchName.isEmpty || !branches.contains(branchToUse)

        do {
            try appState.addSnapshot(name: snapshotName, branch: branchToUse, isNewBranch: isNew, to: wsID)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct CreateAgentSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var tool: AgentTool = .claudeCode
    @State private var taskDescription = ""

    var body: some View {
        VStack(spacing: 20) {
            Text(L10n.newAgent)
                .font(.title2)
                .fontWeight(.semibold)

            if let snapshot = appState.selectedSnapshot {
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .foregroundStyle(.secondary)
                    Text(snapshot.worktreePath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Form {
                Picker(L10n.aiTool, selection: $tool) {
                    ForEach(AgentTool.allCases, id: \.self) { t in
                        Label(t.rawValue, systemImage: t.icon).tag(t)
                    }
                }

                TextField(L10n.agentName, text: $taskDescription)
                    .textFieldStyle(.roundedBorder)
            }
            .frame(width: 320)

            HStack(spacing: 12) {
                Button(L10n.cancel) { dismiss() }
                    .keyboardShortcut(.escape)
                Button(L10n.startAgent) {
                    guard !taskDescription.isEmpty,
                          let wsID = appState.selectedWorkspaceID,
                          let snapshot = appState.selectedSnapshot else { return }
                    appState.addAgent(
                        tool: tool,
                        workingDirectory: snapshot.worktreePath,
                        taskDescription: taskDescription,
                        toSnapshot: snapshot.id,
                        inWorkspace: wsID
                    )
                    dismiss()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(taskDescription.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400)
    }
}

struct DeleteSnapshotSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let snapshot: Snapshot
    let workspaceID: UUID
    @State private var removeWorktree = true
    @State private var hasUncommitted = false
    @State private var showForceConfirm = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.orange)

            Text(L10n.deleteSnapshot)
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(L10n.snapshotName + ":")
                        .foregroundStyle(.secondary)
                    Text(snapshot.name)
                        .fontWeight(.medium)
                }
                HStack {
                    Text(L10n.branch + ":")
                        .foregroundStyle(.secondary)
                    Text(snapshot.branch)
                        .fontWeight(.medium)
                }
                HStack {
                    Text("Agents:")
                        .foregroundStyle(.secondary)
                    Text("\(snapshot.agents.count)")
                        .fontWeight(.medium)
                }
            }
            .font(.body)

            Divider()

            Toggle(L10n.deleteWorktree, isOn: $removeWorktree)

            if removeWorktree {
                Text(snapshot.worktreePath)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.head)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if hasUncommitted && removeWorktree {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                    Text(L10n.uncommittedWarning)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            HStack(spacing: 12) {
                Button(L10n.cancel) { dismiss() }
                    .keyboardShortcut(.escape)
                Button(L10n.delete, role: .destructive) {
                    if hasUncommitted && removeWorktree {
                        showForceConfirm = true
                    } else {
                        performDelete()
                    }
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        .padding(24)
        .frame(width: 400)
        .onAppear {
            hasUncommitted = GitService.hasUncommittedChanges(worktreePath: snapshot.worktreePath)
        }
        .alert(L10n.forceDeleteTitle, isPresented: $showForceConfirm) {
            Button(L10n.cancel, role: .cancel) {}
            Button(L10n.forceDelete, role: .destructive) {
                performDelete()
            }
        } message: {
            Text(L10n.forceDeleteMessage)
        }
    }

    private func performDelete() {
        appState.removeSnapshot(id: snapshot.id, from: workspaceID, removeWorktree: removeWorktree)
        dismiss()
    }
}
