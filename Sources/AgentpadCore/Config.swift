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
/// `{"type":"leftClick"}`, `{"type":"rightClick"}`, `{"type":"pause"}`,
/// `{"type":"layer","tap":{…},"overlay":{"dpadLeft":{…}}}`.
public indirect enum ButtonAction: Equatable {
    /// A key combo or space-separated sequence, parsed by KeyComboParser.
    case key(String)
    /// A URL/deep link opened with the default handler.
    case url(String)
    case leftClick
    case rightClick
    /// Toggle all mapping on/off.
    case pause
    /// Open the agentpad status-bar menu (console convention: Start opens
    /// the menu), so everything stays configurable from the controller.
    case statusMenu
    /// Hold-modifier (Steam-Input style layer shift): while held, buttons in
    /// `overlay` replace their base actions; press + release with no overlay
    /// use fires `tap` instead, so the button keeps a primary action.
    case layer(tap: ButtonAction?, overlay: [String: ButtonAction])
}

extension ButtonAction: Codable {
    private enum CodingKeys: String, CodingKey { case type, value, tap, overlay }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "key": self = .key(try container.decode(String.self, forKey: .value))
        case "url": self = .url(try container.decode(String.self, forKey: .value))
        case "leftClick": self = .leftClick
        case "rightClick": self = .rightClick
        case "pause": self = .pause
        case "statusMenu": self = .statusMenu
        case "layer":
            self = .layer(
                tap: try container.decodeIfPresent(ButtonAction.self, forKey: .tap),
                overlay: try container.decode([String: ButtonAction].self, forKey: .overlay))
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
        case .statusMenu: try container.encode("statusMenu", forKey: .type)
        case .layer(let tap, let overlay):
            try container.encode("layer", forKey: .type)
            try container.encodeIfPresent(tap, forKey: .tap)
            try container.encode(overlay, forKey: .overlay)
        }
    }
}

/// Western-mode sound effects: synthesized gunshot on Return, reload click
/// on left click. Drop a shot.wav / reload.wav next to mapping.json to
/// replace the built-in sounds.
public struct FxConfig: Codable, Equatable {
    public var sounds: Bool
    /// classic · laser · 8bit · silenced — or a system sound name
    public var shotVariant: String
    /// clack · pop · thock · tick — or a system sound name
    public var reloadVariant: String
    /// Playback volume for all FX, 0…1.
    public var volume: Float

    public static let shotVariants = ["classic", "laser", "8bit", "silenced"]
    public static let reloadVariants = ["clack", "pop", "thock", "tick"]
    /// Built-in macOS alert sounds offered for both events: professionally
    /// mastered, played by name, nothing bundled into the repo. Capitalized
    /// names double as menu titles and never collide with the synth list.
    public static let systemVariants = ["Tink", "Glass", "Morse", "Purr", "Hero", "Submarine"]

    public init(sounds: Bool = false, shotVariant: String = "classic",
                reloadVariant: String = "clack", volume: Float = 0.5) {
        self.sounds = sounds
        self.shotVariant = shotVariant
        self.reloadVariant = reloadVariant
        self.volume = volume
    }

    private enum CodingKeys: String, CodingKey { case sounds, shotVariant, reloadVariant, volume }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // every field optional: fx sections from older versions keep decoding
        sounds = try container.decodeIfPresent(Bool.self, forKey: .sounds) ?? false
        shotVariant = try container.decodeIfPresent(String.self, forKey: .shotVariant) ?? "classic"
        reloadVariant = try container.decodeIfPresent(String.self, forKey: .reloadVariant) ?? "clack"
        let rawVolume = try container.decodeIfPresent(Float.self, forKey: .volume) ?? 0.5
        volume = min(max(rawVolume, 0), 1)
    }
}

/// Sticky-target cursor assist ("aim friction"), see the magnet spec.
public struct MagnetConfig: Codable, Equatable {
    public var enabled: Bool
    /// 0…1 — scales how hard targets damp cursor speed.
    public var strength: Float

    public init(enabled: Bool = true, strength: Float = 0.5) {
        self.enabled = enabled
        // same 0…1 invariant as the decode path — a strength above 1 would
        // flip the damping factor negative and reverse cursor movement
        self.strength = min(max(strength, 0), 1)
    }

    private enum CodingKeys: String, CodingKey { case enabled, strength }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // every field optional: older configs keep decoding
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        let raw = try container.decodeIfPresent(Float.self, forKey: .strength) ?? 0.5
        strength = min(max(raw, 0), 1)
    }
}

public struct Config: Codable, Equatable {
    public var pointer: PointerConfig
    public var scroll: ScrollConfig
    /// Button id (a, b, x, y, dpadUp…, leftShoulder…, menu) → action.
    public var buttons: [String: ButtonAction]
    public var fx: FxConfig
    public var magnet: MagnetConfig

    private enum CodingKeys: String, CodingKey { case pointer, scroll, buttons, fx, magnet }

    public init(pointer: PointerConfig, scroll: ScrollConfig,
                buttons: [String: ButtonAction], fx: FxConfig = FxConfig(),
                magnet: MagnetConfig = MagnetConfig()) {
        self.pointer = pointer
        self.scroll = scroll
        self.buttons = buttons
        self.fx = fx
        self.magnet = magnet
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pointer = try container.decode(PointerConfig.self, forKey: .pointer)
        scroll = try container.decode(ScrollConfig.self, forKey: .scroll)
        buttons = try container.decode([String: ButtonAction].self, forKey: .buttons)
        // sections added over time stay optional so old configs keep decoding
        fx = try container.decodeIfPresent(FxConfig.self, forKey: .fx) ?? FxConfig()
        magnet = try container.decodeIfPresent(MagnetConfig.self, forKey: .magnet) ?? MagnetConfig()
    }

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
            // tap = right click; held, it layers shortcuts onto the face
            // buttons and Space switching onto the D-Pad, so plain arrows
            // stay available for menu navigation
            "leftTrigger": .layer(tap: .rightClick, overlay: [
                "a": .key("cmd+tab"),
                "b": .key("delete"),
                "x": .key("cmd+z"),
                "y": .key("ctrl+c"),
                "dpadUp": .key("cmd+a"),
                "dpadLeft": .key("ctrl+left"),
                "dpadRight": .key("ctrl+right"),
            ]),
            // the trigger "fires" the prompt: Return submits/accepts
            "rightTrigger": .key("return"),
            "l3": .key("cmd+c"),
            "r3": .key("cmd+v"),
            // Start opens the menu, console style; Pause sits right inside it
            "menu": .statusMenu,
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
