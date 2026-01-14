import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 0) {
            SidebarView()
                .frame(width: 240)

            Rectangle()
                .fill(Color.border)
                .frame(width: 1)

            detailView
        }
        .background(Color.bg)
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
        case .worktree(let worktreeId):
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
        VStack(spacing: Spacing.lg) {
            Image(systemName: "arrow.left.circle")
                .font(.system(size: 44, weight: .ultraLight))
                .foregroundColor(.textMuted)

            VStack(spacing: Spacing.xs) {
                Text("Select a worktree")
                    .font(.bodyMedium)
                    .foregroundColor(.textSecondary)

                Text("Choose a worktree from the sidebar to view details")
                    .font(.caption)
                    .foregroundColor(.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgElevated)
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
