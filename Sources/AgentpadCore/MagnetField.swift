import Foundation
// CGGeometry only (CGRect math) — no AppKit, the core stays testable
import CoreGraphics

/// Sticky-target cursor assist: inside a clickable element's frame the
/// cursor slows down ("aim friction"); on a slow approach the path bends
/// gently toward the target center (the "magnet" feel). The cursor never
/// moves on its own, never speeds up, and is never held back when moving
/// away — assist only ever reshapes movement the user is already making.
public enum MagnetField {
    /// Targets feel slightly bigger than they are.
    public static let margin: CGFloat = 8
    /// Above this cursor speed (pt/s) the assist disengages entirely.
    public static let speedLimit: CGFloat = 600
    /// Damping at full strength: movement × (1 − 0.55) = ×0.45.
    static let maxDamping: CGFloat = 0.55
    /// Steering engages within this distance of the target's frame.
    public static let approachRange: CGFloat = 80
    /// Direction-blend weight toward the target center at full strength.
    static let maxSteering: CGFloat = 0.35

    public static func adjust(movement: CGVector, cursor: CGPoint,
                              target: CGRect?, strength: Float,
                              speed: CGFloat) -> CGVector {
        guard let target, strength > 0, speed <= speedLimit else { return movement }
        let sticky = target.insetBy(dx: -margin, dy: -margin)
        if sticky.contains(cursor) {
            let factor = 1 - maxDamping * CGFloat(strength)
            return CGVector(dx: movement.dx * factor, dy: movement.dy * factor)
        }
        return steer(movement: movement, cursor: cursor, target: target,
                     strength: CGFloat(strength))
    }

    /// Blend the movement direction toward the target center — keeping the
    /// speed exactly as it was — but only while actually approaching.
    private static func steer(movement: CGVector, cursor: CGPoint,
                              target: CGRect, strength: CGFloat) -> CGVector {
        let dx = max(target.minX - cursor.x, 0, cursor.x - target.maxX)
        let dy = max(target.minY - cursor.y, 0, cursor.y - target.maxY)
        guard hypot(dx, dy) <= approachRange else { return movement }

        let length = hypot(movement.dx, movement.dy)
        guard length > 0 else { return movement }
        let toCenter = CGVector(dx: target.midX - cursor.x, dy: target.midY - cursor.y)
        let toLength = hypot(toCenter.dx, toCenter.dy)
        guard toLength > 0 else { return movement }

        // moving away must stay completely free — no prison feel
        let dot = movement.dx * toCenter.dx + movement.dy * toCenter.dy
        guard dot > 0 else { return movement }

        let weight = min(maxSteering, 0.5 * strength)
        let blendedX = (movement.dx / length) * (1 - weight) + (toCenter.dx / toLength) * weight
        let blendedY = (movement.dy / length) * (1 - weight) + (toCenter.dy / toLength) * weight
        let blendedLength = hypot(blendedX, blendedY)
        guard blendedLength > 0 else { return movement }
        return CGVector(dx: blendedX / blendedLength * length,
                        dy: blendedY / blendedLength * length)
    }
}
