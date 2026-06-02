import SwiftUI
import AppKit

/// 3D Mission Control style snapshot switcher (pure SwiftUI)
struct SnapshotSwitcher3DView: View {
    @Environment(AppState.self) private var appState
    @Binding var isPresented: Bool
    @State private var appeared = false
    @State private var selectedIndex: Int = 0
    @Binding var showCreateSnapshot: Bool
    @State private var snapshotToDelete: Snapshot?
    @State private var cachedImages: [UUID: NSImage] = [:]

    private var snapshots: [Snapshot] {
        appState.selectedWorkspace?.snapshots ?? []
    }

    var body: some View {
        ZStack {
            // Background
            Rectangle()
                .fill(Color(red: 0xD7/255.0, green: 0xD8/255.0, blue: 0xD7/255.0))
                .ignoresSafeArea()
                .onTapGesture(count: 1) {
                    dismiss()
                }

            // Main content
            HStack(spacing: 0) {
                // Left: 3D card stack
                GeometryReader { geo in
                    let cardWidth = geo.size.width * 0.85
                    let cardHeight = geo.size.height * 0.6

                    ZStack {
                        ForEach(Array(snapshots.enumerated()), id: \.element.id) { index, snapshot in
                            // Only render cards within ±3 of selection for performance
                            if abs(index - selectedIndex) <= 3 {
                                snapshotCardView(snapshot: snapshot, index: index, cardWidth: cardWidth, cardHeight: cardHeight, geoHeight: geo.size.height)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Right: Snapshot list panel
                VStack(alignment: .trailing, spacing: 8) {
                    Spacer()

                    ForEach(Array(snapshots.enumerated()), id: \.element.id) { index, snapshot in
                        SnapshotListItem(
                            snapshot: snapshot,
                            isSelected: index == selectedIndex
                        )
                        .onTapGesture(count: 2) {
                            // Double click: enter snapshot
                            appState.selectedSnapshotID = snapshot.id
                            dismiss()
                        }
                        .onTapGesture(count: 1) {
                            // Single click: select
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedIndex = index
                            }
                        }
                        .contextMenu {
                            Button(snapshot.isCompleted ? L10n.markIncomplete : L10n.markCompleted) {
                                if let wsID = appState.selectedWorkspaceID {
                                    appState.toggleSnapshotCompleted(id: snapshot.id, in: wsID)
                                }
                            }
                            Divider()
                            Button(L10n.deleteSnapshot, role: .destructive) {
                                snapshotToDelete = snapshot
                            }
                        }
                    }

                    // New snapshot button
                    Button {
                        dismiss()
                        showCreateSnapshot = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.caption)
                            Text(L10n.newSnapshot)
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(.trailing, 24)
                .frame(width: 180)
            }
        }
        .onAppear {
            if let currentID = appState.selectedSnapshotID,
               let idx = snapshots.firstIndex(where: { $0.id == currentID }) {
                selectedIndex = idx
            }
            cacheAllImages()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                appeared = true
            }
        }
        .onExitCommand {
            dismiss()
        }
        .background {
            // ScrollWheel in background — doesn't block clicks
            ScrollWheelCatcher { delta in
                let newIndex: Int
                if delta > 0 {
                    newIndex = max(0, selectedIndex - 1)
                } else {
                    newIndex = min(snapshots.count - 1, selectedIndex + 1)
                }
                if newIndex != selectedIndex {
                    withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
                        selectedIndex = newIndex
                    }
                }
            }
        }
        .sheet(item: $snapshotToDelete) { snapshot in
            if let wsID = appState.selectedWorkspaceID {
                DeleteSnapshotSheet(snapshot: snapshot, workspaceID: wsID)
            }
        }
    }

    @ViewBuilder
    private func snapshotCardView(snapshot: Snapshot, index: Int, cardWidth: CGFloat, cardHeight: CGFloat, geoHeight: CGFloat) -> some View {
        let isCurrentSelected = index == selectedIndex
        let yOffset = appeared ? cardOffset(index: index, total: snapshots.count, height: geoHeight) : 0.0
        let scale = isCurrentSelected ? 1.0 : (0.85 - CGFloat(abs(index - selectedIndex)) * 0.03)
        let cardOpacity = isCurrentSelected ? 1.0 : (0.85 - Double(abs(index - selectedIndex)) * 0.1)

        Snapshot3DCard(snapshot: snapshot, snapshotImage: snapshotForSnapshot(snapshot), isSelected: isCurrentSelected)
            .frame(width: cardWidth, height: cardHeight)
            .drawingGroup()
            .rotation3DEffect(.degrees(appeared ? 45 : 0), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
            .offset(x: 0, y: yOffset)
            .scaleEffect(scale)
            .opacity(max(0.25, cardOpacity))
            .zIndex(Double(snapshots.count - abs(index - selectedIndex)))
            .shadow(color: .black.opacity(isCurrentSelected ? 0.2 : 0), radius: isCurrentSelected ? 20 : 0, y: 10)
            .onTapGesture(count: 2) {
                // Double click: enter snapshot
                appState.selectedSnapshotID = snapshot.id
                dismiss()
            }
            .onTapGesture(count: 1) {
                // Single click: select
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedIndex = index
                }
            }
            .animation(.interpolatingSpring(stiffness: 300, damping: 25), value: selectedIndex)
    }

    private func dismiss() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            appeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            isPresented = false
        }
    }

