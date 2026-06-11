import Foundation
// CGGeometry only (CGRect math) — no AppKit, the core stays testable
import CoreGraphics

/// Keeps the synthetic cursor on screen. Pure geometry (CG global
/// coordinates, y down) so multi-display edge cases stay unit-testable.
public enum DisplayClamp {
    /// A point inside any display passes through. Anything else snaps to
    /// the nearest point on the nearest display — NOT to the first display
    /// in the list, which used to teleport the cursor off a secondary
    /// screen whenever its menu bar was approached a little too fast.
    public static func clamp(_ point: CGPoint, to displays: [CGRect]) -> CGPoint {
        if displays.contains(where: { $0.contains(point) }) { return point }
        var best = point
        var bestDistance = CGFloat.infinity
        for bounds in displays {
            let candidate = CGPoint(
                x: min(max(point.x, bounds.minX), bounds.maxX - 1),
                y: min(max(point.y, bounds.minY), bounds.maxY - 1))
            let dx = candidate.x - point.x
            let dy = candidate.y - point.y
            let distance = dx * dx + dy * dy
            if distance < bestDistance {
                bestDistance = distance
                best = candidate
            }
        }
        return best
    }
}
