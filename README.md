# AgentTerms

A macOS native command center for managing multiple concurrent AI coding agents (Claude Code, Codex, Gemini, etc.) — built entirely with AI.

## Why AgentTerms?

In the AI coding era, developers run multiple AI agents simultaneously across different projects and branches. AgentTerms solves the pain of:

- **Lost context** — Can't tell which terminal is doing what
- **Missed prompts** — AI needs your input but you don't notice
- **Terminal chaos** — Switching between 5+ terminals constantly

## Features

- **Multi-workspace management** — Organize by Git repository
- **Floor system** — Each floor maps to a Git worktree/branch, fully isolated
- **Real-time status detection** — Monitors AI agent state via session files (running/needs input/idle)
- **Session persistence** — Resume conversations with `--resume` support
- **3D Floor Switcher** — Mission Control-style 3D view to switch between floors
- **Terminal embedding** — Full interactive terminal with SwiftTerm
- **Keyboard shortcuts** — `⌘1-9` to switch agents instantly
- **System notifications** — Get notified when an agent needs your attention
- **Multi-language** — Chinese (default) and English

## Status Detection

AgentTerms passively reads AI tool session files to detect agent state:

| Status | Meaning | Trigger |
|--------|---------|---------|
| 🏃 Running | Agent is thinking/outputting | Session file being written |
| 🙋 Hand Up | Agent is blocked, needs user action | `AskUserQuestion` tool_use detected |
| 😴 Idle | Agent finished, waiting for next instruction | Session file stale > 5s |

## Requirements

- macOS 14.0+
- Swift 5.9+
- Command Line Tools for Xcode

## Build & Run

```bash
# Build
make build

# Run (opens .app bundle)
make run

# Clean build
make clean
```

Or manually:

```bash
swift build
# Copy binary to .app bundle and open
```

## Configuration

Settings are stored in `~/.agentterms/`:

- `config.json` — Workspaces, floors, agents, session bindings
- `settings.json` — Tool commands, config paths, resume args, language

### Tool Configuration

| Tool | Command | Config Path | Resume Arg |
|------|---------|-------------|------------|
| Claude Code | `claude` | `~/.claude` | `--resume` |
| Codex | `codex` | | `resume` |
| Gemini | `gemini` | | |

## Architecture

```
Sources/
├── MastApp.swift              # App entry point
├── Models/
│   ├── Agent.swift            # Agent model + status enum
│   ├── AppState.swift         # Observable app state
│   ├── Floor.swift            # Floor (git worktree)
│   ├── Settings.swift         # Global tool configs
│   └── Workspace.swift        # Workspace (git repo)
├── Services/
│   ├── GitService.swift       # Git worktree operations
│   ├── NotificationService.swift  # macOS notifications
│   ├── PersistenceService.swift   # JSON persistence
│   ├── StatusMonitor.swift    # Session file polling
│   └── TerminalManager.swift  # Terminal lifecycle + session detection
├── Utilities/
│   ├── KeyboardShortcuts.swift
│   ├── L10n.swift             # Localization helper
│   ├── TerminalRepresentable.swift  # SwiftUI ↔ AppKit bridge
│   └── TerminalTheme.swift    # Terminal color schemes
└── Views/
    ├── AgentGridView.swift    # Agent cards + terminal
    ├── ContentView.swift      # Main layout
    ├── FloorSwitcherView.swift  # 3D floor switcher
    └── ...
```

## AI-Native Development

This project is built entirely with AI coding agents. See [CLAUDE.md](CLAUDE.md) for AI development guidelines.

## License

[MIT](LICENSE)
