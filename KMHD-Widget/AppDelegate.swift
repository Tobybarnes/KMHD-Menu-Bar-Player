import Cocoa
import WebKit
import Network

class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var webView: WKWebView!
    private var eventMonitor: Any?
    private var pathMonitor: NWPathMonitor?
    private var retryView: NSView?

    private lazy var aboutController = AboutWindowController()
    private lazy var settingsController = SettingsWindowController(appDelegate: self)

    private let kmhdURL = URL(string: "https://audioplayer.opb.org/kmhd")!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusBarIcon()

        // Build the menu
        let menu = NSMenu()

        let playItem = NSMenuItem(title: "Play KMHD", action: #selector(openPlayer), keyEquivalent: "")
        playItem.target = self
        menu.addItem(playItem)

        menu.addItem(NSMenuItem.separator())

        let websiteItem = NSMenuItem(title: "KMHD.org", action: #selector(openWebsite), keyEquivalent: "")
        websiteItem.target = self
        menu.addItem(websiteItem)

        let playlistItem = NSMenuItem(title: "Playlist", action: #selector(openPlaylist), keyEquivalent: "p")
        playlistItem.target = self
        menu.addItem(playlistItem)

        menu.addItem(NSMenuItem.separator())

        let aboutItem = NSMenuItem(title: "About KMHD Widget", action: #selector(showAboutWindow), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let updateItem = NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates), keyEquivalent: "")
        updateItem.target = self
        menu.addItem(updateItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit KMHD Widget", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu

        // Configure WKWebView with audio permissions
        let config = WKWebViewConfiguration()
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsAirPlayForMediaPlayback = true

        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 300, height: 230), configuration: config)
        webView.navigationDelegate = self

        // Wrap webView in an NSViewController
        let viewController = NSViewController()
        viewController.view = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 230))
        viewController.view.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: viewController.view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: viewController.view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: viewController.view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: viewController.view.trailingAnchor),
        ])

        // Create the popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 230)
        popover.behavior = .transient
        popover.contentViewController = viewController

        // Monitor clicks outside the popover to dismiss it
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if let popover = self?.popover, popover.isShown {
                popover.performClose(nil)
            }
        }

        // Start network path monitor for auto-reconnect
        startNetworkMonitor()

    }

    // MARK: - Player

    @objc private func openPlayer() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            if webView.url == nil {
                webView.load(URLRequest(url: kmhdURL))
            }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - Web Links

    @objc private func openWebsite() {
        NSWorkspace.shared.open(URL(string: "https://www.kmhd.org")!)
    }

    @objc private func openPlaylist() {
        NSWorkspace.shared.open(URL(string: "https://www.kmhd.org/playlist/")!)
    }

    // MARK: - Menu Actions

    @objc func showAboutWindow() {
        aboutController.show()
    }

    @objc func checkForUpdates() {
        UpdateChecker.check()
    }

    @objc func showSettings() {
        settingsController.show()
    }

    // MARK: - Icon Management

    func updateStatusBarIcon() {
        guard let button = statusItem.button else { return }
        if UserDefaults.standard.bool(forKey: "useCustomIcon"),
           let iconPath = Bundle.main.path(forResource: "kmhd-icon", ofType: "png"),
           let image = NSImage(contentsOfFile: iconPath) {
            image.isTemplate = true
            image.size = NSSize(width: 18, height: 18)
            button.image = image
        } else {
            button.image = NSImage(systemSymbolName: "radio", accessibilityDescription: "KMHD Radio")
        }
    }

    // MARK: - Network Error Handling

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        showRetryView()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        showRetryView()
    }

    private func showRetryView() {
        guard retryView == nil, let container = webView.superview else { return }

        let overlay = NSView(frame: container.bounds)
        overlay.autoresizingMask = [.width, .height]
        overlay.wantsLayer = true
        overlay.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let label = NSTextField(labelWithString: "No Connection")
        label.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        label.alignment = .center

        let retryButton = NSButton(title: "Retry", target: self, action: #selector(retryLoad))
        retryButton.bezelStyle = .rounded

        let stack = NSStackView(views: [label, retryButton])
        stack.orientation = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        overlay.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
        ])

        container.addSubview(overlay)
        retryView = overlay
        webView.isHidden = true
    }

    private func removeRetryView() {
        retryView?.removeFromSuperview()
        retryView = nil
        webView.isHidden = false
    }

    @objc private func retryLoad() {
        removeRetryView()
        webView.load(URLRequest(url: kmhdURL))
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        removeRetryView()
    }

    // MARK: - Network Monitor

    private func startNetworkMonitor() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            DispatchQueue.main.async {
                if self?.retryView != nil {
                    self?.retryLoad()
                }
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.tobybarnes.kmhd-widget.network"))
        pathMonitor = monitor
    }

    // MARK: - Cleanup

    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        pathMonitor?.cancel()
    }
}
