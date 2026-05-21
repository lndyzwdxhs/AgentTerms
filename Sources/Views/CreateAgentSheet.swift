import SwiftUI
import AppKit

struct CreateWorkspaceSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPath = ""
    @State private var isValidRepo = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 20) {
            Text(L10n.newWorkspace)
                .font(.title2)
                .fontWeight(.semibold)

            Text(L10n.newWorkspaceDesc)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack {
                TextField(L10n.repoPath, text: $selectedPath)
                    .textFieldStyle(.roundedBorder)
                    .disabled(true)

                Button(L10n.browse) {
                    openDirectoryPicker()
                }
            }
            .frame(width: 400)

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

            HStack(spacing: 12) {
                Button(L10n.cancel) { dismiss() }
                    .keyboardShortcut(.escape)
                Button(L10n.createWorkspace) {
                    appState.addWorkspace(repoPath: selectedPath)
                    dismiss()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(!isValidRepo)
            }
        }
        .padding(24)
        .frame(width: 480)
    }

    private func openDirectoryPicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = L10n.newWorkspaceDesc

        if panel.runModal() == .OK, let url = panel.url {
            selectedPath = url.path
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

struct CreateFloorSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var branch = ""
    @State private var branches: [String] = []
    @State private var isNewBranch = false
    @State private var errorMessage = ""
    @FocusState private var isNameFocused: Bool

    var body: some View {
        VStack(spacing: 20) {
            Text(L10n.newFloor)
                .font(.title2)
                .fontWeight(.semibold)

            Text(L10n.newFloorDesc)
                .font(.caption)
                .foregroundStyle(.secondary)

            Form {
                if branches.isEmpty {
                    TextField(L10n.branch, text: $branch)
                        .textFieldStyle(.roundedBorder)
                } else {
                    Picker(L10n.branch, selection: $branch) {
                        Text(L10n.selectBranch).tag("")
                        ForEach(branches, id: \.self) { b in
                            Text(b).tag(b)
                        }
                    }

                    TextField(L10n.newBranch, text: $branch)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                }

                TextField(L10n.floorName, text: $name, prompt: Text(suggestedName))
                    .textFieldStyle(.roundedBorder)
                    .focused($isNameFocused)
            }
            .frame(width: 350)

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack(spacing: 12) {
                Button(L10n.cancel) { dismiss() }
                    .keyboardShortcut(.escape)
                Button(L10n.createFloor) {
                    createFloor()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(branch.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 420)
        .onAppear {
            loadBranches()
        }
    }

    private var suggestedName: String {
        guard !branch.isEmpty else { return "e.g. payment-refactor" }
        let cleaned = branch
            .replacingOccurrences(of: "feature/", with: "")
            .replacingOccurrences(of: "fix/", with: "")
            .replacingOccurrences(of: "hotfix/", with: "")
        return cleaned
    }

    private var effectiveName: String {
        if name.isEmpty {
            return suggestedName
        }
        return name
    }

    private func loadBranches() {
        guard let wsID = appState.selectedWorkspaceID,
              let workspace = appState.workspaces.first(where: { $0.id == wsID }) else { return }
        branches = GitService.listBranches(repoPath: workspace.repoPath)
    }

    private func createFloor() {
        guard let wsID = appState.selectedWorkspaceID else { return }

        let floorName = effectiveName
        let isNew = !branches.contains(branch)

        do {
            try appState.addFloor(name: floorName, branch: branch, isNewBranch: isNew, to: wsID)
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

            if let floor = appState.selectedFloor {
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .foregroundStyle(.secondary)
                    Text(floor.worktreePath)
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

                TextField(L10n.taskDescription, text: $taskDescription)
                    .textFieldStyle(.roundedBorder)
            }
            .frame(width: 320)

            HStack(spacing: 12) {
                Button(L10n.cancel) { dismiss() }
                    .keyboardShortcut(.escape)
                Button(L10n.startAgent) {
                    guard !taskDescription.isEmpty,
                          let wsID = appState.selectedWorkspaceID,
                          let floor = appState.selectedFloor else { return }
                    appState.addAgent(
                        tool: tool,
                        workingDirectory: floor.worktreePath,
                        taskDescription: taskDescription,
                        toFloor: floor.id,
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

struct DeleteFloorSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let floor: Floor
    let workspaceID: UUID
    @State private var removeWorktree = true
    @State private var hasUncommitted = false
    @State private var showForceConfirm = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.orange)

            Text(L10n.deleteFloor)
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(L10n.floorName + ":")
                        .foregroundStyle(.secondary)
                    Text(floor.name)
                        .fontWeight(.medium)
                }
                HStack {
                    Text(L10n.branch + ":")
                        .foregroundStyle(.secondary)
                    Text(floor.branch)
                        .fontWeight(.medium)
                }
                HStack {
                    Text("Agents:")
                        .foregroundStyle(.secondary)
                    Text("\(floor.agents.count)")
                        .fontWeight(.medium)
                }
            }
            .font(.body)

            Divider()

            Toggle(L10n.deleteWorktree, isOn: $removeWorktree)

            if removeWorktree {
                Text(floor.worktreePath)
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
            hasUncommitted = GitService.hasUncommittedChanges(worktreePath: floor.worktreePath)
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
        appState.removeFloor(id: floor.id, from: workspaceID, removeWorktree: removeWorktree)
        dismiss()
    }
}
