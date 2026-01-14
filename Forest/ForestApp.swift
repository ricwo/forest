import SwiftUI

@main
struct ForestApp: App {
    @State private var appState = AppState()
    @State private var updateService = UpdateService.shared
    @State private var showSettings = false

    var body: some Scene {
        WindowGroup("forest") {
            ContentView()
                .environment(appState)
                .environment(updateService)
                .onAppear {
                    updateService.startPeriodicChecks()
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
}
