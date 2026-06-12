import XCTest
@testable import AgentpadCore

final class TriggerGateTests: XCTestCase {
    func testFeatherTouchNeverPresses() {
        var gate = TriggerGate()
        for value: Float in [0.05, 0.1, 0.2, 0.29, 0.1, 0] {
            XCTAssertNil(gate.update(value: value))
        }
        XCTAssertFalse(gate.isPressed)
    }

    func testPressesAtThresholdAndHoldsThroughTheHysteresisBand() {
        var gate = TriggerGate()
        XCTAssertEqual(gate.update(value: 0.4), true)
        // relaxing into the band between the thresholds keeps the press
        XCTAssertNil(gate.update(value: 0.2))
        XCTAssertEqual(gate.update(value: 0.1), false)
    }

    func testFiresExactlyOncePerFlip() {
        var gate = TriggerGate()
        XCTAssertEqual(gate.update(value: 1.0), true)
        XCTAssertNil(gate.update(value: 0.9))
        XCTAssertNil(gate.update(value: 1.0))
        XCTAssertEqual(gate.update(value: 0.0), false)
        XCTAssertNil(gate.update(value: 0.0))
    }
}
