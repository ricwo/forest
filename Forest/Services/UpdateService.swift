import AppKit
import Foundation

struct GitHubRelease: Codable {
    let tagName: String
    let htmlUrl: String
    let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlUrl = "html_url"
        case assets
    }

    struct Asset: Codable {
        let name: String
        let browserDownloadUrl: String

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadUrl = "browser_download_url"
        }
    }
}

@Observable
final class UpdateService {
    static let shared = UpdateService()

    private let repo = "ricwo/forest"
    let currentVersion: String
    private var timer: Timer?

    var updateAvailable: Bool = false
    var latestVersion: String?
    var downloadURL: URL?
    var releaseURL: URL?

    private init() {
        currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    func startPeriodicChecks() {
        checkForUpdates()
        timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.checkForUpdates()
        }
    }

    func checkForUpdates(showAlert: Bool = false) {
        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else { return }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self,
                  let data = data,
                  error == nil else { return }

            do {
                let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                let latestVersion = release.tagName

                DispatchQueue.main.async {
                    self.latestVersion = latestVersion
                    self.releaseURL = URL(string: release.htmlUrl)

                    if let asset = release.assets.first(where: { $0.name == "forest.dmg" }) {
                        self.downloadURL = URL(string: asset.browserDownloadUrl)
                    }

                    self.updateAvailable = self.isNewerVersion(latestVersion, than: self.currentVersion)

                    if showAlert && !self.updateAvailable {
                        self.showUpToDateAlert()
                    }
                }
            } catch {
                print("Failed to check for updates: \(error)")
            }
        }.resume()
    }

    private func showUpToDateAlert() {
        let alert = NSAlert()
        alert.messageText = "You're up to date!"
        alert.informativeText = "forest \(currentVersion) is the latest version."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func installUpdate() {
        // Run the install script which handles the update
        let script = """
            curl -fsSL https://raw.githubusercontent.com/\(repo)/main/install.sh | bash && open /Applications/forest.app
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", script]

        // Run in Terminal so user can see progress
        let terminalScript = """
            tell application "Terminal"
                activate
                do script "curl -fsSL https://raw.githubusercontent.com/\(repo)/main/install.sh | bash && open /Applications/forest.app"
            end tell
        """

        let appleScript = Process()
        appleScript.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        appleScript.arguments = ["-e", terminalScript]

        try? appleScript.run()

        // Quit current app after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            NSApplication.shared.terminate(nil)
        }
    }

    private func isNewerVersion(_ new: String, than current: String) -> Bool {
        let newParts = new.split(separator: ".").compactMap { Int($0) }
        let currentParts = current.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(newParts.count, currentParts.count) {
            let newPart = i < newParts.count ? newParts[i] : 0
            let currentPart = i < currentParts.count ? currentParts[i] : 0

            if newPart > currentPart { return true }
            if newPart < currentPart { return false }
        }

        return false
    }
}
