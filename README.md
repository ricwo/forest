# forest

A macOS app for managing git worktrees.

## Features

- Add, switch, and remove git worktrees
- View Claude Code session history per worktree
- Open worktrees in your editor (VS Code, Cursor, PyCharm)
- Auto-updates when new versions are available
- **Per-project settings:**
  - Default terminal per project (iTerm, Terminal, Warp, Ghostty, etc.)
  - Custom Claude command per project (e.g., `claude-work`, `claude-personal`)

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/ricwo/forest/main/install.sh | bash
```

Or download the latest `.dmg` from [Releases](https://github.com/ricwo/forest/releases).

Requires macOS 18+ (Apple Silicon).

## Development

```bash
open forest.xcodeproj
```
