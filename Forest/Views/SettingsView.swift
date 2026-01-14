import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var forestPath: String = SettingsService.shared.forestDirectory.path
    @State private var showingFolderPicker = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: Spacing.sm) {
                Image(systemName: "gearshape")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(.accent)

                Text("Settings")
                    .font(.displayMedium)
                    .foregroundColor(.textPrimary)
            }
            .padding(.top, Spacing.xl)
            .padding(.bottom, Spacing.lg)

            // Content
            VStack(alignment: .leading, spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    SectionHeader(title: "Forest Directory")

                    Text("Where worktrees are stored")
                        .font(.caption)
                        .foregroundColor(.textTertiary)

                    HStack(spacing: Spacing.sm) {
                        Text(forestPath)
                            .font(.mono)
                            .foregroundColor(.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, 10)
                            .background(Color.bg)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(Color.border, lineWidth: 1)
                            )

                        Button("Browse...") {
                            showingFolderPicker = true
                        }
                        .buttonStyle(GhostButtonStyle())
                    }
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

                Button("Save") {
                    saveSettings()
                }
                .buttonStyle(AccentButtonStyle())
                .keyboardShortcut(.defaultAction)
            }
            .padding(Spacing.lg)
        }
        .frame(width: 450, height: 280)
        .background(Color.bgElevated)
        .fileImporter(
            isPresented: $showingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                forestPath = url.path
            }
        }
    }

    private func saveSettings() {
        SettingsService.shared.forestDirectory = URL(fileURLWithPath: forestPath)
        dismiss()
    }
}

#Preview {
    SettingsView()
}
