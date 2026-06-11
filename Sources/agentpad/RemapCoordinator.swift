import Foundation
import AgentpadCore

/// In-app rebinding: the user clicks a mapping row in the menu, then presses
/// a controller button; the two buttons swap their actions and the change is
/// persisted. The capture eats the press (and its release) so the pressed
/// button's action doesn't fire mid-rebind.
final class RemapCoordinator {
    private let store: ConfigStore
    private var sourceButton: String?
    private var swallowReleaseOf: String?
    private var timeoutTimer: Timer?

    var isCapturing: Bool { sourceButton != nil }
    var onBegin: ((String) -> Void)?
    var onComplete: (() -> Void)?
    var onCancel: (() -> Void)?

    init(store: ConfigStore) {
        self.store = store
    }

    func begin(for buttonId: String) {
        sourceButton = buttonId
        timeoutTimer?.invalidate()
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: 6, repeats: false) { [weak self] _ in
            self?.cancel()
        }
        let label = store.config.buttons[buttonId].map(MappingSummary.describe) ?? buttonId
        onBegin?(label)
    }

    /// Wired as Engine.captureHandler. Returns true when the event was consumed.
    func handle(id: String, pressed: Bool) -> Bool {
        if let pending = swallowReleaseOf, id == pending, !pressed {
            swallowReleaseOf = nil
            return true
        }
        guard let source = sourceButton else { return false }
        guard pressed else { return true }   // stray releases during capture

        sourceButton = nil
        timeoutTimer?.invalidate()
        swallowReleaseOf = id
        store.swapBinding(source, id)
        onComplete?()
        return true
    }

    func cancel() {
        guard isCapturing else { return }
        sourceButton = nil
        timeoutTimer?.invalidate()
        onCancel?()
    }
}
