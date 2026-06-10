import XCTest
@testable import AgentpadCore

final class CurvesTests: XCTestCase {
    func testInsideDeadzoneReturnsZero() {
        let v = Curves.shape(x: 0.05, y: 0.08, deadzone: 0.12, expo: 0.6)
        XCTAssertEqual(v, .zero)
    }

    func testFullDeflectionHasMagnitudeOne() {
        let v = Curves.shape(x: 1, y: 0, deadzone: 0.12, expo: 0.6)
        XCTAssertEqual(v.x, 1, accuracy: 0.0001)
        XCTAssertEqual(v.y, 0, accuracy: 0.0001)
    }

    func testZeroExpoIsLinear() {
        let v = Curves.shape(x: 0.5, y: 0, deadzone: 0, expo: 0)
        XCTAssertEqual(v.x, 0.5, accuracy: 0.0001)
    }

    func testFullExpoIsCubic() {
        let v = Curves.shape(x: 0.5, y: 0, deadzone: 0, expo: 1)
        XCTAssertEqual(v.x, 0.125, accuracy: 0.0001)
    }

    func testDirectionIsPreserved() {
        let v = Curves.shape(x: 0.3, y: 0.4, deadzone: 0.1, expo: 0.5)
        // input direction is (0.6, 0.8); output must point the same way
        XCTAssertEqual(v.y / v.x, 0.8 / 0.6, accuracy: 0.0001)
        XCTAssertGreaterThan(v.x, 0)
    }

    func testDegenerateDeadzoneReturnsZero() {
        XCTAssertEqual(Curves.shape(x: 1, y: 0, deadzone: 1, expo: 0), .zero)
    }
}
