import SwiftUI
import UniformTypeIdentifiers

extension UUID: @retroactive Identifiable {
    public var id: UUID { self }
}

// MARK: - Move Drop Delegates

struct RepoMoveDelegate: DropDelegate {
    let targetId: UUID
    let allRepos: [Repository]
    let onMove: (Int, Int) -> Void
    let onTargetChange: (UUID?) -> Void

    func dropEntered(info: DropInfo) {
        withAnimation(.easeOut(duration: 0.12)) {
            onTargetChange(targetId)
        }
    }

    func dropExited(info: DropInfo) {
        withAnimation(.easeOut(duration: 0.12)) {
            onTargetChange(nil)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        onTargetChange(nil)
        guard let item = info.itemProviders(for: [UTType.plainText]).first else { return false }

        _ = item.loadObject(ofClass: String.self) { string, _ in
            guard let droppedId = string,
                  let droppedUUID = UUID(uuidString: droppedId),
                  let fromIndex = allRepos.firstIndex(where: { $0.id == droppedUUID }),
                  let toIndex = allRepos.firstIndex(where: { $0.id == targetId }),
                  fromIndex != toIndex
            else { return }

            DispatchQueue.main.async {
                let adjustedTo = fromIndex < toIndex ? toIndex + 1 : toIndex
                onMove(fromIndex, adjustedTo)
            }
        }
        return true
    }
}

struct WorktreeMoveDelegate: DropDelegate {
    let targetId: UUID
    let worktrees: [Worktree]
    let repoId: UUID
    let onMove: (Int, Int) -> Void
    let onTargetChange: ((worktreeId: UUID, repoId: UUID)?) -> Void

    func dropEntered(info: DropInfo) {
        withAnimation(.easeOut(duration: 0.12)) {
            onTargetChange((targetId, repoId))
        }
    }

    func dropExited(info: DropInfo) {
        withAnimation(.easeOut(duration: 0.12)) {
            onTargetChange(nil)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        onTargetChange(nil)
        guard let item = info.itemProviders(for: [UTType.plainText]).first else { return false }

        _ = item.loadObject(ofClass: String.self) { string, _ in
            guard let droppedId = string,
                  let droppedUUID = UUID(uuidString: droppedId),
                  let fromIndex = worktrees.firstIndex(where: { $0.id == droppedUUID }),
                  let toIndex = worktrees.firstIndex(where: { $0.id == targetId }),
                  fromIndex != toIndex
            else { return }

            DispatchQueue.main.async {
                let adjustedTo = fromIndex < toIndex ? toIndex + 1 : toIndex
                onMove(fromIndex, adjustedTo)
            }
        }
        return true
    }
}

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @Environment(UpdateService.self) private var updateService
    @State private var settingsService = SettingsService.shared
    @State private var showingAddRepo = false
    @State private var worktreeSheetRepoId: UUID?
    @State private var repoToRemove: Repository?
    @State private var worktreeToDelete: (worktree: Worktree, repoId: UUID)?
    @State private var deleteError: String?
    @State private var repoDropTargetId: UUID?
    @State private var worktreeDropTarget: (worktreeId: UUID, repoId: UUID)?
    @State private var draggingFromRepoId: UUID?
    @State private var showUpdateAlert = false
    @State private var showSettings = false

