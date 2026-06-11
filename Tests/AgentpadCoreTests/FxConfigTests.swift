import XCTest
@testable import AgentpadCore

final class FxConfigTests: XCTestCase {
    private var tempURL: URL!

    override func setUpWithError() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("agentpad-fx-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        tempURL = dir.appendingPathComponent("mapping.json")
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: tempURL.deletingLastPathComponent())
    }

    func testConfigWithoutFxSectionDecodesWithDefaults() throws {
        // a config written before the fx feature existed
        let legacy = """
        {
          "buttons": { "a": { "type": "leftClick" } },
          "pointer": { "deadzone": 0.12, "expo": 0.6, "maxSpeed": 1400 },
          "scroll": { "deadzone": 0.15, "speed": 600 }
        }
        """
        let config = try JSONDecoder().decode(Config.self, from: Data(legacy.utf8))
        XCTAssertFalse(config.fx.sounds)
    }

    func testFxRoundtrips() throws {
        var config = Config.default
        config.fx.sounds = true
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(Config.self, from: data)
        XCTAssertTrue(decoded.fx.sounds)
        XCTAssertEqual(decoded, config)
    }

    func testSetSoundsPersists() {
        let store = ConfigStore(config: .default, url: tempURL)
        store.setSounds(true)
        XCTAssertTrue(store.config.fx.sounds)
        XCTAssertTrue(ConfigLoader.load(from: tempURL).fx.sounds)
    }
}
