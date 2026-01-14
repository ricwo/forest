import SwiftUI

@main
struct ForestApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
        .defaultSize(width: 900, height: 600)
        .windowResizability(.contentSize)
    }
}
