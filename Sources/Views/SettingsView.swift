import SwiftUI

// MARK: - Settings Tab

private enum SettingsTab: String, CaseIterable {
    case general
    case tools
    case shortcuts

    var label: String {
        switch self {
        case .general: return L10n.settingsGeneral
        case .tools: return L10n.settingsTools
        case .shortcuts: return L10n.settingsShortcuts
        }
    }

    var icon: String {
        switch self {
        case .general: return "gear"
        case .tools: return "terminal"
        case .shortcuts: return "keyboard"
        }
    }
}

// MARK: - Main Settings View

struct SettingsView: View {
    @Environment(Settings.self) private var settings
    @State private var selectedTab: SettingsTab = .general

    // General
    @State private var selectedLanguage: AppLanguage = .zhHans
    @State private var selectedTheme: TerminalTheme = .kittyLowContrast
    @State private var selectedFontName: String = "Menlo"
    @State private var selectedFontSize: CGFloat = 20
    @State private var selectedCopyOnSelect: Bool = false

    // Tool configs
    @State private var claudeCommand = ""
    @State private var claudeConfigPath = ""
    @State private var claudeResumeArg = ""
    @State private var codeBuddyCommand = ""
    @State private var codeBuddyConfigPath = ""
    @State private var codeBuddyResumeArg = ""
    @State private var codexCommand = ""
    @State private var codexConfigPath = ""
    @State private var codexResumeArg = ""
    @State private var geminiCommand = ""
    @State private var geminiConfigPath = ""
    @State private var geminiResumeArg = ""
    @State private var otherCommand = ""
    @State private var otherConfigPath = ""
    @State private var otherResumeArg = ""

    // Shortcuts
    @State private var editedBindings: [ShortcutAction: KeyBinding] = ShortcutAction.defaults
    @State private var recordingAction: ShortcutAction? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            tabBar
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider()

            // Content
            ScrollView {
                VStack(spacing: 20) {
                    switch selectedTab {
                    case .general:
                        generalContent
                    case .tools:
                        toolsContent
                    case .shortcuts:
                        shortcutsContent
                    }
                }
                .padding(24)
            }

            Divider()

