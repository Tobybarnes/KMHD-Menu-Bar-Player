import AVFoundation

/// Plays the KMHD live stream natively, so one click starts the music.
/// Keeps trying to play after stalls, network drops and sleep while the
/// listener wants it playing.
final class RadioPlayer: NSObject {
    /// KMHD's HLS stream, as used by OPB's web player (audioplayer.opb.org/kmhd).
    static let streamURL = URL(string: "https://ais-sa3.cdnstream1.com/2442_128.aac/playlist.m3u8")!

    var onStateChange: (() -> Void)?

    /// What the listener asked for. Playback may briefly lag behind it while buffering.
    private(set) var isPlaying = false

    private var player: AVPlayer?
    private var statusObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    private var retryWorkItem: DispatchWorkItem?

    var isBuffering: Bool {
        guard isPlaying, let player = player else { return false }
        return player.timeControlStatus != .playing
    }

    var volume: Float {
        get { UserDefaults.standard.object(forKey: "volume") as? Float ?? 1.0 }
        set {
            UserDefaults.standard.set(newValue, forKey: "volume")
            player?.volume = newValue
        }
    }

    func play() {
        guard !isPlaying else { return }
        isPlaying = true
        startStream()
        onStateChange?()
    }

    func stop() {
        guard isPlaying else { return }
        isPlaying = false
        retryWorkItem?.cancel()
        tearDown()
        onStateChange?()
    }

    func toggle() {
        isPlaying ? stop() : play()
    }

    /// Jump back to the live edge if we should be playing (after wake or a network change).
    func reconnectIfNeeded() {
        guard isPlaying else { return }
        startStream()
    }

    // MARK: - Stream

    private func startStream() {
        tearDown()

        let item = AVPlayerItem(url: Self.streamURL)
        let player = AVPlayer(playerItem: item)
        player.volume = volume
        player.automaticallyWaitsToMinimizeStalling = true

        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                if item.status == .failed { self?.scheduleRetry() }
            }
        }
        timeControlObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.onStateChange?() }
        }

        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(streamInterrupted), name: .AVPlayerItemFailedToPlayToEndTime, object: item)
        center.addObserver(self, selector: #selector(streamInterrupted), name: .AVPlayerItemPlaybackStalled, object: item)
        center.addObserver(self, selector: #selector(streamInterrupted), name: .AVPlayerItemDidPlayToEndTime, object: item)

        self.player = player
        player.play()
    }

    private func tearDown() {
        NotificationCenter.default.removeObserver(self)
        statusObservation = nil
        timeControlObservation = nil
        player?.pause()
        player = nil
    }

    @objc private func streamInterrupted(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in self?.scheduleRetry() }
    }

    /// Give AVPlayer a few seconds to recover on its own, then restart the stream.
    private func scheduleRetry() {
        guard isPlaying else { return }
        retryWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, self.isPlaying else { return }
            if self.player?.timeControlStatus != .playing {
                self.startStream()
                self.onStateChange?()
            }
        }
        retryWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: work)
    }
}
