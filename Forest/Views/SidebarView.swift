import SwiftUI
import UniformTypeIdentifiers

extension UUID: @retroactive Identifiable {
    public var id: UUID { self }
}

// MARK: - Move Drop Delegate

struct MoveDropDelegate: DropDelegate {
    let prefix: String
    let targetId: UUID
    let items: [UUID]
    let onMove: (Int, Int) -> Void
    let onTargetChange: (UUID?) -> Void
    let isValidDrag: () -> Bool

    func dropEntered(info: DropInfo) {
        guard isValidDrag() else { return }
        withAnimation(.easeOut(duration: 0.15)) {
            onTargetChange(targetId)
        }
    }

    func dropExited(info: DropInfo) {
        withAnimation(.easeOut(duration: 0.15)) {
            onTargetChange(nil)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard isValidDrag() else { return DropProposal(operation: .forbidden) }
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        onTargetChange(nil)

        guard let itemProvider = info.itemProviders(for: [UTType.text]).first else {
            return false
        }

        itemProvider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { data, _ in
            guard let data = data as? Data,
                  let droppedItem = String(data: data, encoding: .utf8),
                  droppedItem.hasPrefix(prefix),
                  let droppedUUID = UUID(uuidString: String(droppedItem.dropFirst(prefix.count))),
                  let fromIndex = items.firstIndex(of: droppedUUID),
                  let toIndex = items.firstIndex(of: targetId),
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
    @State private var draggedWorktreeId: UUID?
    @State private var dropTargetId: UUID?
    @State private var draggedRepoId: UUID?
    @State private var repoDropTargetId: UUID?
    @State private var showUpdateAlert = false
    @State private var showSettings = false

    var body: some View {
        let _ = settingsService.appearanceRefreshTrigger  // Trigger re-render on appearance change

        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Worktrees")
                    .font(.headline)
                    .foregroundColor(.textPrimary)

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
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)

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
                                // Drop indicator above this repo
                                if repoDropTargetId == repo.id && draggedRepoId != repo.id {
                                    RepoDropIndicator()
                                }

                                repoSection(repo)
                                    .draggable("repo:\(repo.id.uuidString)") {
                                        // Drag preview
                                        HStack(spacing: Spacing.sm) {
                                            Image(systemName: "folder.fill")
                                                .font(.system(size: 11))
                                                .foregroundColor(.accent)
                                            Text(repo.name)
                                                .font(.headlineSmall)
                                                .foregroundColor(.textPrimary)
                                        }
                                        .padding(.horizontal, Spacing.md)
                                        .padding(.vertical, Spacing.sm)
                                        .background(Color.bgElevated)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                                        .onAppear { draggedRepoId = repo.id }
                                        .onDisappear {
                                            draggedRepoId = nil
                                            repoDropTargetId = nil
                                        }
                                    }
                                    .onDrop(of: [UTType.text], delegate: MoveDropDelegate(
                                        prefix: "repo:",
                                        targetId: repo.id,
                                        items: sortedRepos.map(\.id),
                                        onMove: { from, to in
                                            appState.moveRepository(from: IndexSet(integer: from), to: to)
                                        },
                                        onTargetChange: { id in repoDropTargetId = id },
                                        isValidDrag: { draggedRepoId != nil }
                                    ))
                                    .opacity(draggedRepoId == repo.id ? 0.4 : 1.0)
                            }

                            // Add divider between repos (not after last)
                            if index < sortedRepos.count - 1 {
                                SubtleDivider()
                                    .padding(.vertical, Spacing.xs)
                            }
                        }
                        .onChange(of: draggedRepoId) { _, newValue in
                            if newValue == nil {
                                repoDropTargetId = nil
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
                    .draggable("worktree:\(worktree.id.uuidString)") {
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
                        .onDisappear {
                            draggedWorktreeId = nil
                            dropTargetId = nil
                        }
                    }
                    .onDrop(of: [UTType.text], delegate: MoveDropDelegate(
                        prefix: "worktree:",
                        targetId: worktree.id,
                        items: worktrees.map(\.id),
                        onMove: { from, to in
                            appState.moveWorktree(in: repo.id, from: IndexSet(integer: from), to: to)
                        },
                        onTargetChange: { id in dropTargetId = id },
                        isValidDrag: { draggedWorktreeId != nil }
                    ))

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

struct RepoDropIndicator: View {
    var body: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(Color.accent)
                .frame(width: 6, height: 6)

            Rectangle()
                .fill(Color.accent)
                .frame(height: 2)
        }
        .padding(.horizontal, Spacing.sm)
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
