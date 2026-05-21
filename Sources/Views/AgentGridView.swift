import SwiftUI

struct AgentGridView: View {
    @Environment(AppState.self) private var appState
    @Environment(Settings.self) private var settings
    @State private var showCreateAgent = false

    private var floor: Floor? {
        appState.selectedFloor
    }

    /// Auto-select first agent and pre-warm all terminals
    private func autoSelectAndWarmTerminals(floor: Floor) {
        // Auto-select first agent if none selected or current selection not in this floor
        if appState.selectedAgentID == nil ||
           !floor.agents.contains(where: { $0.id == appState.selectedAgentID }) {
            appState.selectedAgentID = floor.agents.first?.id
        }

        // Pre-warm terminals for all agents in background
        for agent in floor.agents {
            if !TerminalManager.shared.hasTerminal(for: agent.id) {
                _ = TerminalManager.shared.terminal(
                    for: agent.id,
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
            }
        }
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
                            .id("\(agent.id)-\(agent.status.rawValue)")
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
                .frame(height: 88)

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
            .onAppear {
                autoSelectAndWarmTerminals(floor: floor)
            }
            .onChange(of: appState.selectedFloorID) { _, _ in
                if let floor = appState.selectedFloor, !floor.agents.isEmpty {
                    autoSelectAndWarmTerminals(floor: floor)
                }
            }
        } else {
            EmptyStateView(type: .noAgents)
        }
    }
}

/// Modern agent card — left accent bar style
struct AgentCard: View {
    let agent: Agent
    let index: Int
    let isSelected: Bool
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 0) {
            // Left status accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(agent.status.color)
                .frame(width: isSelected ? 4 : 3, height: 38)
                .shadow(color: agent.status.color.opacity(0.4), radius: 3)
                .padding(.leading, 10)

            VStack(alignment: .leading, spacing: 5) {
                // Row 1: Name + shortcut
                HStack {
                    Text(agent.taskDescription.isEmpty ? "Agent" : agent.taskDescription)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text("⌘\(index)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                }

                // Row 2: Status + tool name
                HStack {
                    Text(agent.status.label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(agent.status.color)
                    Spacer(minLength: 4)
                    Text(agent.tool.displayName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, 14)
        }
        .padding(.vertical, 12)
        .frame(width: 200, height: 64)
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
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 48, height: 64)
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
