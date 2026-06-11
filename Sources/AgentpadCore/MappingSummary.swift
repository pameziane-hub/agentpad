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
        displayOrder.compactMap { entry in
            guard let action = config.buttons[entry.id] else { return nil }
            return (button: entry.label, action: describe(action))
        }
    }

    public static func describe(_ action: ButtonAction) -> String {
        switch action {
        case .leftClick: return "Left Click"
        case .rightClick: return "Right Click"
        case .pause: return "Pause / Resume"
        case .url(let url):
            // friendly label for the dictation app this project was built around
            return url.lowercased().hasPrefix("superwhisper://") ? "Superwhisper" : url
        case .key(let raw):
            return raw.split(separator: " ")
                .map { combo in
                    combo.split(separator: "+")
                        .map { $0.count == 1 ? String($0) : $0.capitalized }
                        .joined(separator: "+")
                }
                .joined(separator: " ")
        }
    }
}
