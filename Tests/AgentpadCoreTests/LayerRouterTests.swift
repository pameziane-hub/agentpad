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

    func testNonOverlayButtonDuringHoldActsNormallyAndSuppressesTap() {
        _ = router.handle(id: "leftTrigger", pressed: true, at: 0, buttons: buttons)
        // RT is not in the overlay: it keeps its base action
        XCTAssertEqual(router.handle(id: "rightTrigger", pressed: true, at: 0.05, buttons: buttons),
                       .action(.key("return"), pressed: true))
        _ = router.handle(id: "rightTrigger", pressed: false, at: 0.1, buttons: buttons)
        // but ANY companion press proves the hold was a chord, not a tap:
        // releasing LT inside the tap window must not fire a phantom right
        // click on top (field bug 2026-06-12: context menus kept popping)
        XCTAssertEqual(router.handle(id: "leftTrigger", pressed: false, at: 0.2, buttons: buttons),
                       .nothing)
    }

    func testReleaseOfEarlierButtonDuringHoldKeepsTap() {
        // a button that was already down BEFORE the layer is no chord:
        // only presses during the hold suppress the tap, releases don't
        _ = router.handle(id: "rightTrigger", pressed: true, at: 0, buttons: buttons)
        _ = router.handle(id: "leftTrigger", pressed: true, at: 0.1, buttons: buttons)
        _ = router.handle(id: "rightTrigger", pressed: false, at: 0.15, buttons: buttons)
        XCTAssertEqual(router.handle(id: "leftTrigger", pressed: false, at: 0.25, buttons: buttons),
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

    // MARK: - Sticky menu after a long hold
    // Field test 2026-06-11: users read the HUD as a menu — hold, RELEASE,
    // then pick at their own pace (logged picks came 0.6–4 s later). No
    // timer can guess that, so the menu simply stays open until resolved.

    func testLongHoldReleaseOpensStickyMenu() {
        _ = router.handle(id: "leftTrigger", pressed: true, at: 0, buttons: buttons)
        XCTAssertEqual(router.handle(id: "leftTrigger", pressed: false, at: 0.5, buttons: buttons),
                       .nothing)
        XCTAssertEqual(router.hudLayer, "leftTrigger")
    }

    func testMenuPickWorksHoweverLateItComes() {
        _ = router.handle(id: "leftTrigger", pressed: true, at: 0, buttons: buttons)
        _ = router.handle(id: "leftTrigger", pressed: false, at: 0.5, buttons: buttons)
        XCTAssertEqual(router.handle(id: "a", pressed: true, at: 4.8, buttons: buttons),
                       .action(.key("cmd+tab"), pressed: true))
        XCTAssertEqual(router.handle(id: "a", pressed: false, at: 4.9, buttons: buttons),
                       .action(.key("cmd+tab"), pressed: false))
    }

    func testMenuStaysOpenAcrossPicksSoSlotsCanBeTried() {
        _ = router.handle(id: "leftTrigger", pressed: true, at: 0, buttons: buttons)
        _ = router.handle(id: "leftTrigger", pressed: false, at: 0.5, buttons: buttons)
        _ = router.handle(id: "a", pressed: true, at: 1.0, buttons: buttons)
        _ = router.handle(id: "a", pressed: false, at: 1.1, buttons: buttons)
        XCTAssertEqual(router.hudLayer, "leftTrigger")
        // a second pick still comes from the menu, not the base mapping
        XCTAssertEqual(router.handle(id: "a", pressed: true, at: 1.5, buttons: buttons),
                       .action(.key("cmd+tab"), pressed: true))
        XCTAssertEqual(router.handle(id: "dpadLeft", pressed: true, at: 2.0, buttons: buttons),
                       .action(.key("ctrl+left"), pressed: true))
    }

    func testEveryPickRestartsTheMenuTimeout() {
        _ = router.handle(id: "leftTrigger", pressed: true, at: 0, buttons: buttons)
        _ = router.handle(id: "leftTrigger", pressed: false, at: 0.5, buttons: buttons)
        _ = router.handle(id: "a", pressed: true, at: 5.0, buttons: buttons)
        _ = router.handle(id: "a", pressed: false, at: 5.1, buttons: buttons)
        // 6 s from the pick, not from the menu opening
        XCTAssertFalse(router.expireMenu(at: 10.9))
        XCTAssertTrue(router.expireMenu(at: 11.1))
    }

    func testLayerTapWhileMenuOpenJustClosesIt() {
        _ = router.handle(id: "leftTrigger", pressed: true, at: 0, buttons: buttons)
        _ = router.handle(id: "leftTrigger", pressed: false, at: 0.5, buttons: buttons)
        // tapping the layer button again closes the menu — no right click,
        // no fresh hold, the whole press/release pair is consumed
        XCTAssertEqual(router.handle(id: "leftTrigger", pressed: true, at: 1.0, buttons: buttons),
                       .nothing)
        XCTAssertNil(router.hudLayer)
        XCTAssertEqual(router.handle(id: "leftTrigger", pressed: false, at: 1.1, buttons: buttons),
                       .nothing)
        XCTAssertEqual(router.handle(id: "a", pressed: true, at: 1.5, buttons: buttons),
                       .action(.leftClick, pressed: true))
    }

    func testNonSlotPressClosesMenuAndActsNormally() {
        _ = router.handle(id: "leftTrigger", pressed: true, at: 0, buttons: buttons)
        _ = router.handle(id: "leftTrigger", pressed: false, at: 0.5, buttons: buttons)
        XCTAssertEqual(router.handle(id: "rightTrigger", pressed: true, at: 2.0, buttons: buttons),
                       .action(.key("return"), pressed: true))
        XCTAssertNil(router.hudLayer)
        XCTAssertEqual(router.handle(id: "a", pressed: true, at: 2.5, buttons: buttons),
                       .action(.leftClick, pressed: true))
    }

    func testUsedLayerReleaseOpensNoMenu() {
        _ = router.handle(id: "leftTrigger", pressed: true, at: 0, buttons: buttons)
        _ = router.handle(id: "dpadLeft", pressed: true, at: 0.1, buttons: buttons)
        _ = router.handle(id: "dpadLeft", pressed: false, at: 0.15, buttons: buttons)
        _ = router.handle(id: "leftTrigger", pressed: false, at: 0.5, buttons: buttons)
        XCTAssertNil(router.hudLayer)
        XCTAssertEqual(router.handle(id: "a", pressed: true, at: 0.55, buttons: buttons),
                       .action(.leftClick, pressed: true))
    }

    func testShortTapRightClicksAndOpensNoMenu() {
        _ = router.handle(id: "leftTrigger", pressed: true, at: 0, buttons: buttons)
        XCTAssertEqual(router.handle(id: "leftTrigger", pressed: false, at: 0.1, buttons: buttons),
                       .tap(.rightClick))
        XCTAssertNil(router.hudLayer)
        XCTAssertEqual(router.handle(id: "a", pressed: true, at: 0.15, buttons: buttons),
                       .action(.leftClick, pressed: true))
    }

    func testHudLayerTracksHeldLayerToo() {
        XCTAssertNil(router.hudLayer)
        _ = router.handle(id: "leftTrigger", pressed: true, at: 0, buttons: buttons)
        XCTAssertEqual(router.hudLayer, "leftTrigger")
    }

    func testMenuExpiresAfterTimeout() {
        _ = router.handle(id: "leftTrigger", pressed: true, at: 0, buttons: buttons)
        _ = router.handle(id: "leftTrigger", pressed: false, at: 0.5, buttons: buttons)
        XCTAssertFalse(router.expireMenu(at: 6.4))   // 5.9 s open: stays
        XCTAssertEqual(router.hudLayer, "leftTrigger")
        XCTAssertTrue(router.expireMenu(at: 6.6))    // 6.1 s open: closes
        XCTAssertNil(router.hudLayer)
        XCTAssertEqual(router.handle(id: "a", pressed: true, at: 6.7, buttons: buttons),
                       .action(.leftClick, pressed: true))
    }

    func testExpireDoesNothingWithoutAnOpenMenu() {
        XCTAssertFalse(router.expireMenu(at: 100))
        _ = router.handle(id: "leftTrigger", pressed: true, at: 0, buttons: buttons)
        // held layer is not an open menu: holding may take as long as it likes
        XCTAssertFalse(router.expireMenu(at: 100))
    }

    func testResetClosesMenu() {
        _ = router.handle(id: "leftTrigger", pressed: true, at: 0, buttons: buttons)
        _ = router.handle(id: "leftTrigger", pressed: false, at: 0.5, buttons: buttons)
        router.reset()
        XCTAssertNil(router.hudLayer)
        XCTAssertEqual(router.handle(id: "a", pressed: true, at: 1.0, buttons: buttons),
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
