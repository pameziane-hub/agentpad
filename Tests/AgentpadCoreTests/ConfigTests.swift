import XCTest
@testable import AgentpadCore

final class ConfigTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("agentpad-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: tempDir)
    }

    func testDefaultConfigRoundtrips() throws {
        let data = try JSONEncoder().encode(Config.default)
        let decoded = try JSONDecoder().decode(Config.self, from: data)
        XCTAssertEqual(decoded, Config.default)
    }

    func testDecodesUrlAction() throws {
        let json = """
        {"type":"url","value":"superwhisper://record"}
        """
        let action = try JSONDecoder().decode(ButtonAction.self, from: Data(json.utf8))
        XCTAssertEqual(action, .url("superwhisper://record"))
    }

    func testDecodesSimpleActions() throws {
        let action = try JSONDecoder().decode(ButtonAction.self, from: Data(#"{"type":"leftClick"}"#.utf8))
        XCTAssertEqual(action, .leftClick)
    }

    func testUnknownActionTypeThrows() {
        XCTAssertThrowsError(
            try JSONDecoder().decode(ButtonAction.self, from: Data(#"{"type":"fly"}"#.utf8))
        )
    }

    func testLoadWithMissingFileWritesDefaultAndReturnsIt() {
        let url = tempDir.appendingPathComponent("mapping.json")
        let config = ConfigLoader.load(from: url)
        XCTAssertEqual(config, .default)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testLoadWithBrokenJsonFallsBackToDefault() throws {
        let url = tempDir.appendingPathComponent("mapping.json")
        try Data("{not json".utf8).write(to: url)
        XCTAssertEqual(ConfigLoader.load(from: url), .default)
    }

    func testLoadReadsUserConfig() throws {
        var custom = Config.default
        custom.pointer.maxSpeed = 999
        custom.buttons["rightShoulder"] = .url("superwhisper://record")
        let url = tempDir.appendingPathComponent("mapping.json")
        try JSONEncoder().encode(custom).write(to: url)
        XCTAssertEqual(ConfigLoader.load(from: url), custom)
    }

    func testDefaultMappingCoversAllButtons() {
        let expected: Set<String> = [
            "a", "b", "x", "y",
            "dpadUp", "dpadDown", "dpadLeft", "dpadRight",
            "leftShoulder", "rightShoulder", "leftTrigger", "rightTrigger",
            "l3", "r3",
            "menu",
        ]
        XCTAssertEqual(Set(Config.default.buttons.keys), expected)
    }
}
