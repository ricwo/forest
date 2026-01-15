import SwiftUI

struct RepositorySettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    let repository: Repository

    @State private var selectedTerminal: Terminal?
    @State private var claudeCommand: String = ""

    private var installedTerminals: Set<Terminal> {
        TerminalService.shared.installedTerminals
    }

    private var effectiveTerminal: Terminal {
        selectedTerminal ?? SettingsService.shared.defaultTerminal
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Project Settings")
                        .font(.displayMedium)
                        .foregroundColor(.textPrimary)

                    Text(repository.name)
                        .font(.bodyRegular)
                        .foregroundColor(.textSecondary)
                }

                Spacer()
            }
            .padding(Spacing.lg)

            SubtleDivider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    terminalSection
                    claudeCommandSection
                }
                .padding(Spacing.lg)
            }

            Spacer()

            // Footer
            SubtleDivider()

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(GhostButtonStyle())
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    saveSettings()
                }
                .buttonStyle(AccentButtonStyle())
                .keyboardShortcut(.defaultAction)
            }
            .padding(Spacing.lg)
        }
        .frame(width: 400, height: 340)
        .background(Color.bgElevated)
        .onAppear {
            selectedTerminal = repository.defaultTerminal
            claudeCommand = repository.claudeCommand ?? ""
        }
    }

    // MARK: - Terminal Section

    private var terminalSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Default Terminal")
                .font(.bodyMedium)
                .foregroundColor(.textSecondary)

            Text("Use a different terminal for this project")
                .font(.caption)
                .foregroundColor(.textTertiary)

            Menu {
                Button {
                    selectedTerminal = nil
                } label: {
                    HStack {
                        Text("Global Default (\(SettingsService.shared.defaultTerminal.displayName))")
                        if selectedTerminal == nil {
                            Image(systemName: "checkmark")
                        }
                    }
                }

                Divider()

                ForEach(Terminal.allCases) { terminal in
                    Button {
                        if installedTerminals.contains(terminal) {
                            selectedTerminal = terminal
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
    }

    // MARK: - Claude Command Section

    private var claudeCommandSection: some View {
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

                if !claudeCommand.isEmpty {
                    Button {
                        claudeCommand = ""
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
    }

    // MARK: - Actions

    private func saveSettings() {
        appState.setDefaultTerminal(selectedTerminal, for: repository.id)
        appState.setClaudeCommand(claudeCommand.isEmpty ? nil : claudeCommand, for: repository.id)
        dismiss()
    }
}

#Preview {
    RepositorySettingsSheet(
        repository: Repository(name: "my-repo", sourcePath: "/Users/test/my-repo")
    )
    .environment(AppState())
}
