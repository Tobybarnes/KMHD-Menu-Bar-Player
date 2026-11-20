import Cocoa
import ServiceManagement

class SettingsWindowController {
    private var window: NSWindow?
    private weak var appDelegate: AppDelegate?
    private var loginCheckbox: NSButton?

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
    }

    func show() {
        if let existing = window, existing.isVisible {
            refreshLoginState()
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 150),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.center()
        window.isReleasedWhenClosed = false

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]

        let iconCheckbox = NSButton(checkboxWithTitle: "Use KMHD logo icon", target: self, action: #selector(iconToggleChanged(_:)))
        iconCheckbox.state = UserDefaults.standard.bool(forKey: "useCustomIcon") ? .on : .off

        let trackCheckbox = NSButton(checkboxWithTitle: "Show track name in menu bar", target: self, action: #selector(trackToggleChanged(_:)))
        trackCheckbox.state = UserDefaults.standard.bool(forKey: "showTrackInMenuBar") ? .on : .off

        let loginCheckbox = NSButton(checkboxWithTitle: "Launch at login", target: self, action: #selector(loginToggleChanged(_:)))
        self.loginCheckbox = loginCheckbox
        refreshLoginState()

        let stack = NSStackView(views: [iconCheckbox, trackCheckbox, loginCheckbox])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -24),
        ])

        window.contentView = contentView
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    @objc private func iconToggleChanged(_ sender: NSButton) {
        UserDefaults.standard.set(sender.state == .on, forKey: "useCustomIcon")
        appDelegate?.updateStatusBarIcon()
    }

    @objc private func trackToggleChanged(_ sender: NSButton) {
        UserDefaults.standard.set(sender.state == .on, forKey: "showTrackInMenuBar")
        appDelegate?.updateStatusBarIcon()
    }

    /// Reads the real login item state from macOS instead of a stored copy that can drift.
    private func refreshLoginState() {
        loginCheckbox?.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func loginToggleChanged(_ sender: NSButton) {
        let enable = sender.state == .on
        do {
            if enable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Launch at Login"
            alert.informativeText = "Could not update login item: \(error.localizedDescription)"
            alert.alertStyle = .warning
            alert.runModal()
        }

        if SMAppService.mainApp.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
        refreshLoginState()
    }
}
