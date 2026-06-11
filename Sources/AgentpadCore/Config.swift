import Foundation

public struct PointerConfig: Codable, Equatable {
    /// Radial stick deadzone (0..<1).
    public var deadzone: Float
    /// 0 = linear, 1 = cubic response.
    public var expo: Float
    /// Cursor speed at full deflection, in points per second.
    public var maxSpeed: Double
}

public struct ScrollConfig: Codable, Equatable {
    public var deadzone: Float
    /// Scroll speed at full deflection, in pixels per second.
    public var speed: Double
}

/// What a controller button does. JSON uses a `type` discriminator:
/// `{"type":"key","value":"shift+tab"}`, `{"type":"url","value":"superwhisper://record"}`,
/// `{"type":"leftClick"}`, `{"type":"rightClick"}`, `{"type":"pause"}`.
public enum ButtonAction: Equatable {
    /// A key combo or space-separated sequence, parsed by KeyComboParser.
    case key(String)
    /// A URL/deep link opened with the default handler.
    case url(String)
    case leftClick
    case rightClick
    /// Toggle all mapping on/off.
    case pause
}

extension ButtonAction: Codable {
    private enum CodingKeys: String, CodingKey { case type, value }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "key": self = .key(try container.decode(String.self, forKey: .value))
        case "url": self = .url(try container.decode(String.self, forKey: .value))
        case "leftClick": self = .leftClick
        case "rightClick": self = .rightClick
        case "pause": self = .pause
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container,
                debugDescription: "Unknown action type '\(type)'")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .key(let value):
            try container.encode("key", forKey: .type)
            try container.encode(value, forKey: .value)
        case .url(let value):
            try container.encode("url", forKey: .type)
            try container.encode(value, forKey: .value)
        case .leftClick: try container.encode("leftClick", forKey: .type)
        case .rightClick: try container.encode("rightClick", forKey: .type)
        case .pause: try container.encode("pause", forKey: .type)
        }
    }
}

public struct Config: Codable, Equatable {
    public var pointer: PointerConfig
    public var scroll: ScrollConfig
    /// Button id (a, b, x, y, dpadUp…, leftShoulder…, menu) → action.
    public var buttons: [String: ButtonAction]

    public static let `default` = Config(
        pointer: PointerConfig(deadzone: 0.12, expo: 0.6, maxSpeed: 1400),
        scroll: ScrollConfig(deadzone: 0.15, speed: 600),
        buttons: [
            // A = click follows Xbox UI convention (A is select/confirm);
            // hold A and move the stick to drag
            "a": .leftClick,
            "b": .key("esc"),
            "x": .key("tab"),
            "y": .key("shift+tab"),
            "dpadUp": .key("up"),
            "dpadDown": .key("down"),
            "dpadLeft": .key("left"),
            "dpadRight": .key("right"),
            "leftShoulder": .key("cmd+`"),
            // double-tap Control: the default macOS dictation shortcut
            "rightShoulder": .key("ctrl ctrl"),
            "leftTrigger": .rightClick,
            // the trigger "fires" the prompt: Return submits/accepts
            "rightTrigger": .key("return"),
            "l3": .key("cmd+c"),
            "r3": .key("cmd+v"),
            "menu": .pause,
        ])
}

public enum ConfigLoader {
    public static var defaultURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/agentpad/mapping.json")
    }

    /// Missing file: writes the default config there (so users have something
    /// to edit) and returns it. Broken JSON: warns on stderr and falls back
    /// to the default — never crashes on user config.
    public static func load(from url: URL = defaultURL) -> Config {
        guard let data = try? Data(contentsOf: url) else {
            writeDefault(to: url)
            return .default
        }
        do {
            return try JSONDecoder().decode(Config.self, from: data)
        } catch {
            FileHandle.standardError.write(Data(
                "agentpad: could not parse \(url.path) (\(error.localizedDescription)), using defaults\n".utf8))
            return .default
        }
    }

    private static func writeDefault(to url: URL) {
        write(.default, to: url)
    }

    public static func write(_ config: Config, to url: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(config) else { return }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url)
    }
}
