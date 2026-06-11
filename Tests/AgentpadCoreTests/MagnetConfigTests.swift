import XCTest
@testable import AgentpadCore

final class MagnetConfigTests: XCTestCase {
    private var tempURL: URL!

    override func setUpWithError() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("agentpad-magnet-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        tempURL = dir.appendingPathComponent("mapping.json")
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: tempURL.deletingLastPathComponent())
    }

    func testDecodesMagnetSection() throws {
        let json = #"{"enabled":false,"strength":0.8}"#
        let magnet = try JSONDecoder().decode(MagnetConfig.self, from: Data(json.utf8))
        XCTAssertFalse(magnet.enabled)
        XCTAssertEqual(magnet.strength, 0.8)
    }

    func testConfigWithoutMagnetSectionDecodesWithDefaults() throws {
        // any config written before the magnet feature existed
        let legacy = """
        {
          "buttons": { "a": { "type": "leftClick" } },
          "pointer": { "deadzone": 0.12, "expo": 0.6, "maxSpeed": 1400 },
          "scroll": { "deadzone": 0.15, "speed": 600 }
        }
        """
        let config = try JSONDecoder().decode(Config.self, from: Data(legacy.utf8))
        XCTAssertTrue(config.magnet.enabled)
        XCTAssertEqual(config.magnet.strength, 0.5)
    }

    func testStrengthClampsToUnitRange() throws {
        let hot = try JSONDecoder().decode(MagnetConfig.self, from: Data(#"{"strength":7}"#.utf8))
        XCTAssertEqual(hot.strength, 1.0)
        let cold = try JSONDecoder().decode(MagnetConfig.self, from: Data(#"{"strength":-1}"#.utf8))
        XCTAssertEqual(cold.strength, 0.0)
    }

    func testMagnetRoundtrips() throws {
        var config = Config.default
        config.magnet.enabled = false
        config.magnet.strength = 0.3
        let decoded = try JSONDecoder().decode(Config.self, from: JSONEncoder().encode(config))
        XCTAssertEqual(decoded, config)
    }

    func testSetMagnetEnabledPersists() {
        let store = ConfigStore(config: .default, url: tempURL)
        store.setMagnetEnabled(false)
        XCTAssertFalse(store.config.magnet.enabled)
        XCTAssertFalse(ConfigLoader.load(from: tempURL).magnet.enabled)
    }
}
