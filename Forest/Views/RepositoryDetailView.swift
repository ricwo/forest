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

    // MARK: - Settings Section

    private var installedTerminals: Set<Terminal> {
        TerminalService.shared.installedTerminals
    }

    private var effectiveTerminal: Terminal {
        selectedTerminal ?? SettingsService.shared.defaultTerminal
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader(title: "Project Settings")

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Default Terminal")
                    .font(.bodyMedium)
                    .foregroundColor(.textSecondary)

                Text("Use a different terminal for this project")
                    .font(.caption)
                    .foregroundColor(.textTertiary)

                Menu {
                    // "Use Global Default" option
                    Button {
                        selectedTerminal = nil
                        appState.setDefaultTerminal(nil, for: repository.id)
                    } label: {
                        HStack {
                            Text("Global Default (\(SettingsService.shared.defaultTerminal.displayName))")
                            if selectedTerminal == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }

                    Divider()

                    // Individual terminal options
                    ForEach(Terminal.allCases) { terminal in
                        Button {
                            if installedTerminals.contains(terminal) {
                                selectedTerminal = terminal
                                appState.setDefaultTerminal(terminal, for: repository.id)
                            }
                        } label: {
                            HStack {
                                Text(terminal.displayName)
                                if !installedTerminals.contains(terminal) {
                                    Text("(not installed)")
                                        .foregroundColor(.secondary)
                                }
                                if selectedTerminal == terminal {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        .disabled(!installedTerminals.contains(terminal))
                    }
                } label: {
                    HStack {
                        Image(systemName: effectiveTerminal.icon)
                            .font(.system(size: 12))
                            .foregroundColor(.accent)
                            .frame(width: 20)

                        Text(selectedTerminal?.displayName ?? "Global Default")
                            .font(.bodyRegular)
                            .foregroundColor(.textPrimary)

                        Spacer()

                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.textTertiary)
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, 10)
                    .background(Color.bg)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.border, lineWidth: 1)
                    )
                }
                .menuStyle(.borderlessButton)
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Claude Command")
                    .font(.bodyMedium)
                    .foregroundColor(.textSecondary)

                Text("Custom command to launch Claude (e.g., claude-work)")
                    .font(.caption)
                    .foregroundColor(.textTertiary)

                HStack {
                    TextField("claude", text: $claudeCommand)
                        .textFieldStyle(.plain)
                        .font(.mono)
                        .foregroundColor(.textPrimary)
                        .onSubmit {
                            saveClaudeCommand()
                        }

                    if !claudeCommand.isEmpty {
                        Button {
                            claudeCommand = ""
                            appState.setClaudeCommand(nil, for: repository.id)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 10)
                .background(Color.bg)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.border, lineWidth: 1)
                )
            }

            // Save button - only show when there are unsaved changes
            if hasUnsavedChanges {
                Button {
                    saveClaudeCommand()
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .semibold))
                        Text("Save")
                            .font(.caption)
                    }
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 5)
                }
                .buttonStyle(AccentButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var hasUnsavedChanges: Bool {
        let savedCommand = repository.claudeCommand ?? ""
        return claudeCommand != savedCommand
    }

    private func saveClaudeCommand() {
        appState.setClaudeCommand(claudeCommand.isEmpty ? nil : claudeCommand, for: repository.id)
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

#Preview {
    RepositoryDetailView(
        repository: Repository(name: "my-repo", sourcePath: "/Users/test/my-repo")
    )
    .environment(AppState())
    .frame(width: 500, height: 600)
}
