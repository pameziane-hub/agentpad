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
    private let config: Config
    private var accessibilityTrusted: Bool

    private(set) var state: State = .noController
    private(set) var controllerName: String?
    var batteryDescription: String? { controller.batteryDescription }
    var onStateChange: (() -> Void)?

    private let log = Logger(subsystem: "com.paulameziane.agentpad", category: "engine")
    private var paused = false
    private var connected = false
    private var stickWasMoving = false
    private var movingTicks = 0
    private var timer: Timer?
    private var lastTick = Date.timeIntervalSinceReferenceDate

    init(controller: ControllerService, output: OutputService, config: Config,
         accessibilityTrusted: Bool) {
        self.controller = controller
        self.output = output
        self.config = config
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

        let move = Curves.shape(x: controller.leftStick.x, y: controller.leftStick.y,
                                deadzone: config.pointer.deadzone, expo: config.pointer.expo)
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
            output.moveCursor(dx: CGFloat(Double(move.x) * config.pointer.maxSpeed * dt),
                              dy: CGFloat(Double(-move.y) * config.pointer.maxSpeed * dt))
        }

        let scroll = Curves.shape(x: controller.rightStick.x, y: controller.rightStick.y,
                                  deadzone: config.scroll.deadzone, expo: 0)
        if scroll != .zero {
            output.scroll(dx: Double(-scroll.x) * config.scroll.speed * dt,
                          dy: Double(scroll.y) * config.scroll.speed * dt)
        }
    }

    private func handleButton(id: String, pressed: Bool) {
        guard let action = config.buttons[id] else { return }

        // pause must always work, even while paused
        if case .pause = action {
            if pressed { togglePause() }
            return
        }
        guard state == .active else { return }

        switch action {
        case .leftClick:
            pressed ? output.leftDown() : output.leftUp()
        case .rightClick:
            pressed ? output.rightDown() : output.rightUp()
        case .key(let raw):
            guard pressed, let sequence = KeyComboParser.parseSequence(raw) else { return }
            output.post(sequence: sequence)
        case .url(let urlString):
            guard pressed else { return }
            output.open(urlString: urlString)
        case .pause:
            break
        }
    }
}
