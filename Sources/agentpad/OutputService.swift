import AppKit
import CoreGraphics
import AgentpadCore
import os.log

/// Synthesizes mouse and keyboard events via CGEvent. Requires the
/// Accessibility permission; without it, posted events are silently dropped.
final class OutputService {
    private let log = Logger(subsystem: "com.paulameziane.agentpad", category: "output")
    private let source = CGEventSource(stateID: .hidSystemState)
    /// The magnet must never fight a drag (text selection!) — with either
    /// button.
    var isDragging: Bool { leftButtonHeld || rightButtonHeld }
    private var leftButtonHeld = false
    private var rightButtonHeld = false
    private var dragLatched = false
    private var pendingDrag = CGVector.zero
    /// Movement below this while the button is held is swallowed, so a click
    /// with a slightly deflected stick stays a click instead of drag-selecting.
    private let dragThreshold: CGFloat = 6
    /// Multi-click bookkeeping: macOS only treats synthetic clicks as
    /// double/triple (select word/line) if the events carry a click count.
    private var clickCount: Int64 = 1
    private var lastClickTime: TimeInterval = 0
    private var lastClickLocation = CGPoint.zero
    private let multiClickRadius: CGFloat = 5

    // MARK: - Mouse

    func moveCursor(dx: CGFloat, dy: CGFloat) {
        if leftButtonHeld, !dragLatched {
            pendingDrag.dx += dx
            pendingDrag.dy += dy
            let distance = (pendingDrag.dx * pendingDrag.dx + pendingDrag.dy * pendingDrag.dy).squareRoot()
            guard distance > dragThreshold else { return }
            // intent is clear: start the drag with the buffered movement
            dragLatched = true
            applyMove(dx: pendingDrag.dx, dy: pendingDrag.dy)
            pendingDrag = .zero
            return
        }
        applyMove(dx: dx, dy: dy)
    }

    private func applyMove(dx: CGFloat, dy: CGFloat) {
        let current = currentLocation()
        let target = clampToDisplays(CGPoint(x: current.x + dx, y: current.y + dy))
        // while the click button is held, movement must be a drag; it keeps
        // the click count so double-click-drag selects word-wise like a mouse
        let type: CGEventType = leftButtonHeld ? .leftMouseDragged : .mouseMoved
        let event = CGEvent(mouseEventSource: source, mouseType: type,
                            mouseCursorPosition: target, mouseButton: .left)
        if leftButtonHeld {
            // drags must stay modifier-clean like clicks (see postMouse)
            event?.flags = []
            event?.setIntegerValueField(.mouseEventClickState, value: clickCount)
        }
        event?.post(tap: .cghidEventTap)
    }

    func leftDown() {
        let now = Date.timeIntervalSinceReferenceDate
        let location = currentLocation()
        let dx = location.x - lastClickLocation.x
        let dy = location.y - lastClickLocation.y
        let nearLastClick = (dx * dx + dy * dy).squareRoot() <= multiClickRadius
        let withinInterval = now - lastClickTime <= NSEvent.doubleClickInterval
        // same spot + system double-click tempo → escalate: 2 = word, 3 = line
        clickCount = (nearLastClick && withinInterval) ? clickCount + 1 : 1
        lastClickTime = now
        lastClickLocation = location

        leftButtonHeld = true
        dragLatched = false
        pendingDrag = .zero
        // diagnosis for "weak click" reports: count escalation and position
        log.debug("leftDown clicks=\(self.clickCount, privacy: .public) at \(Int(location.x), privacy: .public),\(Int(location.y), privacy: .public) front=\(NSWorkspace.shared.frontmostApplication?.localizedName ?? "?", privacy: .public)")
        postMouse(.leftMouseDown, button: .left, clickCount: clickCount)
    }

    func leftUp() {
        log.debug("leftUp clicks=\(self.clickCount, privacy: .public) dragged=\(self.dragLatched, privacy: .public)")
        leftButtonHeld = false
        dragLatched = false
        pendingDrag = .zero
        postMouse(.leftMouseUp, button: .left, clickCount: clickCount)
    }

    func rightDown() {
        rightButtonHeld = true
        postMouse(.rightMouseDown, button: .right)
    }

    func rightUp() {
        rightButtonHeld = false
        postMouse(.rightMouseUp, button: .right)
    }

    func scroll(dx: Double, dy: Double) {
        CGEvent(scrollWheelEvent2Source: source, units: .pixel, wheelCount: 2,
                wheel1: Int32(dy.rounded()), wheel2: Int32(dx.rounded()), wheel3: 0)?
            .post(tap: .cghidEventTap)
    }

