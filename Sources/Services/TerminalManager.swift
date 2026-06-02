import Foundation
import SwiftTerm
import AppKit

/// Caches terminal views so they persist when navigating away and back
final class TerminalManager {
    static let shared = TerminalManager()

    private var terminals: [UUID: CopyOnSelectTerminalView] = [:]
    private var sessionDetectionTimers: [UUID: Timer] = [:]

    private init() {}

    /// Get or create a terminal view for an agent
    func terminal(
        for agentID: UUID,
        theme: TerminalTheme,
        tool: AgentTool,
        command: String,
        workingDirectory: String,
        configPath: String,
        sessionID: String?,
        resumeArg: String,
        copyOnSelect: Bool,
        appState: AppState,
        onProcessExit: @escaping () -> Void
    ) -> CopyOnSelectTerminalView {
        // Return cached terminal if exists
        if let existing = terminals[agentID] {
            return existing
        }

        // Create new terminal
        let terminalView = CopyOnSelectTerminalView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        terminalView.optionAsMetaKey = true
        terminalView.copyOnSelectEnabled = copyOnSelect

        // Apply theme
        applyTheme(theme, to: terminalView)

        // Build environment
        var env = Terminal.getEnvironmentVariables(termName: "xterm-256color")
        if !configPath.isEmpty {
            let expandedPath = (configPath as NSString).expandingTildeInPath
            env.append("CLAUDE_CONFIG_DIR=\(expandedPath)")
            env.append("XDG_CONFIG_HOME=\(expandedPath)")
        }

        // Start interactive shell
        let defaultShell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        terminalView.startProcess(
            executable: defaultShell,
            args: ["-l"],
            environment: env,
            execName: (defaultShell as NSString).lastPathComponent,
            currentDirectory: workingDirectory.isEmpty ? nil : workingDirectory
        )

        // Determine the actual command to send
        if !command.isEmpty {
            let effectiveCommand: String
            if let sid = sessionID, !sid.isEmpty, !resumeArg.isEmpty {
                // Resume mode: append resume arg with session ID
                // Support both "--resume ID" and "--resume=ID" formats
                if resumeArg.hasSuffix("=") {
                    effectiveCommand = "\(command) \(resumeArg)\(sid)"
                } else {
                    effectiveCommand = "\(command) \(resumeArg) \(sid)"
                }
            } else {
                // First launch: normal command, then detect session
                effectiveCommand = command
                startSessionDetection(
                    agentID: agentID,
                    tool: tool,
                    workingDirectory: workingDirectory,
                    configPath: configPath,
                    appState: appState
                )
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                terminalView.send(txt: effectiveCommand + "\n")
            }
        }

        // Store coordinator for process exit callback
        let coordinator = TerminalCoordinator(onProcessExit: onProcessExit)
        terminalView.processDelegate = coordinator
        objc_setAssociatedObject(terminalView, &coordinatorKey, coordinator, .OBJC_ASSOCIATION_RETAIN)

        terminals[agentID] = terminalView
        return terminalView
    }

    /// Remove cached terminal (when agent is deleted)
    func remove(agentID: UUID) {
        terminals.removeValue(forKey: agentID)
        sessionDetectionTimers[agentID]?.invalidate()
        sessionDetectionTimers.removeValue(forKey: agentID)
    }

    /// Update font size for all cached terminals
    func setFontSize(_ size: CGFloat) {
        let font = NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        for terminal in terminals.values {
            terminal.font = font
        }
    }

    /// Update font name and size for all cached terminals
    func setFont(name: String, size: CGFloat) {
        let font: NSFont
        if name.isEmpty {
            font = NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        } else {
            font = NSFont(name: name, size: size)
                ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        }
        for terminal in terminals.values {
            terminal.font = font
        }
    }

    /// Update copy-on-select for all cached terminals
    func setCopyOnSelect(_ enabled: Bool) {
        for terminal in terminals.values {
            terminal.copyOnSelectEnabled = enabled
        }
    }

    /// Check if a terminal exists for an agent
    func hasTerminal(for agentID: UUID) -> Bool {
        terminals[agentID] != nil
    }

