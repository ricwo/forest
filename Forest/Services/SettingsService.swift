import Foundation

enum Editor: String, CaseIterable, Identifiable {
    case vscode = "vscode"
    case cursor = "cursor"
    case pycharm = "pycharm"
    case xcode = "xcode"
    case sublime = "sublime"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .vscode: return "VS Code"
        case .cursor: return "Cursor"
        case .pycharm: return "PyCharm"
        case .xcode: return "Xcode"
        case .sublime: return "Sublime Text"
        }
    }

    var bundleId: String {
        switch self {
        case .vscode: return "com.microsoft.VSCode"
        case .cursor: return "com.todesktop.230313mzl4w4u92"
        case .pycharm: return "com.jetbrains.pycharm"
        case .xcode: return "com.apple.dt.Xcode"
        case .sublime: return "com.sublimetext.4"
        }
    }

    var icon: String {
        switch self {
        case .vscode: return "chevron.left.forwardslash.chevron.right"
        case .cursor: return "cursorarrow.rays"
        case .pycharm: return "p.circle"
        case .xcode: return "hammer"
        case .sublime: return "s.circle"
        }
    }
}

enum Terminal: String, CaseIterable, Identifiable {
    case iterm = "iTerm"
    case terminal = "Terminal"
    case hyper = "Hyper"
    case warp = "Warp"
    case kitty = "kitty"
    case alacritty = "Alacritty"
    case wezterm = "WezTerm"
    case ghostty = "Ghostty"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .iterm: return "iTerm"
        case .terminal: return "Terminal"
        case .hyper: return "Hyper"
        case .warp: return "Warp"
        case .kitty: return "kitty"
        case .alacritty: return "Alacritty"
        case .wezterm: return "WezTerm"
        case .ghostty: return "Ghostty"
        }
    }

    var bundleId: String {
        switch self {
        case .iterm: return "com.googlecode.iterm2"
        case .terminal: return "com.apple.Terminal"
        case .hyper: return "co.zeit.hyper"
        case .warp: return "dev.warp.Warp-Stable"
        case .kitty: return "net.kovidgoyal.kitty"
        case .alacritty: return "org.alacritty"
        case .wezterm: return "com.github.wez.wezterm"
        case .ghostty: return "com.mitchellh.ghostty"
        }
    }

    var icon: String {
        switch self {
        case .iterm: return "terminal"
        case .terminal: return "apple.terminal"
        case .hyper: return "bolt.horizontal"
        case .warp: return "waveform"
        case .kitty: return "cat"
        case .alacritty: return "a.square"
        case .wezterm: return "w.square"
        case .ghostty: return "ghost"
        }
    }

    var supportsAppleScript: Bool {
        switch self {
        case .iterm, .terminal, .hyper, .warp, .kitty, .wezterm, .ghostty:
            return true
        case .alacritty:
            return false
        }
    }
}

@Observable
final class SettingsService {
    static let shared = SettingsService()

    private let defaults = UserDefaults.standard
    private let forestDirectoryKey = "forestDirectory"
    private let defaultEditorKey = "defaultEditor"
    private let defaultTerminalKey = "defaultTerminal"
    private let branchPrefixKey = "branchPrefix"

    var forestDirectory: URL {
        get {
            if let path = defaults.string(forKey: forestDirectoryKey) {
                return URL(fileURLWithPath: path)
            }
            return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("forest")
        }
        set {
            defaults.set(newValue.path, forKey: forestDirectoryKey)
        }
    }

    var defaultEditor: Editor {
        get {
            if let raw = defaults.string(forKey: defaultEditorKey),
               let editor = Editor(rawValue: raw) {
                return editor
            }
            return .cursor
        }
        set {
            defaults.set(newValue.rawValue, forKey: defaultEditorKey)
        }
    }

    var defaultTerminal: Terminal {
        get {
            if let raw = defaults.string(forKey: defaultTerminalKey),
               let terminal = Terminal(rawValue: raw) {
                return terminal
            }
            return .iterm
        }
        set {
            defaults.set(newValue.rawValue, forKey: defaultTerminalKey)
        }
    }

    var branchPrefix: String {
        get {
            defaults.string(forKey: branchPrefixKey) ?? "feat/"
        }
        set {
            defaults.set(newValue, forKey: branchPrefixKey)
        }
    }

    private init() {}
}