    private func cardOffset(index: Int, total: Int, height: CGFloat) -> CGFloat {
        let spacing: CGFloat = 120
        let centerIndex = CGFloat(selectedIndex)
        let diff = CGFloat(index) - centerIndex
        return diff * spacing
    }

    private func snapshotForSnapshot(_ snapshot: Snapshot) -> NSImage? {
        return cachedImages[snapshot.id]
    }

    private func cacheAllImages() {
        var images: [UUID: NSImage] = [:]
        for snapshot in snapshots {
            if let agent = snapshot.agents.first,
               let img = TerminalManager.shared.snapshot(for: agent.id) {
                images[snapshot.id] = img
            }
        }
        cachedImages = images
    }
}

/// Individual 3D snapshot card - glass transparent style
struct Snapshot3DCard: View {
    let snapshot: Snapshot
    let snapshotImage: NSImage?
    let isSelected: Bool

    var body: some View {
        ZStack {
            // Background - highly transparent glass
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.4))

            // Terminal screenshot or placeholder
            if let snapshotImage {
                Image(nsImage: snapshotImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .opacity(0.75)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                // Placeholder
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor).opacity(0.3))
                VStack(spacing: 8) {
                    Image(systemName: "terminal")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(.tertiary)
                    Text(snapshot.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            // Top highlight reflection
            VStack {
                LinearGradient(
                    colors: [.white.opacity(0.12), .clear],
                    startPoint: .top,
                    endPoint: .center
                )
                .frame(height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                Spacer()
            }

            // Snapshot info at bottom - minimal
            VStack {
                Spacer()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(snapshot.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.system(size: 9))
                            Text(snapshot.branch)
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !snapshot.agents.isEmpty {
                        Text("\(snapshot.agents.count) agents")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.thinMaterial, in: Capsule())
                    }
                }
                .padding(12)
                .background(.thinMaterial)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            // Border: glass edge
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(isSelected ? 0.5 : 0.2),
                            .white.opacity(isSelected ? 0.15 : 0.05)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: isSelected ? 1.5 : 0.5
                )

            // Completed stamp
            if snapshot.isCompleted {
                VStack {
                    HStack {
                        Spacer()
                        CompletedStamp()
                            .padding(.top, 12)
                            .padding(.trailing, 12)
                    }
                    Spacer()
                }
            }
        }
    }
}

/// Snapshot list item in the right panel
struct SnapshotListItem: View {
    let snapshot: Snapshot
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(snapshot.aggregatedStatus.color)
                .frame(width: 6, height: 6)

            VStack(alignment: .leading, spacing: 1) {
                Text(snapshot.name)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                Text(snapshot.branch)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.blue.opacity(0.1))
            }
        }
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            }
        }
    }
}

// MARK: - Scroll Wheel Handler

/// NSViewRepresentable that captures scroll wheel events without blocking clicks
struct ScrollWheelCatcher: NSViewRepresentable {
    let onScroll: (CGFloat) -> Void

    func makeNSView(context: Context) -> ScrollWheelNSView {
        let view = ScrollWheelNSView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: ScrollWheelNSView, context: Context) {
        nsView.onScroll = onScroll
    }
}

class ScrollWheelNSView: NSView {
    var onScroll: ((CGFloat) -> Void)?
    private var accumulatedDelta: CGFloat = 0
    private let threshold: CGFloat = 8

    override func scrollWheel(with event: NSEvent) {
        let delta = event.scrollingDeltaY
        accumulatedDelta += delta

        if abs(accumulatedDelta) >= threshold {
            let direction = accumulatedDelta
            accumulatedDelta = 0
            onScroll?(direction)
        }
    }

    // Don't intercept mouse clicks — only scroll events
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Register for scroll events via NSEvent monitor
        NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.scrollWheel(with: event)
            return event
        }
    }
}
