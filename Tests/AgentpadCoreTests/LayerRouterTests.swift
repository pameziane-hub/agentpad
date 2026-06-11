import XCTest
@testable import AgentpadCore

final class LayerRouterTests: XCTestCase {
    private let buttons: [String: ButtonAction] = [
        "a": .leftClick,
        "rightTrigger": .key("return"),
        "dpadLeft": .key("left"),
        "dpadRight": .key("right"),
        "leftTrigger": .layer(tap: .rightClick, overlay: [
            "a": .key("cmd+tab"),
            "dpadLeft": .key("ctrl+left"),
            "dpadRight": .key("ctrl+right"),
        ]),
    ]

    private var router = LayerRouter()

    func testPlainButtonPassesThroughOnPressAndRelease() {
        XCTAssertEqual(router.handle(id: "a", pressed: true, at: 0, buttons: buttons),
                       .action(.leftClick, pressed: true))
        XCTAssertEqual(router.handle(id: "a", pressed: false, at: 0, buttons: buttons),
                       .action(.leftClick, pressed: false))
    }

    func testUnmappedButtonDoesNothing() {
        XCTAssertEqual(router.handle(id: "x", pressed: true, at: 0, buttons: buttons), .nothing)
    }

    func testLayerPressIsSwallowed() {
        XCTAssertEqual(router.handle(id: "leftTrigger", pressed: true, at: 0, buttons: buttons),
                       .nothing)
    }

    func testLayerTapFiresTapActionOnRelease() {
        _ = router.handle(id: "leftTrigger", pressed: true, at: 0, buttons: buttons)
        XCTAssertEqual(router.handle(id: "leftTrigger", pressed: false, at: 0, buttons: buttons),
                       .tap(.rightClick))
    }

    func testHeldLayerRemapsOverlayButtonAndSuppressesTap() {
        _ = router.handle(id: "leftTrigger", pressed: true, at: 0, buttons: buttons)
        XCTAssertEqual(router.handle(id: "dpadLeft", pressed: true, at: 0, buttons: buttons),
                       .action(.key("ctrl+left"), pressed: true))
        XCTAssertEqual(router.handle(id: "dpadLeft", pressed: false, at: 0, buttons: buttons),
                       .action(.key("ctrl+left"), pressed: false))
        // overlay was used: releasing the layer must not right-click
        XCTAssertEqual(router.handle(id: "leftTrigger", pressed: false, at: 0, buttons: buttons),
                       .nothing)
    }

    func testRepeatedOverlayUseStaysRemappedForOneHold() {
        _ = router.handle(id: "leftTrigger", pressed: true, at: 0, buttons: buttons)
        for _ in 0..<3 {
            XCTAssertEqual(router.handle(id: "dpadRight", pressed: true, at: 0, buttons: buttons),
                           .action(.key("ctrl+right"), pressed: true))
            _ = router.handle(id: "dpadRight", pressed: false, at: 0, buttons: buttons)
        }
        XCTAssertEqual(router.handle(id: "leftTrigger", pressed: false, at: 0, buttons: buttons),
                       .nothing)
        // next hold starts fresh
        _ = router.handle(id: "leftTrigger", pressed: true, at: 0, buttons: buttons)
        XCTAssertEqual(router.handle(id: "leftTrigger", pressed: false, at: 0, buttons: buttons),
                       .tap(.rightClick))
    }

    func testNonOverlayButtonDuringHoldActsNormallyAndKeepsTap() {
        _ = router.handle(id: "leftTrigger", pressed: true, at: 0, buttons: buttons)
        // RT is not in the overlay: it keeps its base action
        XCTAssertEqual(router.handle(id: "rightTrigger", pressed: true, at: 0, buttons: buttons),
                       .action(.key("return"), pressed: true))
        // and it does not consume the layer: the tap still fires
        XCTAssertEqual(router.handle(id: "leftTrigger", pressed: false, at: 0, buttons: buttons),
                       .tap(.rightClick))
    }

    func testDpadIsPlainArrowsWithoutTheLayer() {
        XCTAssertEqual(router.handle(id: "dpadLeft", pressed: true, at: 0, buttons: buttons),
                       .action(.key("left"), pressed: true))
    }

    func testLayerWithoutTapReleasesSilently() {
        let noTap: [String: ButtonAction] = [
            "leftTrigger": .layer(tap: nil, overlay: ["a": .leftClick]),
        ]
        _ = router.handle(id: "leftTrigger", pressed: true, at: 0, buttons: noTap)
        XCTAssertEqual(router.handle(id: "leftTrigger", pressed: false, at: 0, buttons: noTap),
                       .nothing)
    }

    func testOverlayPressReleasePairStaysConsistentAcrossLayerRelease() {
        // press dpadLeft while held, release the layer first, then dpadLeft:
        // the release must route to the action chosen at press time, so a
        // down/up pair can never split across two different actions
        _ = router.handle(id: "leftTrigger", pressed: true, at: 0, buttons: buttons)
        _ = router.handle(id: "dpadLeft", pressed: true, at: 0, buttons: buttons)
        _ = router.handle(id: "leftTrigger", pressed: false, at: 0, buttons: buttons)
        XCTAssertEqual(router.handle(id: "dpadLeft", pressed: false, at: 0, buttons: buttons),
                       .action(.key("ctrl+left"), pressed: false))
    }

