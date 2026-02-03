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
    @State private var showRemoveFromForestConfirmation = false
    @State private var claudeSessions: [ClaudeSession] = []
    @State private var currentBranch: String?
    @State private var isValidWorktree: Bool = true

    // Auto-refresh timer (every 3 seconds)
    private let refreshTimer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

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
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // Info section
                    infoSection

                    // Quick actions
                    actionsSection

                    // Claude sessions
                    if !claudeSessions.isEmpty {
                        claudeSessionsSection
                    }

                    // Manage section
                    manageSection

                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.xl)
            }
        }
        .background(Color.bgElevated)
        .onAppear {
            refreshAll()
        }
        .onChange(of: worktree.id) {
            isEditingName = false
            isEditingBranch = false
            errorMessage = nil
            refreshAll()
        }
        .onReceive(refreshTimer) { _ in
            refreshAll()
        }
        .alert("Archive Worktree?", isPresented: $showArchiveConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Archive") {
                appState.archiveWorktree(worktree.id, in: repositoryId)
            }
        } message: {
            Text("The worktree will be hidden from the sidebar but all files remain on disk. You can restore it anytime from the Archived section.")
        }
        .alert("Delete Worktree?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteWorktree()
            }
        } message: {
            Text("This will run `git worktree remove` which permanently deletes the directory at:\n\n\(worktree.path)\n\nThis cannot be undone.")
        }
        .alert("Remove from Forest?", isPresented: $showRemoveFromForestConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                appState.forgetWorktree(worktree, from: repositoryId)
            }
        } message: {
            Text("This worktree is no longer a valid git working tree. Remove it from Forest?\n\nThis only removes it from Forest's list—no files will be deleted.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                // Worktree badge
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 11))
                        .foregroundColor(.textTertiary)

                    Text("WORKTREE")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.textTertiary)
                        .tracking(0.8)
                }

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

                        Text(currentBranch ?? worktree.branch)
                            .font(.mono)
                            .foregroundColor(.textSecondary)

                        Button {
                            editedBranch = currentBranch ?? worktree.branch
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
        VStack(alignment: .leading, spacing: Spacing.xs) {
            // Invalid worktree warning
            if !isValidWorktree {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.yellow)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Invalid Worktree")
                            .font(.captionMedium)
                            .foregroundColor(.textPrimary)

                        Text("This directory is no longer a valid git worktree.")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }

                    Spacer()

                    Button("Remove") {
                        showRemoveFromForestConfirmation = true
                    }
                    .buttonStyle(DestructiveButtonStyle())
                }
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.yellow.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.yellow.opacity(0.3), lineWidth: 1)
                )
            }

            HStack(spacing: Spacing.sm) {
                Text(worktree.path)
                    .font(.monoSmall)
                    .foregroundColor(.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(worktree.path, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10))
                        .foregroundColor(.textMuted)
                }
                .buttonStyle(.plain)
                .help("Copy path")
            }

            if let error = errorMessage {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.destructive)

                    Text(error)
                        .font(.caption)
                        .foregroundColor(.destructive)
                }
            }
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("OPEN IN")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.textMuted)
                .tracking(0.5)

            HStack(spacing: Spacing.sm) {
                CompactActionButton(
                    icon: SettingsService.shared.defaultEditor.icon,
                    label: SettingsService.shared.defaultEditor.displayName,
                    shortcut: "⌘E",
                    action: openInEditor
                )
                .keyboardShortcut("e", modifiers: .command)

                CompactActionButton(icon: "folder", label: "Finder", shortcut: "⌘O") {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: worktree.path)
                }
                .keyboardShortcut("o", modifiers: .command)

                CompactActionButton(icon: "terminal", label: "Terminal", shortcut: "⌘T", action: openInTerminal)
                    .keyboardShortcut("t", modifiers: .command)

                CompactActionButton(icon: "", label: "Claude", shortcut: "⌘N", customImage: "ClaudeLogo", action: startNewClaudeSession)
                    .keyboardShortcut("n", modifiers: .command)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Claude Sessions Section

    private var claudeSessionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("RECENT SESSIONS")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.textMuted)
                .tracking(0.5)

            VStack(spacing: Spacing.xs) {
                ForEach(claudeSessions.prefix(3)) { session in
                    CompactSessionRow(session: session) {
                        continueSession(session)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        .frame(maxWidth: .infinity, alignment: .leading)
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
        appState.deleteWorktree(worktree, from: repositoryId)
    }

    private func openInTerminal() {
        let terminal = appState.getEffectiveTerminal(for: repositoryId)
        if let error = TerminalService.shared.openTerminal(at: worktree.path, preferredTerminal: terminal) {
            errorMessage = error
        }
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

    private func openInEditor() {
        let editor = SettingsService.shared.defaultEditor
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-b", editor.bundleId, worktree.path]

        do {
            try process.run()
        } catch {
            errorMessage = "\(editor.displayName) not found."
        }
    }

    private func refreshAll() {
        loadWorktreeInfo()
        loadClaudeSessions()
    }

    private func loadWorktreeInfo() {
        let worktreeId = worktree.id
        let path = worktree.path
        Task {
            // First check if worktree is valid
            let valid = await GitService.shared.isValidWorktreeAsync(at: path)

            // Only load branch if worktree is valid
            let branch: String? = valid ? await GitService.shared.getCurrentBranchAsync(at: path) : nil

            await MainActor.run {
                // Guard against stale updates if user navigated away
                guard worktree.id == worktreeId else { return }
                isValidWorktree = valid
                currentBranch = branch
            }
        }
    }

    private func loadClaudeSessions() {
        claudeSessions = ClaudeSessionService.shared.getSessions(for: worktree.path)
    }

    private func continueSession(_ session: ClaudeSession) {
        let cmd = appState.getEffectiveClaudeCommand(for: repositoryId)
        runInTerminal("cd '\(worktree.path)' && \(cmd) -r '\(session.id)'")
    }

    private func startNewClaudeSession() {
        let cmd = appState.getEffectiveClaudeCommand(for: repositoryId)
        runInTerminal("cd '\(worktree.path)' && \(cmd)")
    }

    private func runInTerminal(_ script: String) {
        let terminal = appState.getEffectiveTerminal(for: repositoryId)
        if let error = TerminalService.shared.runInTerminal(script, preferredTerminal: terminal) {
            errorMessage = error
        }
    }
}

// MARK: - Claude Session Row

struct ClaudeSessionRow: View {
    let session: ClaudeSession
    let onContinue: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onContinue) {
            HStack(spacing: Spacing.md) {
                // Logo with subtle background
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.bgSubtle)
                        .frame(width: 32, height: 32)

                    Image("ClaudeLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(session.title)
                        .font(.bodyMedium)
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    HStack(spacing: Spacing.xs) {
                        Text(session.relativeTime)
                            .font(.caption)
                            .foregroundColor(.textTertiary)

                        Circle()
                            .fill(Color.textMuted)
                            .frame(width: 3, height: 3)

                        Text("\(session.messageCount) msgs")
                            .font(.caption)
                            .foregroundColor(.textTertiary)

                        if let branch = session.primaryBranch {
                            Circle()
                                .fill(Color.textMuted)
                                .frame(width: 3, height: 3)

                            Text(branch)
                                .font(.monoSmall)
                                .foregroundColor(.textTertiary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                // Continue indicator
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isHovering ? .accent : .textMuted)
                    .padding(6)
                    .background(
                        Circle()
                            .fill(isHovering ? Color.accentLight : Color.clear)
                    )
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isHovering ? Color.bgHover : Color.bgSubtle)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isHovering ? Color.accent.opacity(0.2) : Color.border.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.snappy, value: isHovering)
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let icon: String
    let label: String
    let shortcut: String
    let action: () -> Void
    var customImage: String?
    var iconColor: Color?

    @State private var isHovering = false
    @State private var isPressed = false

    // App-specific icon colors for a cohesive look
    private var resolvedIconColor: Color {
        if let color = iconColor { return color }
        switch label {
        case "Finder": return Color(hex: "4A90D9")  // macOS Finder blue
        case "Terminal": return Color(hex: "2E2E2E")  // Dark terminal
        default: return .accent
        }
    }

    private var resolvedBackgroundColor: Color {
        switch label {
        case "Finder": return Color(hex: "4A90D9").opacity(0.1)
        case "Terminal": return Color(hex: "2E2E2E").opacity(0.08)
        default: return Color.accentLight
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.sm) {
                ZStack {
                    // Icon background with app-specific tint
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isHovering ? resolvedBackgroundColor : Color.bgSubtle)
                        .frame(width: 40, height: 40)

                    // Subtle inner shadow for depth
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.4), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                        .frame(width: 40, height: 40)

                    if let imageName = customImage {
                        Image(imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                    } else {
                        // Use filled icons for better visual weight
                        Image(systemName: filledIcon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(
                                isHovering
                                    ? resolvedIconColor
                                    : resolvedIconColor.opacity(0.7)
                            )
                    }
                }

                Text(label)
                    .font(.captionMedium)
                    .foregroundColor(isHovering ? .textPrimary : .textSecondary)

                ShortcutBadge(shortcut)
            }
            .frame(width: 80, height: 94)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.bgElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isHovering ? resolvedIconColor.opacity(0.3) : Color.border,
                        lineWidth: isHovering ? 1.5 : 1
                    )
            )
            .subtleShadow()
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.96 : (isHovering ? 1.02 : 1))
        .onHover { isHovering = $0 }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .animation(.snappy, value: isHovering)
        .animation(.quick, value: isPressed)
    }

    // Map to filled variants for better visual presence
    private var filledIcon: String {
        switch icon {
        case "folder": return "folder.fill"
        case "terminal": return "terminal.fill"
        default: return icon
        }
    }
}

