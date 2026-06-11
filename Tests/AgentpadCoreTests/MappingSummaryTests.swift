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
            "LT", "LT + A", "LT + B", "LT + X", "LT + Y",
            "LT + D-Pad ↑", "LT + D-Pad ←", "LT + D-Pad →",
            "RT", "LB", "RB", "L3", "R3", "Menu",
        ])
    }

    func testRowsExpandLayerOverlays() {
        let rows = MappingSummary.rows(for: .default)
        let ltIndex = rows.firstIndex(where: { $0.button == "LT" })!
        XCTAssertEqual(rows[ltIndex].action, "Right Click (tap)")
        // slots expand in display order: face buttons first, then D-Pad
        XCTAssertEqual(rows[ltIndex + 1].button, "LT + A")
        XCTAssertEqual(rows[ltIndex + 1].action, "Cmd+Tab")
        XCTAssertEqual(rows[ltIndex + 2].action, "Delete")
        XCTAssertEqual(rows[ltIndex + 3].action, "Cmd+Z")
        XCTAssertEqual(rows[ltIndex + 4].action, "Ctrl+C")
        XCTAssertEqual(rows[ltIndex + 5].button, "LT + D-Pad ↑")
        XCTAssertEqual(rows[ltIndex + 5].action, "Cmd+A")
        XCTAssertEqual(rows[ltIndex + 6].button, "LT + D-Pad ←")
        XCTAssertEqual(rows[ltIndex + 6].action, "Ctrl+Left")
    }

    func testOverlayRowsUseShortLabelsForTheHud() {
        let rows = MappingSummary.overlayRows(forLayer: "leftTrigger", config: .default)
        XCTAssertEqual(rows.first?.button, "A")
        XCTAssertTrue(rows.contains(where: { $0.button == "D-Pad ←" }))
    }

    func testOverlayRowsSpeakPlainWordsNotKeyCombos() {
        // the HUD is a menu for humans: say what a slot does, not its combo
        let rows = MappingSummary.overlayRows(forLayer: "leftTrigger", config: .default)
        let byButton = Dictionary(uniqueKeysWithValues: rows.map { ($0.button, $0.action) })
        XCTAssertEqual(byButton["A"], "Last App")
        XCTAssertEqual(byButton["B"], "Delete")
        XCTAssertEqual(byButton["X"], "Undo")
        XCTAssertEqual(byButton["Y"], "Interrupt")
        XCTAssertEqual(byButton["D-Pad ↑"], "Select All")
        XCTAssertEqual(byButton["D-Pad ←"], "Space ←")
        XCTAssertEqual(byButton["D-Pad →"], "Space →")
    }

    func testUnknownCombosFallBackToTheirKeyNamesInTheHud() {
        var config = Config.default
        config.buttons["leftTrigger"] = .layer(tap: nil, overlay: ["a": .key("cmd+shift+s")])
        let rows = MappingSummary.overlayRows(forLayer: "leftTrigger", config: config)
        XCTAssertEqual(rows.first?.action, "Cmd+Shift+S")
    }

    func testOverlayRowsEmptyForNonLayerButton() {
        XCTAssertTrue(MappingSummary.overlayRows(forLayer: "a", config: .default).isEmpty)
    }

    func testRowsSkipUnconfiguredButtons() {
        var config = Config.default
        config.buttons.removeValue(forKey: "x")
        let rows = MappingSummary.rows(for: config)
        XCTAssertFalse(rows.map(\.button).contains("X"))
        XCTAssertEqual(rows.count, MappingSummary.rows(for: .default).count - 1)
    }
}
