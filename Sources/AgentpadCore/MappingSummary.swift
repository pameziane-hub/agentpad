import Foundation

/// Human-readable description of the current mapping, for display in the
/// menu bar dropdown. Pure formatting, no AppKit.
public enum MappingSummary {
    /// Fixed display order: button id → label shown to the user.
    public static let displayOrder: [(id: String, label: String)] = [
        ("a", "A"), ("b", "B"), ("x", "X"), ("y", "Y"),
        ("dpadUp", "D-Pad ↑"), ("dpadDown", "D-Pad ↓"),
        ("dpadLeft", "D-Pad ←"), ("dpadRight", "D-Pad →"),
        ("leftTrigger", "LT"), ("rightTrigger", "RT"),
        ("leftShoulder", "LB"), ("rightShoulder", "RB"),
        ("l3", "L3"), ("r3", "R3"),
        ("menu", "Menu"),
    ]

    public static func rows(for config: Config) -> [(button: String, action: String)] {
        displayOrder.flatMap { entry -> [(button: String, action: String)] in
            guard let action = config.buttons[entry.id] else { return [] }
            var rows = [(button: entry.label, action: describe(action))]
            // a layer gets one extra row per overlay entry, e.g. "LT + D-Pad ←"
            if case .layer(_, let overlay) = action {
                rows += displayOrder.compactMap { held in
                    guard let overlayAction = overlay[held.id] else { return nil }
                    return (button: "\(entry.label) + \(held.label)",
                            action: describe(overlayAction))
                }
            }
            return rows
        }
    }

    /// Plain words for the hold-HUD: the menu should say what a slot DOES,
    /// not its key combo. Unknown combos fall back to their key names.
    static let friendlyNames: [String: String] = [
        "cmd+tab": "Last App",
        "delete": "Delete",
        "cmd+z": "Undo",
        "ctrl+c": "Interrupt",
        "cmd+a": "Select All",
        "ctrl+left": "Space ←",
        "ctrl+right": "Space →",
    ]

    /// Short-label rows for the hold-HUD: just the overlay of one layer
    /// button, e.g. ("A", "Last App"), in display order.
    public static func overlayRows(forLayer id: String, config: Config)
        -> [(button: String, action: String)] {
        guard case .layer(_, let overlay)? = config.buttons[id] else { return [] }
        return displayOrder.compactMap { entry in
            guard let action = overlay[entry.id] else { return nil }
            if case .key(let raw) = action,
               let friendly = friendlyNames[raw.lowercased()] {
                return (button: entry.label, action: friendly)
            }
            return (button: entry.label, action: describe(action))
        }
    }

    public static func describe(_ action: ButtonAction) -> String {
        switch action {
        case .leftClick: return "Left Click"
        case .rightClick: return "Right Click"
        case .pause: return "Pause / Resume"
        case .statusMenu: return "Open Menu"
        case .url(let url):
            // friendly label for the dictation app this project was built around
            return url.lowercased().hasPrefix("superwhisper://") ? "Superwhisper" : url
        case .layer(let tap, _):
            return tap.map { "\(describe($0)) (tap)" } ?? "Layer"
        case .text(let value):
            return "Types \(value)"
        case .key(let raw):
            return raw.split(separator: " ")
                .map { combo in
                    combo.split(separator: "+")
                        // single characters render like keycaps: Cmd+Z, not Cmd+z
                        .map { $0.count == 1 ? String($0).uppercased() : $0.capitalized }
                        .joined(separator: "+")
                }
                .joined(separator: " ")
        }
    }
}
