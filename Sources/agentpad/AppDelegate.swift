import AppKit
import AgentpadCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var engine: Engine?
    private var menuBar: MenuBarController?
    private var overlay: MapOverlayController?
    private var remap: RemapCoordinator?
    private var trustPoller: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let trusted = AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)

        let store = ConfigStore(config: ConfigLoader.load())
        let engine = Engine(controller: ControllerService(),
                            output: OutputService(),
                            store: store,
                            accessibilityTrusted: trusted)
        let overlay = MapOverlayController(store: store)
        let remap = RemapCoordinator(store: store)
        let menuBar = MenuBarController(engine: engine, store: store) { buttonId in
            remap.begin(for: buttonId)
        }

        engine.onStateChange = { [weak menuBar] in menuBar?.refresh() }
        engine.captureHandler = { id, pressed in remap.handle(id: id, pressed: pressed) }
        engine.onViewButton = { [weak overlay, weak remap] in
            if remap?.isCapturing == true {
                remap?.cancel()
            } else {
                overlay?.toggleMap()
            }
        }

        remap.onBegin = { [weak overlay] actionLabel in overlay?.show(.capture(actionLabel)) }
        remap.onComplete = { [weak overlay] in overlay?.flashConfirmation() }
        remap.onCancel = { [weak overlay] in overlay?.hide() }

        menuBar.install()
        engine.start()

        self.engine = engine
        self.menuBar = menuBar
        self.overlay = overlay
        self.remap = remap

        // pick up the Accessibility grant without forcing a relaunch
        trustPoller = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak engine] _ in
            engine?.updateTrust(AXIsProcessTrusted())
        }
    }
}
