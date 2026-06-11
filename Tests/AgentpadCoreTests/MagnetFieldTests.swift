import XCTest
@testable import AgentpadCore

final class MagnetFieldTests: XCTestCase {
    // a menu-bar-item-sized target
    private let target = CGRect(x: 100, y: 0, width: 80, height: 24)
    private let move = CGVector(dx: 4, dy: 0)

    func testNoTargetLeavesMovementUntouched() {
        XCTAssertEqual(MagnetField.adjust(movement: move, cursor: CGPoint(x: 120, y: 12),
                                          target: nil, strength: 1, speed: 200), move)
    }

    func testHighSpeedIsFreeFlight() {
        // above the speed limit the assist must not engage at all
        let fast = MagnetField.adjust(movement: move, cursor: CGPoint(x: 120, y: 12),
                                      target: target, strength: 1, speed: 1200)
        XCTAssertEqual(fast, move)
    }

    func testInsideTargetDampsMovementByStrength() {
        let damped = MagnetField.adjust(movement: move, cursor: CGPoint(x: 120, y: 12),
                                        target: target, strength: 1, speed: 200)
        XCTAssertEqual(damped.dx, 4 * 0.45, accuracy: 0.001)
        XCTAssertEqual(damped.dy, 0)
    }

    func testHalfStrengthDampsHalfAsHard() {
        let damped = MagnetField.adjust(movement: move, cursor: CGPoint(x: 120, y: 12),
                                        target: target, strength: 0.5, speed: 200)
        XCTAssertEqual(damped.dx, 4 * 0.725, accuracy: 0.001)
    }

    func testMarginAroundTargetIsStickyToo() {
        // 6 pt above the frame still damps (8 pt margin)
        let damped = MagnetField.adjust(movement: move, cursor: CGPoint(x: 120, y: -6),
                                        target: target, strength: 1, speed: 200)
        XCTAssertEqual(damped.dx, 4 * 0.45, accuracy: 0.001)
    }

    func testOutsideMarginKeepsFullSpeed() {
        // outside the sticky zone there is no damping — steering may bend
        // the path (approach zone), but the speed stays exactly the same
        let free = MagnetField.adjust(movement: move, cursor: CGPoint(x: 120, y: 40),
                                      target: target, strength: 1, speed: 200)
        XCTAssertEqual(hypot(free.dx, free.dy), hypot(move.dx, move.dy), accuracy: 0.001)
    }

    func testZeroStrengthIsNeutral() {
        let neutral = MagnetField.adjust(movement: move, cursor: CGPoint(x: 120, y: 12),
                                         target: target, strength: 0, speed: 200)
        XCTAssertEqual(neutral, move)
    }

    // MARK: - Steering (the actual "magnet" feel, phase 2)

    func testApproachBendsTowardTheTargetCenter() {
        // cursor left of the target, slightly below center, moving right:
        // the path bends up toward the center — the target "pulls"
        let cursor = CGPoint(x: 60, y: 20)
        let bent = MagnetField.adjust(movement: move, cursor: cursor,
                                      target: target, strength: 1, speed: 200)
        XCTAssertLessThan(bent.dy, 0)        // bends up (CG y grows down)
        XCTAssertGreaterThan(bent.dx, 0)     // still mainly moving right
    }

    func testSteeringNeverChangesSpeed() {
        let cursor = CGPoint(x: 60, y: 20)
        let bent = MagnetField.adjust(movement: move, cursor: cursor,
                                      target: target, strength: 1, speed: 200)
        XCTAssertEqual(hypot(bent.dx, bent.dy), hypot(move.dx, move.dy), accuracy: 0.001)
    }

    func testMovingAwayIsNeverHeldBack() {
        // moving left, away from the target: no bending, no prison feel
        let away = CGVector(dx: -4, dy: 0)
        let free = MagnetField.adjust(movement: away, cursor: CGPoint(x: 60, y: 20),
                                      target: target, strength: 1, speed: 200)
        XCTAssertEqual(free, away)
    }

    func testNoSteeringBeyondApproachRange() {
        let far = MagnetField.adjust(movement: move, cursor: CGPoint(x: -100, y: 20),
                                     target: target, strength: 1, speed: 200)
        XCTAssertEqual(far, move)
    }

    func testHighSpeedApproachIsFreeFlight() {
        let fast = MagnetField.adjust(movement: move, cursor: CGPoint(x: 60, y: 20),
                                      target: target, strength: 1, speed: 1200)
        XCTAssertEqual(fast, move)
    }
}