            // Bottom save button
            HStack {
                Spacer()
                Button(L10n.save) {
                    saveAll()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .frame(width: 500, height: 540)
        .onAppear { loadAll() }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 24) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 18))
                        Text(tab.label)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(selectedTab == tab ? Color.accentColor : .secondary)
                    .frame(width: 54, height: 44)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - General Tab

    private var generalContent: some View {
        VStack(spacing: 20) {
            SettingsSection(title: L10n.settingsLanguageSection) {
                SettingsRow(label: L10n.settingsLanguageSection) {
                    Picker("", selection: $selectedLanguage) {
                        ForEach(AppLanguage.allCases, id: \.self) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 140)
                }
            }

            SettingsSection(title: L10n.terminalTheme) {
                SettingsRow(label: L10n.terminalTheme) {
                    Picker("", selection: $selectedTheme) {
                        ForEach(TerminalTheme.allCases, id: \.self) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 140)
                }
                Divider().padding(.leading, 14)
                // Theme preview
                themePreview
                    .padding(14)
            }

            SettingsSection(title: L10n.terminalFont) {
                SettingsRow(label: L10n.fontFamily) {
                    Picker("", selection: $selectedFontName) {
                        Text(L10n.systemDefault).tag("")
                        ForEach(availableMonoFonts, id: \.self) { font in
                            Text(font).tag(font)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 180)
                }
                Divider().padding(.leading, 14)
                SettingsRow(label: L10n.fontSize) {
                    HStack(spacing: 8) {
                        Button {
                            if selectedFontSize > 8 { selectedFontSize -= 1 }
                        } label: {
                            Image(systemName: "minus")
                        }
                        .buttonStyle(.borderless)

                        Text("\(Int(selectedFontSize)) pt")
                            .font(.system(size: 13, design: .monospaced))
                            .frame(width: 50)

                        Button {
                            if selectedFontSize < 32 { selectedFontSize += 1 }
                        } label: {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                Divider().padding(.leading, 14)
                SettingsRow(label: L10n.copyOnSelect) {
                    Toggle("", isOn: $selectedCopyOnSelect)
                        .toggleStyle(.switch)
                }
                Divider().padding(.leading, 14)
                // Font preview
                fontPreview
                    .padding(14)
            }
        }
    }

    /// List of available monospace fonts on the system
    private var availableMonoFonts: [String] {
        let monoFamilies = NSFontManager.shared.availableFontFamilies.filter { family in
            if let font = NSFont(name: family, size: 13) {
                return font.isFixedPitch
            }
            return false
        }
        return monoFamilies.sorted()
    }

    private var fontPreview: some View {
        let font: NSFont = {
            if selectedFontName.isEmpty {
                return NSFont.monospacedSystemFont(ofSize: selectedFontSize, weight: .regular)
            } else {
                return NSFont(name: selectedFontName, size: selectedFontSize)
                    ?? NSFont.monospacedSystemFont(ofSize: selectedFontSize, weight: .regular)
            }
        }()
        let colors = selectedTheme.colors
        return Text("ABCabc 0123 → λ fn() { }")
            .font(Font(font))
            .foregroundColor(Color(nsColor: colors.foreground))
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: colors.background))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 0.5)
            )
    }

    // MARK: - Theme Preview

    private var themePreview: some View {
        let colors = selectedTheme.colors
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 0) {
                Text("~/project")
                    .foregroundColor(Color(nsColor: colors.ansiColors[4])) // blue
                Text(" $ ")
                    .foregroundColor(Color(nsColor: colors.foreground))
                Text("claude")
                    .foregroundColor(Color(nsColor: colors.ansiColors[2])) // green
                Text(" --resume abc123")
                    .foregroundColor(Color(nsColor: colors.foreground))
            }
            HStack(spacing: 0) {
                Text("●")
                    .foregroundColor(Color(nsColor: colors.ansiColors[2])) // green
                Text(" Agent running...")
                    .foregroundColor(Color(nsColor: colors.foreground))
            }
            HStack(spacing: 0) {
                Text("Error:")
                    .foregroundColor(Color(nsColor: colors.ansiColors[1])) // red
                Text(" file not found")
                    .foregroundColor(Color(nsColor: colors.foreground))
            }
            HStack(spacing: 0) {
                Text("// TODO: ")
                    .foregroundColor(Color(nsColor: colors.ansiColors[3])) // yellow
                Text("implement feature")
                    .foregroundColor(Color(nsColor: colors.ansiColors[6])) // cyan
            }
        }
        .font(.system(size: 12, design: .monospaced))
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: colors.background))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 0.5)
        )
        .animation(.easeInOut(duration: 0.2), value: selectedTheme)
    }

    // MARK: - Tools Tab

    private var toolsContent: some View {
        VStack(spacing: 20) {
            ToolSection(title: "Claude Code", command: $claudeCommand, configPath: $claudeConfigPath, resumeArg: $claudeResumeArg, commandPlaceholder: "claude", configPlaceholder: "~/.claude", resumePlaceholder: "--resume")

            ToolSection(title: "CodeBuddy", command: $codeBuddyCommand, configPath: $codeBuddyConfigPath, resumeArg: $codeBuddyResumeArg, commandPlaceholder: "codebuddy", configPlaceholder: "~/.codebuddy", resumePlaceholder: "--resume=")

            ToolSection(title: "Codex", command: $codexCommand, configPath: $codexConfigPath, resumeArg: $codexResumeArg, commandPlaceholder: "codex", configPlaceholder: "", resumePlaceholder: "resume")

            ToolSection(title: "Gemini", command: $geminiCommand, configPath: $geminiConfigPath, resumeArg: $geminiResumeArg, commandPlaceholder: "gemini", configPlaceholder: "", resumePlaceholder: "")

            ToolSection(title: "Other", command: $otherCommand, configPath: $otherConfigPath, resumeArg: $otherResumeArg, commandPlaceholder: "shell", configPlaceholder: "", resumePlaceholder: "")
        }
    }

    // MARK: - Shortcuts Tab

    private var shortcutsContent: some View {
        VStack(spacing: 20) {
            SettingsSection(title: L10n.settingsShortcuts) {
                ForEach(ShortcutAction.allCases, id: \.self) { action in
                    if action != ShortcutAction.allCases.first {
                        Divider().padding(.leading, 14)
                    }
                    ShortcutRow(
                        action: action,
                        binding: editedBindings[action] ?? ShortcutAction.defaults[action]!,
                        isRecording: recordingAction == action,
                        onStartRecording: { recordingAction = action },
                        onBindingRecorded: { newBinding in
                            editedBindings[action] = newBinding
                            recordingAction = nil
                        },
                        onCancelRecording: { recordingAction = nil }
                    )
                }
            }

            HStack {
                Button(L10n.resetToDefault) {
                    editedBindings = ShortcutAction.defaults
                }
                .buttonStyle(.borderless)
                Spacer()
            }
        }
    }

    // MARK: - Data

    private func loadAll() {
        selectedLanguage = settings.language
        selectedTheme = settings.terminalTheme
        selectedFontName = settings.terminalFontName
        selectedFontSize = settings.terminalFontSize
        selectedCopyOnSelect = settings.terminalCopyOnSelect
        claudeCommand = settings.toolConfigs[.claudeCode]?.command ?? ""
        claudeConfigPath = settings.toolConfigs[.claudeCode]?.configPath ?? ""
        claudeResumeArg = settings.toolConfigs[.claudeCode]?.resumeArg ?? ""
        codeBuddyCommand = settings.toolConfigs[.codeBuddy]?.command ?? ""
        codeBuddyConfigPath = settings.toolConfigs[.codeBuddy]?.configPath ?? ""
        codeBuddyResumeArg = settings.toolConfigs[.codeBuddy]?.resumeArg ?? ""
        codexCommand = settings.toolConfigs[.codex]?.command ?? ""
        codexConfigPath = settings.toolConfigs[.codex]?.configPath ?? ""
        codexResumeArg = settings.toolConfigs[.codex]?.resumeArg ?? ""
        geminiCommand = settings.toolConfigs[.gemini]?.command ?? ""
        geminiConfigPath = settings.toolConfigs[.gemini]?.configPath ?? ""
        geminiResumeArg = settings.toolConfigs[.gemini]?.resumeArg ?? ""
        otherCommand = settings.toolConfigs[.other]?.command ?? ""
        otherConfigPath = settings.toolConfigs[.other]?.configPath ?? ""
        otherResumeArg = settings.toolConfigs[.other]?.resumeArg ?? ""
        editedBindings = settings.keyBindings
    }

    private func saveAll() {
        settings.language = selectedLanguage
        settings.terminalTheme = selectedTheme
        settings.terminalFontName = selectedFontName
        settings.terminalFontSize = selectedFontSize
        settings.terminalCopyOnSelect = selectedCopyOnSelect
        settings.toolConfigs[.claudeCode] = ToolConfig(command: claudeCommand, configPath: claudeConfigPath, resumeArg: claudeResumeArg)
        settings.toolConfigs[.codeBuddy] = ToolConfig(command: codeBuddyCommand, configPath: codeBuddyConfigPath, resumeArg: codeBuddyResumeArg)
        settings.toolConfigs[.codex] = ToolConfig(command: codexCommand, configPath: codexConfigPath, resumeArg: codexResumeArg)
        settings.toolConfigs[.gemini] = ToolConfig(command: geminiCommand, configPath: geminiConfigPath, resumeArg: geminiResumeArg)
        settings.toolConfigs[.other] = ToolConfig(command: otherCommand, configPath: otherConfigPath, resumeArg: otherResumeArg)
        settings.keyBindings = editedBindings
        settings.save()
        // Apply font to all running terminals
        TerminalManager.shared.setFont(name: selectedFontName, size: selectedFontSize)
        // Apply copy-on-select to all running terminals
        TerminalManager.shared.setCopyOnSelect(selectedCopyOnSelect)
    }
}

