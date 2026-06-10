import AppKit
import AgentpadCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var engine: Engine?
    private var menuBar: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let trusted = AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)

        let engine = Engine(controller: ControllerService(),
                            output: OutputService(),
                            config: ConfigLoader.load(),
                            accessibilityTrusted: trusted)
        let menuBar = MenuBarController(engine: engine)
        engine.onStateChange = { [weak menuBar] in menuBar?.refresh() }

        menuBar.install()
        engine.start()

        self.engine = engine
        self.menuBar = menuBar
    }
}
