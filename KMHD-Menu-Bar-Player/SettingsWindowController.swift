import Cocoa
import ServiceManagement

class SettingsWindowController {
    private var window: NSWindow?
    private weak var appDelegate: AppDelegate?

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
    }

    func show() {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 160),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.center()
        window.isReleasedWhenClosed = false

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]

        // Icon toggle
        let iconCheckbox = NSButton(checkboxWithTitle: "Use KMHD logo icon", target: self, action: #selector(iconToggleChanged(_:)))
        iconCheckbox.state = UserDefaults.standard.bool(forKey: "useCustomIcon") ? .on : .off

        // Launch at login
        let loginCheckbox = NSButton(checkboxWithTitle: "Launch at login", target: self, action: #selector(loginToggleChanged(_:)))
        loginCheckbox.state = UserDefaults.standard.bool(forKey: "launchAtLogin") ? .on : .off

        let stack = NSStackView(views: [iconCheckbox, loginCheckbox])
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
        let useCustom = sender.state == .on
        UserDefaults.standard.set(useCustom, forKey: "useCustomIcon")
        appDelegate?.updateStatusBarIcon()
    }

    @objc private func loginToggleChanged(_ sender: NSButton) {
        let enable = sender.state == .on
        UserDefaults.standard.set(enable, forKey: "launchAtLogin")
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
            // Revert checkbox state
            sender.state = enable ? .off : .on
            UserDefaults.standard.set(!enable, forKey: "launchAtLogin")
        }
    }
}
