import AppKit
import AgentpadCore
import os.log

/// Binds controller input to output actions: a 120 Hz tick maps the sticks
/// to cursor movement and scrolling, button events dispatch config actions.
final class Engine {
    enum State {
        case noController
        case active
        case paused
        case noPermission
    }

    private let controller: ControllerService
    private let output: OutputService
    private let store: ConfigStore
    private let soundFX: SoundFX
    private var accessibilityTrusted: Bool

    private(set) var state: State = .noController
    private(set) var controllerName: String?
    var batteryDescription: String? { controller.batteryDescription }
    var onStateChange: (() -> Void)?
    /// The View button is reserved for UI (mapping overlay / cancel capture).
    var onViewButton: (() -> Void)?
    /// Remap capture: gets every button event first; returning true consumes it.
    var captureHandler: ((String, Bool) -> Bool)?

    private let log = Logger(subsystem: "com.paulameziane.agentpad", category: "engine")
    private var paused = false
    private var connected = false
    private var stickWasMoving = false
    private var movingTicks = 0
    private var timer: Timer?
    private var lastTick = Date.timeIntervalSinceReferenceDate

    init(controller: ControllerService, output: OutputService, store: ConfigStore,
         soundFX: SoundFX, accessibilityTrusted: Bool) {
        self.controller = controller
        self.output = output
        self.store = store
        self.soundFX = soundFX
        self.accessibilityTrusted = accessibilityTrusted
    }

    func start() {
        controller.onConnect = { [weak self] name in
            self?.connected = true
            self?.controllerName = name
            self?.refreshState()
        }
        controller.onDisconnect = { [weak self] in
            self?.connected = false
            self?.controllerName = nil
            self?.refreshState()
        }
        controller.onButton = { [weak self] id, pressed in
            self?.handleButton(id: id, pressed: pressed)
        }
        controller.start()

        let timer = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        // .common keeps the cursor moving while menus are open
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        refreshState()
    }

    func togglePause() {
        paused.toggle()
        refreshState()
    }

    /// Called by the trust poller so granting Accessibility in System
    /// Settings takes effect without relaunching the app.
    func updateTrust(_ trusted: Bool) {
        guard trusted != accessibilityTrusted else { return }
        accessibilityTrusted = trusted
        refreshState()
    }

    private func refreshState() {
        if !accessibilityTrusted {
            state = .noPermission
        } else if !connected {
            state = .noController
        } else if paused {
            state = .paused
        } else {
            state = .active
        }
        log.info("state: \(String(describing: self.state), privacy: .public)")
        onStateChange?()
    }

    private func tick() {
        guard state == .active else { return }
        let now = Date.timeIntervalSinceReferenceDate
        let dt = min(now - lastTick, 0.1)
        lastTick = now

        let pointer = store.config.pointer
        let move = Curves.shape(x: controller.leftStick.x, y: controller.leftStick.y,
                                deadzone: pointer.deadzone, expo: pointer.expo)
        if move != .zero, !stickWasMoving {
            stickWasMoving = true
            movingTicks = 0
            log.debug("stick movement started")
        } else if move == .zero {
            stickWasMoving = false
        }
        if stickWasMoving {
            movingTicks += 1
            // proves timer cadence in log captures: ~1 line per second of movement
            if movingTicks % 120 == 0 {
                log.debug("movement running: \(self.movingTicks, privacy: .public) ticks")
            }
        }
        if move != .zero {
            // GameController y points up, screen y points down
            output.moveCursor(dx: CGFloat(Double(move.x) * pointer.maxSpeed * dt),
                              dy: CGFloat(Double(-move.y) * pointer.maxSpeed * dt))
        }

        let scrollConfig = store.config.scroll
        let scroll = Curves.shape(x: controller.rightStick.x, y: controller.rightStick.y,
                                  deadzone: scrollConfig.deadzone, expo: 0)
        if scroll != .zero {
            output.scroll(dx: Double(-scroll.x) * scrollConfig.speed * dt,
                          dy: Double(scroll.y) * scrollConfig.speed * dt)
        }
    }

    private func handleButton(id: String, pressed: Bool) {
        // View is the UI button: overlay toggle / capture cancel, never mapped
        if id == "view" {
            if pressed { onViewButton?() }
            return
        }
        // an active remap capture eats the event
        if let capture = captureHandler, capture(id, pressed) { return }

        guard let action = store.config.buttons[id] else { return }

        // pause must always work, even while paused
        if case .pause = action {
            if pressed { togglePause() }
            return
        }
        guard state == .active else { return }

        switch action {
        case .leftClick:
            if pressed, store.config.fx.sounds {
                soundFX.playReload(variant: store.config.fx.reloadVariant)
            }
            pressed ? output.leftDown() : output.leftUp()
        case .rightClick:
            pressed ? output.rightDown() : output.rightUp()
        case .key(let raw):
            guard pressed, let sequence = KeyComboParser.parseSequence(raw) else { return }
            // western mode: Return fires the configured shot sound
            if store.config.fx.sounds, sequence.contains(where: { $0.keyCode == 36 }) {
                soundFX.playShot(variant: store.config.fx.shotVariant)
            }
            output.post(sequence: sequence)
        case .url(let urlString):
            guard pressed else { return }
            output.open(urlString: urlString)
        case .pause:
            break
        }
    }
}
