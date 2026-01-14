import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @State private var showingAddRepo = false
    @State private var showingAddWorktree = false
    @State private var repoToRemove: Repository?
    @State private var worktreeToDelete: (worktree: Worktree, repoId: UUID)?
    @State private var deleteError: String?

    var body: some View {
        @Bindable var state = appState

        List(selection: $state.selectedWorktreeId) {
            // Active worktrees by repo
            ForEach(appState.repositories) { repo in
                Section {
                    // Repo row (swipeable)
                    RepoRow(repo: repo) {
                        appState.selectedRepositoryId = repo.id
                        showingAddWorktree = true
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            repoToRemove = repo
                        } label: {
                            Label("Remove", systemImage: "folder.badge.minus")
                        }
                    }

                    // Worktrees
                    ForEach(appState.activeWorktrees(for: repo)) { worktree in
                        WorktreeRow(worktree: worktree)
                            .tag(worktree.id)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    worktreeToDelete = (worktree, repo.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    appState.archiveWorktree(worktree.id, in: repo.id)
                                } label: {
                                    Label("Archive", systemImage: "archivebox")
                                }
                                .tint(.orange)
                            }
                    }
                }
            }

            // Archived section
            if appState.hasArchivedWorktrees() {
                Section {
                    DisclosureGroup {
                        ForEach(appState.repositories) { repo in
                            ForEach(appState.archivedWorktrees(for: repo)) { worktree in
                                ArchivedWorktreeRow(worktree: worktree, repoName: repo.name)
                                    .tag(worktree.id)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            worktreeToDelete = (worktree, repo.id)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                        Button {
                                            appState.unarchiveWorktree(worktree.id, in: repo.id)
                                        } label: {
                                            Label("Restore", systemImage: "arrow.uturn.backward")
                                        }
                                        .tint(.forest)
                                    }
                            }
                        }
                    } label: {
                        Label("Archived", systemImage: "archivebox")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 240)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddRepo = true
                } label: {
                    Label("Add Repository", systemImage: "folder.badge.plus")
                }
            }
        }
        .sheet(isPresented: $showingAddRepo) {
            AddRepositorySheet()
        }
        .sheet(isPresented: $showingAddWorktree) {
            if let repoId = appState.selectedRepositoryId {
                AddWorktreeSheet(repositoryId: repoId)
            }
        }
        .alert("Remove Repository?", isPresented: Binding(
            get: { repoToRemove != nil },
            set: { if !$0 { repoToRemove = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                repoToRemove = nil
            }
            Button("Remove", role: .destructive) {
                if let repo = repoToRemove {
                    appState.removeRepository(repo)
                }
                repoToRemove = nil
            }
        } message: {
            Text("This will remove \"\(repoToRemove?.name ?? "")\" from Forest. The repository and its worktrees will not be deleted from disk.")
        }
        .alert("Delete Worktree?", isPresented: Binding(
            get: { worktreeToDelete != nil },
            set: { if !$0 { worktreeToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                worktreeToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let (worktree, repoId) = worktreeToDelete {
                    do {
                        try appState.deleteWorktree(worktree, from: repoId)
                    } catch {
                        deleteError = error.localizedDescription
                    }
                }
                worktreeToDelete = nil
            }
        } message: {
            Text("This will permanently delete \"\(worktreeToDelete?.worktree.name ?? "")\" and remove it from git. This cannot be undone.")
        }
        .alert("Error", isPresented: Binding(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("OK") { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
    }
}

struct RepoRow: View {
    let repo: Repository
    let onAddWorktree: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "tree.fill")
                .foregroundStyle(.forest)
                .font(.system(size: 16))

            Text(repo.name)
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer()

            Button(action: onAddWorktree) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.forest)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .opacity(isHovering ? 1 : 0.7)
            .scaleEffect(isHovering ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovering)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

struct WorktreeRow: View {
    let worktree: Worktree

    var body: some View {
        HStack {
            Image(systemName: "leaf.fill")
                .foregroundStyle(.forest.opacity(0.7))
                .font(.caption)
            VStack(alignment: .leading, spacing: 2) {
                Text(worktree.name)
                    .fontWeight(.medium)
                Text(worktree.branch)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .padding(.leading, 8)
    }
}

struct ArchivedWorktreeRow: View {
    let worktree: Worktree
    let repoName: String

    var body: some View {
        HStack {
            Image(systemName: "leaf")
                .foregroundStyle(.secondary)
                .font(.caption)
            VStack(alignment: .leading, spacing: 2) {
                Text(worktree.name)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Text("\(repoName) · \(worktree.branch)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}

extension ShapeStyle where Self == Color {
    static var forest: Color {
        Color(red: 0.29, green: 0.49, blue: 0.35)
    }
}

#Preview {
    SidebarView()
        .environment(AppState())
}
