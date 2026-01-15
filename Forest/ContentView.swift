import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var settingsService = SettingsService.shared

    var body: some View {
        // swiftlint:disable:next redundant_discardable_let
        let _ = settingsService.appearanceRefreshTrigger  // Trigger re-render on appearance change

        HStack(spacing: 0) {
            SidebarView()
                .frame(width: 240)

            Rectangle()
                .fill(Color.border)
                .frame(width: 1)

            detailView
        }
        .ignoresSafeArea(edges: .top)
        .background(Color.bg)
        .background(
            WindowConfigurator { window in
                window.titleVisibility = .hidden
                window.titlebarAppearsTransparent = true
                window.styleMask.insert(.fullSizeContentView)
                window.isMovableByWindowBackground = true
                window.toolbar?.showsBaselineSeparator = false

                // Vertically center traffic lights in header (52pt height)
                let buttons: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
                for buttonType in buttons {
                    if let button = window.standardWindowButton(buttonType) {
                        var frame = button.frame
                        frame.origin.y = -12  // Move down to center in header
                        button.setFrameOrigin(frame.origin)
                    }
                }
            }
        )
    }

    @ViewBuilder
    private var detailView: some View {
        switch appState.selection {
        case .repository(let repoId):
            if let repo = appState.repositories.first(where: { $0.id == repoId }) {
                RepositoryDetailView(repository: repo)
            } else {
                EmptyStateView()
            }
        case .worktree:
            if let worktree = appState.selectedWorktree,
               let repoId = appState.selectedWorktreeRepoId {
                WorktreeDetailView(worktree: worktree, repositoryId: repoId)
            } else {
                EmptyStateView()
            }
        case nil:
            EmptyStateView()
        }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: Spacing.xl) {
            // Subtle decorative element
            ZStack {
                // Background rings
                ForEach(0..<3) { i in
                    Circle()
                        .strokeBorder(Color.border.opacity(0.5 - Double(i) * 0.15), lineWidth: 1)
                        .frame(width: CGFloat(60 + i * 30), height: CGFloat(60 + i * 30))
                }

                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(.textMuted)
            }

            VStack(spacing: Spacing.sm) {
                Text("Select a worktree")
                    .font(.headline)
                    .foregroundColor(.textSecondary)

                Text("Choose from the sidebar to view details")
                    .font(.caption)
                    .foregroundColor(.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                Color.bgElevated

                // Subtle gradient overlay
                LinearGradient(
                    colors: [Color.accent.opacity(0.02), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