// MARK: - Shortcut Row

private struct ShortcutRow: View {
    let action: ShortcutAction
    let binding: KeyBinding
    let isRecording: Bool
    let onStartRecording: () -> Void
    let onBindingRecorded: (KeyBinding) -> Void
    let onCancelRecording: () -> Void

    var body: some View {
        HStack {
            Text(action.displayName)
                .font(.system(size: 13))
            Spacer()
            if isRecording {
                ShortcutRecorderView(onRecorded: onBindingRecorded, onCancel: onCancelRecording)
            } else {
                Button {
                    onStartRecording()
                } label: {
                    Text(binding.displayString)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Shortcut Recorder

private struct ShortcutRecorderView: NSViewRepresentable {
    let onRecorded: (KeyBinding) -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> ShortcutRecorderNSView {
        let view = ShortcutRecorderNSView(onRecorded: onRecorded, onCancel: onCancel)
        // Make it first responder on next run loop to ensure it's in the view hierarchy
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: ShortcutRecorderNSView, context: Context) {}
}

private class ShortcutRecorderNSView: NSView {
    let onRecorded: (KeyBinding) -> Void
    let onCancel: () -> Void
    private var monitor: Any?

    init(onRecorded: @escaping (KeyBinding) -> Void, onCancel: @escaping () -> Void) {
        self.onRecorded = onRecorded
        self.onCancel = onCancel
        super.init(frame: NSRect(x: 0, y: 0, width: 120, height: 24))
        wantsLayer = true
        layer?.cornerRadius = 4
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.controlAccentColor.cgColor

        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKey(event)
            return nil
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit {
        if let m = monitor { NSEvent.removeMonitor(m) }
    }

    override var intrinsicContentSize: NSSize { NSSize(width: 120, height: 24) }

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let str = L10n.pressShortcut
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let size = (str as NSString).size(withAttributes: attrs)
        let point = NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2)
        (str as NSString).draw(at: point, withAttributes: attrs)
    }

    private func handleKey(_ event: NSEvent) {
        // Escape cancels
        if event.keyCode == 53 {
            onCancel()
            return
        }

        let eventMods = event.modifierFlags.intersection([.command, .shift, .option, .control])
        // Require at least one modifier
        guard !eventMods.isEmpty else { return }

        var modifiers: Set<KeyBinding.KeyModifier> = []
        if eventMods.contains(.command) { modifiers.insert(.command) }
        if eventMods.contains(.shift) { modifiers.insert(.shift) }
        if eventMods.contains(.option) { modifiers.insert(.option) }
        if eventMods.contains(.control) { modifiers.insert(.control) }

        let key: String
        switch event.keyCode {
        case 126: key = "↑"
        case 125: key = "↓"
        case 123: key = "←"
        case 124: key = "→"
        case 36: key = "↩"
        default:
            key = event.charactersIgnoringModifiers?.lowercased() ?? ""
        }

        guard !key.isEmpty else { return }

        let binding = KeyBinding(key: key, modifiers: modifiers)
        onRecorded(binding)
    }
}

// MARK: - Reusable Components

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(spacing: 0) {
                content
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
            )
        }
    }
}

private struct SettingsRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
            Spacer()
            content
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

private struct ToolSection: View {
    let title: String
    @Binding var command: String
    @Binding var configPath: String
    @Binding var resumeArg: String
    var commandPlaceholder: String = ""
    var configPlaceholder: String = ""
    var resumePlaceholder: String = ""

    var body: some View {
        SettingsSection(title: title) {
            SettingsRow(label: L10n.command) {
                TextField("", text: $command, prompt: Text(commandPlaceholder))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
            }
            Divider().padding(.leading, 14)
            SettingsRow(label: L10n.configPath) {
                TextField("", text: $configPath, prompt: Text(configPlaceholder))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
            }
            Divider().padding(.leading, 14)
            SettingsRow(label: L10n.resumeArg) {
                TextField("", text: $resumeArg, prompt: Text(resumePlaceholder))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
            }
        }
    }
}
