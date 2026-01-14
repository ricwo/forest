import SwiftUI
import AppKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settingsService = SettingsService.shared
    @State private var forestPath: String = SettingsService.shared.forestDirectory.path
    @State private var showingFolderPicker = false
    @State private var selectedEditor: Editor = SettingsService.shared.defaultEditor
    @State private var selectedTerminal: Terminal = SettingsService.shared.defaultTerminal
    @State private var branchPrefix: String = SettingsService.shared.branchPrefix
    @State private var appearanceMode: AppearanceMode = SettingsService.shared.appearanceMode
    private let originalAppearanceMode: AppearanceMode = SettingsService.shared.appearanceMode

    private var installedTerminals: Set<Terminal> {
        TerminalService.shared.installedTerminals
    }

    var body: some View {
        let _ = settingsService.appearanceRefreshTrigger  // Trigger re-render on appearance change

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
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // Forest Directory
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

                    SubtleDivider()

                    // Default Editor
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        SectionHeader(title: "Default Editor")

                        Text("Opens worktrees with ⌘E")
                            .font(.caption)
                            .foregroundColor(.textTertiary)

                        Menu {
                            ForEach(Editor.allCases) { editor in
                                Button {
                                    selectedEditor = editor
                                } label: {
                                    HStack {
                                        Text(editor.displayName)
                                        if selectedEditor == editor {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: selectedEditor.icon)
                                    .font(.system(size: 12))
                                    .foregroundColor(.accent)
                                    .frame(width: 20)

                                Text(selectedEditor.displayName)
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

                    SubtleDivider()

                    // Default Terminal
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        SectionHeader(title: "Default Terminal")

                        Text("Opens terminals with \u{2318}T")
                            .font(.caption)
                            .foregroundColor(.textTertiary)

                        Menu {
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
                                Image(systemName: selectedTerminal.icon)
                                    .font(.system(size: 12))
                                    .foregroundColor(.accent)
                                    .frame(width: 20)

                                Text(selectedTerminal.displayName)
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

                    SubtleDivider()

                    // Branch Prefix
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        SectionHeader(title: "Branch Prefix")

                        Text("Auto-added when creating new branches")
                            .font(.caption)
                            .foregroundColor(.textTertiary)

                        MinimalTextField(placeholder: "feat/", text: $branchPrefix, isMonospace: true)
                    }

                    SubtleDivider()

                    // Appearance
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        SectionHeader(title: "Appearance")

                        Text("Choose your preferred color scheme")
                            .font(.caption)
                            .foregroundColor(.textTertiary)

                        HStack(spacing: Spacing.sm) {
                            ForEach(AppearanceMode.allCases) { mode in
                                Button {
                                    appearanceMode = mode
                                    applyAppearance(mode)
                                } label: {
                                    VStack(spacing: Spacing.xs) {
                                        Image(systemName: mode.icon)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(appearanceMode == mode ? .accent : .textSecondary)
                                        Text(mode.displayName)
                                            .font(.caption)
                                            .foregroundColor(appearanceMode == mode ? .textPrimary : .textSecondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, Spacing.md)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(appearanceMode == mode ? Color.accentLight : Color.bg)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .strokeBorder(appearanceMode == mode ? Color.accent.opacity(0.3) : Color.border, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.vertical, Spacing.sm)
            }

            Spacer()

            // Footer
            SubtleDivider()

            HStack {
                Button("Cancel") {
                    settingsService.activeAppearance = nil
                    applyAppearance(originalAppearanceMode)
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
        .frame(width: 450, height: 520)
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
        SettingsService.shared.defaultEditor = selectedEditor
        SettingsService.shared.defaultTerminal = selectedTerminal
        SettingsService.shared.branchPrefix = branchPrefix
        SettingsService.shared.appearanceMode = appearanceMode
        settingsService.activeAppearance = nil  // Clear preview, saved value now matches
        dismiss()
    }

    private func applyAppearance(_ mode: AppearanceMode) {
        // Set active appearance for preview
        settingsService.activeAppearance = mode

        let appearance: NSAppearance?
        switch mode {
        case .system:
            appearance = nil
        case .light:
            appearance = NSAppearance(named: .aqua)
        case .dark:
            appearance = NSAppearance(named: .darkAqua)
        }

        NSApp.appearance = appearance
        for window in NSApp.windows {
            window.appearance = appearance
            window.invalidateShadow()
            window.displayIfNeeded()
        }
        settingsService.appearanceRefreshTrigger += 1
    }
}

#Preview {
    SettingsView()
}
