import Foundation

struct CrashReport: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let signal: String?
    let exception: String?
    let reason: String?
    let stackTrace: [String]
    let appVersion: String
    let osVersion: String

    init(
        signal: String? = nil,
        exception: String? = nil,
        reason: String? = nil,
        stackTrace: [String] = []
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.signal = signal
        self.exception = exception
        self.reason = reason
        self.stackTrace = stackTrace
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        self.osVersion = ProcessInfo.processInfo.operatingSystemVersionString
    }

    var title: String {
        if let signal = signal {
            return "Signal: \(signal)"
        } else if let exception = exception {
            return exception
        }
        return "Unknown Crash"
    }

    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

@Observable
final class CrashReportService {
    static let shared = CrashReportService()

    private let crashesDirectory: URL
    private let maxCrashReports = 20

    private(set) var crashReports: [CrashReport] = []

    var crashesDirectoryPath: String {
        crashesDirectory.path
    }

    private init() {
        let libraryLogs = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Logs")
            .appendingPathComponent("Forest")
            .appendingPathComponent("Crashes")

        self.crashesDirectory = libraryLogs

        try? FileManager.default.createDirectory(at: crashesDirectory, withIntermediateDirectories: true)

        loadCrashReports()
        setupCrashHandlers()
        checkForPreviousCrash()
    }

    // MARK: - Crash Handlers

    private func setupCrashHandlers() {
        // Store reference to self for signal handler
        CrashReportService.sharedInstance = self

        // Set up Objective-C exception handler
        NSSetUncaughtExceptionHandler { exception in
            CrashReportService.sharedInstance?.handleException(exception)
        }

        // Set up signal handlers for common crash signals
        setupSignalHandler(SIGABRT)
        setupSignalHandler(SIGSEGV)
        setupSignalHandler(SIGBUS)
        setupSignalHandler(SIGFPE)
        setupSignalHandler(SIGILL)
        setupSignalHandler(SIGTRAP)
    }

    private static var sharedInstance: CrashReportService?
    private static var previousSignalHandlers: [Int32: (@convention(c) (Int32) -> Void)?] = [:]

    private func setupSignalHandler(_ signal: Int32) {
        let handler: @convention(c) (Int32) -> Void = { sig in
            CrashReportService.sharedInstance?.handleSignal(sig)

            // Call previous handler if exists
            if let previousHandler = CrashReportService.previousSignalHandlers[sig] {
                previousHandler?(sig)
            }
        }

        CrashReportService.previousSignalHandlers[signal] = Foundation.signal(signal, handler)
    }

    private func handleException(_ exception: NSException) {
        let stackTrace = exception.callStackSymbols

        let report = CrashReport(
            exception: exception.name.rawValue,
            reason: exception.reason,
            stackTrace: stackTrace
        )

        saveCrashReport(report)

        LogService.shared.error(
            "Uncaught exception: \(exception.name.rawValue) - \(exception.reason ?? "no reason")",
            category: "Crash"
        )
    }

    private func handleSignal(_ signal: Int32) {
        let signalName = signalNameFor(signal)
        let stackTrace = Thread.callStackSymbols

        let report = CrashReport(
            signal: signalName,
            stackTrace: stackTrace
        )

        saveCrashReportSync(report)

        LogService.shared.error("Received signal: \(signalName)", category: "Crash")

        // Re-raise the signal to allow default handling (crash)
        Foundation.signal(signal, SIG_DFL)
        raise(signal)
    }

    private func signalNameFor(_ signal: Int32) -> String {
        switch signal {
        case SIGABRT: return "SIGABRT"
        case SIGSEGV: return "SIGSEGV"
        case SIGBUS: return "SIGBUS"
        case SIGFPE: return "SIGFPE"
        case SIGILL: return "SIGILL"
        case SIGTRAP: return "SIGTRAP"
        default: return "Signal \(signal)"
        }
    }

    // MARK: - Persistence

