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
    private let onPreviewShot: (String) -> Void
    private let onPreviewReload: (String) -> Void
    private let hasCustomShot: Bool
    private let hasCustomReload: Bool
    private var statusItem: NSStatusItem?

    private static let shotNames = [
        "classic": "Revolver", "laser": "Laser", "8bit": "8-Bit", "silenced": "Silenced",
    ]
    private static let reloadNames = [
        "clack": "Clack", "pop": "Pop", "thock": "Thock", "tick": "Tick",
    ]

    init(engine: Engine, store: ConfigStore,
         onRemapRequest: @escaping (String) -> Void,
         onPreviewShot: @escaping (String) -> Void,
         onPreviewReload: @escaping (String) -> Void,
         hasCustomShot: Bool, hasCustomReload: Bool) {
        self.engine = engine
        self.store = store
        self.onRemapRequest = onRemapRequest
        self.onPreviewShot = onPreviewShot
        self.onPreviewReload = onPreviewReload
        self.hasCustomShot = hasCustomShot
        self.hasCustomReload = hasCustomReload
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

        menu.addItem(soundFxItem())

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

    // MARK: - Sound FX submenu
    // Every row is a custom view: AppKit only auto-closes menus for native
    // item clicks, so view-based rows let flavors be auditioned in a row
    // without reopening the menu (same trick keeps the slider alive).

    private func soundFxItem() -> NSMenuItem {
        let parent = NSMenuItem(title: "Sound FX", action: nil, keyEquivalent: "")
        parent.image = symbolImage(["speaker.wave.2.fill"])
        let submenu = NSMenu()

        let enabledRow = TryoutRow(title: "Enabled", checked: store.config.fx.sounds)
        enabledRow.onClick = { [weak self, weak enabledRow] in
            guard let self else { return }
            let nowOn = !self.store.config.fx.sounds
            self.store.setSounds(nowOn)
            enabledRow?.checked = nowOn
            // audible proof when switching on; silence means off
            if nowOn { self.onPreviewReload(self.store.config.fx.reloadVariant) }
        }
        submenu.addItem(menuItem(for: enabledRow))

        submenu.addItem(.separator())
        submenu.addItem(sectionHeader("VOLUME"))
        submenu.addItem(volumeSliderItem())

        submenu.addItem(.separator())
        submenu.addItem(sectionHeader("SHOT (on Return)"))
        var shotVariants = FxConfig.shotVariants + FxConfig.systemVariants
        if hasCustomShot { shotVariants.append("custom") }
        addVariantRows(to: submenu, variants: shotVariants, names: Self.shotNames,
                       customTitle: "Custom (shot.wav)",
                       current: store.config.fx.shotVariant,
                       preview: onPreviewShot)

        submenu.addItem(.separator())
        submenu.addItem(sectionHeader("RELOAD (on left click)"))
        var reloadVariants = FxConfig.reloadVariants + FxConfig.systemVariants
        if hasCustomReload { reloadVariants.append("custom") }
        addVariantRows(to: submenu, variants: reloadVariants, names: Self.reloadNames,
                       customTitle: "Custom (reload.wav)",
                       current: store.config.fx.reloadVariant,
                       preview: onPreviewReload)

        parent.submenu = submenu
        return parent
    }

    /// One group of audition rows; clicking moves the group's checkmark
    /// live and plays the preview, the menu stays open throughout.
    private func addVariantRows(to submenu: NSMenu, variants: [String],
                                names: [String: String], customTitle: String,
                                current: String, preview: @escaping (String) -> Void) {
        let groupId = customTitle   // unique per group, never shown
        for variant in variants {
            let title = variant == "custom" ? customTitle : names[variant] ?? variant
            let row = TryoutRow(title: title, checked: variant == current, groupId: groupId)
            // sibling rows are found through the submenu at click time, so
            // no row ever retains another (menus get rebuilt on every open)
            row.onClick = { [weak submenu, weak row] in
                submenu?.items.compactMap { $0.view as? TryoutRow }
                    .filter { $0.groupId == groupId }
                    .forEach { $0.checked = false }
                row?.checked = true
                preview(variant)
            }
            submenu.addItem(menuItem(for: row))
        }
    }

    private func menuItem(for row: TryoutRow) -> NSMenuItem {
        let item = NSMenuItem()
        item.view = row
        return item
    }

    /// Slider row: drag, release, hear the new level on the click sound.
    private func volumeSliderItem() -> NSMenuItem {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        let slider = NSSlider(value: Double(store.config.fx.volume),
                              minValue: 0, maxValue: 1,
                              target: self, action: #selector(volumeChanged(_:)))
        slider.isContinuous = false   // fire once on release, not while dragging
        slider.frame = NSRect(x: 22, y: 2, width: 176, height: 20)
        container.addSubview(slider)
        let item = NSMenuItem()
        item.view = container
        return item
    }

    @objc private func volumeChanged(_ sender: NSSlider) {
        store.setVolume(sender.floatValue)
        // audible feedback at the new level, on the currently picked click sound
        onPreviewReload(store.config.fx.reloadVariant)
    }

    // MARK: - Header card

    private func headerView() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 52))

        let dot = NSTextField(labelWithString: "●")
        dot.font = .systemFont(ofSize: 12)
        dot.textColor = stateColor()
        dot.frame = NSRect(x: 14, y: 26, width: 16, height: 16)
        view.addSubview(dot)

        var appTitle = "agentpad"
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            appTitle += "  v\(version)"
        }
        let title = NSTextField(labelWithString: appTitle)
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

/// Menu row that survives its own click: AppKit only auto-closes menus for
/// native items, so a view-based row keeps the menu open — exactly what
/// auditioning sounds needs. Draws its own hover highlight and checkmark.
private final class TryoutRow: NSView {
    let groupId: String
    var onClick: (() -> Void)?
    var checked: Bool {
        didSet { check.isHidden = !checked }
    }

    private let check = NSTextField(labelWithString: "✓")
    private var hovered = false {
        didSet { needsDisplay = true }
    }

    init(title: String, checked: Bool, groupId: String = "") {
        self.checked = checked
        self.groupId = groupId
        super.init(frame: NSRect(x: 0, y: 0, width: 220, height: 22))

        check.font = .systemFont(ofSize: 12, weight: .semibold)
        check.frame = NSRect(x: 10, y: 3, width: 14, height: 16)
        check.isHidden = !checked
        addSubview(check)

        let label = NSTextField(labelWithString: title)
        label.font = .menuFont(ofSize: 13)
        label.frame = NSRect(x: 28, y: 3, width: 184, height: 16)
        addSubview(label)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func updateTrackingAreas() {
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds, options: [.mouseEnteredAndExited, .activeAlways],
            owner: self, userInfo: nil))
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) { hovered = true }
    override func mouseExited(with event: NSEvent) { hovered = false }
    override func mouseUp(with event: NSEvent) { onClick?() }

    override func draw(_ dirtyRect: NSRect) {
        if hovered {
            NSColor.selectedContentBackgroundColor.withAlphaComponent(0.25).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 5, dy: 0),
                         xRadius: 4, yRadius: 4).fill()
        }
        super.draw(dirtyRect)
    }
}
