import SwiftUI

struct RepositoryDetailView: View {
    @Environment(AppState.self) private var appState
    let repository: Repository

    @State private var currentBranch: String?
    @State private var errorMessage: String?
    @State private var claudeSessions: [ClaudeSession] = []

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
                VStack(alignment: .leading, spacing: Spacing.xxl) {
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

                Text(repository.sourcePath)
                    .font(.mono)
                    .foregroundColor(.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)

                Spacer()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(repository.sourcePath, forType: .string)
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
                    shortcut: "⌘O",
                    action: {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: repository.sourcePath)
                    }
                )
                .keyboardShortcut("o", modifiers: .command)

                ActionButton(
                    icon: "terminal",
                    label: "Terminal",
                    shortcut: "⌘T",
                    action: openInTerminal
                )
                .keyboardShortcut("t", modifiers: .command)

                ActionButton(
                    icon: "",
                    label: "PyCharm",
                    shortcut: "⌘P",
                    action: openInPyCharm,
                    customImage: "PyCharmLogo"
                )
                .keyboardShortcut("p", modifiers: .command)

                ActionButton(
                    icon: "",
                    label: "Claude",
                    shortcut: "⌘N",
                    action: startNewClaudeSession,
                    customImage: "ClaudeLogo"
                )
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Claude Sessions Section

    private var claudeSessionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader(title: "Claude Sessions")

            VStack(spacing: Spacing.xs) {
                ForEach(claudeSessions.prefix(5)) { session in
                    ClaudeSessionRow(session: session) {
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
        currentBranch = GitService.shared.getCurrentBranch(at: repository.sourcePath)
    }

    private func loadClaudeSessions() {
        claudeSessions = ClaudeSessionService.shared.getSessions(for: repository.sourcePath)
    }

    private func openInTerminal() {
        let apps = ["iTerm", "Terminal"]

        for app in apps {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-a", app, repository.sourcePath]

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
        runInTerminal("cd '\(repository.sourcePath)' && claude -r '\(session.id)'")
    }

    private func startNewClaudeSession() {
        runInTerminal("cd '\(repository.sourcePath)' && claude")
    }

    private func runInTerminal(_ script: String) {
        let apps = ["iTerm", "Terminal"]

        for app in apps {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")

            if app == "iTerm" {
                process.arguments = [
                    "-e", """
                        tell application "iTerm"
                            activate
                            if (count of windows) = 0 then
                                create window with default profile
                            else
                                tell current window
                                    create tab with default profile
                                end tell
                            end if
                            tell current session of current window
                                write text "\(script)"
                            end tell
                        end tell
                    """
                ]
            } else {
                process.arguments = [
                    "-e", """
                        tell application "Terminal"
                            activate
                            do script "\(script)"
                        end tell
                    """
                ]
            }

            do {
                try process.run()
                return
            } catch {
                continue
            }
        }

        errorMessage = "Could not open terminal"
    }
}

#Preview {
    RepositoryDetailView(
        repository: Repository(name: "my-repo", sourcePath: "/Users/test/my-repo")
    )
    .environment(AppState())
    .frame(width: 500, height: 600)
}
