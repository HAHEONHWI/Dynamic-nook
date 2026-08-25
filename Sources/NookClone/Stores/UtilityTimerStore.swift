import Foundation
import Observation

@MainActor
@Observable
final class UtilityTimerStore {
    enum Mode: String, Sendable { case countdown, stopwatch }

    private(set) var mode: Mode
    private(set) var isRunning = false
    private(set) var elapsed: TimeInterval = 0
    private(set) var duration: TimeInterval = 300
    private var referenceDate: Date?
    @ObservationIgnored var onCompletion: (() -> Void)?
    @ObservationIgnored private var ticker: Task<Void, Never>?

    init(mode: Mode = .countdown) {
        self.mode = mode
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                self?.refresh()
            }
        }
    }

    deinit { ticker?.cancel() }

    func select(_ mode: Mode) { reset(); self.mode = mode }
    func setMinutes(_ minutes: Int) { duration = TimeInterval(max(1, minutes) * 60); reset() }
    func startPause(now: Date = .now) {
        if isRunning { elapsed = currentElapsed(now: now); referenceDate = nil; isRunning = false }
        else { referenceDate = now.addingTimeInterval(-elapsed); isRunning = true }
    }
    func reset() { isRunning = false; elapsed = 0; referenceDate = nil }
    func refresh(now: Date = .now) {
        guard isRunning else { return }
        elapsed = currentElapsed(now: now)
        if mode == .countdown, elapsed >= duration {
            elapsed = duration
            isRunning = false
            referenceDate = nil
            onCompletion?()
        }
    }
    var displayedSeconds: Int { Int((mode == .countdown ? max(0, duration - elapsed) : elapsed).rounded(.down)) }
    var clockText: String { String(format: "%02d:%02d", displayedSeconds / 60, displayedSeconds % 60) }
    private func currentElapsed(now: Date) -> TimeInterval { referenceDate.map { max(0, now.timeIntervalSince($0)) } ?? elapsed }
}
