# AgentTerms - AI Development Guide

This file provides context for AI coding agents working on this project.

## Project Overview

AgentTerms is a macOS native app that manages multiple concurrent AI coding agent terminals. It monitors agent status, supports session resume, and provides a unified interface for developers running multiple AI agents simultaneously.

## Tech Stack

- **Language:** Swift 5.9+
- **UI Framework:** SwiftUI + AppKit (NSViewRepresentable bridges)
- **Terminal:** SwiftTerm (v1.2.0+) — Swift-native terminal emulator
- **Platform:** macOS 14.0+
- **Package Manager:** Swift Package Manager
- **Persistence:** JSON files in `~/.agentterms/`

## Key Concepts

### Workspace → Floor → Agent

- **Workspace** = A Git repository (e.g. `/Users/dev/my-project`)
- **Floor** = A Git worktree tied to a branch (isolated working copy)
- **Agent** = An AI tool instance running in a terminal on a floor

### Status Detection

Status is detected by reading JSONL session files from AI tools:
- Claude Code: `{configPath}/projects/{encoded-dir}/{sessionID}.jsonl`
- The encoding replaces `/` and `_` with `-` in the directory path

Status logic:
- Last message `type: "assistant"` + file stale > 5s → idle
- Last message `type: "assistant"` + contains `AskUserQuestion` tool_use → needsInput
- Last message `type: "user"` + file updating → running
- No terminal running → idle

### Session Binding

Each agent has a `sessionID` persisted in `config.json`. On first launch, `TerminalManager` polls for new JSONL files to discover the session ID. On subsequent launches, it uses `--resume {sessionID}` to restore the conversation.

## Build Commands

```bash
swift build                    # Debug build
swift package clean            # Clean build artifacts
swift build -c release         # Release build
```

## File Structure

- `Sources/` — All source code
- `Sources/Models/` — Data models (Agent, Floor, Workspace, Settings)
- `Sources/Services/` — Business logic (StatusMonitor, TerminalManager, GitService)
- `Sources/Utilities/` — Helpers (L10n, themes, keyboard shortcuts)
- `Sources/Views/` — SwiftUI views
- `Sources/Resources/` — Localization files (.lproj)

## Important Patterns

1. **Observable state:** `AppState` is the single source of truth, passed via SwiftUI Environment
2. **Terminal persistence:** `TerminalManager` singleton caches `LocalProcessTerminalView` instances so they survive SwiftUI view lifecycle
3. **NSView bridging:** `TerminalContainerView` (NSView) swaps terminal subviews without destroying them
4. **Status polling:** `StatusMonitor` polls every 2 seconds, only updates if status actually changed
5. **Localization:** Custom `L10n` helper with `String.localized` extension, supports zh-Hans and en

## Things to Watch Out For

- SwiftTerm's `LocalProcessTerminalView` must not be destroyed when navigating between agents
- `Bundle.module` in SPM resolves to `AgentTerms_AgentTerms.bundle` — must be copied to `.app` bundle
- macOS app bundles are required for proper keyboard handling and notifications
- The `.app` bundle must be manually assembled (binary + resource bundle + Info.plist + icns)
