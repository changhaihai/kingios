import AVFoundation

/// Replaces the Android foreground service: silent looping audio keeps the
/// process (and the WebSocket pipeline) alive while the app is in background.
final class KeepAlive {
    static let shared = KeepAlive()
    private var player: AVAudioPlayer?

    func start() {
        guard player == nil else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.mixWithOthers])
        try? session.setActive(true)
        guard let url = Bundle.main.url(forResource: "silence", withExtension: "wav") else { return }
        let p = try? AVAudioPlayer(contentsOf: url)
        p?.numberOfLoops = -1
        p?.volume = 0
        p?.play()
        player = p
    }
}
