import AppKit

@MainActor
final class HapticService {
    func perform(enabled: Bool, pattern: NSHapticFeedbackManager.FeedbackPattern = .alignment) {
        guard enabled else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    }
}
