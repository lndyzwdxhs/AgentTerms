import SwiftUI

struct SettingsView: View {
    @Environment(Settings.self) private var settings
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

    @State private var selectedLanguage: AppLanguage = .zhHans

    var body: some View {
        Form {
            Section("Language / 语言") {
                Picker("", selection: $selectedLanguage) {
                    ForEach(AppLanguage.allCases, id: \.self) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Section("Claude Code") {
                TextField(L10n.command, text: $claudeCommand, prompt: Text("claude"))
                    .textFieldStyle(.roundedBorder)
                TextField(L10n.configPath, text: $claudeConfigPath, prompt: Text("~/.claude"))
                    .textFieldStyle(.roundedBorder)
                TextField(L10n.resumeArg, text: $claudeResumeArg, prompt: Text("--resume"))
                    .textFieldStyle(.roundedBorder)
            }

            Section("Codex") {
                TextField(L10n.command, text: $codexCommand, prompt: Text("codex"))
                    .textFieldStyle(.roundedBorder)
                TextField(L10n.configPath, text: $codexConfigPath, prompt: Text(""))
                    .textFieldStyle(.roundedBorder)
                TextField(L10n.resumeArg, text: $codexResumeArg, prompt: Text("resume"))
                    .textFieldStyle(.roundedBorder)
            }

            Section("Gemini") {
                TextField(L10n.command, text: $geminiCommand, prompt: Text("gemini"))
                    .textFieldStyle(.roundedBorder)
                TextField(L10n.configPath, text: $geminiConfigPath, prompt: Text(""))
                    .textFieldStyle(.roundedBorder)
                TextField(L10n.resumeArg, text: $geminiResumeArg, prompt: Text(""))
                    .textFieldStyle(.roundedBorder)
            }

            Section("Other") {
                TextField(L10n.command, text: $otherCommand, prompt: Text("shell"))
                    .textFieldStyle(.roundedBorder)
                TextField(L10n.configPath, text: $otherConfigPath, prompt: Text(""))
                    .textFieldStyle(.roundedBorder)
                TextField(L10n.resumeArg, text: $otherResumeArg, prompt: Text(""))
                    .textFieldStyle(.roundedBorder)
            }

            Section {
                Button(L10n.save) {
                    saveAll()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 520)
        .padding()
        .navigationTitle(L10n.settings)
        .onAppear {
            loadAll()
        }
    }

    private func loadAll() {
        selectedLanguage = settings.language
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
        settings.toolConfigs[.claudeCode] = ToolConfig(command: claudeCommand, configPath: claudeConfigPath, resumeArg: claudeResumeArg)
        settings.toolConfigs[.codex] = ToolConfig(command: codexCommand, configPath: codexConfigPath, resumeArg: codexResumeArg)
        settings.toolConfigs[.gemini] = ToolConfig(command: geminiCommand, configPath: geminiConfigPath, resumeArg: geminiResumeArg)
        settings.toolConfigs[.other] = ToolConfig(command: otherCommand, configPath: otherConfigPath, resumeArg: otherResumeArg)
        settings.save()
    }
}