    /// Capture a snapshot of the terminal view as NSImage
    func snapshot(for agentID: UUID) -> NSImage? {
        guard let view = terminals[agentID] else { return nil }
        let bounds = view.bounds
        guard bounds.width > 0, bounds.height > 0 else { return nil }

        guard let rep = view.bitmapImageRepForCachingDisplay(in: bounds) else { return nil }
        view.cacheDisplay(in: bounds, to: rep)

        let image = NSImage(size: bounds.size)
        image.addRepresentation(rep)
        return image
    }

    // MARK: - Session Detection

    /// After first launch, poll for new JSONL file to discover the session ID
    private func startSessionDetection(
        agentID: UUID,
        tool: AgentTool,
        workingDirectory: String,
        configPath: String,
        appState: AppState
    ) {
        // Compute the expected project directory path
        let base: String
        if !configPath.isEmpty {
            base = (configPath as NSString).expandingTildeInPath
        } else {
            // Default base path depends on tool type
            switch tool {
            case .codeBuddy:
                base = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codebuddy").path
            default:
                base = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude").path
            }
        }
        // Use appropriate encoding based on tool type
        let encodedDir: String
        if tool == .codeBuddy || base.contains(".codebuddy") {
            encodedDir = StatusMonitor.encodeCodeBuddyProjectDirName(workingDirectory: workingDirectory)
        } else {
            encodedDir = StatusMonitor.encodeProjectDirName(workingDirectory: workingDirectory)
        }
        let projectDir = URL(fileURLWithPath: base)
            .appendingPathComponent("projects")
            .appendingPathComponent(encodedDir)

        // Record existing files (may be empty if dir doesn't exist yet)
        let existingFiles = Set(jsonlFiles(in: projectDir))
        print("[AgentTerms] Session detection started for agent \(agentID). Dir: \(projectDir.path), existing: \(existingFiles.count)")

        var attempts = 0
        // No timeout — keep polling until session is detected or terminal is removed
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            attempts += 1

            let currentFiles = Set(self?.jsonlFiles(in: projectDir) ?? [])
            let newFiles = currentFiles.subtracting(existingFiles)

            if let newFile = newFiles.first {
                // Found new session file — extract session ID from filename
                let sessionID = (newFile as NSString).deletingPathExtension
                let projPath = projectDir.path
                print("[AgentTerms] Session detected: \(sessionID) for agent \(agentID)")
                DispatchQueue.main.async {
                    appState.bindSession(agentID: agentID, sessionID: sessionID, projectPath: projPath)
                }
                timer.invalidate()
                self?.sessionDetectionTimers.removeValue(forKey: agentID)
            }
        }

        sessionDetectionTimers[agentID] = timer
    }

    /// Get list of JSONL filenames in a directory
    private func jsonlFiles(in dir: URL) -> [String] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: dir.path) else { return [] }
        return files.filter { $0.hasSuffix(".jsonl") }
    }

    // MARK: - Theme

    private func applyTheme(_ theme: TerminalTheme, to view: LocalProcessTerminalView) {
        let colors = theme.colors
        view.nativeForegroundColor = colors.foreground
        view.nativeBackgroundColor = colors.background
        view.caretColor = colors.cursor
        view.selectedTextBackgroundColor = colors.selection

        let ansiColors: [SwiftTerm.Color] = colors.ansiColors.map { nsColor in
            let c = nsColor.usingColorSpace(.sRGB) ?? nsColor
            let r = UInt16(c.redComponent * 65535)
            let g = UInt16(c.greenComponent * 65535)
            let b = UInt16(c.blueComponent * 65535)
            return SwiftTerm.Color(red: r, green: g, blue: b)
        }
        view.installColors(ansiColors)
    }
}

private var coordinatorKey: UInt8 = 0

class TerminalCoordinator: NSObject, LocalProcessTerminalViewDelegate {
    let onProcessExit: () -> Void

    init(onProcessExit: @escaping () -> Void) {
        self.onProcessExit = onProcessExit
    }

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        DispatchQueue.main.async { [weak self] in
            self?.onProcessExit()
        }
    }

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
}
