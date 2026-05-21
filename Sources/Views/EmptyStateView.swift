import SwiftUI

enum EmptyStateType {
    case noWorkspaces
    case noSnapshots
    case noAgents
    case selectSnapshot
}

struct EmptyStateView: View {
    @Environment(AppState.self) private var appState
    let type: EmptyStateType
    @State private var showCreateWorkspace = false
    @State private var showCreateSnapshot = false
    @State private var showCreateAgent = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title2)
                .fontWeight(.medium)
            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(action: primaryAction) {
                Text(buttonTitle)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showCreateWorkspace) { CreateWorkspaceSheet() }
        .sheet(isPresented: $showCreateSnapshot) { CreateSnapshotSheet() }
        .sheet(isPresented: $showCreateAgent) { CreateAgentSheet() }
    }

    private var icon: String {
        switch type {
        case .noWorkspaces: return "folder.badge.plus"
        case .noSnapshots: return "square.stack.3d.up"
        case .noAgents: return "terminal"
        case .selectSnapshot: return "sidebar.left"
        }
    }

    private var title: String {
        switch type {
        case .noWorkspaces: return L10n.welcomeTitle
        case .noSnapshots: return L10n.noSnapshotsTitle
        case .noAgents: return L10n.noAgentsTitle
        case .selectSnapshot: return L10n.selectSnapshotTitle
        }
    }

    private var subtitle: String {
        switch type {
        case .noWorkspaces: return L10n.welcomeSubtitle
        case .noSnapshots: return L10n.noSnapshotsSubtitle
        case .noAgents: return L10n.noAgentsSubtitle
        case .selectSnapshot: return L10n.selectSnapshotSubtitle
        }
    }

    private var buttonTitle: String {
        switch type {
        case .noWorkspaces: return L10n.createWorkspace
        case .noSnapshots: return L10n.newSnapshot
        case .noAgents: return L10n.startAgent
        case .selectSnapshot: return L10n.createWorkspace
        }
    }

    private func primaryAction() {
        switch type {
        case .noWorkspaces, .selectSnapshot: showCreateWorkspace = true
        case .noSnapshots: showCreateSnapshot = true
        case .noAgents: showCreateAgent = true
        }
    }
}
