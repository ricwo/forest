import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            if let worktree = appState.selectedWorktree,
               let repoId = appState.selectedWorktreeRepoId {
                WorktreeDetailView(worktree: worktree, repositoryId: repoId)
            } else {
                EmptyStateView()
            }
        }
        .navigationTitle("Forest")
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "tree.fill")
                .font(.system(size: 60))
                .foregroundStyle(.forest.opacity(0.5))

            Text("Welcome to Forest")
                .font(.title2)
                .fontWeight(.medium)

            Text("Add a repository to get started,\nthen create worktrees to work on multiple branches.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
