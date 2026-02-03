import SwiftUI

struct RepositoryDetailView: View {
    @Environment(AppState.self) private var appState
    let repository: Repository

    @State private var currentBranch: String?
    @State private var errorMessage: String?
    @State private var claudeSessions: [ClaudeSession] = []
    @State private var showSettings = false

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
        .onChange(of: repository.id) {
            errorMessage = nil
            refreshAll()
        }
        .sheet(isPresented: $showSettings) {
            RepositorySettingsSheet(repository: repository)
        }
        .onReceive(refreshTimer) { _ in
            refreshAll()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                // Repository badge
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.accent)

                    Text("REPOSITORY")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.accent)
                        .tracking(0.8)
                }

                Text(repository.name)
                    .font(.displayMedium)
                    .foregroundColor(.textPrimary)

                if let branch = currentBranch {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "arrow.branch")
                            .font(.system(size: 11))
                            .foregroundColor(.accent)

                        Text(branch)
                            .font(.mono)
                            .foregroundColor(.textSecondary)
                    }
                }
            }

            Spacer()

            FetchButton(repoId: repository.id)

            Button {
                showSettings = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 11))
                    Text("Settings")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.accentLight)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Project Settings")
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.sm) {
                Text(repository.sourcePath)
                    .font(.monoSmall)
                    .foregroundColor(.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(repository.sourcePath, forType: .string)
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
                CompactActionButton(icon: "folder", label: "Finder", shortcut: "⌘O") {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: repository.sourcePath)
                }
                .keyboardShortcut("o", modifiers: .command)

                CompactActionButton(icon: "terminal", label: "Terminal", shortcut: "⌘T", action: openInTerminal)
                    .keyboardShortcut("t", modifiers: .command)

                CompactActionButton(icon: "", label: "PyCharm", shortcut: "⌘P", customImage: "PyCharmLogo", action: openInPyCharm)
                    .keyboardShortcut("p", modifiers: .command)

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

            VStack(spacing: 2) {
                ForEach(claudeSessions.prefix(3)) { session in
                    CompactSessionRow(session: session) {
                        continueSession(session)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Actions

    private func refreshAll() {
        loadBranch()
        loadClaudeSessions()
    }

    private func loadBranch() {
        // Only load branch if repository source path exists
        guard FileManager.default.fileExists(atPath: repository.sourcePath) else {
            currentBranch = nil
            return
        }
        // Use async to avoid blocking main thread during SwiftUI updates
        // which can cause run loop re-entrancy crashes
        let repoId = repository.id
        let path = repository.sourcePath
        Task {
            let branch = await GitService.shared.getCurrentBranchAsync(at: path)
            await MainActor.run {
                // Guard against stale updates if user navigated away
                guard repository.id == repoId else { return }
                currentBranch = branch
            }
        }
    }

    private func loadClaudeSessions() {
        claudeSessions = ClaudeSessionService.shared.getSessions(for: repository.sourcePath)
    }

    private func openInTerminal() {
        let terminal = appState.getEffectiveTerminal(for: repository.id)
        if let error = TerminalService.shared.openTerminal(at: repository.sourcePath, preferredTerminal: terminal) {
            errorMessage = error
        }
    }

    private func openInPyCharm() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "charm '\(repository.sourcePath)' || pycharm '\(repository.sourcePath)'"]

        do {
            try process.run()
        } catch {
            errorMessage = "PyCharm not found. Install from jetbrains.com or use Toolbox."
        }
    }

    private func continueSession(_ session: ClaudeSession) {
        let cmd = appState.getEffectiveClaudeCommand(for: repository.id)
        runInTerminal("cd '\(repository.sourcePath)' && \(cmd) -r '\(session.id)'")
    }

    private func startNewClaudeSession() {
        let cmd = appState.getEffectiveClaudeCommand(for: repository.id)
        runInTerminal("cd '\(repository.sourcePath)' && \(cmd)")
    }

    private func runInTerminal(_ script: String) {
        let terminal = appState.getEffectiveTerminal(for: repository.id)
        if let error = TerminalService.shared.runInTerminal(script, preferredTerminal: terminal) {
            errorMessage = error
        }
    }
}

// MARK: - Fetch Button

private struct FetchButton: View {
    @Environment(AppState.self) private var appState
    let repoId: UUID

    @State private var showPopover = false

    private var status: FetchStatus {
        appState.fetchStatus(for: repoId)
    }

    var body: some View {
        Button {
            handleTap()
        } label: {
            HStack(spacing: 5) {
                switch status {
                case .idle:
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11))
                    Text("Fetch")
                        .font(.system(size: 11, weight: .medium))
                case .fetching:
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.7)
                    Text("Fetching...")
                        .font(.system(size: 11, weight: .medium))
                case .success:
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Fetched")
                        .font(.system(size: 11, weight: .medium))
                case .warning:
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                    Text("Fetched")
                        .font(.system(size: 11, weight: .medium))
                case .error:
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                    Text("Failed")
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(status == .fetching)
        .help(helpText)
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            popoverContent
        }
    }

    private var foregroundColor: Color {
        switch status {
        case .idle: return .accent
        case .fetching: return .textTertiary
        case .success: return .success
        case .warning: return .warning
        case .error: return .destructive
        }
    }

    private var backgroundColor: Color {
        switch status {
        case .idle: return .accentLight
        case .fetching: return Color.bgSubtle
        case .success: return Color.success.opacity(0.1)
        case .warning: return Color.warning.opacity(0.1)
        case .error: return Color.destructive.opacity(0.1)
        }
    }

    private var helpText: String {
        switch status {
        case .idle: return "Fetch from all remotes"
        case .fetching: return "Fetching..."
        case .success: return "Fetch complete"
        case .warning(let msg): return msg
        case .error(let msg): return msg
        }
    }

    private func handleTap() {
        switch status {
        case .idle:
            Task { await appState.fetchRepository(repoId) }
        case .warning, .error:
            showPopover = true
        case .fetching, .success:
            break
        }
    }

    @ViewBuilder
    private var popoverContent: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            switch status {
            case .warning(let msg):
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.warning)
                        .font(.system(size: 12))
                    Text(msg)
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
            case .error(let msg):
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.destructive)
                        .font(.system(size: 12))
                    Text(msg)
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                Button {
                    showPopover = false
                    Task { await appState.fetchRepository(repoId) }
                } label: {
                    Text("Retry")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            default:
                EmptyView()
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: 280)
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

                        if let branch = session.primaryBranch {
                            Circle()
                                .fill(Color.textMuted)
                                .frame(width: 2, height: 2)

                            Text(branch)
                                .font(.monoSmall)
                                .foregroundColor(.textTertiary)
                                .lineLimit(1)
                        }
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
    RepositoryDetailView(
        repository: Repository(name: "my-repo", sourcePath: "/Users/test/my-repo")
    )
    .environment(AppState())
    .frame(width: 500, height: 600)
}
