import Foundation

/// Modifier flags, kept CoreGraphics-free so the core stays testable;
/// the app layer maps these onto CGEventFlags.
public struct KeyFlags: OptionSet, Equatable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let command = KeyFlags(rawValue: 1 << 0)
    public static let shift = KeyFlags(rawValue: 1 << 1)
    public static let control = KeyFlags(rawValue: 1 << 2)
    public static let option = KeyFlags(rawValue: 1 << 3)
}

/// One key press: a macOS virtual key code (kVK_*, layout-position based)
/// plus the modifiers held while pressing it.
public struct KeyCombo: Equatable {
    public let keyCode: UInt16
    public let flags: KeyFlags

    public init(keyCode: UInt16, flags: KeyFlags) {
        self.keyCode = keyCode
        self.flags = flags
    }
}

/// Parses config strings like "return", "shift+tab", "cmd+`" and
/// space-separated sequences like "ctrl ctrl" (double-tap for macOS dictation).
public enum KeyComboParser {
    static let keyCodes: [String: UInt16] = [
        "return": 36, "enter": 36,
        "tab": 48,
        "space": 49,
        "esc": 53, "escape": 53,
        "`": 50, "backtick": 50,
        "delete": 51, "backspace": 51,
        "left": 123, "right": 124, "down": 125, "up": 126,
        // modifier keys usable as the key itself (e.g. double-ctrl)
        "cmd": 55, "command": 55,
        "shift": 56,
        "ctrl": 59, "control": 59,
        "opt": 58, "option": 58, "alt": 58,
        // digit row, for answering numbered prompt options
        "1": 18, "2": 19, "3": 20, "4": 21, "5": 23,
        "6": 22, "7": 26, "8": 28, "9": 25, "0": 29,
        // letters (kVK_ANSI_*), for shortcuts like cmd+c / cmd+v
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7,
        "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
        "y": 16, "t": 17, "o": 31, "u": 32, "i": 34, "p": 35, "l": 37,
        "j": 38, "k": 40, "n": 45, "m": 46,
    ]

    static let modifierKeyCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]

    static let modifierFlags: [String: KeyFlags] = [
        "cmd": .command, "command": .command,
        "shift": .shift,
        "ctrl": .control, "control": .control,
        "opt": .option, "option": .option, "alt": .option,
    ]

    public static func parse(_ raw: String) -> KeyCombo? {
        let parts = raw.lowercased().split(separator: "+").map(String.init)
        guard let keyName = parts.last, let keyCode = keyCodes[keyName] else { return nil }
        var flags: KeyFlags = []
        for modifier in parts.dropLast() {
            guard let flag = modifierFlags[modifier] else { return nil }
            flags.insert(flag)
        }
        return KeyCombo(keyCode: keyCode, flags: flags)
    }

    public static func parseSequence(_ raw: String) -> [KeyCombo]? {
        let elements = raw.split(separator: " ").map(String.init)
        guard !elements.isEmpty else { return nil }
        var combos: [KeyCombo] = []
        for element in elements {
            guard let combo = parse(element) else { return nil }
            combos.append(combo)
        }
        return combos
    }

    public static func isModifierOnly(_ combo: KeyCombo) -> Bool {
        modifierKeyCodes.contains(combo.keyCode)
    }
}
