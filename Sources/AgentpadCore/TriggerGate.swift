import Foundation

/// Turns an analog trigger value into a digital press with a real pull
/// threshold and hysteresis. GCController's built-in isPressed reacts to a
/// feather touch — a finger resting on LT produced phantom taps, which the
/// layer turned into phantom right clicks (field bug 2026-06-12).
public struct TriggerGate {
    /// Pull beyond this to register a press…
    public static let pressThreshold: Float = 0.30
    /// …and relax below this to release: the gap swallows jitter.
    public static let releaseThreshold: Float = 0.15

    public private(set) var isPressed = false

    public init() {}

    /// Feed every analog value; returns the new digital state when it
    /// flips, nil while nothing changes.
    public mutating func update(value: Float) -> Bool? {
        if !isPressed, value >= Self.pressThreshold {
            isPressed = true
            return true
        }
        if isPressed, value <= Self.releaseThreshold {
            isPressed = false
            return false
        }
        return nil
    }
}
