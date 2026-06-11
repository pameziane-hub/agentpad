import Foundation
// CGGeometry only (CGRect math) — no AppKit, the core stays testable
import CoreGraphics

/// Sticky-target cursor assist ("aim friction"): inside a clickable
/// element's frame the cursor slows down, so it stops slipping past small
/// targets. The cursor never moves on its own — this only ever damps
/// movement the user is already making, and only on slow approaches.
public enum MagnetField {
    /// Targets feel slightly bigger than they are.
    public static let margin: CGFloat = 8
    /// Above this cursor speed (pt/s) the assist disengages entirely.
    public static let speedLimit: CGFloat = 600
    /// Damping at full strength: movement × (1 − 0.55) = ×0.45.
    static let maxDamping: CGFloat = 0.55

    public static func adjust(movement: CGVector, cursor: CGPoint,
                              target: CGRect?, strength: Float,
                              speed: CGFloat) -> CGVector {
        guard let target, strength > 0, speed <= speedLimit,
              target.insetBy(dx: -margin, dy: -margin).contains(cursor) else {
            return movement
        }
        let factor = 1 - maxDamping * CGFloat(strength)
        return CGVector(dx: movement.dx * factor, dy: movement.dy * factor)
    }
}
