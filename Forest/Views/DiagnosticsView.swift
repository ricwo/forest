import SwiftUI
import AppKit

enum DiagnosticFilter: String, CaseIterable {
    case all = "All"
    case logs = "Logs"
    case crashes = "Crashes"
    case errorsOnly = "Errors"
}

struct DiagnosticsView: View {
    @Environment(\.dismiss) private var dismiss
    private var logService: LogService { LogService.shared }
    private var crashService: CrashReportService { CrashReportService.shared }
    @State private var filter: DiagnosticFilter = .all
    @State private var selectedCrash: CrashReport?
    @State private var searchText = ""

    private var filteredLogs: [LogEntry] {
        var logs = logService.recentEntries

        if filter == .errorsOnly {
            logs = logs.filter { $0.level == .error || $0.level == .warning }
        }

        if !searchText.isEmpty {
            logs = logs.filter {
                $0.message.localizedCaseInsensitiveContains(searchText) ||
                $0.category.localizedCaseInsensitiveContains(searchText)
            }
        }

        return logs.reversed()
    }

    private var filteredCrashes: [CrashReport] {
        var crashes = crashService.crashReports

        if !searchText.isEmpty {
            crashes = crashes.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                ($0.reason?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        return crashes
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: Spacing.sm) {
                Image(systemName: "stethoscope")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(.accent)

                Text("Diagnostics")
                    .font(.displayMedium)
                    .foregroundColor(.textPrimary)
            }
            .padding(.top, Spacing.xl)
            .padding(.bottom, Spacing.lg)

            // Filter & Search
            VStack(spacing: Spacing.md) {
                // Filter pills
                HStack(spacing: Spacing.sm) {
                    ForEach(DiagnosticFilter.allCases, id: \.self) { filterOption in
                        FilterPill(
                            title: filterOption.rawValue,
                            isSelected: filter == filterOption,
                            count: countFor(filterOption)
                        ) {
                            withAnimation(.snappy) {
                                filter = filterOption
                            }
                        }
                    }
                    Spacer()
                }

                // Search
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundColor(.textTertiary)

                    TextField("Search logs and crashes...", text: $searchText)
                        .font(.bodyRegular)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 8)
                .background(Color.bg)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.border, lineWidth: 1)
                )
            }
            .padding(.horizontal, Spacing.xl)

            // Content
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.sm) {
                    if filter == .all || filter == .crashes {
                        if !filteredCrashes.isEmpty {
                            SectionHeader(title: "Crash Reports", icon: "xmark.octagon")
                                .padding(.top, Spacing.md)

                            ForEach(filteredCrashes) { crash in
                                CrashReportRow(crash: crash) {
                                    selectedCrash = crash
                                }
                            }
                        }
                    }

                    if filter == .all || filter == .logs || filter == .errorsOnly {
                        if !filteredLogs.isEmpty {
                            SectionHeader(title: "Logs", icon: "doc.text")
                                .padding(.top, Spacing.md)

                            ForEach(filteredLogs) { entry in
                                LogEntryRow(entry: entry)
                            }
                        }
                    }

                    if filteredLogs.isEmpty && filteredCrashes.isEmpty {
                        EmptyDiagnosticsView()
                    }
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.vertical, Spacing.md)
            }

            Spacer()

            // Footer
            SubtleDivider()

            HStack {
                Button("Open Logs Folder") {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: logService.logsDirectoryPath)
                }
                .buttonStyle(GhostButtonStyle())

                Spacer()

                Button("Clear All") {
                    logService.clearLogs()
                    crashService.clearCrashReports()
                }
                .buttonStyle(GhostButtonStyle(color: .destructive))

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(AccentButtonStyle())
                .keyboardShortcut(.defaultAction)
            }
            .padding(Spacing.lg)
        }
        .frame(width: 600, height: 550)
        .background(Color.bgElevated)
        .sheet(item: $selectedCrash) { crash in
            CrashDetailView(crash: crash)
        }
    }

    private func countFor(_ filter: DiagnosticFilter) -> Int? {
        switch filter {
        case .all:
            return nil
        case .logs:
            return logService.recentEntries.count
        case .crashes:
            let count = crashService.crashReports.count
            return count > 0 ? count : nil
        case .errorsOnly:
            let count = logService.recentEntries.filter { $0.level == .error || $0.level == .warning }.count
            return count > 0 ? count : nil
        }
    }
}

