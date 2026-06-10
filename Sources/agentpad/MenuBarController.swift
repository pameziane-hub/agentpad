import AppKit
import AgentpadCore

/// Status item in the menu bar: icon reflects the engine state, menu offers
/// pause, opening the config file, and quit.
final class MenuBarController: NSObject {
    private let engine: Engine
    private var statusItem: NSStatusItem?

    init(engine: Engine) {
        self.engine = engine
    }

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem = item
        item.menu = buildMenu()
        refresh()
    }

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
        statusItem?.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let status = NSMenuItem(title: statusLine(), action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

        let pauseTitle = engine.state == .paused ? "Resume" : "Pause"
        let pause = NSMenuItem(title: pauseTitle, action: #selector(togglePause), keyEquivalent: "p")
        pause.target = self
        menu.addItem(pause)

        let config = NSMenuItem(title: "Open Config", action: #selector(openConfig), keyEquivalent: "")
        config.target = self
        menu.addItem(config)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit agentpad", action: #selector(NSApplication.terminate(_:)),
                              keyEquivalent: "q")
        menu.addItem(quit)
        return menu
    }

    private func statusLine() -> String {
        switch engine.state {
        case .noPermission:
            return "⚠️ Grant Accessibility permission, then restart"
        case .noController:
            return "No controller connected"
        case .active, .paused:
            return engine.controllerName ?? "Controller connected"
        }
    }

    @objc private func togglePause() {
        engine.togglePause()
    }

    @objc private func openConfig() {
        NSWorkspace.shared.open(ConfigLoader.defaultURL)
    }
}
