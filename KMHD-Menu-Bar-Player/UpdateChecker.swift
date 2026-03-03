import Cocoa

class UpdateChecker {
    private static let releasesURL = "https://api.github.com/repos/Tobybarnes/KMHD-widget/releases/latest"

    static func check() {
        guard let url = URL(string: releasesURL) else { return }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    showAlert(title: "Update Check Failed", message: "Could not connect to GitHub.\n\(error.localizedDescription)")
                    return
                }

                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

                guard let data = data,
                      statusCode == 200,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String,
                      let htmlURL = json["html_url"] as? String else {
                    let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
                    if statusCode == 404 {
                        showAlert(title: "No Releases Found", message: "No published releases yet. You have version \(currentVersion).")
                    } else {
                        showAlert(title: "Update Check Failed", message: "Could not read release information (HTTP \(statusCode)).")
                    }
                    return
                }

                let remoteVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
                let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"

                if remoteVersion.compare(currentVersion, options: .numeric) == .orderedDescending {
                    let alert = NSAlert()
                    alert.messageText = "Update Available"
                    alert.informativeText = "Version \(remoteVersion) is available. You have version \(currentVersion)."
                    alert.addButton(withTitle: "Download")
                    alert.addButton(withTitle: "Later")
                    alert.alertStyle = .informational
                    if alert.runModal() == .alertFirstButtonReturn {
                        NSWorkspace.shared.open(URL(string: htmlURL)!)
                    }
                } else {
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
        alert.runModal()
    }
}
