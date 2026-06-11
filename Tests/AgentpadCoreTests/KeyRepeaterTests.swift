import XCTest
@testable import AgentpadCore

final class KeyRepeaterTests: XCTestCase {
    private let combo = KeyCombo(keyCode: 51, flags: [])      // delete
    private let other = KeyCombo(keyCode: 126, flags: [])     // up
    private var repeater = KeyRepeater(initialDelay: 0.5, interval: 0.1)

    func testNoFireBeforeInitialDelay() {
        repeater.keyDown(id: "b", combo: combo, at: 10.0)
        XCTAssertNil(repeater.nextFire(at: 10.4))
    }

    func testFiresAfterDelayThenAtInterval() {
        repeater.keyDown(id: "b", combo: combo, at: 10.0)
        XCTAssertEqual(repeater.nextFire(at: 10.5), combo)
        XCTAssertNil(repeater.nextFire(at: 10.55))
        XCTAssertEqual(repeater.nextFire(at: 10.6), combo)
    }

    func testReleaseStopsRepeat() {
        repeater.keyDown(id: "b", combo: combo, at: 10.0)
        repeater.keyUp(id: "b")
        XCTAssertNil(repeater.nextFire(at: 11.0))
    }

    func testReleaseOfDifferentButtonKeepsRepeat() {
        repeater.keyDown(id: "b", combo: combo, at: 10.0)
        repeater.keyUp(id: "a")
        XCTAssertEqual(repeater.nextFire(at: 10.5), combo)
    }

    func testNewKeyReplacesRepeatLikeAKeyboard() {
        repeater.keyDown(id: "b", combo: combo, at: 10.0)
        repeater.keyDown(id: "dpadUp", combo: other, at: 10.3)
        // the old key no longer fires; the new key fires on its own clock
        XCTAssertNil(repeater.nextFire(at: 10.5))
        XCTAssertEqual(repeater.nextFire(at: 10.8), other)
    }

    func testResetStopsRepeat() {
        repeater.keyDown(id: "b", combo: combo, at: 10.0)
        repeater.reset()
        XCTAssertNil(repeater.nextFire(at: 11.0))
    }
}
