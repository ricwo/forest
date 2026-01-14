import SwiftUI

@main
struct ForestApp: App {
    @State private var appState = AppState()
    @State private var updateService = UpdateService.shared

    var body: some Scene {
        WindowGroup("forest") {
            ContentView()
                .environment(appState)
                .environment(updateService)
                .onAppear {
                    updateService.startPeriodicChecks()
                }
        }
        .defaultSize(width: 900, height: 600)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    updateService.checkForUpdates()
                }
                .keyboardShortcut("U", modifiers: [.command])
            }
        }
    }
}
