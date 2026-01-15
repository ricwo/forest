import SwiftUI
import AppKit

@main
struct ForestApp: App {
    @State private var appState = AppState()
    @State private var updateService = UpdateService.shared
    @State private var settingsService = SettingsService.shared
    @State private var logService = LogService.shared
    @State private var crashService = CrashReportService.shared
    @State private var showSettings = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(updateService)
                .onAppear {
                    logService.info("Forest app launched", category: "App")
                    updateService.startPeriodicChecks()
                    applyAppearance(settingsService.appearanceMode)
                }
                .sheet(isPresented: $showSettings) {
                    SettingsView()
                }
        }
        .defaultSize(width: 900, height: 600)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    updateService.checkForUpdates(showAlert: true)
                }
                .keyboardShortcut("U", modifiers: [.command])

                Divider()

                Button("Settings...") {
                    showSettings = true
                }
                .keyboardShortcut(",", modifiers: [.command])
            }
        }
    }

    private func applyAppearance(_ mode: AppearanceMode) {
        let appearance: NSAppearance?
        switch mode {
        case .system:
            appearance = nil
        case .light:
            appearance = NSAppearance(named: .aqua)
        case .dark:
            appearance = NSAppearance(named: .darkAqua)
        }

        NSApp.appearance = appearance
        for window in NSApp.windows {
            window.appearance = appearance
            window.invalidateShadow()
            window.displayIfNeeded()
        }
        settingsService.appearanceRefreshTrigger += 1
    }
}

// MARK: - Window Configuration

struct WindowConfigurator: NSViewRepresentable {
    var configure: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = WindowConfiguratorView()
        view.configure = configure
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? WindowConfiguratorView else { return }
        view.configure = configure
        view.applyConfiguration()
    }
}

class WindowConfiguratorView: NSView {
    var configure: ((NSWindow) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyConfiguration()

        // Observe screen changes
        if let window = window {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidChangeScreen),
                name: NSWindow.didChangeScreenNotification,
                object: window
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidChangeScreen),
                name: NSWindow.didBecomeMainNotification,
                object: window
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidChangeScreen),
                name: NSWindow.didResignMainNotification,
                object: window
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidChangeScreen),
                name: NSWindow.didBecomeKeyNotification,
                object: window
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidChangeScreen),
                name: NSWindow.didResignKeyNotification,
                object: window
            )
        }
    }

    @objc private func windowDidChangeScreen() {
        applyConfiguration()
    }

    func applyConfiguration() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let window = self.window else { return }
            self.configure?(window)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
