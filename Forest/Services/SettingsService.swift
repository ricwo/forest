import Foundation
import SwiftUI

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

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

@Observable
final class SettingsService {
    static let shared = SettingsService()

    private let defaults = UserDefaults.standard
    private let forestDirectoryKey = "forestDirectory"
    private let defaultEditorKey = "defaultEditor"
    private let branchPrefixKey = "branchPrefix"
    private let appearanceModeKey = "appearanceMode"

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

    var branchPrefix: String {
        get {
            defaults.string(forKey: branchPrefixKey) ?? "feat/"
        }
        set {
            defaults.set(newValue, forKey: branchPrefixKey)
        }
    }

    var appearanceMode: AppearanceMode {
        get {
            if let raw = defaults.string(forKey: appearanceModeKey),
               let mode = AppearanceMode(rawValue: raw) {
                return mode
            }
            return .system
        }
        set {
            defaults.set(newValue.rawValue, forKey: appearanceModeKey)
        }
    }

    /// Incremented when appearance changes to trigger SwiftUI view updates
    var appearanceRefreshTrigger: Int = 0

    /// Currently active appearance (may differ from saved during preview)
    var activeAppearance: AppearanceMode?

    /// Returns whether dark mode should be active based on current settings
    var isDarkModeActive: Bool {
        let mode = activeAppearance ?? appearanceMode
        switch mode {
        case .dark:
            return true
        case .light:
            return false
        case .system:
            return NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        }
    }

    private init() {}
}
