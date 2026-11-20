import Cocoa
import MediaPlayer
import Network

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private let radio = RadioPlayer()
    private var tracks: [Track] = []
    private var playlistTimer: Timer?
    private var pathMonitor: NWPathMonitor?
    private var networkWasDown = false
    private var wasPlaying = false

    private lazy var aboutController = AboutWindowController()
    private lazy var settingsController = SettingsWindowController(appDelegate: self)

    private let menuWidth: CGFloat = 280

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageLeading
        }

        radio.onStateChange = { [weak self] in self?.playbackChanged() }

        setupRemoteCommands()
        startNetworkMonitor()
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)

        updateStatusBarIcon()
        updateNowPlayingInfo()
        refreshPlaylist()
        playlistTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refreshPlaylist()
        }

        UpdateChecker.checkInBackgroundIfDue()
    }

    // MARK: - Clicks

    /// Left-click plays or pauses. Right-click (or Control-click) opens the menu.
    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showMenu()
        } else {
            radio.toggle()
        }
    }

    @objc private func togglePlayback() {
        radio.toggle()
    }

    private func showMenu() {
        rebuildMenu()
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    // MARK: - Menu

    private func rebuildMenu() {
        menu.removeAllItems()

        if let current = tracks.first {
            menu.addItem(nowPlayingItem(for: current))
        } else {
            let item = NSMenuItem(title: "KMHD Jazz Radio", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let playItem = NSMenuItem(title: radio.isPlaying ? "Pause" : "Play",
                                  action: #selector(togglePlayback), keyEquivalent: "")
        playItem.target = self
        menu.addItem(playItem)
        menu.addItem(volumeItem())

        let earlier = tracks.dropFirst().prefix(4)
        if !earlier.isEmpty {
            menu.addItem(.separator())
            menu.addItem(headerItem("Earlier"))
            for track in earlier {
                let item = NSMenuItem(title: track.shortDescription, action: #selector(openPlaylist), keyEquivalent: "")
                item.target = self
                item.toolTip = track.album.isEmpty ? nil : track.album
                menu.addItem(item)
            }
        }

        let playlistItem = NSMenuItem(title: "Full Playlist on KMHD.org", action: #selector(openPlaylist), keyEquivalent: "")
        playlistItem.target = self
        if earlier.isEmpty { menu.addItem(.separator()) }
        menu.addItem(playlistItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let updateItem = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        updateItem.target = self
        menu.addItem(updateItem)

        let aboutItem = NSMenuItem(title: "About KMHD Menu Bar Player", action: #selector(showAboutWindow), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Quit KMHD Menu Bar Player",
                                action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private func nowPlayingItem(for track: Track) -> NSMenuItem {
        // The feed can lag a little, so only call it "now" until shortly after it should have ended.
        let isCurrent = Date() < track.end.addingTimeInterval(120)

        let label = NSTextField(labelWithString: isCurrent ? "Now playing" : "Last played")
        label.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        label.textColor = .secondaryLabelColor

        let title = NSTextField(labelWithString: track.title)
        title.font = .boldSystemFont(ofSize: NSFont.systemFontSize)

        let details = [track.artist, track.album].filter { !$0.isEmpty }.joined(separator: " · ")
        let detail = NSTextField(labelWithString: details)
        detail.font = .systemFont(ofSize: NSFont.systemFontSize)
        detail.textColor = .secondaryLabelColor

        for field in [label, title, detail] {
            field.lineBreakMode = .byTruncatingTail
            field.maximumNumberOfLines = 1
            field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }

        let stack = NSStackView(views: details.isEmpty ? [label, title] : [label, title, detail])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        stack.edgeInsets = NSEdgeInsets(top: 4, left: 14, bottom: 6, right: 14)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView(frame: NSRect(x: 0, y: 0, width: menuWidth, height: 60))
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
        container.setFrameSize(NSSize(width: menuWidth, height: ceil(stack.fittingSize.height)))

        let item = NSMenuItem()
        item.view = container
        return item
    }

    private func volumeItem() -> NSMenuItem {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: menuWidth, height: 28))

        let icon = NSImageView(frame: NSRect(x: 14, y: 6, width: 16, height: 16))
        icon.image = NSImage(systemSymbolName: "speaker.wave.2", accessibilityDescription: "Volume")
        icon.contentTintColor = .secondaryLabelColor
        container.addSubview(icon)

        let slider = NSSlider(value: Double(radio.volume), minValue: 0, maxValue: 1,
                              target: self, action: #selector(volumeChanged(_:)))
        slider.frame = NSRect(x: 38, y: 4, width: menuWidth - 38 - 14, height: 20)
        slider.isContinuous = true
        container.addSubview(slider)

        let item = NSMenuItem()
        item.view = container
        return item
    }

    private func headerItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.attributedTitle = NSAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor,
        ])
        item.isEnabled = false
        return item
    }

    @objc private func volumeChanged(_ sender: NSSlider) {
        radio.volume = Float(sender.doubleValue)
    }

    // MARK: - Playlist

    private func refreshPlaylist() {
        Playlist.fetchRecent { [weak self] fetched in
            guard let self = self, !fetched.isEmpty, fetched != self.tracks else { return }
            self.tracks = fetched
            self.updateStatusTitle()
            self.updateNowPlayingInfo()
        }
    }

    // MARK: - Playback state

    private func playbackChanged() {
        updateStatusBarIcon()
        updateNowPlayingInfo()
        // Buffering changes call this often; only fetch when playback actually starts.
        if radio.isPlaying && !wasPlaying { refreshPlaylist() }
        wasPlaying = radio.isPlaying
    }

    func updateStatusBarIcon() {
        guard let button = statusItem.button else { return }
        let useLogo = UserDefaults.standard.bool(forKey: "useCustomIcon")
        button.image = StatusIcon.image(useLogo: useLogo, playing: radio.isPlaying)
        button.alphaValue = radio.isBuffering ? 0.5 : 1.0
        button.toolTip = radio.isPlaying ? "Click to pause KMHD" : "Click to play KMHD"
        updateStatusTitle()
    }

    private func updateStatusTitle() {
        guard let button = statusItem.button else { return }
        let showTrack = UserDefaults.standard.bool(forKey: "showTrackInMenuBar")
        guard showTrack, radio.isPlaying, let track = tracks.first,
              Date() < track.end.addingTimeInterval(120) else {
            button.title = ""
            return
        }
        var text = track.shortDescription
        if text.count > 32 { text = String(text.prefix(31)) + "…" }
        button.title = " " + text
    }

    // MARK: - Media keys and Control Center

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            self?.radio.play()
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.radio.stop()
            return .success
        }
        center.stopCommand.addTarget { [weak self] _ in
            self?.radio.stop()
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.radio.toggle()
            return .success
        }
        center.nextTrackCommand.isEnabled = false
        center.previousTrackCommand.isEnabled = false
        center.changePlaybackPositionCommand.isEnabled = false
    }

    private func updateNowPlayingInfo() {
        let center = MPNowPlayingInfoCenter.default()
        var info: [String: Any] = [
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
        ]
        if let track = tracks.first, Date() < track.end.addingTimeInterval(120) {
            info[MPMediaItemPropertyTitle] = track.title
            info[MPMediaItemPropertyArtist] = track.artist.isEmpty ? "KMHD Jazz Radio" : track.artist
            if !track.album.isEmpty { info[MPMediaItemPropertyAlbumTitle] = track.album }
        } else {
            info[MPMediaItemPropertyTitle] = "KMHD Jazz Radio"
        }
        center.nowPlayingInfo = info
        center.playbackState = radio.isPlaying ? .playing : .paused
    }

    // MARK: - Reconnect

    @objc private func didWake(_ notification: Notification) {
        // Give the network a moment to come back before restarting the stream.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.radio.reconnectIfNeeded()
            self?.refreshPlaylist()
        }
    }

    private func startNetworkMonitor() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if path.status == .satisfied {
                    if self.networkWasDown {
                        self.networkWasDown = false
                        self.radio.reconnectIfNeeded()
                        self.refreshPlaylist()
                    }
                } else {
                    self.networkWasDown = true
                }
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.tobybarnes.kmhd-menu-bar-player.network"))
        pathMonitor = monitor
    }

    // MARK: - Links and windows

    @objc private func openPlaylist() {
        NSWorkspace.shared.open(URL(string: "https://www.kmhd.org/playlist/")!)
    }

    @objc func showAboutWindow() {
        aboutController.show()
    }

    @objc func checkForUpdates() {
        UpdateChecker.check()
    }

    @objc func showSettings() {
        settingsController.show()
    }

    // MARK: - Cleanup

    func applicationWillTerminate(_ notification: Notification) {
        pathMonitor?.cancel()
        playlistTimer?.invalidate()
    }
}
