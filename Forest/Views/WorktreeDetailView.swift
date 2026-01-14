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
        Form {
            Section {
                LabeledContent("Name") {
                    if isEditingName {
                        HStack {
                            TextField("Name", text: $editedName)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 200)
                            Button("Save") {
                                renameWorktree()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.forest)
                            Button("Cancel") {
                                isEditingName = false
                            }
                        }
                    } else {
                        HStack {
                            Text(worktree.name)
                            Spacer()
                            Button("Edit") {
                                editedName = worktree.name
                                isEditingName = true
                            }
                        }
                    }
                }

                LabeledContent("Branch") {
                    if isEditingBranch {
                        HStack {
                            TextField("Branch", text: $editedBranch)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 200)
                            Button("Rename") {
                                renameBranch()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.forest)
                            Button("Cancel") {
                                isEditingBranch = false
                            }
                        }
                    } else {
                        HStack {
                            Text(worktree.branch)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Rename") {
                                editedBranch = worktree.branch
                                isEditingBranch = true
                            }
                        }
                    }
                }

                LabeledContent("Path") {
                    Text(worktree.path)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            } header: {
                Label("Worktree Info", systemImage: "leaf.fill")
            }

            Section {
                HStack(spacing: 16) {
                    Button {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: worktree.path)
                    } label: {
                        Label {
                            HStack(spacing: 4) {
                                Text("Finder")
                                KeyboardShortcutBadge("⌘O")
                            }
                        } icon: {
                            Image(systemName: "folder")
                        }
                    }
                    .keyboardShortcut("o", modifiers: .command)

                    Button {
                        openInITerm()
                    } label: {
                        Label {
                            HStack(spacing: 4) {
                                Text("iTerm")
                                KeyboardShortcutBadge("⌘I")
                            }
                        } icon: {
                            Image(systemName: "terminal")
                        }
                    }
                    .keyboardShortcut("i", modifiers: .command)

                    Button {
                        openInPyCharm()
                    } label: {
                        Label {
                            HStack(spacing: 4) {
                                Text("PyCharm")
                                KeyboardShortcutBadge("⌘P")
                            }
                        } icon: {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                        }
                    }
                    .keyboardShortcut("p", modifiers: .command)
                }
            } header: {
                Label("Open In", systemImage: "bolt.fill")
            }

            Section {
                HStack(spacing: 12) {
                    Button {
                        showArchiveConfirmation = true
                    } label: {
                        Label("Archive", systemImage: "archivebox")
                    }

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            } header: {
                Label("Manage", systemImage: "gearshape")
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(worktree.name)
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
            Text("This worktree will be hidden from the main list but preserved on disk. You can restore it from the Archived section.")
        }
        .alert("Delete Worktree?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteWorktree()
            }
        } message: {
            Text("This will permanently delete \"\(worktree.name)\" and remove it from git. This cannot be undone.")
        }
    }

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

    private func openInITerm() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "iTerm", worktree.path]

        do {
            try process.run()
        } catch {
            errorMessage = "Failed to open iTerm: \(error.localizedDescription)"
        }
    }

    private func openInPyCharm() {
        let possibleApps = [
            "PyCharm",
            "PyCharm CE",
            "PyCharm Professional"
        ]

        for appName in possibleApps {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-a", appName, worktree.path]

            do {
                try process.run()
                return
            } catch {
                continue
            }
        }

        // Fallback to command line tools
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

struct KeyboardShortcutBadge: View {
    let shortcut: String

    init(_ shortcut: String) {
        self.shortcut = shortcut
    }

    var body: some View {
        Text(shortcut)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(.secondary.opacity(0.15))
            .cornerRadius(4)
            .foregroundStyle(.secondary)
    }
}

#Preview {
    WorktreeDetailView(
        worktree: Worktree(name: "feature-auth", branch: "feat/feature-auth", path: "/Users/test/forest/myrepo/feature-auth"),
        repositoryId: UUID()
    )
    .environment(AppState())
}
