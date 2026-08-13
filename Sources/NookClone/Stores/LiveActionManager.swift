import Foundation
import Observation

@MainActor
@Observable
final class LiveActionManager {
    private(set) var currentAction: LiveAction?
    private(set) var queuedActions: [LiveAction] = []
    private var dismissalTask: Task<Void, Never>?

    func enqueue(_ action: LiveAction) {
        if let currentAction, action.priority > currentAction.priority {
            queuedActions.insert(currentAction, at: 0)
            present(action)
        } else if currentAction == nil {
            present(action)
        } else {
            queuedActions.append(action)
        }
    }

    func dismissCurrent() {
        dismissalTask?.cancel()
        dismissalTask = nil
        currentAction = nil
        presentNextIfNeeded()
    }

    func clear() {
        dismissalTask?.cancel()
        dismissalTask = nil
        currentAction = nil
        queuedActions.removeAll()
    }

    private func present(_ action: LiveAction) {
        dismissalTask?.cancel()
        currentAction = action
        dismissalTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(action.duration))
            guard !Task.isCancelled else { return }
            self?.currentAction = nil
            self?.presentNextIfNeeded()
        }
    }

    private func presentNextIfNeeded() {
        guard currentAction == nil, !queuedActions.isEmpty else { return }
        present(queuedActions.removeFirst())
    }
}
