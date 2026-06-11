import AppKit
import AgentpadCore

/// Game-style cheat-sheet overlay: a translucent HUD panel in the middle of
/// the screen showing the full mapping (toggled with the View button) or the
/// "press a button" prompt while rebinding. Non-activating and click-through,
/// so focus never leaves the app you're working in.
final class MapOverlayController {
    enum Mode {
        case map
        case capture(String)
    }

    private let store: ConfigStore
    private var panel: NSPanel?
    private(set) var isShowingMap = false

    init(store: ConfigStore) {
        self.store = store
    }

    func toggleMap() {
        if isShowingMap {
            hide()
        } else {
            show(.map)
        }
    }

    func show(_ mode: Mode) {
        hide()
        let content = buildContent(for: mode)
        let panel = NSPanel(contentRect: content.frame,
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .modalPanel
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = content
        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(
                x: frame.midX - content.frame.width / 2,
                y: frame.midY - content.frame.height / 2))
        }
        panel.orderFrontRegardless()
        self.panel = panel
        if case .map = mode { isShowingMap = true }
    }

    /// Brief "rebound!" confirmation: show the fresh map, then auto-hide.
    func flashConfirmation() {
        show(.map)
        isShowingMap = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            guard let self, !self.isShowingMap else { return }
            self.hide()
        }
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
        isShowingMap = false
    }

    // MARK: - Hold-layer HUD

    private var hudPanel: NSPanel?

    /// Compact hold-HUD: one pill near the bottom of the screen listing a
    /// layer's slots while the layer button is held. Suppressed while the
    /// full map is open — the map already shows everything.
    func showLayerHud(forLayer id: String) {
        hideLayerHud()
        guard !isShowingMap else { return }
        let rows = MappingSummary.overlayRows(forLayer: id, config: store.config)
        guard !rows.isEmpty else { return }

        let line = rows.map { "\($0.button) \($0.action)" }.joined(separator: "   ·   ")
        let label = NSTextField(labelWithString: line)
        label.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        label.textColor = .labelColor
        label.sizeToFit()

        let container = hudContainer(width: label.frame.width + 44,
                                     height: label.frame.height + 24)
        container.layer?.cornerRadius = container.frame.height / 2
        label.setFrameOrigin(NSPoint(x: 22, y: 12))
        container.addSubview(label)

        let panel = NSPanel(contentRect: container.frame,
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .modalPanel
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = container
        if let screen = NSScreen.main {
            // top-center, just under the menu bar: that's where eyes already
            // are while working — bottom placement got overlooked in testing
            let frame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: frame.midX - container.frame.width / 2,
                                         y: frame.maxY - container.frame.height - 12))
        }
        panel.orderFrontRegardless()
        hudPanel = panel
    }

    func hideLayerHud() {
        hudPanel?.orderOut(nil)
        hudPanel = nil
    }

    // MARK: - Rendering

    private func buildContent(for mode: Mode) -> NSView {
        switch mode {
        case .map: return buildMapView()
        case .capture(let label): return buildCaptureView(actionLabel: label)
        }
    }

    private func buildMapView() -> NSView {
        let rows = MappingSummary.rows(for: store.config)
        let height = CGFloat(96 + rows.count * 28)
        let container = hudContainer(width: 400, height: height)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(title("🎮  agentpad mapping"))
        stack.setCustomSpacing(14, after: stack.arrangedSubviews.last!)

        for row in rows {
            stack.addArrangedSubview(mappingRow(button: row.button, action: row.action))
        }

        stack.setCustomSpacing(14, after: stack.arrangedSubviews.last!)
        stack.addArrangedSubview(hint("View button closes · click a menu row to rebind"))

        embed(stack, in: container)
        return container
    }

    private func buildCaptureView(actionLabel: String) -> NSView {
        let container = hudContainer(width: 400, height: 170)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(title("Press a button for:"))
        let action = NSTextField(labelWithString: actionLabel)
        action.font = .monospacedSystemFont(ofSize: 22, weight: .bold)
        action.textColor = .systemGreen
        stack.addArrangedSubview(action)
        stack.addArrangedSubview(hint("View button cancels · times out after 6 s"))

        embed(stack, in: container)
        return container
    }

    private func hudContainer(width: CGFloat, height: CGFloat) -> NSVisualEffectView {
        let view = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        view.material = .hudWindow
        view.state = .active
        view.blendingMode = .behindWindow
        view.wantsLayer = true
        view.layer?.cornerRadius = 18
        view.layer?.masksToBounds = true
        return view
    }

    private func embed(_ stack: NSStackView, in container: NSView) {
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
    }

    private func title(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .boldSystemFont(ofSize: 16)
        label.textColor = .labelColor
        return label
    }

    private func hint(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 11)
        label.textColor = .tertiaryLabelColor
        return label
    }

    private func mappingRow(button: String, action: String) -> NSView {
        let buttonLabel = NSTextField(labelWithString: button)
        buttonLabel.font = .monospacedSystemFont(ofSize: 13, weight: .bold)
        buttonLabel.textColor = .secondaryLabelColor
        buttonLabel.alignment = .right
        buttonLabel.translatesAutoresizingMaskIntoConstraints = false
        buttonLabel.widthAnchor.constraint(equalToConstant: 86).isActive = true

        let actionLabel = NSTextField(labelWithString: action)
        actionLabel.font = .systemFont(ofSize: 13)
        actionLabel.textColor = .labelColor

        let row = NSStackView(views: [buttonLabel, actionLabel])
        row.orientation = .horizontal
        row.spacing = 14
        return row
    }
}
