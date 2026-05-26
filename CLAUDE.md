# AgentTerms - AI Development Guide

This file provides context for AI coding agents working on this project.

## Development Principles

### 1. Think Before Coding

Don't assume. Don't hide confusion. Surface tradeoffs.

- State assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

### 2. Simplicity First

Minimum code that solves the problem. Nothing speculative.

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

### 3. Surgical Changes

Touch only what you must. Clean up only your own mess.

- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it — don't delete it.
- Every changed line should trace directly to the user's request.

### 4. Goal-Driven Execution

Define success criteria. Loop until verified.

- Transform tasks into verifiable goals before implementing.
- For multi-step tasks, state a brief plan with verification checks.
- Strong success criteria let you loop independently; weak criteria require clarification.

---

## Project Overview

AgentTerms is a macOS native app that manages multiple concurrent AI coding agent terminals. It monitors agent status, supports session resume, and provides a unified interface for developers running multiple AI agents simultaneously.

**GitHub:** https://github.com/lndyzwdxhs/AgentTerms
**License:** MIT

## Tech Stack

- **Language:** Swift 5.9+
- **UI Framework:** SwiftUI + AppKit (NSViewRepresentable bridges)
- **Terminal:** SwiftTerm (v1.2.0+) — Swift-native terminal emulator
- **Platform:** macOS 14.0+
- **Package Manager:** Swift Package Manager
- **Persistence:** JSON files in `~/.agentterms/`

## Key Concepts

### Workspace → Snapshot → Agent

- **Workspace** = A Git repository (e.g. `/Users/dev/my-project`)
- **Snapshot** = A Git worktree tied to a branch (isolated working copy)
- **Agent** = An AI tool instance running in a terminal on a snapshot

### Status Detection

Status is detected by reading JSONL session files from AI tools:
- Claude Code: `{configPath}/projects/{encoded-dir}/{sessionID}.jsonl`
- CodeBuddy: `~/.codebuddy/projects/{encoded-dir}/{sessionID}.jsonl`

**Path encoding differences:**
- Claude Code: replaces `/` AND `_` with `-`
- CodeBuddy: strips leading `/`, replaces remaining `/` with `-`, keeps `_`

**JSONL format differences:**

| | Claude Code | CodeBuddy |
|---|---|---|
| User message | `type: "user"` | `type: "message"` + `role: "user"` |
| AI response | `type: "assistant"` | `type: "message"` + `role: "assistant"` |
| Tool call | `tool_use` block inside assistant content | `type: "function_call"` + `name` field |
| Tool result | `type: "user"` with tool_result | `type: "function_result"` |
| Metadata to skip | permission-mode, last-prompt, file-history-snapshot, attachment | file-history-snapshot, ai-title |

**Resume arg format:**
- Claude Code: `--resume {sessionID}` (space separated)
- CodeBuddy: `--resume={sessionID}` (equals sign, no space)

Status logic (shared across tools):
- Agent executing tool (not AskUserQuestion) → running (🏃)
- AskUserQuestion / permission_request → needsInput (🙋)
- Last message is assistant + file stale > 5s → idle (😴)
- Last message is user + file updating → running (🏃)
- No terminal running → idle

### Session Binding

Each agent has a `sessionID` persisted in `config.json`. On first launch, `TerminalManager` polls (every 1s, no timeout) for new JSONL files to discover the session ID. On subsequent launches, it uses `--resume {sessionID}` to restore the conversation. The resume argument format is configurable per tool in settings.

### Configuration Files

`~/.agentterms/config.json` — Workspaces, snapshots, agents (sessionID, projectPath, but NOT status)
`~/.agentterms/settings.json` — Tool commands, config paths, resume args, language

**Important:** `status` is runtime-only. It is NOT persisted. On app launch all agents start as `idle`.

## Build & Run

```bash
make build          # Debug build
make run            # Build + assemble .app + open
make release        # Release build
make package        # Release + assemble .app
make dmg            # Create DMG for distribution
make clean          # Clean all artifacts
make icon           # Generate .icns from logo.png
```

## File Structure

