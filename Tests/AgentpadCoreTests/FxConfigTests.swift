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

    func testFxSectionWithoutVariantsDecodesWithDefaults() throws {
        // an fx section written before sound variants existed
        let legacy = #"{"sounds": true}"#
        let fx = try JSONDecoder().decode(FxConfig.self, from: Data(legacy.utf8))
        XCTAssertTrue(fx.sounds)
        XCTAssertEqual(fx.shotVariant, "classic")
        XCTAssertEqual(fx.reloadVariant, "clack")
    }

    func testVariantsRoundtrip() throws {
        var config = Config.default
        config.fx.shotVariant = "laser"
        config.fx.reloadVariant = "thock"
        let decoded = try JSONDecoder().decode(Config.self, from: JSONEncoder().encode(config))
        XCTAssertEqual(decoded.fx.shotVariant, "laser")
        XCTAssertEqual(decoded.fx.reloadVariant, "thock")
    }

    func testSetVariantsPersists() {
        let store = ConfigStore(config: .default, url: tempURL)
        store.setShotVariant("8bit")
        store.setReloadVariant("pop")
        let reloaded = ConfigLoader.load(from: tempURL)
        XCTAssertEqual(reloaded.fx.shotVariant, "8bit")
        XCTAssertEqual(reloaded.fx.reloadVariant, "pop")
    }

    func testVolumeDefaultsToHalfForLegacyFxSections() throws {
        let legacy = #"{"sounds":true,"shotVariant":"laser","reloadVariant":"clack"}"#
        let fx = try JSONDecoder().decode(FxConfig.self, from: Data(legacy.utf8))
        XCTAssertEqual(fx.volume, 0.5)
    }

    func testVolumeRoundtrips() throws {
        var fx = FxConfig()
        fx.volume = 0.2
        let decoded = try JSONDecoder().decode(FxConfig.self, from: JSONEncoder().encode(fx))
        XCTAssertEqual(decoded.volume, 0.2)
    }

    func testVolumeClampsOutOfRangeValues() throws {
        let loud = try JSONDecoder().decode(FxConfig.self, from: Data(#"{"volume":3.5}"#.utf8))
        XCTAssertEqual(loud.volume, 1.0)
        let negative = try JSONDecoder().decode(FxConfig.self, from: Data(#"{"volume":-2}"#.utf8))
        XCTAssertEqual(negative.volume, 0.0)
    }

    func testSetVolumePersists() {
        let store = ConfigStore(config: .default, url: tempURL)
        store.setVolume(0.25)
        XCTAssertEqual(store.config.fx.volume, 0.25)
        XCTAssertEqual(ConfigLoader.load(from: tempURL).fx.volume, 0.25)
    }

    func testSystemVariantsDontCollideWithSynthNamesInMenus() {
        XCTAssertTrue(FxConfig.systemVariants.contains("Tink"))
        let synth = Set((FxConfig.shotVariants + FxConfig.reloadVariants).map { $0.lowercased() })
        let system = Set(FxConfig.systemVariants.map { $0.lowercased() })
        XCTAssertTrue(synth.isDisjoint(with: system))
    }
}
