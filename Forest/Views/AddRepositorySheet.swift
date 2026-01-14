import SwiftUI

struct AddRepositorySheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPath: String = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "tree.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.forest)

                Text("Add Repository")
                    .font(.headline)

                Text("Select a local git repository to manage with Forest")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top)

            if !selectedPath.isEmpty {
                GroupBox {
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(.forest)
                        Text(selectedPath)
                            .lineLimit(1)
                            .truncationMode(.head)
                        Spacer()
                    }
                }
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Choose Folder...") {
                    chooseFolder()
                }

                if !selectedPath.isEmpty {
                    Button("Add Repository") {
                        addRepository()
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(.forest)
                }
            }
        }
        .padding()
        .frame(width: 400, height: 250)
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

            if !GitService.shared.isGitRepository(at: selectedPath) {
                errorMessage = "This folder is not a git repository"
            }
        }
    }

    private func addRepository() {
        guard !selectedPath.isEmpty else { return }
        guard GitService.shared.isGitRepository(at: selectedPath) else {
            errorMessage = "This folder is not a git repository"
            return
        }

        appState.addRepository(from: selectedPath)
        dismiss()
    }
}

#Preview {
    AddRepositorySheet()
        .environment(AppState())
}
