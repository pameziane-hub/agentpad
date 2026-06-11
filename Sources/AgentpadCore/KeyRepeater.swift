import Foundation

/// Keyboard-style auto-repeat for held buttons mapped to a single key combo.
/// Pure logic: the engine tick passes time in and posts whatever comes back,
/// so timing is unit-testable. Like a real keyboard, only the most recently
/// pressed key repeats; a new press replaces the old repeat.
public struct KeyRepeater {
    private let initialDelay: TimeInterval
    private let interval: TimeInterval
    private var heldId: String?
    private var combo: KeyCombo?
    private var nextFireTime: TimeInterval = 0

    public init(initialDelay: TimeInterval, interval: TimeInterval) {
        self.initialDelay = initialDelay
        self.interval = interval
    }

    public mutating func keyDown(id: String, combo: KeyCombo, at time: TimeInterval) {
        heldId = id
        self.combo = combo
        nextFireTime = time + initialDelay
    }

    public mutating func keyUp(id: String) {
        guard id == heldId else { return }
        reset()
    }

    public mutating func reset() {
        heldId = nil
        combo = nil
    }

    /// At most one fire per call; the 120 Hz tick outpaces any repeat rate.
    /// Advancing from the scheduled time (not `time`) keeps the cadence even.
    public mutating func nextFire(at time: TimeInterval) -> KeyCombo? {
        guard let combo, time >= nextFireTime else { return nil }
        nextFireTime += interval
        return combo
    }
}
