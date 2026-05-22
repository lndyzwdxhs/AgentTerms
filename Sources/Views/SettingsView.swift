import SwiftUI

// MARK: - Settings Tab

private enum SettingsTab: String, CaseIterable {
    case general
    case tools

    var label: String {
        switch self {
        case .general: return L10n.settingsGeneral
        case .tools: return L10n.settingsTools
        }
    }

    var icon: String {
        switch self {
        case .general: return "gear"
        case .tools: return "terminal"
        }
    }
}

// MARK: - Main Settings View

struct SettingsView: View {
    @Environment(Settings.self) private var settings
    @State private var selectedTab: SettingsTab = .general

    // General
    @State private var selectedLanguage: AppLanguage = .zhHans
    @State private var selectedTheme: TerminalTheme = .dracula

    // Tool configs
    @State private var claudeCommand = ""
    @State private var claudeConfigPath = ""
    @State private var claudeResumeArg = ""
    @State private var codexCommand = ""
    @State private var codexConfigPath = ""
    @State private var codexResumeArg = ""
    @State private var geminiCommand = ""
    @State private var geminiConfigPath = ""
    @State private var geminiResumeArg = ""
    @State private var otherCommand = ""
    @State private var otherConfigPath = ""
    @State private var otherResumeArg = ""

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
        .frame(width: 500, height: 480)
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
        }
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

            ToolSection(title: "Codex", command: $codexCommand, configPath: $codexConfigPath, resumeArg: $codexResumeArg, commandPlaceholder: "codex", configPlaceholder: "", resumePlaceholder: "resume")

            ToolSection(title: "Gemini", command: $geminiCommand, configPath: $geminiConfigPath, resumeArg: $geminiResumeArg, commandPlaceholder: "gemini", configPlaceholder: "", resumePlaceholder: "")

            ToolSection(title: "Other", command: $otherCommand, configPath: $otherConfigPath, resumeArg: $otherResumeArg, commandPlaceholder: "shell", configPlaceholder: "", resumePlaceholder: "")
        }
    }

    // MARK: - Data

    private func loadAll() {
        selectedLanguage = settings.language
        selectedTheme = settings.terminalTheme
        claudeCommand = settings.toolConfigs[.claudeCode]?.command ?? ""
        claudeConfigPath = settings.toolConfigs[.claudeCode]?.configPath ?? ""
        claudeResumeArg = settings.toolConfigs[.claudeCode]?.resumeArg ?? ""
        codexCommand = settings.toolConfigs[.codex]?.command ?? ""
        codexConfigPath = settings.toolConfigs[.codex]?.configPath ?? ""
        codexResumeArg = settings.toolConfigs[.codex]?.resumeArg ?? ""
        geminiCommand = settings.toolConfigs[.gemini]?.command ?? ""
        geminiConfigPath = settings.toolConfigs[.gemini]?.configPath ?? ""
        geminiResumeArg = settings.toolConfigs[.gemini]?.resumeArg ?? ""
        otherCommand = settings.toolConfigs[.other]?.command ?? ""
        otherConfigPath = settings.toolConfigs[.other]?.configPath ?? ""
        otherResumeArg = settings.toolConfigs[.other]?.resumeArg ?? ""
    }

    private func saveAll() {
        settings.language = selectedLanguage
        settings.terminalTheme = selectedTheme
        settings.toolConfigs[.claudeCode] = ToolConfig(command: claudeCommand, configPath: claudeConfigPath, resumeArg: claudeResumeArg)
        settings.toolConfigs[.codex] = ToolConfig(command: codexCommand, configPath: codexConfigPath, resumeArg: codexResumeArg)
        settings.toolConfigs[.gemini] = ToolConfig(command: geminiCommand, configPath: geminiConfigPath, resumeArg: geminiResumeArg)
        settings.toolConfigs[.other] = ToolConfig(command: otherCommand, configPath: otherConfigPath, resumeArg: otherResumeArg)
        settings.save()
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
