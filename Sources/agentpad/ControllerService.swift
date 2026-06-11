import Foundation
import GameController
import os.log

/// Wraps GCController discovery and input. Xbox controllers paired over
/// Bluetooth show up automatically; handlers fire on the main queue.
final class ControllerService {
    private let log = Logger(subsystem: "com.paulameziane.agentpad", category: "input")
    var onConnect: ((String) -> Void)?
    var onDisconnect: (() -> Void)?
    /// Button id (matching Config.buttons keys) and pressed state.
    var onButton: ((String, Bool) -> Void)?

    private(set) var leftStick: SIMD2<Float> = .zero
    private(set) var rightStick: SIMD2<Float> = .zero
    private(set) var current: GCController?

    /// e.g. "82 % ⚡" while charging, nil when the controller doesn't report battery
    var batteryDescription: String? {
        guard let battery = current?.battery, battery.batteryLevel >= 0 else { return nil }
        let percent = Int((battery.batteryLevel * 100).rounded())
        switch battery.batteryState {
        case .charging: return "\(percent) % ⚡"
        case .full: return "100 %"
        default: return "\(percent) %"
        }
    }

    func start() {
        // A menu bar app is never the frontmost app. Without this flag the
        // framework posts connect notifications but withholds ALL input
        // events, which looks like a dead controller.
        GCController.shouldMonitorBackgroundEvents = true

        NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect, object: nil, queue: .main
        ) { [weak self] notification in
            guard let controller = notification.object as? GCController else { return }
            self?.attach(controller)
        }
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect, object: nil, queue: .main
        ) { [weak self] _ in
            self?.current = nil
            self?.leftStick = .zero
            self?.rightStick = .zero
            self?.onDisconnect?()
        }
        GCController.controllers().forEach(attach)
    }

    private func attach(_ controller: GCController) {
        guard let pad = controller.extendedGamepad else {
            log.warning("controller without extendedGamepad profile ignored")
            return
        }
        current = controller
        log.info("controller connected: \(controller.vendorName ?? "unknown", privacy: .public)")
        onConnect?(controller.vendorName ?? "Controller")

        pad.leftThumbstick.valueChangedHandler = { [weak self] _, x, y in
            self?.leftStick = SIMD2(x, y)
        }
        pad.rightThumbstick.valueChangedHandler = { [weak self] _, x, y in
            self?.rightStick = SIMD2(x, y)
        }

        bind(pad.buttonA, as: "a")
        bind(pad.buttonB, as: "b")
        bind(pad.buttonX, as: "x")
        bind(pad.buttonY, as: "y")
        bind(pad.leftShoulder, as: "leftShoulder")
        bind(pad.rightShoulder, as: "rightShoulder")
        bind(pad.leftTrigger, as: "leftTrigger")
        bind(pad.rightTrigger, as: "rightTrigger")
        bind(pad.dpad.up, as: "dpadUp")
        bind(pad.dpad.down, as: "dpadDown")
        bind(pad.dpad.left, as: "dpadLeft")
        bind(pad.dpad.right, as: "dpadRight")
        bind(pad.buttonMenu, as: "menu")
    }

    private func bind(_ button: GCControllerButtonInput, as id: String) {
        button.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.log.debug("button \(id, privacy: .public) \(pressed ? "down" : "up", privacy: .public)")
            self?.onButton?(id, pressed)
        }
    }
}