// MARK: - Supporting Views

struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let count: Int?
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Text(title)
                    .font(.captionMedium)

                if let count = count, count > 0 {
                    Text("\(count)")
                        .font(.caption)
                        .foregroundColor(isSelected ? .accent : .textTertiary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.accentLight : Color.bgSubtle)
                        )
                }
            }
            .foregroundColor(isSelected ? .accent : .textSecondary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentLight : (isHovering ? Color.bgHover : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? Color.accent.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

struct LogEntryRow: View {
    let entry: LogEntry

    private var levelColor: Color {
        switch entry.level {
        case .debug: return .textTertiary
        case .info: return .accent
        case .warning: return .warning
        case .error: return .destructive
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: entry.level.icon)
                .font(.system(size: 10))
                .foregroundColor(levelColor)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Spacing.sm) {
                    Text(entry.category)
                        .font(.captionMedium)
                        .foregroundColor(.textSecondary)

                    Text(formatTime(entry.timestamp))
                        .font(.caption)
                        .foregroundColor(.textTertiary)
                }

                Text(entry.message)
                    .font(.mono)
                    .foregroundColor(.textPrimary)
                    .lineLimit(3)
            }

            Spacer()
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.bgSubtle)
        )
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

struct CrashReportRow: View {
    let crash: CrashReport
    let onTap: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.md) {
                Image(systemName: "xmark.octagon.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.destructive)

                VStack(alignment: .leading, spacing: 2) {
                    Text(crash.title)
                        .font(.bodyMedium)
                        .foregroundColor(.textPrimary)

                    HStack(spacing: Spacing.sm) {
                        Text(crash.relativeTime)
                            .font(.caption)
                            .foregroundColor(.textTertiary)

                        if let reason = crash.reason {
                            Text("•")
                                .foregroundColor(.textMuted)
                            Text(reason)
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.textTertiary)
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovering ? Color.destructiveLight : Color.bgSubtle)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.border, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

struct CrashDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let crash: CrashReport

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(crash.title)
                        .font(.headline)
                        .foregroundColor(.textPrimary)

                    Text(crash.relativeTime)
                        .font(.caption)
                        .foregroundColor(.textTertiary)
                }

                Spacer()

                Button {
                    if let url = CrashReportService.shared.exportCrashReport(crash) {
                        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .buttonStyle(GhostButtonStyle())
            }
            .padding(Spacing.lg)
            .background(Color.bgElevated)

            SubtleDivider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // Info section
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        SectionHeader(title: "Details")

                        InfoRow(label: "App Version", value: crash.appVersion)
                        InfoRow(label: "OS Version", value: crash.osVersion)

                        if let reason = crash.reason {
                            InfoRow(label: "Reason", value: reason)
                        }
                    }

                    // Stack trace
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        SectionHeader(title: "Stack Trace")

                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(crash.stackTrace.enumerated()), id: \.offset) { index, frame in
                                Text("\(index): \(frame)")
                                    .font(.monoSmall)
                                    .foregroundColor(.textSecondary)
                                    .textSelection(.enabled)
                            }
                        }
                        .padding(Spacing.md)
                        .background(Color.bg)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
                .padding(Spacing.lg)
            }

            SubtleDivider()

            // Footer
            HStack {
                Button("Delete Report") {
                    CrashReportService.shared.deleteCrashReport(crash)
                    dismiss()
                }
                .buttonStyle(GhostButtonStyle(color: .destructive))

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(AccentButtonStyle())
                .keyboardShortcut(.defaultAction)
            }
            .padding(Spacing.lg)
        }
        .frame(width: 550, height: 450)
        .background(Color.bgElevated)
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.textTertiary)
                .frame(width: 100, alignment: .leading)

            Text(value)
                .font(.bodyRegular)
                .foregroundColor(.textPrimary)
                .textSelection(.enabled)
        }
    }
}

struct EmptyDiagnosticsView: View {
    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(.accent)

            Text("All Clear")
                .font(.headline)
                .foregroundColor(.textPrimary)

            Text("No logs or crash reports to display")
                .font(.caption)
                .foregroundColor(.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxxl)
    }
}

#Preview {
    DiagnosticsView()
}
