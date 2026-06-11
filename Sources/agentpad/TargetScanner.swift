import AppKit
import ApplicationServices
import AgentpadCore
import os.log

/// Feeds the magnet: every ~100 ms while the stick is moving, asks the
/// Accessibility API what clickable element sits under the cursor and
/// publishes its frame to the main thread. All AX calls stay on one serial
/// queue — first contact with a "cold" app can block for ~30 ms (probed
/// 2026-06-11), which must never happen on the 120 Hz tick.
final class TargetScanner {
    /// Latest clickable frame under or just ahead of the cursor, global CG
    /// coordinates. Read from the main thread (the engine tick).
    private(set) var currentTarget: CGRect?

    private let log = Logger(subsystem: "com.paulameziane.agentpad", category: "magnet")
    private let queue = DispatchQueue(label: "com.paulameziane.agentpad.magnet", qos: .utility)
    private var timer: DispatchSourceTimer?
    private let systemWide = AXUIElementCreateSystemWide()
    // touched on `queue` only
    private var active = false
    private var heading = CGVector.zero
    /// How far ahead of the cursor the look-ahead probe sits, so targets
    /// start pulling before the cursor arrives (steering's approach zone).
    private static let lookahead: CGFloat = 44

    /// Engine flips this with stick activity; no movement = no scanning,
    /// so idle agentpad never wakes other apps.
    func setActive(_ isActive: Bool) {
        queue.async {
            guard self.active != isActive else { return }
            self.active = isActive
            if !isActive { DispatchQueue.main.async { self.currentTarget = nil } }
        }
    }

    /// Current movement direction (any scale), for the look-ahead probe.
    func update(heading: CGVector) {
        queue.async { self.heading = heading }
    }

    /// Roles worth being sticky for. Containers and giant frames are
    /// filtered out — a 4096 pt AXGroup must never glue the cursor.
    private static let clickableRoles: Set<String> = [
        "AXButton", "AXMenuBarItem", "AXMenuItem", "AXMenuButton",
        "AXLink", "AXCheckBox", "AXRadioButton", "AXPopUpButton",
        "AXTextField", "AXComboBox", "AXDockItem", "AXTabButton",
        "AXDisclosureTriangle", "AXIncrementor", "AXSegmentedControl",
    ]
    private static let maxTargetSize = CGSize(width: 320, height: 120)
    /// Hit-tests usually land on a button's LABEL (AXStaticText, AXImage…);
    /// climb this many parents looking for a clickable role.
    private static let parentClimb = 4

    func start() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(100))
        timer.setEventHandler { [weak self] in self?.scan() }
        timer.resume()
        self.timer = timer
    }

    private func scan() {
        guard active else { return }
        // CGEvent location is in global CG coordinates (top-left origin),
        // the same space AX hit-testing expects
        guard let cursor = CGEvent(source: nil)?.location else { return }
        var frame = clickableFrame(at: cursor)
        // nothing underneath: probe ahead in the movement direction, so
        // the steering assist sees its target before the cursor lands
        if frame == nil {
            let length = hypot(heading.dx, heading.dy)
            if length > 0 {
                let probe = CGPoint(x: cursor.x + heading.dx / length * Self.lookahead,
                                    y: cursor.y + heading.dy / length * Self.lookahead)
                frame = clickableFrame(at: probe)
            }
        }
        DispatchQueue.main.async { self.currentTarget = frame }
    }

    private func clickableFrame(at point: CGPoint) -> CGRect? {
        // the menu bar is the headline use case AND the place where point
        // hit-testing is flakiest (status items only expose their app's
        // root): query the frontmost app's menu bar directly instead
        if point.y < 24, let item = menuBarItemViaFrontApp(at: point) {
            return item
        }

        var element: AXUIElement?
        guard AXUIElementCopyElementAtPosition(
                systemWide, Float(point.x), Float(point.y), &element) == .success,
              var element else { return nil }

        // the menu bar hit-tests as its container; one drill-down finds
        // the actual item under the point
        if role(of: element) == "AXMenuBar",
           let item = menuBarItem(in: element, at: point) {
            element = item
        }
        // hits usually land on the label INSIDE a button: climb parents
        // until a clickable role turns up
        var hitRole = role(of: element) ?? "?"
        var climbed = 0
        while !Self.clickableRoles.contains(hitRole), climbed < Self.parentClimb {
            var parentRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(
                    element, kAXParentAttribute as CFString, &parentRef) == .success,
                  let parentRef else { break }
            element = parentRef as! AXUIElement
            hitRole = role(of: element) ?? "?"
            climbed += 1
        }
        guard Self.clickableRoles.contains(hitRole) else {
            log.debug("reject role=\(hitRole, privacy: .public)")
            return nil
        }
        guard let frame = frame(of: element),
              frame.width <= Self.maxTargetSize.width,
              frame.height <= Self.maxTargetSize.height else {
            log.debug("reject size role=\(hitRole, privacy: .public)")
            return nil
        }
        log.debug("target role=\(hitRole, privacy: .public) \(Int(frame.width), privacy: .public)x\(Int(frame.height), privacy: .public)")
        return frame
    }

    /// App menus (left) live on the frontmost app's AXMenuBar; status
    /// items (right) on its AXExtrasMenuBar. Both expose reliable item
    /// frames where point hit-tests don't.
    private func menuBarItemViaFrontApp(at point: CGPoint) -> CGRect? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }
        let app = AXUIElementCreateApplication(frontApp.processIdentifier)
        for attribute in [kAXMenuBarAttribute, kAXExtrasMenuBarAttribute] {
            var barRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(app, attribute as CFString, &barRef) == .success,
                  let barRef else { continue }
            let bar = barRef as! AXUIElement
            if let item = menuBarItem(in: bar, at: point),
               let frame = frame(of: item) {
                log.debug("target menubar item \(Int(frame.width), privacy: .public)x\(Int(frame.height), privacy: .public)")
                return frame
            }
        }
        return nil
    }

    private func menuBarItem(in menuBar: AXUIElement, at point: CGPoint) -> AXUIElement? {
        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
                menuBar, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement] else { return nil }
        return children.first { frame(of: $0)?.contains(point) == true }
    }

    private func role(of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &value)
        return value as? String
    }

    private func frame(of element: AXUIElement) -> CGRect? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, "AXFrame" as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var rect = CGRect.zero
        guard AXValueGetValue(value as! AXValue, .cgRect, &rect) else { return nil }
        return rect
    }
}
