# Forest

A macOS app for managing git worktrees.

## Requirements

- macOS 14+
- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## Build

```bash
./scripts/build.sh
```

Output in `release/`:
- `Forest.app`
- `Forest.zip`
- `Forest.dmg`

## Development

```bash
xcodegen generate
open Forest.xcodeproj
```

## Lint

```bash
brew install swiftlint
swiftlint
```
