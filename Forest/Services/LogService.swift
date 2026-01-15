import Foundation
import os.log

enum LogLevel: String, Codable, CaseIterable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"

    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        }
    }

    var icon: String {
        switch self {
        case .debug: return "ant"
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        }
    }
}

struct LogEntry: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let level: LogLevel
    let category: String
    let message: String
    let file: String?
    let function: String?
    let line: Int?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        level: LogLevel,
        category: String,
        message: String,
        file: String? = nil,
        function: String? = nil,
        line: Int? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = message
        self.file = file
        self.function = function
        self.line = line
    }
}

@Observable
final class LogService {
    static let shared = LogService()

    private let subsystem = Bundle.main.bundleIdentifier ?? "com.forest.app"
    private var loggers: [String: Logger] = [:]
    private let logsDirectory: URL
    private let maxLogFiles = 7
    private let maxEntriesInMemory = 500

    private(set) var recentEntries: [LogEntry] = []

    var logsDirectoryPath: String {
        logsDirectory.path
    }

    private init() {
        let libraryLogs = (FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("Logs")
            .appendingPathComponent("Forest")

        self.logsDirectory = libraryLogs

        try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)

        loadTodaysLogs()
        cleanupOldLogs()
    }

    private func logger(for category: String) -> Logger {
        if let existing = loggers[category] {
            return existing
        }
        let logger = Logger(subsystem: subsystem, category: category)
        loggers[category] = logger
        return logger
    }

    // MARK: - Public Logging API

    func debug(_ message: String, category: String = "General", file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .debug, message: message, category: category, file: file, function: function, line: line)
    }

    func info(_ message: String, category: String = "General", file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .info, message: message, category: category, file: file, function: function, line: line)
    }

    func warning(_ message: String, category: String = "General", file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .warning, message: message, category: category, file: file, function: function, line: line)
    }

    func error(_ message: String, category: String = "General", file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .error, message: message, category: category, file: file, function: function, line: line)
    }

    // swiftlint:disable:next function_parameter_count
    private func log(level: LogLevel, message: String, category: String, file: String, function: String, line: Int) {
        let osLogger = logger(for: category)
        let fileName = URL(fileURLWithPath: file).lastPathComponent

        // Log to system (visible in Console.app)
        osLogger.log(level: level.osLogType, "[\(fileName):\(line)] \(message)")

        // Store in memory
        let entry = LogEntry(
            level: level,
            category: category,
            message: message,
            file: fileName,
            function: function,
            line: line
        )

        DispatchQueue.main.async { [weak self] in
            self?.addEntry(entry)
        }

        // Write to file
        persistEntry(entry)
    }

    private func addEntry(_ entry: LogEntry) {
        recentEntries.append(entry)
        if recentEntries.count > maxEntriesInMemory {
            recentEntries.removeFirst(recentEntries.count - maxEntriesInMemory)
        }
    }

    // MARK: - Persistence

    private func currentLogFileURL() -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let filename = "forest-\(formatter.string(from: Date())).log"
        return logsDirectory.appendingPathComponent(filename)
    }

    private func persistEntry(_ entry: LogEntry) {
        let fileURL = currentLogFileURL()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let logLine = "[\(formatter.string(from: entry.timestamp))] [\(entry.level.rawValue)] [\(entry.category)] \(entry.message)\n"

        DispatchQueue.global(qos: .utility).async {
            if let data = logLine.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    if let handle = try? FileHandle(forWritingTo: fileURL) {
                        handle.seekToEndOfFile()
                        handle.write(data)
                        try? handle.close()
                    }
                } else {
                    try? data.write(to: fileURL)
                }
            }
        }
    }

    private func loadTodaysLogs() {
        let fileURL = currentLogFileURL()
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return
        }

        let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        for line in lines.suffix(maxEntriesInMemory) {
            if let entry = parseLogLine(line, formatter: formatter) {
                recentEntries.append(entry)
            }
        }
    }

    private func parseLogLine(_ line: String, formatter: ISO8601DateFormatter) -> LogEntry? {
        // Parse: [timestamp] [LEVEL] [category] message
        let pattern = #"\[(.+?)\] \[(.+?)\] \[(.+?)\] (.+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }

        guard let timestampRange = Range(match.range(at: 1), in: line),
              let levelRange = Range(match.range(at: 2), in: line),
              let categoryRange = Range(match.range(at: 3), in: line),
              let messageRange = Range(match.range(at: 4), in: line) else {
            return nil
        }

        let timestampStr = String(line[timestampRange])
        let levelStr = String(line[levelRange])
        let category = String(line[categoryRange])
        let message = String(line[messageRange])

        guard let date = formatter.date(from: timestampStr),
              let level = LogLevel(rawValue: levelStr) else {
            return nil
        }

        return LogEntry(timestamp: date, level: level, category: category, message: message)
    }

    private func cleanupOldLogs() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }

            let fileManager = FileManager.default
            guard let files = try? fileManager.contentsOfDirectory(at: self.logsDirectory, includingPropertiesForKeys: [.creationDateKey]) else {
                return
            }

            let logFiles = files.filter { $0.pathExtension == "log" }
                .sorted { url1, url2 in
                    let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                    let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                    return date1 > date2
                }

            if logFiles.count > self.maxLogFiles {
                for file in logFiles.dropFirst(self.maxLogFiles) {
                    try? fileManager.removeItem(at: file)
                }
            }
        }
    }

    // MARK: - Public Utilities

    func clearLogs() {
        recentEntries.removeAll()
        let fileManager = FileManager.default
        if let files = try? fileManager.contentsOfDirectory(at: logsDirectory, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "log" {
                try? fileManager.removeItem(at: file)
            }
        }
    }

    func exportLogs() -> URL? {
        let exportURL = logsDirectory.appendingPathComponent("forest-logs-export.txt")

        var content = "Forest Log Export\n"
        content += "Generated: \(Date())\n"
        content += "=".repeated(50) + "\n\n"

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

        for entry in recentEntries {
            content += "[\(formatter.string(from: entry.timestamp))] [\(entry.level.rawValue)] [\(entry.category)] \(entry.message)\n"
        }

        try? content.write(to: exportURL, atomically: true, encoding: .utf8)
        return exportURL
    }
}

private extension String {
    func repeated(_ count: Int) -> String {
        String(repeating: self, count: count)
    }
}
