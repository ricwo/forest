import SwiftUI

struct AddRepositorySheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPath: String = ""
    @State private var errorMessage: String?
    @State private var existingWorktrees: [(path: String, branch: String)] = []
    @State private var importWorktrees: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: Spacing.sm) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(.accent)

                Text("Add Repository")
                    .font(.displayMedium)
                    .foregroundColor(.textPrimary)

                Text("Select a local git repository to manage")
                    .font(.bodyRegular)
                    .foregroundColor(.textSecondary)
            }
            .padding(.top, Spacing.xxl)
            .padding(.bottom, Spacing.xl)

            // Content
            VStack(spacing: Spacing.md) {
                if selectedPath.isEmpty {
                    Button {
                        chooseFolder()
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "folder")
                                .font(.system(size: 14))
                            Text("Choose Folder")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SubtleButtonStyle())
                } else {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.accent)

                        Text(selectedPath)
                            .font(.mono)
                            .foregroundColor(.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.head)

                        Spacer()

                        Button {
                            selectedPath = ""
                            errorMessage = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(Spacing.md)
                    .background(Color.accentLight)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.accent.opacity(0.2), lineWidth: 1)
                    )
                }

                if let error = errorMessage {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.destructive)

                        Text(error)
                            .font(.caption)
                            .foregroundColor(.destructive)
                    }
                }

                // Worktree import option
                if !existingWorktrees.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Toggle(isOn: $importWorktrees) {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: "arrow.triangle.branch")
                                    .font(.system(size: 12))
                                    .foregroundColor(.accent)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Import \(existingWorktrees.count) existing worktree\(existingWorktrees.count == 1 ? "" : "s")")
                                        .font(.bodyMedium)
                                        .foregroundColor(.textPrimary)

                                    Text("Move to ~/forest and manage with Forest")
                                        .font(.caption)
                                        .foregroundColor(.textTertiary)
                                }
                            }
                        }
                        .toggleStyle(.checkbox)

                        if importWorktrees {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                ForEach(existingWorktrees, id: \.path) { worktree in
                                    HStack(spacing: Spacing.sm) {
                                        Text(URL(fileURLWithPath: worktree.path).lastPathComponent)
                                            .font(.mono)
                                            .foregroundColor(.textSecondary)

                                        Text("·")
                                            .foregroundColor(.textMuted)

                                        Text(worktree.branch)
                                            .font(.caption)
                                            .foregroundColor(.textTertiary)
                                    }
                                }
                            }
                            .padding(.leading, Spacing.xl)
                        }
                    }
                    .padding(Spacing.md)
                    .background(Color.bg)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.border, lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, Spacing.xl)

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

                if !selectedPath.isEmpty {
                    Button {
                        chooseFolder()
                    } label: {
                        Text("Change")
                    }
                    .buttonStyle(SubtleButtonStyle())
                }

                Button("Add Repository") {
                    addRepository()
                }
                .buttonStyle(AccentButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(selectedPath.isEmpty || errorMessage != nil)
            }
            .padding(Spacing.lg)
        }
        .frame(width: 420, height: existingWorktrees.isEmpty ? 320 : 420)
        .background(Color.bgElevated)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a git repository"

        if panel.runModal() == .OK, let url = panel.url {
            selectedPath = url.path
            errorMessage = nil
            existingWorktrees = []

            if !GitService.shared.isGitRepository(at: selectedPath) {
                errorMessage = "Not a git repository"
            } else {
                // Check for existing worktrees
                existingWorktrees = appState.getExistingWorktrees(for: selectedPath)
            }
        }
    }

    private func addRepository() {
        guard !selectedPath.isEmpty else { return }
        guard GitService.shared.isGitRepository(at: selectedPath) else {
            errorMessage = "Not a git repository"
            return
        }

        appState.addRepository(from: selectedPath)

        // Import existing worktrees if requested
        if importWorktrees && !existingWorktrees.isEmpty {
            if let repo = appState.repositories.first(where: { $0.sourcePath == selectedPath }) {
                do {
                    try appState.importExistingWorktrees(for: repo.id)
                } catch {
                    // Still dismiss, but worktrees won't be imported
                    print("Failed to import worktrees: \(error)")
                }
            }
        }

        dismiss()
    }
}

#Preview {
    AddRepositorySheet()
        .environment(AppState())
}
