import SwiftUI

struct WorktreeDetailView: View {
    @Environment(AppState.self) private var appState
    let worktree: Worktree
    let repositoryId: UUID

    @State private var editedName: String = ""
    @State private var editedBranch: String = ""
    @State private var isEditingName = false
    @State private var isEditingBranch = false
    @State private var errorMessage: String?
    @State private var showDeleteConfirmation = false
    @State private var showArchiveConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.xl)
                .padding(.bottom, Spacing.lg)

            SubtleDivider()

            // Content
            ScrollView {
                VStack(spacing: Spacing.xxl) {
                    // Info section
                    infoSection

                    // Quick actions
                    actionsSection

                    // Manage section
                    manageSection
                }
                .padding(Spacing.xl)
            }
        }
        .background(Color.bgElevated)
        .onChange(of: worktree.id) {
            isEditingName = false
            isEditingBranch = false
            errorMessage = nil
        }
        .alert("Archive Worktree?", isPresented: $showArchiveConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Archive") {
                appState.archiveWorktree(worktree.id, in: repositoryId)
            }
        } message: {
            Text("This worktree will be hidden from the main list but preserved on disk.")
        }
        .alert("Delete Worktree?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteWorktree()
            }
        } message: {
            Text("This will permanently delete \"\(worktree.name)\" and remove it from git.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                if isEditingName {
                    HStack(spacing: Spacing.sm) {
                        MinimalTextField(placeholder: "Name", text: $editedName)
                            .frame(width: 200)

                        Button("Save") { renameWorktree() }
                            .buttonStyle(AccentButtonStyle())

                        Button("Cancel") { isEditingName = false }
                            .buttonStyle(GhostButtonStyle())
                    }
                } else {
                    HStack(spacing: Spacing.sm) {
                        Text(worktree.name)
                            .font(.displayMedium)
                            .foregroundColor(.textPrimary)

                        Button {
                            editedName = worktree.name
                            isEditingName = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 12))
                                .foregroundColor(.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if isEditingBranch {
                    HStack(spacing: Spacing.sm) {
                        MinimalTextField(placeholder: "Branch", text: $editedBranch, isMonospace: true)
                            .frame(width: 200)

                        Button("Save") { renameBranch() }
                            .buttonStyle(AccentButtonStyle())

                        Button("Cancel") { isEditingBranch = false }
                            .buttonStyle(GhostButtonStyle())
                    }
                } else {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "arrow.branch")
                            .font(.system(size: 11))
                            .foregroundColor(.accent)

                        Text(worktree.branch)
                            .font(.mono)
                            .foregroundColor(.textSecondary)

                        Button {
                            editedBranch = worktree.branch
                            isEditingBranch = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 10))
                                .foregroundColor(.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer()
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader(title: "Location")

            HStack(spacing: Spacing.sm) {
                Image(systemName: "folder")
                    .font(.system(size: 12))
                    .foregroundColor(.textTertiary)

                Text(worktree.path)
                    .font(.mono)
                    .foregroundColor(.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)

                Spacer()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(worktree.path, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11))
                        .foregroundColor(.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Copy path")
            }
            .padding(Spacing.md)
            .background(Color.bg)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.border, lineWidth: 1)
            )

            if let error = errorMessage {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.destructive)

                    Text(error)
                        .font(.caption)
                        .foregroundColor(.destructive)
                }
                .padding(.top, Spacing.xs)
            }
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader(title: "Open in")

            HStack(spacing: Spacing.sm) {
                ActionButton(
                    icon: "folder",
                    label: "Finder",
                    shortcut: "⌘O"
                ) {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: worktree.path)
                }
                .keyboardShortcut("o", modifiers: .command)

                ActionButton(
                    icon: "terminal",
                    label: "Terminal",
                    shortcut: "⌘T"
                ) {
                    openInTerminal()
                }
                .keyboardShortcut("t", modifiers: .command)

                ActionButton(
                    icon: "chevron.left.forwardslash.chevron.right",
                    label: "PyCharm",
                    shortcut: "⌘P"
                ) {
                    openInPyCharm()
                }
                .keyboardShortcut("p", modifiers: .command)
            }
        }
    }

    // MARK: - Manage Section

    private var manageSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader(title: "Manage")

            HStack(spacing: Spacing.sm) {
                Button {
                    showArchiveConfirmation = true
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "archivebox")
                            .font(.system(size: 12))
                        Text("Archive")
                    }
                }
                .buttonStyle(SubtleButtonStyle())

                Button {
                    showDeleteConfirmation = true
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                        Text("Delete")
                    }
                }
                .buttonStyle(DestructiveButtonStyle())
            }
        }
    }

    // MARK: - Actions

    private func renameWorktree() {
        do {
            try appState.renameWorktree(worktree.id, in: repositoryId, newName: editedName)
            isEditingName = false
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func renameBranch() {
        do {
            try appState.renameBranch(worktree.id, in: repositoryId, newBranch: editedBranch)
            isEditingBranch = false
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteWorktree() {
        do {
            try appState.deleteWorktree(worktree, from: repositoryId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func openInTerminal() {
        // Try iTerm first, then fall back to Terminal
        let apps = ["iTerm", "Terminal"]

        for app in apps {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-a", app, worktree.path]

            do {
                try process.run()
                return
            } catch {
                continue
            }
        }

        errorMessage = "Could not open terminal"
    }

    private func openInPyCharm() {
        // Try charm (JetBrains Toolbox) or pycharm CLI
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "charm '\(worktree.path)' || pycharm '\(worktree.path)'"]

        do {
            try process.run()
        } catch {
            errorMessage = "PyCharm not found. Install from jetbrains.com or use Toolbox."
        }
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let icon: String
    let label: String
    let shortcut: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(isHovering ? .accent : .textSecondary)

                Text(label)
                    .font(.captionMedium)
                    .foregroundColor(.textSecondary)

                ShortcutBadge(shortcut)
            }
            .frame(width: 80, height: 80)
            .background(isHovering ? Color.bgHover : Color.bg)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isHovering ? Color.accent.opacity(0.3) : Color.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovering)
    }
}

#Preview {
    WorktreeDetailView(
        worktree: Worktree(name: "feature-auth", branch: "feat/feature-auth", path: "/Users/test/forest/myrepo/feature-auth"),
        repositoryId: UUID()
    )
    .environment(AppState())
    .frame(width: 500, height: 600)
}
