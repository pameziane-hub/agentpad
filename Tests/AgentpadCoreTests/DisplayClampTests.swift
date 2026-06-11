import XCTest
@testable import AgentpadCore

final class DisplayClampTests: XCTestCase {
    // CG global coordinates: origin at the main display's top-left, y grows
    // downward. A 1512×982 MacBook panel sits to the right of a 1920×1080
    // main display, its top edge 200 pt lower.
    private let main = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    private let macbook = CGRect(x: 1920, y: 200, width: 1512, height: 982)
    private var displays: [CGRect] { [main, macbook] }

    func testPointInsideADisplayIsUntouched() {
        let point = CGPoint(x: 2500, y: 600)
        XCTAssertEqual(DisplayClamp.clamp(point, to: displays), point)
    }

    func testOvershootClampsToTheNearestDisplayNotTheFirst() {
        // aiming for the MacBook's menu bar overshoots its top edge; the
        // cursor must stick to that edge, not teleport to the main display
        let overshoot = CGPoint(x: 2500, y: 190)
        XCTAssertEqual(DisplayClamp.clamp(overshoot, to: displays),
                       CGPoint(x: 2500, y: 200))
    }

    func testOvershootOnMainClampsToMain() {
        let overshoot = CGPoint(x: 500, y: -40)
        XCTAssertEqual(DisplayClamp.clamp(overshoot, to: displays),
                       CGPoint(x: 500, y: 0))
    }

    func testFarCornerOvershootClampsBothAxes() {
        let overshoot = CGPoint(x: 3600, y: 1300)
        XCTAssertEqual(DisplayClamp.clamp(overshoot, to: displays),
                       CGPoint(x: 1920 + 1512 - 1, y: 982 + 200 - 1))
    }

    func testNoDisplaysReturnsThePointUnchanged() {
        let point = CGPoint(x: 10, y: 10)
        XCTAssertEqual(DisplayClamp.clamp(point, to: []), point)
    }
}
