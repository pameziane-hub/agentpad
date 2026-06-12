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

    func testDecodesStatusMenuAction() throws {
        let action = try JSONDecoder().decode(
            ButtonAction.self, from: Data(#"{"type":"statusMenu"}"#.utf8))
        XCTAssertEqual(action, .statusMenu)
        let data = try JSONEncoder().encode(ButtonAction.statusMenu)
        XCTAssertEqual(try JSONDecoder().decode(ButtonAction.self, from: data), .statusMenu)
    }

    func testDefaultMenuButtonOpensTheStatusMenu() {
        // console convention: Start opens the menu; Pause lives inside it
        XCTAssertEqual(Config.default.buttons["menu"], .statusMenu)
    }

    func testDecodesTextAction() throws {
        let action = try JSONDecoder().decode(
            ButtonAction.self, from: Data(#"{"type":"text","value":"/"}"#.utf8))
        XCTAssertEqual(action, .text("/"))
        let data = try JSONEncoder().encode(ButtonAction.text("/"))
        XCTAssertEqual(try JSONDecoder().decode(ButtonAction.self, from: data), .text("/"))
    }

    func testDefaultLayerTypesSlashOnDpadDown() throws {
        // the slash opens every CLI agent's command menu; text (not a key
        // combo) so it survives keyboard layouts where "/" needs Shift
        guard case .layer(_, let overlay)? = Config.default.buttons["leftTrigger"] else {
            return XCTFail("LT should be a layer")
        }
        XCTAssertEqual(overlay["dpadDown"], .text("/"))
    }

    func testDecodesLayerAction() throws {
        let json = """
        {"type":"layer","tap":{"type":"rightClick"},
         "overlay":{"dpadLeft":{"type":"key","value":"ctrl+left"},
                    "dpadRight":{"type":"key","value":"ctrl+right"}}}
        """
        let action = try JSONDecoder().decode(ButtonAction.self, from: Data(json.utf8))
        XCTAssertEqual(action, .layer(tap: .rightClick, overlay: [
            "dpadLeft": .key("ctrl+left"),
            "dpadRight": .key("ctrl+right"),
        ]))
    }

    func testDecodesLayerWithoutTap() throws {
        let json = #"{"type":"layer","overlay":{"a":{"type":"leftClick"}}}"#
        let action = try JSONDecoder().decode(ButtonAction.self, from: Data(json.utf8))
        XCTAssertEqual(action, .layer(tap: nil, overlay: ["a": .leftClick]))
    }

    func testLayerActionRoundtrips() throws {
        let layer = ButtonAction.layer(tap: .rightClick,
                                       overlay: ["dpadLeft": .key("ctrl+left")])
        let data = try JSONEncoder().encode(layer)
        XCTAssertEqual(try JSONDecoder().decode(ButtonAction.self, from: data), layer)
    }

    func testDefaultLeftTriggerIsRightClickLayer() {
        XCTAssertEqual(Config.default.buttons["leftTrigger"],
                       .layer(tap: .rightClick, overlay: [
                           "a": .key("cmd+tab"),
                           "b": .key("delete"),
                           "x": .key("cmd+z"),
                           "y": .key("ctrl+c"),
                           "dpadUp": .key("cmd+a"),
                           "dpadDown": .text("/"),
                           "dpadLeft": .key("ctrl+left"),
                           "dpadRight": .key("ctrl+right"),
                       ]))
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