    private func postMouse(_ type: CGEventType, button: CGMouseButton, clickCount: Int64 = 1) {
        let event = CGEvent(mouseEventSource: source, mouseType: type,
                            mouseCursorPosition: currentLocation(), mouseButton: button)
        // never inherit modifier state: a stuck or held Ctrl would turn the
        // left click into a context-menu click (field bug 2026-06-12)
        event?.flags = []
        event?.setIntegerValueField(.mouseEventClickState, value: clickCount)
        event?.post(tap: .cghidEventTap)
    }

    private func currentLocation() -> CGPoint {
        CGEvent(source: nil)?.location ?? .zero
    }

    private func clampToDisplays(_ point: CGPoint) -> CGPoint {
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        CGGetActiveDisplayList(16, &displayIDs, &count)
        let bounds = (0..<Int(count)).map { CGDisplayBounds(displayIDs[$0]) }
        guard !bounds.isEmpty else { return point }
        return DisplayClamp.clamp(point, to: bounds)
    }

    // MARK: - Keyboard

    func post(sequence: [KeyCombo]) {
        for (index, combo) in sequence.enumerated() {
            post(combo)
            // gap so double-taps (e.g. ctrl ctrl for dictation) register as two presses
            if index < sequence.count - 1 { usleep(60_000) }
        }
    }

    /// Types literal text: the events carry the unicode payload instead of a
    /// positional key code, so "/" stays "/" on German ISO as well as US
    /// ANSI. CGEvent caps the payload per event (~20 UTF-16 units), hence
    /// the chunking — also the base for longer snippets later.
    func typeText(_ string: String) {
        let units = Array(string.utf16)
        let chunkSize = 20
        for start in stride(from: 0, to: units.count, by: chunkSize) {
            let chunk = Array(units[start..<min(start + chunkSize, units.count)])
            for keyDown in [true, false] {
                guard let event = CGEvent(keyboardEventSource: source,
                                          virtualKey: 0, keyDown: keyDown) else { continue }
                event.keyboardSetUnicodeString(stringLength: chunk.count,
                                               unicodeString: chunk)
                event.post(tap: .cghidEventTap)
            }
        }
        log.debug("typeText \(string, privacy: .public)")
    }

    func post(_ combo: KeyCombo) {
        if KeyComboParser.isModifierOnly(combo) {
            postModifierTap(combo)
            return
        }
        var flags = cgFlags(combo.flags)
        // real keyboards set fn+numpad on arrow keys; system hot-keys like
        // Mission Control's ctrl+arrow space switching match against that
        if (123...126).contains(combo.keyCode) {
            flags.insert(.maskSecondaryFn)
            flags.insert(.maskNumericPad)
        }
        for keyDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source,
                                      virtualKey: combo.keyCode, keyDown: keyDown) else { continue }
            event.flags = flags
            event.post(tap: .cghidEventTap)
        }
    }

    /// A bare modifier press (e.g. Control for macOS dictation) must be sent
    /// as flagsChanged events, not keyDown/keyUp.
    private func postModifierTap(_ combo: KeyCombo) {
        guard let down = CGEvent(keyboardEventSource: source,
                                 virtualKey: combo.keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source,
                               virtualKey: combo.keyCode, keyDown: false) else { return }
        down.type = .flagsChanged
        down.flags = modifierFlag(for: combo.keyCode)
        up.type = .flagsChanged
        up.flags = []
        down.post(tap: .cghidEventTap)
        usleep(20_000)
        up.post(tap: .cghidEventTap)
    }

    private func modifierFlag(for keyCode: UInt16) -> CGEventFlags {
        switch keyCode {
        case 54, 55: return .maskCommand
        case 56, 60: return .maskShift
        case 58, 61: return .maskAlternate
        case 59, 62: return .maskControl
        case 63: return .maskSecondaryFn
        default: return []
        }
    }

    private func cgFlags(_ flags: KeyFlags) -> CGEventFlags {
        var result: CGEventFlags = []
        if flags.contains(.command) { result.insert(.maskCommand) }
        if flags.contains(.shift) { result.insert(.maskShift) }
        if flags.contains(.control) { result.insert(.maskControl) }
        if flags.contains(.option) { result.insert(.maskAlternate) }
        return result
    }

    // MARK: - URLs

    func open(urlString: String) {
        guard let url = URL(string: urlString) else { return }
        // never activate the handling app: dictation tools must paste into
        // the input that is focused RIGHT NOW, so the frontmost app (your
        // terminal with the agent session) has to keep focus throughout
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        NSWorkspace.shared.open(url, configuration: configuration)
    }
}
