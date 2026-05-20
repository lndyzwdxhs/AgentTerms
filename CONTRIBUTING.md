# Contributing to AgentTerms

AgentTerms is an AI-native project — built entirely with AI coding agents. Contributions from both humans and AI agents are welcome.

## Development Setup

1. Clone the repo:
```bash
git clone https://github.com/YOUR_USERNAME/AgentTerms.git
cd AgentTerms
```

2. Build:
```bash
make build
```

3. Run:
```bash
make run
```

## How to Contribute

### For AI Agents

Read [CLAUDE.md](CLAUDE.md) for full project context, architecture, and conventions.

### For Humans

1. Fork the repo
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Make your changes
4. Test locally with `make run`
5. Commit and push
6. Open a Pull Request

## Guidelines

- Keep the UI clean and minimal — avoid over-engineering
- Status detection must be passive (read files, never inject into agent processes)
- Support multiple AI tools generically — don't hardcode Claude-specific logic
- Maintain Chinese + English localization for all user-facing strings
- Test on macOS 14.0+

## Areas Looking for Contributions

- [ ] Codex status detection implementation
- [ ] Gemini status detection implementation
- [ ] Detail area screenshot for 3D floor switcher
- [ ] Drag-and-drop to reorder agents
- [ ] Import/export workspace configurations
- [ ] Menu bar quick-action panel
- [ ] Custom terminal themes
- [ ] Agent task description auto-detection from first prompt

## Reporting Issues

Please include:
- macOS version
- AI tool and version (e.g. Claude Code 2.1.x)
- Steps to reproduce
- Expected vs actual behavior
