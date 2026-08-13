import Foundation
import Observation

enum FocusTimerState: Equatable, Sendable {
    case idle
    case running
    case paused
    case completed
}

enum FocusTimerKind: Equatable, Sendable {
    case focus
    case breakTime
}

@MainActor
@Observable
final class FocusTimerStore {
    private(set) var state: FocusTimerState = .idle
    private(set) var kind: FocusTimerKind = .focus
    private(set) var selectedMinutes: Int
    private(set) var remainingSeconds: TimeInterval
    private(set) var endDate: Date?
    @ObservationIgnored var onCompletion: (() -> Void)?
    @ObservationIgnored private var tickerTask: Task<Void, Never>?

    init(defaultMinutes: Int = 25, startTicker: Bool = true) {
        let minutes = max(1, defaultMinutes)
        selectedMinutes = minutes
        remainingSeconds = TimeInterval(minutes * 60)
        if startTicker {
            tickerTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1))
                    guard !Task.isCancelled else { return }
                    self?.refresh()
                }
            }
        }
    }

    deinit { tickerTask?.cancel() }

    func select(minutes: Int, kind: FocusTimerKind = .focus) {
        self.kind = kind
        selectedMinutes = max(1, minutes)
        remainingSeconds = TimeInterval(selectedMinutes * 60)
        endDate = nil
        state = .idle
    }

    func start(minutes: Int? = nil, now: Date = Date()) {
        if let minutes { selectedMinutes = max(1, minutes) }
        remainingSeconds = TimeInterval(selectedMinutes * 60)
        endDate = now.addingTimeInterval(remainingSeconds)
        state = .running
    }

    func pause(now: Date = Date()) {
        guard state == .running, let endDate else { return }
        remainingSeconds = max(0, endDate.timeIntervalSince(now))
        self.endDate = nil
        state = remainingSeconds > 0 ? .paused : .completed
    }

    func resume(now: Date = Date()) {
        guard state == .paused, remainingSeconds > 0 else { return }
        endDate = now.addingTimeInterval(remainingSeconds)
        state = .running
    }

    func reset(defaultMinutes: Int? = nil) {
        kind = .focus
        if let defaultMinutes { selectedMinutes = max(1, defaultMinutes) }
        remainingSeconds = TimeInterval(selectedMinutes * 60)
        endDate = nil
        state = .idle
    }

    func refresh(now: Date = Date()) {
        guard state == .running, let endDate else { return }
        let remaining = endDate.timeIntervalSince(now)
        guard remaining <= 0 else {
            remainingSeconds = remaining
            return
        }
        remainingSeconds = 0
        self.endDate = nil
        state = .completed
        onCompletion?()
    }

    var progress: Double {
        let total = TimeInterval(max(1, selectedMinutes) * 60)
        return min(max(1 - remainingSeconds / total, 0), 1)
    }

    var clockText: String {
        let seconds = max(0, Int(remainingSeconds.rounded(.up)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
