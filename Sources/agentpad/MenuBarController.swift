import AppKit
import AgentpadCore

/// Status item in the menu bar with a Superwhisper-style dropdown: a header
/// card showing connection state and battery, the live button mapping
/// (click a row to rebind it from the controller), and the app actions.
/// The menu is rebuilt on every open so it never goes stale.
final class MenuBarController: NSObject, NSMenuDelegate {
    private let engine: Engine
    private let store: ConfigStore
    private let onRemapRequest: (String) -> Void
    private var statusItem: NSStatusItem?

    init(engine: Engine, store: ConfigStore, onRemapRequest: @escaping (String) -> Void) {
        self.engine = engine
        self.store = store
        self.onRemapRequest = onRemapRequest
    }

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
        refresh()
    }

    /// Updates the bar icon; menu content is rebuilt lazily in menuNeedsUpdate.
    func refresh() {
        guard let button = statusItem?.button else { return }
        let (symbol, description): (String, String)
        switch engine.state {
        case .active: (symbol, description) = ("gamecontroller.fill", "agentpad active")
        case .noController: (symbol, description) = ("gamecontroller", "no controller")
        case .paused: (symbol, description) = ("pause.circle", "agentpad paused")
        case .noPermission: (symbol, description) = ("exclamationmark.triangle", "missing permission")
        }
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: description)
        button.appearsDisabled = engine.state == .noController
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let header = NSMenuItem()
        header.view = headerView()
        menu.addItem(header)
        menu.addItem(.separator())

        switch engine.state {
        case .noPermission:
            let grant = NSMenuItem(title: "Grant Accessibility Permission…",
                                   action: #selector(openAccessibilitySettings), keyEquivalent: "")
            grant.target = self
            grant.image = symbolImage(["lock.shield"])
            menu.addItem(grant)
            menu.addItem(.separator())
        case .active, .paused:
            let pause = NSMenuItem(title: engine.state == .paused ? "Resume" : "Pause",
                                   action: #selector(togglePause), keyEquivalent: "p")
            pause.target = self
            pause.image = symbolImage([engine.state == .paused ? "play.fill" : "pause.fill"])
            menu.addItem(pause)
            menu.addItem(.separator())
        case .noController:
            break
        }

        menu.addItem(sectionHeader("MAPPING — click a row, then press its new button"))
        for entry in MappingSummary.displayOrder {
            guard let action = store.config.buttons[entry.id] else { continue }
            let item = NSMenuItem(title: "\(entry.label)   —   \(MappingSummary.describe(action))",
                                  action: #selector(remapRow(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = entry.id
            item.image = symbolImage(buttonSymbols(for: entry.label))
            menu.addItem(item)
        }
        menu.addItem(.separator())

        let openConfig = NSMenuItem(title: "Open Config", action: #selector(openConfigFile), keyEquivalent: "")
        openConfig.target = self
        openConfig.image = symbolImage(["gearshape"])
        menu.addItem(openConfig)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit agentpad", action: #selector(NSApplication.terminate(_:)),
                              keyEquivalent: "q")
        quit.image = symbolImage(["power"])
        menu.addItem(quit)
    }

    // MARK: - Header card

    private func headerView() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 52))

        let dot = NSTextField(labelWithString: "●")
        dot.font = .systemFont(ofSize: 12)
        dot.textColor = stateColor()
        dot.frame = NSRect(x: 14, y: 26, width: 16, height: 16)
        view.addSubview(dot)

        let title = NSTextField(labelWithString: "agentpad")
        title.font = .boldSystemFont(ofSize: 13)
        title.frame = NSRect(x: 32, y: 26, width: 200, height: 17)
        view.addSubview(title)

        let subtitle = NSTextField(labelWithString: subtitleText())
        subtitle.font = .systemFont(ofSize: 11)
        subtitle.textColor = .secondaryLabelColor
        subtitle.lineBreakMode = .byTruncatingTail
        subtitle.frame = NSRect(x: 32, y: 8, width: 254, height: 15)
        view.addSubview(subtitle)

        return view
    }

    private func stateColor() -> NSColor {
        switch engine.state {
        case .active: return .systemGreen
        case .paused: return .systemOrange
        case .noController: return .systemGray
        case .noPermission: return .systemRed
        }
    }

    private func subtitleText() -> String {
        switch engine.state {
        case .noPermission:
            return "No Accessibility permission — nothing will move"
        case .noController:
            return "No controller — pair one via Bluetooth"
        case .active, .paused:
            let name = engine.controllerName ?? "Controller"
            let state = engine.state == .paused ? "paused" : "active"
            if let battery = engine.batteryDescription {
                return "\(name) · 🔋 \(battery) · \(state)"
            }
            return "\(name) · \(state)"
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> NSMenuItem {
        if #available(macOS 14.0, *) {
            return .sectionHeader(title: title)
        }
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    /// First SF Symbol that exists on this macOS version; rows degrade to
    /// text-only if none do.
    private func symbolImage(_ names: [String]) -> NSImage? {
        for name in names {
            if let image = NSImage(systemSymbolName: name, accessibilityDescription: nil) {
                return image
            }
        }
        return nil
    }

    private func buttonSymbols(for label: String) -> [String] {
        switch label {
        case "A": return ["a.circle.fill"]
        case "B": return ["b.circle.fill"]
        case "X": return ["x.circle.fill"]
        case "Y": return ["y.circle.fill"]
        case "LT": return ["lt.button.roundedtop.horizontal.fill", "l2.button.roundedtop.horizontal.fill", "circle.lefthalf.filled"]
        case "RT": return ["rt.button.roundedtop.horizontal.fill", "r2.button.roundedtop.horizontal.fill", "circle.righthalf.filled"]
        case "LB": return ["lb.button.roundedbottom.horizontal.fill", "l1.button.roundedbottom.horizontal.fill", "circle.lefthalf.filled"]
        case "RB": return ["rb.button.roundedbottom.horizontal.fill", "r1.button.roundedbottom.horizontal.fill", "circle.righthalf.filled"]
        case "L3": return ["l.joystick.press.down.fill", "l.joystick.press.down"]
        case "R3": return ["r.joystick.press.down.fill", "r.joystick.press.down"]
        case "Menu": return ["line.3.horizontal.circle.fill"]
        default: return ["dpad.fill"]
        }
    }

    // MARK: - Actions

    @objc private func remapRow(_ sender: NSMenuItem) {
        guard let buttonId = sender.representedObject as? String else { return }
        onRemapRequest(buttonId)
    }

    @objc private func togglePause() {
        engine.togglePause()
    }

    @objc private func openConfigFile() {
        NSWorkspace.shared.open(ConfigLoader.defaultURL)
    }

    @objc private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
