import Foundation

/// Resolves button events against the mapping, including hold-layers: while
/// a `.layer` button is held, buttons listed in its overlay swap to their
/// overlay actions; press + release with no overlay use fires the layer's
/// tap action instead. Pure state machine — the app shell executes the
/// returned events, so all timing-free routing logic stays unit-testable.
public struct LayerRouter {
    public enum Event: Equatable {
        /// Forward the action with the button's press state.
        case action(ButtonAction, pressed: Bool)
        /// Fire a full press + release in one go (a layer's tap action).
        case tap(ButtonAction)
        case nothing
    }

    public private(set) var heldLayer: String?
    private var layerUsed = false
    /// Action chosen at press time, so a down/up pair never splits across
    /// two different actions when the layer state changes in between.
    private var pressActions: [String: ButtonAction] = [:]

    public init() {}

    public mutating func handle(id: String, pressed: Bool,
                                buttons: [String: ButtonAction]) -> Event {
        pressed ? handlePress(of: id, buttons: buttons)
                : handleRelease(of: id, buttons: buttons)
    }

    /// Clear all held state (on pause, disconnect, …) so no layer or
    /// press/release pair survives across an interruption.
    public mutating func reset() {
        heldLayer = nil
        layerUsed = false
        pressActions = [:]
    }

    private mutating func handlePress(of id: String,
                                      buttons: [String: ButtonAction]) -> Event {
        if let layerId = heldLayer, layerId != id,
           case .layer(_, let overlay)? = buttons[layerId],
           let overlayAction = overlay[id] {
            layerUsed = true
            pressActions[id] = overlayAction
            return .action(overlayAction, pressed: true)
        }
        guard let action = buttons[id] else { return .nothing }
        if case .layer = action {
            // a second layer while one is held is ignored rather than stacked
            guard heldLayer == nil else { return .nothing }
            heldLayer = id
            layerUsed = false
            return .nothing
        }
        pressActions[id] = action
        return .action(action, pressed: true)
    }

    private mutating func handleRelease(of id: String,
                                        buttons: [String: ButtonAction]) -> Event {
        if id == heldLayer {
            heldLayer = nil
            guard case .layer(let tap, _)? = buttons[id], let tap, !layerUsed else {
                return .nothing
            }
            return .tap(tap)
        }
        guard let action = pressActions.removeValue(forKey: id) else { return .nothing }
        return .action(action, pressed: false)
    }
}
