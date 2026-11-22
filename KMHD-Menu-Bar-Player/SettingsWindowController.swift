import Cocoa
import ServiceManagement

final class SettingsWindowController: NSObject {
    private var window: NSWindow?
    private weak var appDelegate: AppDelegate?

    private let iconPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let trackCheckbox = NSButton(checkboxWithTitle: "Show the track name while playing", target: nil, action: nil)
    private let loginCheckbox = NSButton(checkboxWithTitle: "Open at login", target: nil, action: nil)
    private let autoUpdateCheckbox = NSButton(checkboxWithTitle: "Check for updates automatically", target: nil, action: nil)
    private let updateStatus = NSTextField(labelWithString: "")
    private let updateButton = NSButton(title: "Check Now", target: nil, action: nil)
    private let spinner = NSProgressIndicator()

    private let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        super.init()
        NotificationCenter.default.addObserver(
            self, selector: #selector(updateStateChanged), name: UpdateChecker.didChange, object: nil)
    }

    func show() {
        if window == nil { window = makeWindow() }
        refresh()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Layout

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "KMHD.menu Settings"
        window.isReleasedWhenClosed = false

        iconPopup.addItems(withTitles: ["Radio", "KMHD logo"])
        iconPopup.target = self
        iconPopup.action = #selector(iconChanged(_:))

        trackCheckbox.target = self
        trackCheckbox.action = #selector(trackToggleChanged(_:))

        loginCheckbox.target = self
        loginCheckbox.action = #selector(loginToggleChanged(_:))

        autoUpdateCheckbox.target = self
        autoUpdateCheckbox.action = #selector(autoUpdateChanged(_:))

        updateStatus.textColor = .secondaryLabelColor
        updateStatus.lineBreakMode = .byTruncatingTail

        updateButton.bezelStyle = .rounded
        updateButton.target = self
        updateButton.action = #selector(updateButtonPressed)

        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isDisplayedWhenStopped = false

        let versionText = NSTextField(labelWithString: versionString())
        versionText.isSelectable = true

        let updateRow = NSStackView(views: [updateButton, spinner, updateStatus])
        updateRow.orientation = .horizontal
        updateRow.spacing = 8
        updateRow.alignment = .centerY

        let grid = NSGridView(views: [
            [label("Menu bar icon:"), iconPopup],
            [NSGridCell.emptyContentView, trackCheckbox],
            [label("Startup:"), loginCheckbox],
            [label("Version:"), versionText],
            [label("Updates:"), updateRow],
            [NSGridCell.emptyContentView, autoUpdateCheckbox],
        ])
        grid.rowSpacing = 10
        grid.columnSpacing = 8
        grid.rowAlignment = .firstBaseline
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 1).xPlacement = .leading
        // Extra room before each group so related settings read together without dividers.
        grid.row(at: 2).topPadding = 10
        grid.row(at: 3).topPadding = 10
        grid.row(at: 4).rowAlignment = .none
        grid.row(at: 4).yPlacement = .center
        grid.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            grid.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -24),
            grid.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 32),
            grid.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -32),
            content.widthAnchor.constraint(equalToConstant: 440),
        ])

        window.contentView = content
        window.setContentSize(content.fittingSize)
        window.center()
        return window
    }

    private func label(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.alignment = .right
        return field
    }

    private func versionString() -> String {
        let build = UpdateChecker.buildNumber
        return build.isEmpty ? UpdateChecker.currentVersion : "\(UpdateChecker.currentVersion) (build \(build))"
    }

    // MARK: - State

    private func refresh() {
        let defaults = UserDefaults.standard
        iconPopup.selectItem(at: defaults.bool(forKey: "useCustomIcon") ? 1 : 0)
        trackCheckbox.state = defaults.bool(forKey: "showTrackInMenuBar") ? .on : .off
        autoUpdateCheckbox.state = UpdateChecker.shared.checksAutomatically ? .on : .off
        refreshLoginState()
        refreshUpdateRow()
    }

    /// Reads the real login item state from macOS instead of a stored copy that can drift.
    private func refreshLoginState() {
        loginCheckbox.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    private func refreshUpdateRow() {
        let checker = UpdateChecker.shared
        let state = checker.state

        if state.isBusy {
            spinner.startAnimation(nil)
        } else {
            spinner.stopAnimation(nil)
        }
        updateButton.isEnabled = !state.isBusy

        switch state {
        case .available(let release):
            updateButton.title = checker.installButtonTitle(for: release)
            updateStatus.stringValue = "\(release.version) is available"
        case .downloading(let release):
            updateButton.title = "Check Now"
            updateStatus.stringValue = "Downloading \(release.version)…"
        case .installing:
            updateButton.title = "Check Now"
            updateStatus.stringValue = "Installing…"
        case .checking:
            updateButton.title = "Check Now"
            updateStatus.stringValue = "Checking…"
        case .upToDate:
            updateButton.title = "Check Now"
            updateStatus.stringValue = "You're up to date"
        case .failed(let message):
            updateButton.title = "Try Again"
            updateStatus.stringValue = message
        case .idle:
            updateButton.title = "Check Now"
            if let last = checker.lastChecked {
                updateStatus.stringValue = "Checked " + relativeFormatter.localizedString(for: last, relativeTo: Date())
            } else {
                updateStatus.stringValue = ""
            }
        }
    }

    @objc private func updateStateChanged() {
        refreshUpdateRow()
    }

    // MARK: - Actions

    @objc private func iconChanged(_ sender: NSPopUpButton) {
        UserDefaults.standard.set(sender.indexOfSelectedItem == 1, forKey: "useCustomIcon")
        appDelegate?.updateStatusBarIcon()
    }

    @objc private func trackToggleChanged(_ sender: NSButton) {
        UserDefaults.standard.set(sender.state == .on, forKey: "showTrackInMenuBar")
        appDelegate?.updateStatusBarIcon()
    }

    @objc private func autoUpdateChanged(_ sender: NSButton) {
        UpdateChecker.shared.checksAutomatically = sender.state == .on
    }

    @objc private func updateButtonPressed() {
        let checker = UpdateChecker.shared
        if let release = checker.availableRelease {
            checker.install(release)
        } else {
            checker.check(interactive: true)
        }
    }

    @objc private func loginToggleChanged(_ sender: NSButton) {
        do {
            if sender.state == .on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn't change Open at Login"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }

        if SMAppService.mainApp.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
        refreshLoginState()
    }
}