    var body: some View {
        // swiftlint:disable:next redundant_discardable_let
        let _ = settingsService.appearanceRefreshTrigger  // Trigger re-render on appearance change

        VStack(spacing: 0) {
            // Header - aligned with traffic lights
            HStack(spacing: Spacing.sm) {
                ForestBranding()

                if updateService.updateAvailable {
                    Button {
                        showUpdateAlert = true
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 10))
                            Text("Update")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.accent)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                IconButton(icon: "gearshape") {
                    showSettings = true
                }

                IconButton(icon: "plus") {
                    showingAddRepo = true
                }
            }
            .padding(.leading, 78)  // Space for traffic lights
            .padding(.trailing, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .frame(height: 52)  // Match title bar height

            SubtleDivider()

            // Content
            if appState.repositories.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: Spacing.xs) {
                        let sortedRepos = appState.sortedRepositories
                        ForEach(Array(sortedRepos.enumerated()), id: \.element.id) { index, repo in
                            VStack(spacing: 0) {
                                // Drop indicator
                                if repoDropTargetId == repo.id {
                                    RepoDropIndicator()
                                }
                                repoSection(repo, allRepos: sortedRepos)
                            }

                            // Add divider between repos (not after last)
                            if index < sortedRepos.count - 1 {
                                SubtleDivider()
                                    .padding(.vertical, Spacing.xs)
                            }
                        }

                        // Archived
                        if appState.hasArchivedWorktrees() {
                            SubtleDivider()
                                .padding(.vertical, Spacing.xs)
                            archivedSection
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
        .sheet(isPresented: $showSettings) {
            SettingsView()
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
        .alert("Update Available", isPresented: $showUpdateAlert) {
            Button("Later", role: .cancel) {}
            Button("Update Now") {
                updateService.installUpdate()
            }
        } message: {
            Text("Version \(updateService.latestVersion ?? "?") is available. The app will restart after updating.")
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
    private func repoSection(_ repo: Repository, allRepos: [Repository]) -> some View {
        VStack(spacing: 0) {
            // Repo header with drag support
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
            .draggable(repo.id.uuidString)
            .onDrop(of: [UTType.plainText], delegate: RepoMoveDelegate(
                targetId: repo.id,
                allRepos: allRepos,
                onMove: { from, to in
                    appState.moveRepository(from: IndexSet(integer: from), to: to)
                },
                onTargetChange: { repoDropTargetId = $0 }
            ))

            // Worktrees with drag reordering
            let worktrees = appState.activeWorktrees(for: repo)
            ForEach(worktrees) { worktree in
                VStack(spacing: 0) {
                    // Drop indicator (only show within same repo)
                    if worktreeDropTarget?.worktreeId == worktree.id &&
                       worktreeDropTarget?.repoId == repo.id &&
                       draggingFromRepoId == repo.id {
                        WorktreeDropIndicator()
                    }
                    WorktreeListRow(
                        worktree: worktree,
                        isSelected: appState.selection == .worktree(worktree.id),
                        isDragging: false,
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
                        Text(worktree.name)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.sm)
                            .background(Color.bgElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                            .onAppear { draggingFromRepoId = repo.id }
                            .onDisappear { draggingFromRepoId = nil }
                    }
                    .onDrop(of: [UTType.plainText], delegate: WorktreeMoveDelegate(
                        targetId: worktree.id,
                        worktrees: worktrees,
                        repoId: repo.id,
                        onMove: { from, to in
                            appState.moveWorktree(in: repo.id, from: IndexSet(integer: from), to: to)
                        },
                        onTargetChange: { worktreeDropTarget = $0 }
                    ))
                }
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
        HStack(spacing: Spacing.sm) {
            // Selection indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(isSelected ? Color.accent : Color.clear)
                .frame(width: 3, height: 20)

            // Folder icon with background
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.accent.opacity(0.12))
                    .frame(width: 22, height: 22)

                Image(systemName: "folder.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.accent)
            }

            Text(repo.name)
                .font(.headlineSmall)
                .foregroundColor(isSelected ? .textPrimary : .textSecondary)

            Spacer()

            // Hover actions
            if isHovering {
                HStack(spacing: 2) {
                    Button(action: onAdd) {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.accent)
                            .frame(width: 18, height: 18)
                            .background(Color.accentLight)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)

                    Button(action: onRemove) {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.textTertiary)
                            .frame(width: 18, height: 18)
                            .background(Color.bgHover)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.bgSelected : (isHovering ? Color.bgHover : Color.bgSubtle.opacity(0.5)))
        )
        .padding(.horizontal, Spacing.sm)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { isHovering = $0 }
        .animation(.quick, value: isSelected)
        .animation(.quick, value: isHovering)
    }
}

// MARK: - Drop Indicator

struct RepoDropIndicator: View {
    var body: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(Color.accent.opacity(0.6))
                .frame(width: 5, height: 5)
            Rectangle()
                .fill(Color.accent.opacity(0.4))
                .frame(height: 1.5)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 2)
    }
}

struct WorktreeDropIndicator: View {
    var body: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(Color.accent.opacity(0.6))
                .frame(width: 5, height: 5)
            Rectangle()
                .fill(Color.accent.opacity(0.4))
                .frame(height: 1.5)
        }
        .padding(.leading, Spacing.xl)
        .padding(.trailing, Spacing.sm)
        .padding(.vertical, 2)
    }
}

// MARK: - Worktree List Row

struct WorktreeListRow: View {
    let worktree: Worktree
    let isSelected: Bool
    var isDragging: Bool = false
    let onSelect: () -> Void
    let onArchive: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Indent spacer + branch indicator
            HStack(spacing: 0) {
                // Tree connector line
                Rectangle()
                    .fill(Color.border)
                    .frame(width: 1, height: 20)
                    .padding(.leading, 18)

                // Horizontal connector
                Rectangle()
                    .fill(Color.border)
                    .frame(width: 8, height: 1)
            }

            // Selection dot
            Circle()
                .fill(isSelected ? Color.accent : Color.textMuted.opacity(0.5))
                .frame(width: 6, height: 6)

            VStack(alignment: .leading, spacing: 1) {
                Text(worktree.name)
                    .font(.bodyMedium)
                    .foregroundColor(isSelected ? .textPrimary : .textSecondary)

                Text(worktree.branch)
                    .font(.monoSmall)
                    .foregroundColor(.textTertiary)
            }

            Spacer()
        }
        .padding(.trailing, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? Color.bgSelected : (isHovering ? Color.bgHover : Color.clear))
                .padding(.leading, Spacing.xl)
        )
        .overlay(alignment: .trailing) {
            if isHovering && !isDragging {
                HStack(spacing: 3) {
                    Button(action: onArchive) {
                        Image(systemName: "archivebox")
                            .font(.system(size: 10))
                            .foregroundColor(.textTertiary)
                            .frame(width: 20, height: 20)
                            .background(Color.bgSubtle)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundColor(.destructive)
                            .frame(width: 20, height: 20)
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
        .animation(.quick, value: isSelected)
        .animation(.quick, value: isHovering)
        .animation(.quick, value: isDragging)
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
