import Cocoa

class UpdateChecker {
    private static let releasesURL = "https://api.github.com/repos/Tobybarnes/KMHD-Menu-Bar-Player/releases/latest"
    private static let lastCheckKey = "lastUpdateCheck"

    private static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    /// Quietly checks at most once a day and only speaks up when there is a newer version.
    static func checkInBackgroundIfDue() {
        let last = UserDefaults.standard.object(forKey: lastCheckKey) as? Date ?? .distantPast
        guard Date().timeIntervalSince(last) > 86_400 else { return }
        check(silent: true)
    }

    static func check(silent: Bool = false) {
        guard let url = URL(string: releasesURL) else { return }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    if !silent {
                        showAlert(title: "Update Check Failed", message: "Could not connect to GitHub.\n\(error.localizedDescription)")
                    }
                    return
                }

                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

                guard let data = data,
                      statusCode == 200,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String,
                      let htmlURL = json["html_url"] as? String else {
                    guard !silent else { return }
                    if statusCode == 404 {
                        showAlert(title: "No Releases Found", message: "No published releases yet. You have version \(currentVersion).")
                    } else {
                        showAlert(title: "Update Check Failed", message: "Could not read release information (HTTP \(statusCode)).")
                    }
                    return
                }

                UserDefaults.standard.set(Date(), forKey: lastCheckKey)
                let remoteVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName

                if remoteVersion.compare(currentVersion, options: .numeric) == .orderedDescending {
                    let alert = NSAlert()
                    alert.messageText = "Update Available"
                    alert.informativeText = "Version \(remoteVersion) is available. You have version \(currentVersion)."
                    alert.addButton(withTitle: "Download")
                    alert.addButton(withTitle: "Later")
                    alert.alertStyle = .informational
                    NSApp.activate(ignoringOtherApps: true)
                    if alert.runModal() == .alertFirstButtonReturn, let url = URL(string: htmlURL) {
                        NSWorkspace.shared.open(url)
                    }
                } else if !silent {
                    showAlert(title: "You're Up to Date", message: "KMHD Menu Bar Player \(currentVersion) is the latest version.")
                }
            }
        }.resume()
    }

    private static func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        // Menu bar apps sit in the background, so bring the alert to the front.
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
