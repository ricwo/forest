import SwiftUI

struct AddWorktreeSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let repositoryId: UUID

    @State private var worktreeName: String = ""
    @State private var branchName: String = ""
    @State private var createNewBranch: Bool = true
    @State private var existingBranches: [String] = []
    @State private var selectedExistingBranch: String = ""
    @State private var errorMessage: String?
    @State private var isCreating = false
    @State private var hasManuallyEditedBranch = false

    private var repository: Repository? {
        appState.repositories.first { $0.id == repositoryId }
    }

    private var isValid: Bool {
        !worktreeName.isEmpty &&
        (createNewBranch ? !branchName.isEmpty : !selectedExistingBranch.isEmpty)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: Spacing.sm) {
                Image(systemName: "plus.square.on.square")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(.accent)

                Text("New Worktree")
                    .font(.displayMedium)
                    .foregroundColor(.textPrimary)

                if let repo = repository {
                    Text("in \(repo.name)")
                        .font(.bodyRegular)
                        .foregroundColor(.textSecondary)
                }
            }
            .padding(.top, Spacing.xl)
            .padding(.bottom, Spacing.lg)

            // Content
            VStack(spacing: Spacing.lg) {
                // Worktree name
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    SectionHeader(title: "Name")

                    MinimalTextField(placeholder: "my-feature", text: $worktreeName)
                        .onChange(of: worktreeName) { _, newValue in
                            let sanitized = newValue.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
                            if sanitized != newValue {
                                worktreeName = sanitized
                            }
                            if !hasManuallyEditedBranch && createNewBranch {
                                branchName = sanitized.isEmpty ? "" : "feat/\(sanitized)"
                            }
                        }

                    if let repo = repository {
                        Text("~/forest/\(repo.name)/\(worktreeName.isEmpty ? "..." : worktreeName)")
                            .font(.caption)
                            .foregroundColor(.textTertiary)
                    }
                }

                // Branch
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    SectionHeader(title: "Branch")

                    // Toggle
                    HStack(spacing: 0) {
                        BranchToggleButton(
                            title: "New branch",
                            isSelected: createNewBranch
                        ) {
                            createNewBranch = true
                            if !hasManuallyEditedBranch && !worktreeName.isEmpty {
                                branchName = "feat/\(worktreeName)"
                            }
                        }

                        BranchToggleButton(
                            title: "Existing",
                            isSelected: !createNewBranch
                        ) {
                            createNewBranch = false
                        }
                    }
                    .background(Color.bg)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.border, lineWidth: 1)
                    )

                    if createNewBranch {
                        MinimalTextField(placeholder: "feat/my-feature", text: $branchName, isMonospace: true)
                            .onChange(of: branchName) { _, newValue in
                                let expectedAuto = "feat/\(worktreeName)"
                                if newValue != expectedAuto && !newValue.isEmpty {
                                    hasManuallyEditedBranch = true
                                }
                            }
                    } else {
                        Menu {
                            ForEach(existingBranches, id: \.self) { branch in
                                Button(branch) {
                                    selectedExistingBranch = branch
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedExistingBranch.isEmpty ? "Select branch" : selectedExistingBranch)
                                    .font(selectedExistingBranch.isEmpty ? .bodyRegular : .mono)
                                    .foregroundColor(selectedExistingBranch.isEmpty ? .textTertiary : .textSecondary)

                                Spacer()

                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.textTertiary)
                            }
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, 10)
                            .background(Color.bgElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(Color.border, lineWidth: 1)
                            )
                        }
                        .menuStyle(.borderlessButton)
                    }
                }

                // Error
                if let error = errorMessage {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.destructive)

                        Text(error)
                            .font(.caption)
                            .foregroundColor(.destructive)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
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

                Button("Create Worktree") {
                    createWorktree()
                }
                .buttonStyle(AccentButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid || isCreating)
            }
            .padding(Spacing.lg)
        }
        .frame(width: 400, height: 420)
        .background(Color.bgElevated)
        .onAppear {
            loadBranches()
        }
    }

    private func loadBranches() {
        guard let repo = repository else { return }
        existingBranches = GitService.shared.listBranches(at: repo.sourcePath)
    }

    private func createWorktree() {
        guard let repo = repository else { return }
        isCreating = true
        errorMessage = nil

        let branch = createNewBranch ? branchName : selectedExistingBranch

        do {
            try appState.createWorktree(
                in: repo.id,
                name: worktreeName,
                branch: branch,
                createNewBranch: createNewBranch
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isCreating = false
        }
    }
}

// MARK: - Branch Toggle Button

struct BranchToggleButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.captionMedium)
                .foregroundColor(isSelected ? .textPrimary : .textTertiary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(isSelected ? Color.bgHover : Color.clear)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AddWorktreeSheet(repositoryId: UUID())
        .environment(AppState())
}
