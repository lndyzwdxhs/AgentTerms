import SwiftUI

struct AgentGridView: View {
    @Environment(AppState.self) private var appState
    @Environment(Settings.self) private var settings
    @State private var showCreateAgent = false

    private var floor: Floor? {
        appState.selectedFloor
    }

    var body: some View {
        if let floor, !floor.agents.isEmpty {
            VStack(spacing: 0) {
                // Top: Agent cards - modern segmented style
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(floor.agents.enumerated()), id: \.element.id) { index, agent in
                            AgentCard(
                                agent: agent,
                                index: index + 1,
                                isSelected: agent.id == appState.selectedAgentID
                            )
                            .onTapGesture {
                                appState.selectedAgentID = agent.id
                            }
                            .contextMenu {
                                Button(L10n.openTerminal) {
                                    appState.selectedAgentID = agent.id
                                }
                                Divider()
                                Button(L10n.deleteAgent, role: .destructive) {
                                    if let wsID = appState.selectedWorkspaceID {
                                        TerminalManager.shared.remove(agentID: agent.id)
                                        appState.removeAgent(id: agent.id, fromFloor: floor.id, inWorkspace: wsID)
                                    }
                                }
                            }
                        }

                        // Add button
                        AddAgentCard {
                            showCreateAgent = true
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .frame(height: 70)

                // Bottom: Terminal area
                if let agentID = appState.selectedAgentID,
                   let agent = floor.agents.first(where: { $0.id == agentID }) {
                    TerminalSwitcherView(
                        agentID: agent.id,
                        theme: .dracula,
                        command: settings.command(for: agent.tool),
                        workingDirectory: agent.workingDirectory,
                        configPath: settings.configPath(for: agent.tool),
                        sessionID: agent.sessionID,
                        resumeArg: settings.resumeArg(for: agent.tool),
                        appState: appState,
                        onProcessExit: {
                            appState.updateAgentStatus(agentID: agent.id, status: .idle)
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.black.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                } else {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(nsColor: .textBackgroundColor).opacity(0.4))
                        .overlay {
                            VStack(spacing: 8) {
                                Image(systemName: "terminal")
                                    .font(.system(size: 32, weight: .light))
                                    .foregroundStyle(.tertiary)
                                Text("Select an agent")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.black.opacity(0.05), lineWidth: 1)
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }
            }
            .sheet(isPresented: $showCreateAgent) {
                CreateAgentSheet()
            }
        } else {
            EmptyStateView(type: .noAgents)
        }
    }
}

/// Modern agent card - clean, pill-like tabs
struct AgentCard: View {
    let agent: Agent
    let index: Int
    let isSelected: Bool
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            // Status dot
            Circle()
                .fill(agent.status.color)
                .frame(width: 8, height: 8)
                .shadow(color: agent.status.color.opacity(0.4), radius: 3)
                .opacity(agent.status == .running ? (isHovered ? 1.0 : 0.7) : 1.0)

            VStack(alignment: .leading, spacing: 2) {
                Text(agent.taskDescription.isEmpty ? "Agent" : agent.taskDescription)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(agent.status.label)
                        .foregroundStyle(agent.status.color)
                    Text("•")
                    Text("⌘\(index)")
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(width: 160, height: 46)
        .overlay(alignment: .topTrailing) {
            Text(agent.tool.displayName)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.tertiary)
                .padding(.top, 5)
                .padding(.trailing, 8)
        }
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
            } else if isHovered {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.5))
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? Color.black.opacity(0.08) : Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 0.5)
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        // Subtle scale effect on click
        .scaleEffect(isHovered && !isSelected ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

/// Add agent card modern style
struct AddAgentCard: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 40, height: 46)
                .background {
                    if isHovered {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.5))
                    } else {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.clear)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .scaleEffect(isHovered ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
    }
}
