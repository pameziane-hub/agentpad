import XCTest
@testable import AgentpadCore

final class LayerRouterTests: XCTestCase {
    private let buttons: [String: ButtonAction] = [
        "a": .leftClick,
        "rightTrigger": .key("return"),
        "dpadLeft": .key("left"),
        "dpadRight": .key("right"),
        "leftTrigger": .layer(tap: .rightClick, overlay: [
            "dpadLeft": .key("ctrl+left"),
            "dpadRight": .key("ctrl+right"),
        ]),
    ]

    private var router = LayerRouter()

    func testPlainButtonPassesThroughOnPressAndRelease() {
        XCTAssertEqual(router.handle(id: "a", pressed: true, buttons: buttons),
                       .action(.leftClick, pressed: true))
        XCTAssertEqual(router.handle(id: "a", pressed: false, buttons: buttons),
                       .action(.leftClick, pressed: false))
    }

    func testUnmappedButtonDoesNothing() {
        XCTAssertEqual(router.handle(id: "x", pressed: true, buttons: buttons), .nothing)
    }

    func testLayerPressIsSwallowed() {
        XCTAssertEqual(router.handle(id: "leftTrigger", pressed: true, buttons: buttons),
                       .nothing)
    }

    func testLayerTapFiresTapActionOnRelease() {
        _ = router.handle(id: "leftTrigger", pressed: true, buttons: buttons)
        XCTAssertEqual(router.handle(id: "leftTrigger", pressed: false, buttons: buttons),
                       .tap(.rightClick))
    }

    func testHeldLayerRemapsOverlayButtonAndSuppressesTap() {
        _ = router.handle(id: "leftTrigger", pressed: true, buttons: buttons)
        XCTAssertEqual(router.handle(id: "dpadLeft", pressed: true, buttons: buttons),
                       .action(.key("ctrl+left"), pressed: true))
        XCTAssertEqual(router.handle(id: "dpadLeft", pressed: false, buttons: buttons),
                       .action(.key("ctrl+left"), pressed: false))
        // overlay was used: releasing the layer must not right-click
        XCTAssertEqual(router.handle(id: "leftTrigger", pressed: false, buttons: buttons),
                       .nothing)
    }

    func testRepeatedOverlayUseStaysRemappedForOneHold() {
        _ = router.handle(id: "leftTrigger", pressed: true, buttons: buttons)
        for _ in 0..<3 {
            XCTAssertEqual(router.handle(id: "dpadRight", pressed: true, buttons: buttons),
                           .action(.key("ctrl+right"), pressed: true))
            _ = router.handle(id: "dpadRight", pressed: false, buttons: buttons)
        }
        XCTAssertEqual(router.handle(id: "leftTrigger", pressed: false, buttons: buttons),
                       .nothing)
        // next hold starts fresh
        _ = router.handle(id: "leftTrigger", pressed: true, buttons: buttons)
        XCTAssertEqual(router.handle(id: "leftTrigger", pressed: false, buttons: buttons),
                       .tap(.rightClick))
    }

    func testNonOverlayButtonDuringHoldActsNormallyAndKeepsTap() {
        _ = router.handle(id: "leftTrigger", pressed: true, buttons: buttons)
        // RT is not in the overlay: it keeps its base action
        XCTAssertEqual(router.handle(id: "rightTrigger", pressed: true, buttons: buttons),
                       .action(.key("return"), pressed: true))
        // and it does not consume the layer: the tap still fires
        XCTAssertEqual(router.handle(id: "leftTrigger", pressed: false, buttons: buttons),
                       .tap(.rightClick))
    }

    func testDpadIsPlainArrowsWithoutTheLayer() {
        XCTAssertEqual(router.handle(id: "dpadLeft", pressed: true, buttons: buttons),
                       .action(.key("left"), pressed: true))
    }

    func testLayerWithoutTapReleasesSilently() {
        let noTap: [String: ButtonAction] = [
            "leftTrigger": .layer(tap: nil, overlay: ["a": .leftClick]),
        ]
        _ = router.handle(id: "leftTrigger", pressed: true, buttons: noTap)
        XCTAssertEqual(router.handle(id: "leftTrigger", pressed: false, buttons: noTap),
                       .nothing)
    }

    func testOverlayPressReleasePairStaysConsistentAcrossLayerRelease() {
        // press dpadLeft while held, release the layer first, then dpadLeft:
        // the release must route to the action chosen at press time, so a
        // down/up pair can never split across two different actions
        _ = router.handle(id: "leftTrigger", pressed: true, buttons: buttons)
        _ = router.handle(id: "dpadLeft", pressed: true, buttons: buttons)
        _ = router.handle(id: "leftTrigger", pressed: false, buttons: buttons)
        XCTAssertEqual(router.handle(id: "dpadLeft", pressed: false, buttons: buttons),
                       .action(.key("ctrl+left"), pressed: false))
    }

    func testReleaseWithoutPriorPressDoesNothing() {
        XCTAssertEqual(router.handle(id: "a", pressed: false, buttons: buttons), .nothing)
    }

    func testResetClearsHeldLayer() {
        _ = router.handle(id: "leftTrigger", pressed: true, buttons: buttons)
        router.reset()
        // after reset the pending tap is gone…
        XCTAssertEqual(router.handle(id: "leftTrigger", pressed: false, buttons: buttons),
                       .nothing)
        // …and the d-pad is back to plain arrows
        XCTAssertEqual(router.handle(id: "dpadLeft", pressed: true, buttons: buttons),
                       .action(.key("left"), pressed: true))
    }
}
