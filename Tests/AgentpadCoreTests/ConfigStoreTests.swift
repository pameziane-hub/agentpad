import XCTest
@testable import AgentpadCore

final class ConfigStoreTests: XCTestCase {
    private var tempURL: URL!

    override func setUpWithError() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("agentpad-store-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        tempURL = dir.appendingPathComponent("mapping.json")
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: tempURL.deletingLastPathComponent())
    }

    func testSwapExchangesActionsOfTwoMappedButtons() {
        let store = ConfigStore(config: .default, url: tempURL)
        let aAction = store.config.buttons["a"]
        let bAction = store.config.buttons["b"]
        store.swapBinding("a", "b")
        XCTAssertEqual(store.config.buttons["a"], bAction)
        XCTAssertEqual(store.config.buttons["b"], aAction)
    }

    func testSwapWithUnmappedButtonMovesAction() {
        var config = Config.default
        config.buttons.removeValue(forKey: "x")
        let store = ConfigStore(config: config, url: tempURL)
        let yAction = store.config.buttons["y"]
        store.swapBinding("y", "x")
        XCTAssertEqual(store.config.buttons["x"], yAction)
        XCTAssertNil(store.config.buttons["y"])
    }

    func testSwapPersistsToDisk() throws {
        let store = ConfigStore(config: .default, url: tempURL)
        store.swapBinding("a", "b")
        let reloaded = ConfigLoader.load(from: tempURL)
        XCTAssertEqual(reloaded, store.config)
    }

    func testSwapNotifiesObserver() {
        let store = ConfigStore(config: .default, url: tempURL)
        var notified = false
        store.onChange = { notified = true }
        store.swapBinding("a", "b")
        XCTAssertTrue(notified)
    }

    func testSwapSameButtonIsNoOp() {
        let store = ConfigStore(config: .default, url: tempURL)
        let before = store.config
        store.swapBinding("a", "a")
        XCTAssertEqual(store.config, before)
    }
}