    func testReleaseWithoutPriorPressDoesNothing() {
        XCTAssertEqual(router.handle(id: "a", pressed: false, at: 0, buttons: buttons), .nothing)
    }

    func testExposesHeldLayerId() {
        XCTAssertNil(router.heldLayer)
        _ = router.handle(id: "leftTrigger", pressed: true, at: 0, buttons: buttons)
        XCTAssertEqual(router.heldLayer, "leftTrigger")
        _ = router.handle(id: "leftTrigger", pressed: false, at: 0, buttons: buttons)
        XCTAssertNil(router.heldLayer)
    }

    // MARK: - Menu-style grace window
    // Field test 2026-06-11: users read the HUD as a menu — hold, RELEASE,
    // then pick. A short grace window after a long hold honors that.

    func testLongHoldReleaseFiresNothing() {
        _ = router.handle(id: "leftTrigger", pressed: true, at: 0, buttons: buttons)
        XCTAssertEqual(router.handle(id: "leftTrigger", pressed: false, at: 0.5, buttons: buttons),
                       .nothing)
    }

    func testOverlayPressWithinGraceStillRemaps() {
        _ = router.handle(id: "leftTrigger", pressed: true, at: 0, buttons: buttons)
        _ = router.handle(id: "leftTrigger", pressed: false, at: 0.5, buttons: buttons)
        XCTAssertEqual(router.handle(id: "a", pressed: true, at: 0.65, buttons: buttons),
                       .action(.key("cmd+tab"), pressed: true))
        XCTAssertEqual(router.handle(id: "a", pressed: false, at: 0.7, buttons: buttons),
                       .action(.key("cmd+tab"), pressed: false))
    }

    func testGraceExpires() {
        _ = router.handle(id: "leftTrigger", pressed: true, at: 0, buttons: buttons)
        _ = router.handle(id: "leftTrigger", pressed: false, at: 0.5, buttons: buttons)
        XCTAssertEqual(router.handle(id: "a", pressed: true, at: 0.8, buttons: buttons),
                       .action(.leftClick, pressed: true))
    }

    func testGraceConsumedByFirstPress() {
        _ = router.handle(id: "leftTrigger", pressed: true, at: 0, buttons: buttons)
        _ = router.handle(id: "leftTrigger", pressed: false, at: 0.5, buttons: buttons)
        _ = router.handle(id: "a", pressed: true, at: 0.6, buttons: buttons)
        _ = router.handle(id: "a", pressed: false, at: 0.62, buttons: buttons)
        // one menu pick per grace: the second press is back to base
        XCTAssertEqual(router.handle(id: "a", pressed: true, at: 0.7, buttons: buttons),
                       .action(.leftClick, pressed: true))
    }

    func testNonOverlayPressClearsGrace() {
        _ = router.handle(id: "leftTrigger", pressed: true, at: 0, buttons: buttons)
        _ = router.handle(id: "leftTrigger", pressed: false, at: 0.5, buttons: buttons)
        XCTAssertEqual(router.handle(id: "rightTrigger", pressed: true, at: 0.55, buttons: buttons),
                       .action(.key("return"), pressed: true))
        XCTAssertEqual(router.handle(id: "a", pressed: true, at: 0.6, buttons: buttons),
                       .action(.leftClick, pressed: true))
    }

    func testUsedLayerReleaseGrantsNoGrace() {
        _ = router.handle(id: "leftTrigger", pressed: true, at: 0, buttons: buttons)
        _ = router.handle(id: "dpadLeft", pressed: true, at: 0.1, buttons: buttons)
        _ = router.handle(id: "dpadLeft", pressed: false, at: 0.15, buttons: buttons)
        _ = router.handle(id: "leftTrigger", pressed: false, at: 0.5, buttons: buttons)
        XCTAssertEqual(router.handle(id: "a", pressed: true, at: 0.55, buttons: buttons),
                       .action(.leftClick, pressed: true))
    }

    func testShortTapGrantsNoGrace() {
        _ = router.handle(id: "leftTrigger", pressed: true, at: 0, buttons: buttons)
        XCTAssertEqual(router.handle(id: "leftTrigger", pressed: false, at: 0.1, buttons: buttons),
                       .tap(.rightClick))
        XCTAssertEqual(router.handle(id: "a", pressed: true, at: 0.15, buttons: buttons),
                       .action(.leftClick, pressed: true))
    }

    func testResetClearsHeldLayer() {
        _ = router.handle(id: "leftTrigger", pressed: true, at: 0, buttons: buttons)
        router.reset()
        // after reset the pending tap is gone…
        XCTAssertEqual(router.handle(id: "leftTrigger", pressed: false, at: 0, buttons: buttons),
                       .nothing)
        // …and the d-pad is back to plain arrows
        XCTAssertEqual(router.handle(id: "dpadLeft", pressed: true, at: 0, buttons: buttons),
                       .action(.key("left"), pressed: true))
    }
}
