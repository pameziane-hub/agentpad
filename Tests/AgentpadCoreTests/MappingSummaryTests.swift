import XCTest
@testable import AgentpadCore

final class MappingSummaryTests: XCTestCase {
    func testDescribesKeyActions() {
        XCTAssertEqual(MappingSummary.describe(.key("return")), "Return")
        XCTAssertEqual(MappingSummary.describe(.key("shift+tab")), "Shift+Tab")
        XCTAssertEqual(MappingSummary.describe(.key("ctrl ctrl")), "Ctrl Ctrl")
    }

    func testDescribesClicksAndPause() {
        XCTAssertEqual(MappingSummary.describe(.leftClick), "Left Click")
        XCTAssertEqual(MappingSummary.describe(.rightClick), "Right Click")
        XCTAssertEqual(MappingSummary.describe(.pause), "Pause / Resume")
    }

    func testDescribesKnownDictationUrls() {
        XCTAssertEqual(MappingSummary.describe(.url("superwhisper://record")), "Superwhisper")
        XCTAssertEqual(MappingSummary.describe(.url("raycast://foo")), "raycast://foo")
    }

    func testRowsAreOrderedAndComplete() {
        let rows = MappingSummary.rows(for: .default)
        XCTAssertEqual(rows.count, Config.default.buttons.count)
        XCTAssertEqual(rows.first?.button, "A")
        XCTAssertEqual(rows.first?.action, "Return")
        // every configured button shows up, in the fixed display order
        XCTAssertEqual(rows.map(\.button), [
            "A", "B", "X", "Y",
            "D-Pad ↑", "D-Pad ↓", "D-Pad ←", "D-Pad →",
            "LT", "RT", "LB", "RB", "Menu",
        ])
    }

    func testRowsSkipUnconfiguredButtons() {
        var config = Config.default
        config.buttons.removeValue(forKey: "x")
        let rows = MappingSummary.rows(for: config)
        XCTAssertFalse(rows.map(\.button).contains("X"))
        XCTAssertEqual(rows.count, Config.default.buttons.count - 1)
    }
}
