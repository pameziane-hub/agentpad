import AppKit
import AgentpadCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var engine: Engine?
    private var menuBar: MenuBarController?
    private var trustPoller: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let trusted = AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)

        let config = ConfigLoader.load()
        let engine = Engine(controller: ControllerService(),
                            output: OutputService(),
                            config: config,
                            accessibilityTrusted: trusted)
        let menuBar = MenuBarController(engine: engine, config: config)
        engine.onStateChange = { [weak menuBar] in menuBar?.refresh() }

        menuBar.install()
        engine.start()

        self.engine = engine
        self.menuBar = menuBar

        // pick up the Accessibility grant without forcing a relaunch
        trustPoller = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak engine] _ in
            engine?.updateTrust(AXIsProcessTrusted())
        }
    }
}
