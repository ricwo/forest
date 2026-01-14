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

    private var sanitizedWorktreeName: String {
        worktreeName.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
    }

    private var worktreeNameError: String? {
        if worktreeName.isEmpty { return nil }
        if worktreeName != sanitizedWorktreeName {
            return "Only letters, numbers, hyphens, and underscores allowed"
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField("Worktree Name", text: $worktreeName)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: worktreeName) { _, newValue in
                            // Auto-sanitize input
                            let sanitized = newValue.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
                            if sanitized != newValue {
                                worktreeName = sanitized
                            }
                            // Update branch name if not manually edited
                            if !hasManuallyEditedBranch && createNewBranch {
                                branchName = sanitized.isEmpty ? "" : "feat/\(sanitized)"
                            }
                        }
                    if let error = worktreeNameError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Folder name in ~/forest/\(repository?.name ?? "repo")/")
                }

                Section {
                    Picker("Branch Type", selection: $createNewBranch) {
                        Text("Create new branch").tag(true)
                        Text("Use existing branch").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: createNewBranch) { _, newValue in
                        if newValue && !hasManuallyEditedBranch && !worktreeName.isEmpty {
                            branchName = "feat/\(worktreeName)"
                        }
                    }

                    if createNewBranch {
                        TextField("New Branch Name", text: $branchName)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: branchName) { _, newValue in
                                // Mark as manually edited if user changes it from the auto-generated value
                                let expectedAuto = "feat/\(worktreeName)"
                                if newValue != expectedAuto && !newValue.isEmpty {
                                    hasManuallyEditedBranch = true
                                }
                            }
                    } else {
                        Picker("Existing Branch", selection: $selectedExistingBranch) {
                            Text("Select a branch").tag("")
                            ForEach(existingBranches, id: \.self) { branch in
                                Text(branch).tag(branch)
                            }
                        }
                    }
                } header: {
                    Text("Branch")
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create Worktree") {
                    createWorktree()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(.forest)
                .disabled(!isValid || isCreating)
            }
            .padding()
        }
        .frame(width: 400, height: 340)
        .onAppear {
            loadBranches()
        }
    }

    private var isValid: Bool {
        !worktreeName.isEmpty &&
        worktreeNameError == nil &&
        (createNewBranch ? !branchName.isEmpty : !selectedExistingBranch.isEmpty)
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

#Preview {
    AddWorktreeSheet(repositoryId: UUID())
        .environment(AppState())
}
