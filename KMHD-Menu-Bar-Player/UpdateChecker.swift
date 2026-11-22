import Cocoa

struct Release {
    let version: String
    let pageURL: URL
    let dmgURL: URL?
}

enum UpdateState {
    case idle
    case checking
    case upToDate
    case available(Release)
    case downloading(Release)
    case installing(Release)
    case failed(String)

    var isBusy: Bool {
        switch self {
        case .checking, .downloading, .installing: return true
        default: return false
        }
    }
}

/// Checks GitHub releases for a newer version and, when the release has a DMG,
/// installs it in place and relaunches.
final class UpdateChecker {
    static let shared = UpdateChecker()
    static let didChange = Notification.Name("UpdateCheckerDidChange")

    private let releasesURL = URL(string: "https://api.github.com/repos/Tobybarnes/KMHD-Menu-Bar-Player/releases/latest")!
    private let lastCheckKey = "lastUpdateCheck"
    private let notifiedVersionKey = "lastNotifiedUpdateVersion"
    private let autoCheckKey = "checkForUpdatesAutomatically"

    private(set) var state: UpdateState = .idle {
        didSet { NotificationCenter.default.post(name: Self.didChange, object: self) }
    }

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
    }

    var lastChecked: Date? {
        UserDefaults.standard.object(forKey: lastCheckKey) as? Date
    }

    var checksAutomatically: Bool {
        get { UserDefaults.standard.object(forKey: autoCheckKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: autoCheckKey) }
    }

    var availableRelease: Release? {
        if case .available(let release) = state { return release }
        return nil
    }

    /// True when the app sits somewhere it can replace itself, such as Applications.
    /// Running from the DMG or a translocated copy falls back to the release page.
    var canInstallInPlace: Bool {
        let bundle = Bundle.main.bundleURL
        if bundle.path.contains("/AppTranslocation/") || bundle.path.hasPrefix("/Volumes/") { return false }
        return FileManager.default.isWritableFile(atPath: bundle.deletingLastPathComponent().path)
    }

    // MARK: - Checking

    /// Quietly checks at most once a day and only speaks up when there is a newer version.
    func checkInBackgroundIfDue() {
        guard checksAutomatically, !state.isBusy, availableRelease == nil else { return }
        if let last = lastChecked, Date().timeIntervalSince(last) < 86_400 { return }
        check(interactive: false)
    }

    /// Interactive checks show their result in Settings; background checks raise an
    /// alert once per new version.
    func check(interactive: Bool = true) {
        guard !state.isBusy else { return }
        state = .checking

        var request = URLRequest(url: releasesURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.handle(data: data, response: response, error: error, interactive: interactive)
            }
        }.resume()
    }

    private func handle(data: Data?, response: URLResponse?, error: Error?, interactive: Bool) {
        if error != nil {
            state = .failed("Couldn't reach GitHub")
            return
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        let page = (json?["html_url"] as? String).flatMap { URL(string: $0) }
        guard status == 200,
              let json = json,
              let tag = json["tag_name"] as? String,
              let page = page else {
            state = status == 404 ? .upToDate : .failed("Couldn't read the latest release")
            return
        }

        UserDefaults.standard.set(Date(), forKey: lastCheckKey)

        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        guard version.compare(Self.currentVersion, options: .numeric) == .orderedDescending else {
            state = .upToDate
            return
        }

        let assets = json["assets"] as? [[String: Any]] ?? []
        let dmg = assets
            .first { ($0["name"] as? String)?.lowercased().hasSuffix(".dmg") == true }
            .flatMap { $0["browser_download_url"] as? String }
            .flatMap { URL(string: $0) }

        let release = Release(version: version, pageURL: page, dmgURL: dmg)
        state = .available(release)

        if !interactive && UserDefaults.standard.string(forKey: notifiedVersionKey) != version {
            UserDefaults.standard.set(version, forKey: notifiedVersionKey)
            promptToInstall(release)
        }
    }

    private func promptToInstall(_ release: Release) {
        let alert = NSAlert()
        alert.messageText = "KMHD Menu Bar Player \(release.version) is available"
        alert.informativeText = "You have \(Self.currentVersion)."
        alert.addButton(withTitle: installButtonTitle(for: release))
        alert.addButton(withTitle: "Later")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            install(release)
        }
    }

    func installButtonTitle(for release: Release) -> String {
        release.dmgURL != nil && canInstallInPlace ? "Install and Relaunch" : "Download"
    }

    // MARK: - Installing

    func install(_ release: Release) {
        guard let dmgURL = release.dmgURL, canInstallInPlace else {
            NSWorkspace.shared.open(release.pageURL)
            return
        }
        guard !state.isBusy else { return }
        state = .downloading(release)

        URLSession.shared.downloadTask(with: dmgURL) { [weak self] location, response, error in
            guard let self = self else { return }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard error == nil, status == 200, let location = location else {
                DispatchQueue.main.async { self.state = .failed("The download didn't finish") }
                return
            }

            // The downloaded file is deleted when this handler returns, so move it first.
            let dmg = FileManager.default.temporaryDirectory
                .appendingPathComponent("KMHD-update-\(UUID().uuidString).dmg")
            do {
                try FileManager.default.moveItem(at: location, to: dmg)
                DispatchQueue.main.async { self.state = .installing(release) }
                try self.installApp(from: dmg)
                DispatchQueue.main.async { self.relaunch() }
            } catch {
                try? FileManager.default.removeItem(at: dmg)
                let message = (error as? UpdateError)?.message ?? "The update couldn't be installed"
                DispatchQueue.main.async { self.state = .failed(message) }
            }
        }.resume()
    }

    /// Mounts the DMG, copies the app beside the running one, then swaps them.
    private func installApp(from dmg: URL) throws {
        let fm = FileManager.default
        let mount = fm.temporaryDirectory.appendingPathComponent("KMHD-mount-\(UUID().uuidString)")
        try fm.createDirectory(at: mount, withIntermediateDirectories: true)

        try run("/usr/bin/hdiutil", ["attach", dmg.path, "-nobrowse", "-noautoopen", "-readonly", "-mountpoint", mount.path])
        defer {
            try? run("/usr/bin/hdiutil", ["detach", mount.path, "-force"])
            try? fm.removeItem(at: mount)
            try? fm.removeItem(at: dmg)
        }

        let newApp: URL
        if let name = try fm.contentsOfDirectory(atPath: mount.path).first(where: { $0.hasSuffix(".app") }) {
            newApp = mount.appendingPathComponent(name)
        } else if fm.fileExists(atPath: mount.appendingPathComponent("Contents/Info.plist").path) {
            newApp = mount
        } else {
            throw UpdateError("The download didn't contain the app")
        }

        guard Bundle(url: newApp)?.bundleIdentifier == Bundle.main.bundleIdentifier else {
            throw UpdateError("The download wasn't KMHD Menu Bar Player")
        }

        let current = Bundle.main.bundleURL
        let staged = current.deletingLastPathComponent()
            .appendingPathComponent(".KMHD-update-\(UUID().uuidString).app")
        do {
            try run("/usr/bin/ditto", [newApp.path, staged.path])
            _ = try fm.replaceItemAt(current, withItemAt: staged)
        } catch {
            try? fm.removeItem(at: staged)
            throw error
        }
    }

    private func relaunch() {
        let pid = ProcessInfo.processInfo.processIdentifier
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done; /usr/bin/open \"$0\"",
                          Bundle.main.bundlePath]
        do {
            try task.run()
            NSApp.terminate(nil)
        } catch {
            state = .failed("Installed. Quit and reopen to finish")
        }
    }

    private func run(_ tool: String, _ arguments: [String]) throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: tool)
        task.arguments = arguments
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try task.run()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else {
            throw UpdateError("The update couldn't be installed")
        }
    }
}

private struct UpdateError: Error {
    let message: String
    init(_ message: String) { self.message = message }
}
