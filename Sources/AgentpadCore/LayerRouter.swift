import Foundation

/// Resolves button events against the mapping, including hold-layers: while
/// a `.layer` button is held, buttons listed in its overlay swap to their
/// overlay actions. Pure state machine — the app shell passes time in and
/// executes the returned events, so all routing logic stays unit-testable.
///
/// Two gestures share the layer button, split by hold duration:
/// - short tap (< `holdThreshold`): fires the layer's `tap` action.
/// - long hold (≥ `holdThreshold`, the HUD is showing): a menu. Slots work
///   while held AND for `graceWindow` after release, because users naturally
///   release the "menu button" before picking (field test 2026-06-11).
///   Releasing without a pick fires nothing.
public struct LayerRouter {
    public enum Event: Equatable {
        /// Forward the action with the button's press state.
        case action(ButtonAction, pressed: Bool)
        /// Fire a full press + release in one go (a layer's tap action).
        case tap(ButtonAction)
        case nothing
    }

    /// Hold duration at which a layer press stops being a tap and becomes
    /// a menu. The HUD uses the same threshold, so "HUD visible" and
    /// "menu mode" are always the same thing.
    public static let holdThreshold: TimeInterval = 0.3
    /// How long slots stay pickable after releasing a long-held layer.
    public static let graceWindow: TimeInterval = 0.25

    public private(set) var heldLayer: String?
    private var heldSince: TimeInterval = 0
    private var layerUsed = false
    /// Menu pick still allowed until this deadline after a long-hold release.
    private var grace: (layerId: String, until: TimeInterval)?
    /// Action chosen at press time, so a down/up pair never splits across
    /// two different actions when the layer state changes in between.
    private var pressActions: [String: ButtonAction] = [:]

    public init() {}

    public mutating func handle(id: String, pressed: Bool, at time: TimeInterval,
                                buttons: [String: ButtonAction]) -> Event {
        pressed ? handlePress(of: id, at: time, buttons: buttons)
                : handleRelease(of: id, at: time, buttons: buttons)
    }

    /// Clear all held state (on pause, disconnect, …) so no layer, grace
    /// window, or press/release pair survives across an interruption.
    public mutating func reset() {
        heldLayer = nil
        layerUsed = false
        grace = nil
        pressActions = [:]
    }

    private mutating func handlePress(of id: String, at time: TimeInterval,
                                      buttons: [String: ButtonAction]) -> Event {
        if let layerId = heldLayer, layerId != id,
           case .layer(_, let overlay)? = buttons[layerId],
           let overlayAction = overlay[id] {
            layerUsed = true
            pressActions[id] = overlayAction
            return .action(overlayAction, pressed: true)
        }
        // a released menu: the first press after it decides — a slot within
        // the window picks from the menu, anything else closes it
        if let grace {
            self.grace = nil
            if time < grace.until,
               case .layer(_, let overlay)? = buttons[grace.layerId],
               let overlayAction = overlay[id] {
                pressActions[id] = overlayAction
                return .action(overlayAction, pressed: true)
            }
        }
        guard let action = buttons[id] else { return .nothing }
        if case .layer = action {
            // a second layer while one is held is ignored rather than stacked
            guard heldLayer == nil else { return .nothing }
            heldLayer = id
            heldSince = time
            layerUsed = false
            return .nothing
        }
        pressActions[id] = action
        return .action(action, pressed: true)
    }

    private mutating func handleRelease(of id: String, at time: TimeInterval,
                                        buttons: [String: ButtonAction]) -> Event {
        if id == heldLayer {
            heldLayer = nil
            guard !layerUsed, case .layer(let tap, _)? = buttons[id] else { return .nothing }
            if time - heldSince < Self.holdThreshold {
                return tap.map { .tap($0) } ?? .nothing
            }
            grace = (layerId: id, until: time + Self.graceWindow)
            return .nothing
        }
        guard let action = pressActions.removeValue(forKey: id) else { return .nothing }
        return .action(action, pressed: false)
    }
}
