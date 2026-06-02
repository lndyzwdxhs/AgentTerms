import SwiftUI

struct AgentGridView: View {
    @Environment(AppState.self) private var appState
    @Environment(Settings.self) private var settings
    @State private var showCreateAgent = false
    @State private var draggedAgentID: UUID?
    @State private var editingSessionAgent: Agent?

    private var snapshot: Snapshot? {
        appState.selectedSnapshot
    }

    /// Auto-select first agent and pre-warm all terminals
    private func autoSelectAndWarmTerminals(snapshot: Snapshot) {
        // Restore last-selected agent if current selection not in this snapshot
        if appState.selectedAgentID == nil ||
           !snapshot.agents.contains(where: { $0.id == appState.selectedAgentID }) {
            appState.restoreAgentSelection(for: snapshot.id)
        }

        // Pre-warm terminals for all agents in background
        for agent in snapshot.agents {
            if !TerminalManager.shared.hasTerminal(for: agent.id) {
                _ = TerminalManager.shared.terminal(
                    for: agent.id,
                    theme: settings.terminalTheme,
                    tool: agent.tool,
                    command: settings.command(for: agent.tool),
                    workingDirectory: agent.workingDirectory,
                    configPath: settings.configPath(for: agent.tool),
                    sessionID: agent.sessionID,
                    resumeArg: settings.resumeArg(for: agent.tool),
                    copyOnSelect: settings.terminalCopyOnSelect,
                    appState: appState,
                    onProcessExit: {
                        appState.updateAgentStatus(agentID: agent.id, status: .idle)
                    }
                )
            }
        }
    }

    var body: some View {
        if let snapshot, !snapshot.agents.isEmpty {
            VStack(spacing: 0) {
                // Top: Agent cards - modern segmented style
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(snapshot.agents.enumerated()), id: \.element.id) { index, agent in
                            AgentCard(
                                agent: agent,
                                index: index + 1,
                                isSelected: agent.id == appState.selectedAgentID
                            )
                            .id("\(agent.id)-\(agent.status.rawValue)")
                            .opacity(draggedAgentID == agent.id ? 0.4 : 1.0)
                            .onDrag {
                                draggedAgentID = agent.id
                                return NSItemProvider(object: agent.id.uuidString as NSString)
                            }
                            .onDrop(of: [.text], delegate: AgentDropDelegate(
                                targetAgentID: agent.id,
                                appState: appState,
                                snapshot: snapshot,
                                draggedAgentID: $draggedAgentID
                            ))
                            .onTapGesture {
                                appState.selectedAgentID = agent.id
                            }
                            .contextMenu {
                                Button(L10n.reopenTerminal) {
                                    TerminalManager.shared.remove(agentID: agent.id)
                                    appState.selectedAgentID = agent.id
                                }
                                Divider()
                                Button(L10n.editSessionID) {
                                    editingSessionAgent = agent
                                }
                                Divider()
                                Button(L10n.deleteAgent, role: .destructive) {
                                    if let wsID = appState.selectedWorkspaceID {
                                        TerminalManager.shared.remove(agentID: agent.id)
                                        appState.removeAgent(id: agent.id, fromSnapshot: snapshot.id, inWorkspace: wsID)
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
                   let agent = snapshot.agents.first(where: { $0.id == agentID }) {
                    TerminalSwitcherView(
                        agentID: agent.id,
                        theme: settings.terminalTheme,
                        tool: agent.tool,
                        command: settings.command(for: agent.tool),
                        workingDirectory: agent.workingDirectory,
                        configPath: settings.configPath(for: agent.tool),
                        sessionID: agent.sessionID,
                        resumeArg: settings.resumeArg(for: agent.tool),
                        fontName: settings.terminalFontName,
                        fontSize: settings.terminalFontSize,
                        copyOnSelect: settings.terminalCopyOnSelect,
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
            .sheet(item: $editingSessionAgent) { agent in
                EditSessionIDSheet(agent: agent)
            }
            .onAppear {
                autoSelectAndWarmTerminals(snapshot: snapshot)
            }
            .onChange(of: appState.selectedSnapshotID) { _, _ in
                if let snapshot = appState.selectedSnapshot, !snapshot.agents.isEmpty {
                    autoSelectAndWarmTerminals(snapshot: snapshot)
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
                // Row 1: Name + session indicator + shortcut
                HStack(spacing: 4) {
                    Text(agent.taskDescription.isEmpty ? "Agent" : agent.taskDescription)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if let sessionID = agent.sessionID, !sessionID.isEmpty {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.green)
                            .help("已连接 Session ID: \(sessionID)")
                    }
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
                    .shadow(color: Color.accentColor.opacity(0.15), radius: 6, y: 2)
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
                .stroke(isSelected ? Color.accentColor.opacity(0.5) : Color(nsColor: .separatorColor).opacity(0.3), lineWidth: isSelected ? 1.5 : 0.5)
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

// MARK: - Edit Session ID Sheet

struct EditSessionIDSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let agent: Agent
    @State private var sessionID: String = ""

    var body: some View {
        VStack(spacing: 16) {
            Text(L10n.editSessionID)
                .font(.headline)

            TextField("Session ID", text: $sessionID)
                .textFieldStyle(.roundedBorder)
                .frame(width: 360)

            HStack {
                Button(L10n.cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(L10n.save) {
                    appState.bindSession(agentID: agent.id, sessionID: sessionID)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(sessionID == (agent.sessionID ?? ""))
            }
        }
        .padding(24)
        .frame(width: 420)
        .onAppear {
            sessionID = agent.sessionID ?? ""
        }
    }
}

// MARK: - Drag & Drop Delegate

struct AgentDropDelegate: DropDelegate {
    let targetAgentID: UUID
    let appState: AppState
    let snapshot: Snapshot
    @Binding var draggedAgentID: UUID?

    func performDrop(info: DropInfo) -> Bool {
        draggedAgentID = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggedID = draggedAgentID,
              draggedID != targetAgentID,
              let wsID = appState.selectedWorkspaceID,
              let fromIndex = snapshot.agents.firstIndex(where: { $0.id == draggedID }),
              let toIndex = snapshot.agents.firstIndex(where: { $0.id == targetAgentID }) else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            appState.moveAgent(fromIndex: fromIndex, toIndex: toIndex, inSnapshot: snapshot.id, inWorkspace: wsID)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func validateDrop(info: DropInfo) -> Bool {
        draggedAgentID != nil
    }
}
