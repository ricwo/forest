# Forest

macOS app for managing Git worktrees. Built with SwiftUI.

## Stack

- Swift 5.9, SwiftUI
- macOS 18+ (Apple Silicon)
- Xcode project (not SPM)

## Structure

```
Forest/
  ForestApp.swift      # App entry, menus
  AppState.swift       # Main state management
  Theme.swift          # Colors, typography, components
  Models/              # Repository, Worktree, ClaudeSession
  Services/            # GitService, SettingsService, UpdateService
  Views/               # SwiftUI views
```

## Build & Run

```bash
xcodebuild -scheme forest -configuration Debug build
```

## Design

Use the `frontend-design` skill for any UI/design work. If it's not available, ask the user to add it from the Claude Code marketplace (or do it yourself if you can).

Principles: beautiful, minimal, delightful UI with subtle, forest-y theming.
