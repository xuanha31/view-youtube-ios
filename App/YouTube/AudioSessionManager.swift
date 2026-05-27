import AVFoundation
import MediaPlayer

/// Keeps audio playing when the screen is locked or the app is backgrounded,
/// and wires up Lock Screen / Control Center transport controls.
final class AudioSessionManager {
    static let shared = AudioSessionManager()
    private init() {}

    /// `.playback` category is what allows sound to continue with the screen
    /// off. Must be paired with the `audio` UIBackgroundMode (see Info.plist).
    func activate() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .moviePlayback)
            try session.setActive(true)
        } catch {
            print("[AudioSession] activate failed: \(error)")
        }
        configureRemoteCommands()
    }

    // MARK: - Lock screen / Control Center controls

    /// Forwards play/pause/seek presses to the web player via injected JS.
    /// `onCommand` is set by the web view once it is ready.
    var onCommand: ((TransportCommand) -> Void)?

    enum TransportCommand { case play, pause, next, previous }

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            self?.onCommand?(.play); return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.onCommand?(.pause); return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.onCommand?(.next); return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.onCommand?(.previous); return .success
        }
    }

    /// Updates the "Now Playing" metadata shown on the Lock Screen.
    func updateNowPlaying(title: String, isPlaying: Bool) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        info[MPMediaItemPropertyArtist] = "ViewTube"
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
