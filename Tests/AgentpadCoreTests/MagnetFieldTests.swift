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
                                      target: target, strength: 1, speed: 800)
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

    func testOutsideMarginIsUntouched() {
        let free = MagnetField.adjust(movement: move, cursor: CGPoint(x: 120, y: 40),
                                      target: target, strength: 1, speed: 200)
        XCTAssertEqual(free, move)
    }

    func testZeroStrengthIsNeutral() {
        let neutral = MagnetField.adjust(movement: move, cursor: CGPoint(x: 120, y: 12),
                                         target: target, strength: 0, speed: 200)
        XCTAssertEqual(neutral, move)
    }
}