    private func saveCrashReport(_ report: CrashReport) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.saveCrashReportSync(report)
        }
    }

    private func saveCrashReportSync(_ report: CrashReport) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "crash-\(formatter.string(from: report.timestamp)).json"
        let fileURL = crashesDirectory.appendingPathComponent(filename)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        if let data = try? encoder.encode(report) {
            try? data.write(to: fileURL)
        }

        // Also write a human-readable version
        let textFilename = "crash-\(formatter.string(from: report.timestamp)).txt"
        let textFileURL = crashesDirectory.appendingPathComponent(textFilename)
        let textContent = formatCrashReportAsText(report)
        try? textContent.write(to: textFileURL, atomically: true, encoding: .utf8)

        // Mark that we crashed
        UserDefaults.standard.set(true, forKey: "forest.didCrash")
        UserDefaults.standard.set(fileURL.path, forKey: "forest.lastCrashPath")
    }

    private func formatCrashReportAsText(_ report: CrashReport) -> String {
        var text = """
        Forest Crash Report
        ===================

        Date: \(report.timestamp)
        App Version: \(report.appVersion)
        OS Version: \(report.osVersion)

        """

        if let signal = report.signal {
            text += "Signal: \(signal)\n"
        }

        if let exception = report.exception {
            text += "Exception: \(exception)\n"
        }

        if let reason = report.reason {
            text += "Reason: \(reason)\n"
        }

        text += "\nStack Trace:\n"
        text += "-----------\n"
        for (index, frame) in report.stackTrace.enumerated() {
            text += "\(index): \(frame)\n"
        }

        return text
    }

    private func loadCrashReports() {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: crashesDirectory, includingPropertiesForKeys: [.creationDateKey]) else {
            return
        }

        let jsonFiles = files.filter { $0.pathExtension == "json" }
            .sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                return date1 > date2
            }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        crashReports = jsonFiles.compactMap { fileURL in
            guard let data = try? Data(contentsOf: fileURL),
                  let report = try? decoder.decode(CrashReport.self, from: data) else {
                return nil
            }
            return report
        }

        // Clean up old reports
        if jsonFiles.count > maxCrashReports {
            for file in jsonFiles.dropFirst(maxCrashReports) {
                try? fileManager.removeItem(at: file)
                // Also remove corresponding .txt file
                let txtFile = file.deletingPathExtension().appendingPathExtension("txt")
                try? fileManager.removeItem(at: txtFile)
            }
        }
    }

    private func checkForPreviousCrash() {
        if UserDefaults.standard.bool(forKey: "forest.didCrash") {
            UserDefaults.standard.set(false, forKey: "forest.didCrash")
            loadCrashReports()
            LogService.shared.info("App recovered from previous crash", category: "Crash")
        }
    }

    // MARK: - Public API

    func clearCrashReports() {
        crashReports.removeAll()
        let fileManager = FileManager.default
        if let files = try? fileManager.contentsOfDirectory(at: crashesDirectory, includingPropertiesForKeys: nil) {
            for file in files {
                try? fileManager.removeItem(at: file)
            }
        }
    }

    func deleteCrashReport(_ report: CrashReport) {
        crashReports.removeAll { $0.id == report.id }

        let fileManager = FileManager.default
        if let files = try? fileManager.contentsOfDirectory(at: crashesDirectory, includingPropertiesForKeys: nil) {
            for file in files where file.lastPathComponent.contains(report.id.uuidString) ||
                                   file.lastPathComponent.contains(formatDateForFilename(report.timestamp)) {
                try? fileManager.removeItem(at: file)
            }
        }
    }

    private func formatDateForFilename(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter.string(from: date)
    }

    func exportCrashReport(_ report: CrashReport) -> URL? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "crash-\(formatter.string(from: report.timestamp)).txt"
        let fileURL = crashesDirectory.appendingPathComponent(filename)

        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }

        let content = formatCrashReportAsText(report)
        try? content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
}
