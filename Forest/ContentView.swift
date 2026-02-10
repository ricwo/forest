import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var settingsService = SettingsService.shared
    @State private var sidebarWidth: CGFloat = 240

    private let minSidebarWidth: CGFloat = 180
    private let maxSidebarWidth: CGFloat = 400

    var body: some View {
        // swiftlint:disable:next redundant_discardable_let
        let _ = settingsService.appearanceRefreshTrigger  // Trigger re-render on appearance change

        HStack(spacing: 0) {
            SidebarView()
                .frame(width: sidebarWidth)

            SidebarDivider(sidebarWidth: $sidebarWidth, minWidth: minSidebarWidth, maxWidth: maxSidebarWidth)

            detailView
        }
        .background(Color.bg)
        .alert("Worktree removal failed",
            isPresented: Binding(
                get: { appState.deleteError != nil },
                set: { if !$0 { appState.deleteError = nil } }
            )
        ) {
            Button("OK") { appState.deleteError = nil }
        } message: {
            if let err = appState.deleteError {
                Text("Could not remove \"\(err.worktreeName)\" from git.\n\nThe directory may need manual cleanup:\n\(err.worktreePath)\n\n\(err.message)")
            }
        }
        .alert("Worktree Has Unsaved Changes",
            isPresented: Binding(
                get: { appState.dirtyWorktreeConfirmation != nil },
                set: { if !$0 { appState.dirtyWorktreeConfirmation = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) {
                appState.dirtyWorktreeConfirmation = nil
            }
            Button("Delete Anyway", role: .destructive) {
                appState.confirmDeleteDirtyWorktree()
            }
        } message: {
            if let confirmation = appState.dirtyWorktreeConfirmation {
                Text("\"\(confirmation.worktree.name)\" has uncommitted or untracked files that will be permanently lost.")
            }
        }
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

// MARK: - Sidebar Divider

private struct SidebarDivider: View {
    @Binding var sidebarWidth: CGFloat
    let minWidth: CGFloat
    let maxWidth: CGFloat

    @State private var isHovering = false
    @State private var isDragging = false
    @State private var dragStartWidth: CGFloat = 0

    private var isActive: Bool { isDragging || isHovering }

    var body: some View {
        Rectangle()
            .fill(isActive ? Color.accent.opacity(isDragging ? 0.5 : 0.3) : Color.border)
            .frame(width: 1)
            .frame(width: 7)  // fixed layout slot; wider hit target
            .contentShape(Rectangle())
            .onHover { hovering in
                if !isDragging { isHovering = hovering }
            }
            .onContinuousHover { phase in
                if isDragging { return }
                switch phase {
                case .active:
                    NSCursor.resizeLeftRight.push()
                case .ended:
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            dragStartWidth = sidebarWidth
                            NSCursor.resizeLeftRight.push()
                        }
                        var transaction = Transaction()
                        transaction.animation = nil
                        withTransaction(transaction) {
                            sidebarWidth = round(min(max(dragStartWidth + value.translation.width, minWidth), maxWidth))
                        }
                    }
                    .onEnded { _ in
                        isDragging = false
                        NSCursor.pop()
                    }
            )
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
