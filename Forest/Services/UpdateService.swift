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

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
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
        guard let downloadURL = downloadURL else { return }

        // Create temp directory for download
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let dmgPath = tempDir.appendingPathComponent("forest.dmg")

        // Download DMG silently
        URLSession.shared.downloadTask(with: downloadURL) { [weak self] localURL, _, error in
            guard let self = self,
                  let localURL = localURL,
                  error == nil else {
                print("Failed to download update: \(error?.localizedDescription ?? "unknown")")
                return
            }

            do {
                try FileManager.default.moveItem(at: localURL, to: dmgPath)
                DispatchQueue.main.async {
                    self.performUpdate(dmgPath: dmgPath, tempDir: tempDir)
                }
            } catch {
                print("Failed to move downloaded file: \(error)")
            }
        }.resume()
    }

    private func performUpdate(dmgPath: URL, tempDir: URL) {
        let pid = ProcessInfo.processInfo.processIdentifier

        // Create update script that runs after app quits
        let script = """
        #!/bin/bash
        # Mount DMG (no -quiet, we need the output to find mount point)
        MOUNT_DIR=$(hdiutil attach "\(dmgPath.path)" -nobrowse 2>/dev/null | grep "/Volumes" | sed 's/.*\\(\\/Volumes\\/.*\\)/\\1/')

        if [ -z "$MOUNT_DIR" ]; then
            echo "Failed to mount DMG"
            exit 1
        fi

        # Replace app
        rm -rf /Applications/forest.app
        cp -R "$MOUNT_DIR/forest.app" /Applications/

        # Cleanup
        hdiutil detach "$MOUNT_DIR" -quiet 2>/dev/null
        xattr -cr /Applications/forest.app 2>/dev/null || true
        rm -rf "\(tempDir.path)"

        # Wait for old app to quit, then open new one
        while kill -0 \(pid) 2>/dev/null; do
            sleep 0.1
        done
        open /Applications/forest.app
        """

        let scriptPath = tempDir.appendingPathComponent("update.sh")
        do {
            try script.write(to: scriptPath, atomically: true, encoding: .utf8)

            // Run script in background (detached from Terminal)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [scriptPath.path]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try process.run()

            // Quit app so update can proceed
            NSApplication.shared.terminate(nil)
        } catch {
            print("Failed to run update script: \(error)")
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
