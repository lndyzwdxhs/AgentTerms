import SwiftUI

enum EmptyStateType {
    case noWorkspaces
    case noFloors
    case noAgents
    case selectFloor
}

struct EmptyStateView: View {
    @Environment(AppState.self) private var appState
    let type: EmptyStateType
    @State private var showCreateWorkspace = false
    @State private var showCreateFloor = false
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
        .sheet(isPresented: $showCreateFloor) { CreateFloorSheet() }
        .sheet(isPresented: $showCreateAgent) { CreateAgentSheet() }
    }

    private var icon: String {
        switch type {
        case .noWorkspaces: return "folder.badge.plus"
        case .noFloors: return "square.stack.3d.up"
        case .noAgents: return "terminal"
        case .selectFloor: return "sidebar.left"
        }
    }

    private var title: String {
        switch type {
        case .noWorkspaces: return L10n.welcomeTitle
        case .noFloors: return L10n.noFloorsTitle
        case .noAgents: return L10n.noAgentsTitle
        case .selectFloor: return L10n.selectFloorTitle
        }
    }

    private var subtitle: String {
        switch type {
        case .noWorkspaces: return L10n.welcomeSubtitle
        case .noFloors: return L10n.noFloorsSubtitle
        case .noAgents: return L10n.noAgentsSubtitle
        case .selectFloor: return L10n.selectFloorSubtitle
        }
    }

    private var buttonTitle: String {
        switch type {
        case .noWorkspaces: return L10n.createWorkspace
        case .noFloors: return L10n.newFloor
        case .noAgents: return L10n.startAgent
        case .selectFloor: return L10n.createWorkspace
        }
    }

    private func primaryAction() {
        switch type {
        case .noWorkspaces, .selectFloor: showCreateWorkspace = true
        case .noFloors: showCreateFloor = true
        case .noAgents: showCreateAgent = true
        }
    }
}
