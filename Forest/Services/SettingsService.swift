import Foundation

@Observable
final class SettingsService {
    static let shared = SettingsService()

    private let defaults = UserDefaults.standard
    private let forestDirectoryKey = "forestDirectory"

    var forestDirectory: URL {
        get {
            if let path = defaults.string(forKey: forestDirectoryKey) {
                return URL(fileURLWithPath: path)
            }
            return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("forest")
        }
        set {
            defaults.set(newValue.path, forKey: forestDirectoryKey)
        }
    }

    private init() {}
}
