import SwiftUI

extension UUID: @retroactive Identifiable {
    public var id: UUID { self }
}

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @State private var showingAddRepo = false
    @State private var worktreeSheetRepoId: UUID?
    @State private var repoToRemove: Repository?
    @State private var worktreeToDelete: (worktree: Worktree, repoId: UUID)?
    @State private var deleteError: String?
    @State private var draggedWorktreeId: UUID?
    @State private var dropTargetId: UUID?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Worktrees")
                    .font(.headline)
                    .foregroundColor(.textPrimary)

                Spacer()

                IconButton(icon: "plus") {
                    showingAddRepo = true
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)

            SubtleDivider()

            // Content
            if appState.repositories.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: Spacing.xs) {
                        ForEach(appState.repositories) { repo in
                            repoSection(repo)
                        }

                        // Archived
                        if appState.hasArchivedWorktrees() {
                            archivedSection
                                .padding(.top, Spacing.md)
                        }
                    }
                    .padding(.vertical, Spacing.sm)
                }
            }
        }
        .background(Color.bg)
        .sheet(isPresented: $showingAddRepo) {
            AddRepositorySheet()
        }
        .sheet(item: $worktreeSheetRepoId) { repoId in
            AddWorktreeSheet(repositoryId: repoId)
        }
        .alert("Remove Repository?", isPresented: Binding(
            get: { repoToRemove != nil },
            set: { if !$0 { repoToRemove = nil } }
        )) {
            Button("Cancel", role: .cancel) { repoToRemove = nil }
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
            Button("Cancel", role: .cancel) { worktreeToDelete = nil }
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
            Text("This will permanently delete \"\(worktreeToDelete?.worktree.name ?? "")\" and remove it from git.")
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

    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            // Tree illustration
            ZStack {
                Circle()
                    .fill(Color.accentLight)
                    .frame(width: 72, height: 72)

                Image(systemName: "tree.fill")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(.accent)
            }

            VStack(spacing: Spacing.sm) {
                Text("Plant your first tree")
                    .font(.headline)
                    .foregroundColor(.textPrimary)

                Text("Add a repository to start\nmanaging worktrees")
                    .font(.caption)
                    .foregroundColor(.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            Button {
                showingAddRepo = true
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Add Repository")
                }
            }
            .buttonStyle(AccentButtonStyle())
            .padding(.top, Spacing.sm)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    @ViewBuilder
    private func repoSection(_ repo: Repository) -> some View {
        VStack(spacing: 0) {
            // Repo header (now selectable)
            RepoHeaderRow(
                repo: repo,
                isSelected: appState.selection == .repository(repo.id),
                onSelect: {
                    appState.selection = .repository(repo.id)
                },
                onAdd: {
                    worktreeSheetRepoId = repo.id
                },
                onRemove: {
                    repoToRemove = repo
                }
            )

            // Worktrees with drag reordering
            let worktrees = appState.activeWorktrees(for: repo)
            ForEach(Array(worktrees.enumerated()), id: \.element.id) { index, worktree in
                VStack(spacing: 0) {
                    // Drop indicator above this item
                    if dropTargetId == worktree.id && draggedWorktreeId != worktree.id {
                        DropIndicator()
                    }

                    WorktreeListRow(
                        worktree: worktree,
                        isSelected: appState.selection == .worktree(worktree.id),
                        isDragging: draggedWorktreeId == worktree.id,
                        onSelect: {
                            appState.selection = .worktree(worktree.id)
                        },
                        onArchive: {
                            appState.archiveWorktree(worktree.id, in: repo.id)
                        },
                        onDelete: {
                            worktreeToDelete = (worktree, repo.id)
                        }
                    )
                    .draggable(worktree.id.uuidString) {
                        // Drag preview
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.system(size: 11))
                                .foregroundColor(.accent)
                            Text(worktree.name)
                                .font(.bodyMedium)
                                .foregroundColor(.textPrimary)
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(Color.bgElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                        .onAppear { draggedWorktreeId = worktree.id }
                    }
                    .dropDestination(for: String.self) { items, _ in
                        dropTargetId = nil
                        draggedWorktreeId = nil

                        guard let droppedId = items.first,
                              let droppedUUID = UUID(uuidString: droppedId),
                              let fromIndex = worktrees.firstIndex(where: { $0.id == droppedUUID }),
                              let toIndex = worktrees.firstIndex(where: { $0.id == worktree.id }),
                              fromIndex != toIndex
                        else { return false }

                        let adjustedTo = fromIndex < toIndex ? toIndex + 1 : toIndex
                        appState.moveWorktree(in: repo.id, from: IndexSet(integer: fromIndex), to: adjustedTo)
                        return true
                    } isTargeted: { isTargeted in
                        withAnimation(.easeOut(duration: 0.15)) {
                            dropTargetId = isTargeted ? worktree.id : (dropTargetId == worktree.id ? nil : dropTargetId)
                        }
                    }

                    // Drop indicator at the end (after last item)
                    if index == worktrees.count - 1 && dropTargetId == nil && draggedWorktreeId != nil {
                        // Show at end when hovering below last item
                    }
                }
            }
        }
        .onChange(of: draggedWorktreeId) { _, newValue in
            if newValue == nil {
                dropTargetId = nil
            }
        }
    }

    private var archivedSection: some View {
        VStack(spacing: 0) {
            DisclosureGroup {
                ForEach(appState.repositories) { repo in
                    ForEach(appState.archivedWorktrees(for: repo)) { worktree in
                        ArchivedListRow(
                            worktree: worktree,
                            repoName: repo.name,
                            isSelected: appState.selection == .worktree(worktree.id),
                            onSelect: {
                                appState.selection = .worktree(worktree.id)
                            },
                            onRestore: {
                                appState.unarchiveWorktree(worktree.id, in: repo.id)
                            },
                            onDelete: {
                                worktreeToDelete = (worktree, repo.id)
                            }
                        )
                    }
                }
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "archivebox")
                        .font(.system(size: 12))
                        .foregroundColor(.textTertiary)
                    Text("Archived")
                        .font(.caption)
                        .foregroundColor(.textTertiary)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
        }
    }
}

// MARK: - Repo Header Row

struct RepoHeaderRow: View {
    let repo: Repository
    let isSelected: Bool
    let onSelect: () -> Void
    let onAdd: () -> Void
    let onRemove: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Accent indicator (same as worktree rows)
            RoundedRectangle(cornerRadius: 2)
                .fill(isSelected ? Color.accent : Color.clear)
                .frame(width: 3, height: 28)

            Image(systemName: "folder.fill")
                .font(.system(size: 12))
                .foregroundColor(.accent)

            Text(repo.name)
                .font(.captionMedium)
                .foregroundColor(isSelected ? .textPrimary : .textSecondary)

            Spacer()

            if isHovering {
                HStack(spacing: 2) {
                    Button(action: onAdd) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.textTertiary)
                            .frame(width: 20, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button(action: onRemove) {
                        Image(systemName: "minus")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.textTertiary)
                            .frame(width: 20, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(isSelected ? Color.bgSelected : (isHovering ? Color.bgHover : Color.clear))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(.horizontal, Spacing.sm)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isSelected)
        .animation(.easeOut(duration: 0.15), value: isHovering)
    }
}

// MARK: - Worktree List Row

// MARK: - Drop Indicator

struct DropIndicator: View {
    var body: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(Color.accent)
                .frame(width: 6, height: 6)

            Rectangle()
                .fill(Color.accent)
                .frame(height: 2)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 2)
    }
}

