import SwiftUI

/// Shows floors as cards within a workspace (similar to Maestri's floor bubbles)
struct FloorGridView: View {
    @Environment(AppState.self) private var appState
    let workspace: Workspace
    @State private var showCreateFloor = false

    private let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 320), spacing: 16)
    ]

    var body: some View {
        VStack(spacing: 0) {
            if workspace.floors.isEmpty {
                EmptyStateView(type: .noFloors)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(workspace.floors) { floor in
                            FloorCard(floor: floor)
                                .onTapGesture {
                                    appState.selectedFloorID = floor.id
                                }
                                .contextMenu {
                                    Button(L10n.openTerminal) {
                                        appState.selectedFloorID = floor.id
                                    }
                                    Divider()
                                    Button(L10n.deleteFloor, role: .destructive) {
                                        appState.removeFloor(id: floor.id, from: workspace.id)
                                    }
                                }
                        }

                        // "New Floor" card
                        NewFloorCard {
                            showCreateFloor = true
                        }
                    }
                    .padding(24)
                }
            }
        }
        .navigationTitle(workspace.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreateFloor = true
                } label: {
                    Image(systemName: "plus")
                }
                .help(L10n.newFloor)
            }

            // Back button when viewing from a floor
            if appState.selectedFloorID != nil {
                ToolbarItem(placement: .navigation) {
                    Button {
                        appState.selectedFloorID = nil
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                }
            }
        }
        .sheet(isPresented: $showCreateFloor) {
            CreateFloorSheet()
        }
    }
}

struct FloorCard: View {
    let floor: Floor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: name + status
            HStack {
                Text(floor.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Circle()
                    .fill(floor.aggregatedStatus.color)
                    .frame(width: 10, height: 10)
            }

            // Branch info
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.caption2)
                Text(floor.branch)
                    .font(.caption)
                    .lineLimit(1)
            }
            .foregroundStyle(.secondary)

            Divider()

            // Agent summary
            if floor.agents.isEmpty {
                Text(L10n.noAgents)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                HStack(spacing: 12) {
                    AgentStatusCount(count: floor.agents.filter { $0.status == .running }.count, status: .running)
                    AgentStatusCount(count: floor.agents.filter { $0.status == .needsInput }.count, status: .needsInput)
                    AgentStatusCount(count: floor.agents.filter { $0.status == .idle }.count, status: .idle)
                }
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(floor.aggregatedStatus == .needsInput ? Color.red.opacity(0.5) : Color.clear, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.05), radius: 3, y: 2)
    }
}

struct AgentStatusCount: View {
    let count: Int
    let status: AgentStatus

    var body: some View {
        if count > 0 {
            HStack(spacing: 3) {
                Circle()
                    .fill(status.color)
                    .frame(width: 6, height: 6)
                Text("\(count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct NewFloorCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text(L10n.newFloor)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 100)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
                    .foregroundStyle(.quaternary)
            )
        }
        .buttonStyle(.plain)
    }
}
