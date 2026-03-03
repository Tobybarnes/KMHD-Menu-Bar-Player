import Cocoa

class AboutWindowController {
    private var window: NSWindow?

    func show() {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About KMHD Widget"
        window.center()
        window.isReleasedWhenClosed = false

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"

        let nameLabel = NSTextField(labelWithString: "KMHD Widget")
        nameLabel.font = NSFont.boldSystemFont(ofSize: 18)
        nameLabel.alignment = .center

        let versionLabel = NSTextField(labelWithString: "Version \(version)")
        versionLabel.font = NSFont.systemFont(ofSize: 13)
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.alignment = .center

        let creditLabel = NSTextField(labelWithString: "Made by Toby Barnes")
        creditLabel.font = NSFont.systemFont(ofSize: 13)
        creditLabel.alignment = .center

        let disclaimerLabel = NSTextField(labelWithString: "Not affiliated with OPB or KMHD.")
        disclaimerLabel.font = NSFont.systemFont(ofSize: 11)
        disclaimerLabel.textColor = .tertiaryLabelColor
        disclaimerLabel.alignment = .center

        let linkButton = NSButton(title: "GitHub", target: self, action: #selector(openGitHub))
        linkButton.bezelStyle = .inline
        linkButton.contentTintColor = .linkColor

        let stack = NSStackView(views: [nameLabel, versionLabel, creditLabel, disclaimerLabel, linkButton])
        stack.orientation = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -20),
        ])

        window.contentView = contentView
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    @objc private func openGitHub() {
        NSWorkspace.shared.open(URL(string: "https://github.com/Tobybarnes/KMHD-widget")!)
    }
}