// MARK: - Compact Action Button

private struct CompactActionButton: View {
    let icon: String
    let label: String
    let shortcut: String
    var customImage: String?
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isHovering ? Color.bgHover : Color.bgSubtle)
                        .frame(width: 36, height: 36)

                    if let imageName = customImage {
                        Image(imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 14))
                            .foregroundColor(isHovering ? .accent : .textSecondary)
                    }
                }

                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(isHovering ? .textPrimary : .textTertiary)
            }
            .frame(width: 56)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Compact Session Row

private struct CompactSessionRow: View {
    let session: ClaudeSession
    let onContinue: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onContinue) {
            HStack(spacing: Spacing.sm) {
                Image("ClaudeLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
                    .opacity(0.8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.title)
                        .font(.caption)
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    HStack(spacing: Spacing.xs) {
                        Text(session.relativeTime)
                            .font(.system(size: 10))
                            .foregroundColor(.textTertiary)

                        Circle()
                            .fill(Color.textMuted)
                            .frame(width: 2, height: 2)

                        Text("\(session.messageCount) msgs")
                            .font(.system(size: 10))
                            .foregroundColor(.textTertiary)
                    }
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 10))
                    .foregroundColor(isHovering ? .accent : .textMuted)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovering ? Color.bgHover : Color.bgSubtle)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
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
