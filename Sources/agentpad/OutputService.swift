import AppKit
import CoreGraphics
import AgentpadCore

/// Synthesizes mouse and keyboard events via CGEvent. Requires the
/// Accessibility permission; without it, posted events are silently dropped.
final class OutputService {
    private let source = CGEventSource(stateID: .hidSystemState)
    private var leftButtonHeld = false

    // MARK: - Mouse

    func moveCursor(dx: CGFloat, dy: CGFloat) {
        let current = currentLocation()
        let target = clampToDisplays(CGPoint(x: current.x + dx, y: current.y + dy))
        // while the trigger holds the left button, movement must be a drag
        let type: CGEventType = leftButtonHeld ? .leftMouseDragged : .mouseMoved
        CGEvent(mouseEventSource: source, mouseType: type,
                mouseCursorPosition: target, mouseButton: .left)?
            .post(tap: .cghidEventTap)
    }

    func leftDown() {
        leftButtonHeld = true
        postMouse(.leftMouseDown, button: .left)
    }

    func leftUp() {
        leftButtonHeld = false
        postMouse(.leftMouseUp, button: .left)
    }

    func rightDown() { postMouse(.rightMouseDown, button: .right) }
    func rightUp() { postMouse(.rightMouseUp, button: .right) }

    func scroll(dx: Double, dy: Double) {
        CGEvent(scrollWheelEvent2Source: source, units: .pixel, wheelCount: 2,
                wheel1: Int32(dy.rounded()), wheel2: Int32(dx.rounded()), wheel3: 0)?
            .post(tap: .cghidEventTap)
    }

    private func postMouse(_ type: CGEventType, button: CGMouseButton) {
        CGEvent(mouseEventSource: source, mouseType: type,
                mouseCursorPosition: currentLocation(), mouseButton: button)?
            .post(tap: .cghidEventTap)
    }

    private func currentLocation() -> CGPoint {
        CGEvent(source: nil)?.location ?? .zero
    }

    private func clampToDisplays(_ point: CGPoint) -> CGPoint {
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        CGGetActiveDisplayList(16, &displayIDs, &count)
        let bounds = (0..<Int(count)).map { CGDisplayBounds(displayIDs[$0]) }
        if bounds.contains(where: { $0.contains(point) }) { return point }
        let main = bounds.first ?? CGDisplayBounds(CGMainDisplayID())
        return CGPoint(x: min(max(point.x, main.minX), main.maxX - 1),
                       y: min(max(point.y, main.minY), main.maxY - 1))
    }

    // MARK: - Keyboard

    func post(sequence: [KeyCombo]) {
        for (index, combo) in sequence.enumerated() {
            post(combo)
            // gap so double-taps (e.g. ctrl ctrl for dictation) register as two presses
            if index < sequence.count - 1 { usleep(60_000) }
        }
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