struct WorktreeListRow: View {
    let worktree: Worktree
    let isSelected: Bool
    var isDragging: Bool = false
    let onSelect: () -> Void
    let onArchive: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Accent indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(isSelected ? Color.accent : Color.clear)
                .frame(width: 3, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(worktree.name)
                    .font(.bodyMedium)
                    .foregroundColor(isSelected ? .textPrimary : .textSecondary)

                Text(worktree.branch)
                    .font(.caption)
                    .foregroundColor(.textTertiary)
            }

            Spacer()
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(isSelected ? Color.bgSelected : (isHovering ? Color.bgHover : Color.clear))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .trailing) {
            if isHovering && !isDragging {
                HStack(spacing: 4) {
                    Button(action: onArchive) {
                        Image(systemName: "archivebox")
                            .font(.system(size: 11))
                            .foregroundColor(.textTertiary)
                            .frame(width: 22, height: 22)
                            .background(Color.bgHover)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(.destructive)
                            .frame(width: 22, height: 22)
                            .background(Color.destructiveLight)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.trailing, Spacing.md)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .opacity(isDragging ? 0.4 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isSelected)
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .animation(.easeOut(duration: 0.15), value: isDragging)
    }
}

// MARK: - Archived List Row

struct ArchivedListRow: View {
    let worktree: Worktree
    let repoName: String
    let isSelected: Bool
    let onSelect: () -> Void
    let onRestore: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: Spacing.md) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.textMuted)
                .frame(width: 3, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(worktree.name)
                    .font(.bodyMedium)
                    .foregroundColor(.textTertiary)

                Text("\(repoName) · \(worktree.branch)")
                    .font(.caption)
                    .foregroundColor(.textMuted)
            }

            Spacer()
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(isSelected ? Color.bgSelected : (isHovering ? Color.bgHover : Color.clear))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .trailing) {
            if isHovering {
                HStack(spacing: 4) {
                    Button(action: onRestore) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 11))
                            .foregroundColor(.accent)
                            .frame(width: 22, height: 22)
                            .background(Color.accentLight)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(.destructive)
                            .frame(width: 22, height: 22)
                            .background(Color.destructiveLight)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.trailing, Spacing.md)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovering)
    }
}

#Preview {
    SidebarView()
        .environment(AppState())
        .frame(width: 280, height: 500)
}
