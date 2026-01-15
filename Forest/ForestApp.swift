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
