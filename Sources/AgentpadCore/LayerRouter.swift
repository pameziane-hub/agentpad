import Foundation

/// Resolves button events against the mapping, including hold-layers: while
/// a `.layer` button is held, buttons listed in its overlay swap to their
/// overlay actions. Pure state machine — the app shell passes time in and
/// executes the returned events, so all routing logic stays unit-testable.
///
/// Two gestures share the layer button, split by hold duration:
/// - short tap (< `holdThreshold`): fires the layer's `tap` action.
/// - long hold (≥ `holdThreshold`, the HUD is showing): a menu. Releasing
///   keeps the menu open — field test 2026-06-11 showed picks arrive 0.6–4 s
///   after release, so no timer can work. The next press resolves it: a slot
///   picks, anything else closes the menu and acts normally.
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
    /// An untouched open menu folds away by itself after this long.
    public static let menuTimeout: TimeInterval = 6.0

    public private(set) var heldLayer: String?
    /// Layer whose menu stays open after release, awaiting a pick.
    private var openMenu: String?
    private var menuOpenedAt: TimeInterval = 0
    private var heldSince: TimeInterval = 0
    private var layerUsed = false
    /// Action chosen at press time, so a down/up pair never splits across
    /// two different actions when the layer state changes in between.
    private var pressActions: [String: ButtonAction] = [:]

    /// The layer the HUD should show: a held layer or an open menu.
    /// HUD visible == slots active, always.
    public var hudLayer: String? { heldLayer ?? openMenu }

    public init() {}

    public mutating func handle(id: String, pressed: Bool, at time: TimeInterval,
                                buttons: [String: ButtonAction]) -> Event {
        pressed ? handlePress(of: id, at: time, buttons: buttons)
                : handleRelease(of: id, at: time, buttons: buttons)
    }

    /// Driven by the engine tick: folds an untouched menu away after
    /// `menuTimeout`. Returns true when it closed (the HUD needs updating).
    public mutating func expireMenu(at time: TimeInterval) -> Bool {
        guard openMenu != nil, time - menuOpenedAt >= Self.menuTimeout else { return false }
        openMenu = nil
        return true
    }

    /// Clear all held state (on pause, disconnect, …) so no layer, open
    /// menu, or press/release pair survives across an interruption.
    public mutating func reset() {
        heldLayer = nil
        openMenu = nil
        layerUsed = false
        pressActions = [:]
    }

    private mutating func handlePress(of id: String, at time: TimeInterval,
                                      buttons: [String: ButtonAction]) -> Event {
        if let layerId = heldLayer, layerId != id {
            // ANY companion press makes the hold a chord — the layer release
            // must never fire its tap on top of it (phantom right clicks
            // kept opening context menus, field bug 2026-06-12)
            layerUsed = true
            if case .layer(_, let overlay)? = buttons[layerId],
               let overlayAction = overlay[id] {
                pressActions[id] = overlayAction
                return .action(overlayAction, pressed: true)
            }
        }
        // an open menu: slots pick from it and KEEP it open (so the slots
        // can be tried in a row), tapping the layer button again closes it,
        // anything else closes it and acts normally below
        if let menuId = openMenu {
            if id == menuId {
                openMenu = nil
                // the matching release finds no held layer and no press
                // action, so the whole close-press is consumed silently
                return .nothing
            }
            if case .layer(_, let overlay)? = buttons[menuId],
               let overlayAction = overlay[id] {
                menuOpenedAt = time   // every pick restarts the timeout
                pressActions[id] = overlayAction
                return .action(overlayAction, pressed: true)
            }
            openMenu = nil
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
            openMenu = id
            menuOpenedAt = time
            return .nothing
        }
        guard let action = pressActions.removeValue(forKey: id) else { return .nothing }
        return .action(action, pressed: false)
    }
}
