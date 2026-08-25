import AppKit

@MainActor
final class TimerAlertService {
    private let playPrimary: () -> Bool
    private let playFallback: () -> Void

    init(
        playPrimary: (() -> Bool)? = nil,
        playFallback: @escaping () -> Void = { NSSound.beep() }
    ) {
        if let playPrimary {
            self.playPrimary = playPrimary
        } else {
            let sound = NSSound(named: NSSound.Name("Glass"))
            self.playPrimary = { sound?.play() ?? false }
        }
        self.playFallback = playFallback
    }

    func play() {
        if !playPrimary() {
            playFallback()
        }
    }
}