```
Sources/
├── AgentTermsApp.swift          # @main App entry point
├── Models/
│   ├── Agent.swift              # Agent struct + AgentStatus enum + AgentTool enum
│   ├── AppState.swift           # @Observable app state, all mutations here
│   ├── Snapshot.swift           # Snapshot (git worktree)
│   ├── Settings.swift           # @Observable settings, ToolConfig struct
│   └── Workspace.swift          # Workspace (git repo)
├── Services/
│   ├── GitService.swift         # git worktree add/remove/list
│   ├── NotificationService.swift # UNUserNotificationCenter (requires .app bundle)
│   ├── PersistenceService.swift # JSON read/write to ~/.agentterms/
│   ├── PTYService.swift         # Default command lookup per tool
│   ├── StatusMonitor.swift      # Polls JSONL files every 2s
│   └── TerminalManager.swift    # Terminal lifecycle, snapshot, session detection
├── Utilities/
│   ├── KeyboardShortcuts.swift  # Cmd+1-9 agent switching
│   ├── L10n.swift               # Localization (zh-Hans, en)
│   ├── TerminalRepresentable.swift  # NSViewRepresentable bridge
│   └── TerminalTheme.swift      # Dracula, Solarized, etc.
├── Views/
│   ├── AgentGridView.swift      # Agent cards + terminal area
│   ├── ContentView.swift        # NavigationSplitView + toolbar
│   ├── CreateAgentSheet.swift   # Workspace/Snapshot/Agent creation sheets
│   ├── EmptyStateView.swift     # Placeholder views
│   ├── SnapshotGridView.swift   # Snapshot grid (unused in current UI)
│   ├── SnapshotSwitcher3DView.swift  # 3D Mission Control snapshot switcher
│   ├── SettingsView.swift       # Settings form
│   ├── SidebarView.swift        # Left sidebar (workspace list)
│   └── TerminalFullView.swift   # Full-screen terminal view
└── Resources/
    ├── en.lproj/Localizable.strings
    └── zh-Hans.lproj/Localizable.strings
```

## Important Patterns

### Data Flow

```
┌─────────────┐     ┌──────────────┐     ┌─────────────────┐
│  SwiftUI    │────▶│   AppState   │◀────│ PersistenceService│
│  Views      │     │ (Observable) │     │ (~/.agentterms/) │
└─────────────┘     └──────────────┘     └─────────────────┘
                           ▲
                           │ updates status
                    ┌──────────────┐
                    │ StatusMonitor │──── reads JSONL files every 2s
                    └──────────────┘
                           
┌─────────────┐     ┌──────────────────┐
│  Terminal    │────▶│ TerminalManager  │──── caches terminal instances
│  Views      │     │   (singleton)    │──── detects sessionID
└─────────────┘     └──────────────────┘
```

### Key Design Decisions

1. **Observable state:** `AppState` is the single source of truth, passed via SwiftUI `.environment(appState)`
2. **Terminal persistence:** `TerminalManager` singleton caches `LocalProcessTerminalView` instances so they survive SwiftUI view lifecycle
3. **NSView bridging:** `TerminalContainerView` (NSView) swaps terminal subviews without destroying them
4. **Status polling:** `StatusMonitor` polls every 2 seconds, only updates if status actually changed AND new status is not `.unknown`
5. **Localization:** Custom `L10n` helper with `String.localized` extension, supports zh-Hans and en. Bundle loaded from `Bundle.module`.
6. **Session detection:** No timeout — polls indefinitely until JSONL file appears (user may not send first message for hours)
7. **Status is runtime-only:** Never persisted. On app launch all agents start as `idle`, then StatusMonitor picks up real state within 2s.

## Coding Conventions

- Keep UI simple and clean — no over-engineering, no unnecessary animations
- Status detection must be passive (read files only, never inject into agent processes)
- Support multiple AI tools generically — use `AgentTool` enum + `ToolConfig`
- All user-facing strings must be localized (zh-Hans + en)
- `CodingKeys` with `decodeIfPresent` for backward compatibility when adding new fields
- No status persistence — status is always derived from runtime state

## Things to Watch Out For

- SwiftTerm's `LocalProcessTerminalView` must NOT be destroyed when navigating between agents
- `Bundle.module` in SPM resolves to `AgentTerms_AgentTerms.bundle` — must be copied to BOTH `Contents/MacOS/` and `Contents/Resources/` in the .app bundle
- macOS app bundles are required for `UNUserNotificationCenter` and proper keyboard handling
- The `.app` bundle must be manually assembled (binary + resource bundle + Info.plist + icns)
- When adding new `Codable` fields, always use `decodeIfPresent` with default values for backward compat
- Claude Code encodes project directory paths by replacing both `/` and `_` with `-`
- JSONL files end with metadata lines (`permission-mode`, `last-prompt`) — must skip these to find actual last message
