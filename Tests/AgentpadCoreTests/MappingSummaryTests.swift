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

    func testDescribesLayerByItsTapAction() {
        let layer = ButtonAction.layer(tap: .rightClick,
                                       overlay: ["dpadLeft": .key("ctrl+left")])
        XCTAssertEqual(MappingSummary.describe(layer), "Right Click (tap)")
    }

    func testDescribesLayerWithoutTap() {
        XCTAssertEqual(MappingSummary.describe(.layer(tap: nil, overlay: [:])), "Layer")
    }

    func testRowsAreOrderedAndComplete() {
        let rows = MappingSummary.rows(for: .default)
        XCTAssertEqual(rows.first?.button, "A")
        XCTAssertEqual(rows.first?.action, "Left Click")
        // every configured button shows up, in the fixed display order;
        // the LT layer expands into one extra row per overlay entry
        XCTAssertEqual(rows.map(\.button), [
            "A", "B", "X", "Y",
            "D-Pad ↑", "D-Pad ↓", "D-Pad ←", "D-Pad →",
            "LT", "LT + D-Pad ←", "LT + D-Pad →",
            "RT", "LB", "RB", "L3", "R3", "Menu",
        ])
    }

    func testRowsExpandLayerOverlays() {
        let rows = MappingSummary.rows(for: .default)
        let ltIndex = rows.firstIndex(where: { $0.button == "LT" })!
        XCTAssertEqual(rows[ltIndex].action, "Right Click (tap)")
        XCTAssertEqual(rows[ltIndex + 1].button, "LT + D-Pad ←")
        XCTAssertEqual(rows[ltIndex + 1].action, "Ctrl+Left")
        XCTAssertEqual(rows[ltIndex + 2].button, "LT + D-Pad →")
        XCTAssertEqual(rows[ltIndex + 2].action, "Ctrl+Right")
    }

    func testRowsSkipUnconfiguredButtons() {
        var config = Config.default
        config.buttons.removeValue(forKey: "x")
        let rows = MappingSummary.rows(for: config)
        XCTAssertFalse(rows.map(\.button).contains("X"))
        XCTAssertEqual(rows.count, MappingSummary.rows(for: .default).count - 1)
    }
}
