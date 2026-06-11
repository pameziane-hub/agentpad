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
    /// HUD hook: fires with the layer button id on hold, nil on release.
    var onLayerHold: ((String?) -> Void)?

    private var router = LayerRouter()
    private var repeater = KeyRepeater(
        initialDelay: NSEvent.keyRepeatDelay,
        interval: NSEvent.keyRepeatInterval)

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
        if state != .active {
            // no ghost layer or running repeat may survive a pause,
            // disconnect, or permission loss
            router.reset()
            repeater.reset()
            onLayerHold?(nil)
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

        if let combo = repeater.nextFire(at: now) {
            // repeats skip the FX hook on purpose: one shot sound per press
            output.post(combo)
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

        // pause must always work, even while paused
        if case .pause = store.config.buttons[id] {
            if pressed { togglePause() }
            return
        }
        guard state == .active else { return }

        let now = Date.timeIntervalSinceReferenceDate
        let heldBefore = router.heldLayer
        let event = router.handle(id: id, pressed: pressed, at: now,
                                  buttons: store.config.buttons)
        if router.heldLayer != heldBefore { onLayerHold?(router.heldLayer) }

        switch event {
        case .nothing:
            break
        case .action(let action, let isDown):
            feedRepeater(id: id, action: action, pressed: isDown, at: now)
            perform(action, pressed: isDown)
        case .tap(let action):
            perform(action, pressed: true)
            perform(action, pressed: false)
        }
    }

    /// Single key combos repeat while held, like a real keyboard key.
    /// Sequences, modifier-only taps, clicks and URLs don't repeat.
    private func feedRepeater(id: String, action: ButtonAction, pressed: Bool,
                              at now: TimeInterval) {
        guard case .key(let raw) = action else { return }
        if pressed {
            guard let sequence = KeyComboParser.parseSequence(raw),
                  sequence.count == 1, let combo = sequence.first,
                  !KeyComboParser.isModifierOnly(combo) else { return }
            repeater.keyDown(id: id, combo: combo, at: now)
        } else {
            repeater.keyUp(id: id)
        }
    }

    private func perform(_ action: ButtonAction, pressed: Bool) {
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
        case .pause, .layer:
            break
        }
    }
}
