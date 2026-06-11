# LT Hold-Layer: Slots, HUD & Key Auto-Repeat — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the already-built `LayerRouter` into the Engine, add keyboard-style auto-repeat, a hold-HUD hint panel, and the 6-slot default overlay; ship as v0.3.0.

**Architecture:** All timing-free logic lives in `AgentpadCore` (unit-tested): `LayerRouter` (done), new `KeyRepeater` (pure, time passed in), `MappingSummary.overlayRows` for HUD content. The app shell (`Engine`, `MapOverlayController`) executes router events, drives the repeater from the 120 Hz tick, and shows/hides the HUD panel.

**Tech Stack:** Swift SPM (no Xcode project), XCTest, AppKit/CGEvent app shell. Build: `./scripts/make-app.sh`. Spec: `docs/superpowers/specs/2026-06-11-layer-hud-repeat-design.md`.

**Already done (commits `f8f9be1`, `342e9f3`):** `ButtonAction.layer` + Codable, `LayerRouter` (12 tests), `MappingSummary` layer rows, default LT = 2-slot layer. 58 tests green.

---

### Task 1: KeyRepeater (core, TDD)

**Files:**
- Create: `Tests/AgentpadCoreTests/KeyRepeaterTests.swift`
- Create: `Sources/AgentpadCore/KeyRepeater.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
@testable import AgentpadCore

final class KeyRepeaterTests: XCTestCase {
    private let combo = KeyCombo(keyCode: 51, flags: [])      // delete
    private let other = KeyCombo(keyCode: 126, flags: [])     // up
    private var repeater = KeyRepeater(initialDelay: 0.5, interval: 0.1)

    func testNoFireBeforeInitialDelay() {
        repeater.keyDown(id: "b", combo: combo, at: 10.0)
        XCTAssertNil(repeater.nextFire(at: 10.4))
    }

    func testFiresAfterDelayThenAtInterval() {
        repeater.keyDown(id: "b", combo: combo, at: 10.0)
        XCTAssertEqual(repeater.nextFire(at: 10.5), combo)
        XCTAssertNil(repeater.nextFire(at: 10.55))
        XCTAssertEqual(repeater.nextFire(at: 10.6), combo)
    }

    func testReleaseStopsRepeat() {
        repeater.keyDown(id: "b", combo: combo, at: 10.0)
        repeater.keyUp(id: "b")
        XCTAssertNil(repeater.nextFire(at: 11.0))
    }

    func testReleaseOfDifferentButtonKeepsRepeat() {
        repeater.keyDown(id: "b", combo: combo, at: 10.0)
        repeater.keyUp(id: "a")
        XCTAssertEqual(repeater.nextFire(at: 10.5), combo)
    }

    func testNewKeyReplacesRepeatLikeAKeyboard() {
        repeater.keyDown(id: "b", combo: combo, at: 10.0)
        repeater.keyDown(id: "dpadUp", combo: other, at: 10.3)
        // the old key no longer fires; the new key fires on its own clock
        XCTAssertNil(repeater.nextFire(at: 10.5))
        XCTAssertEqual(repeater.nextFire(at: 10.8), other)
    }

    func testResetStopsRepeat() {
        repeater.keyDown(id: "b", combo: combo, at: 10.0)
        repeater.reset()
        XCTAssertNil(repeater.nextFire(at: 11.0))
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test 2>&1 | grep error | head -3`
Expected: `cannot find 'KeyRepeater' in scope`

- [ ] **Step 3: Implement**

```swift
import Foundation

/// Keyboard-style auto-repeat for held buttons mapped to a single key combo.
/// Pure logic: the engine tick passes time in and posts whatever comes back,
/// so timing is unit-testable. Like a real keyboard, only the most recently
/// pressed key repeats; a new press replaces the old repeat.
public struct KeyRepeater {
    private let initialDelay: TimeInterval
    private let interval: TimeInterval
    private var heldId: String?
    private var combo: KeyCombo?
    private var nextFireTime: TimeInterval = 0

    public init(initialDelay: TimeInterval, interval: TimeInterval) {
        self.initialDelay = initialDelay
        self.interval = interval
    }

    public mutating func keyDown(id: String, combo: KeyCombo, at time: TimeInterval) {
        heldId = id
        self.combo = combo
        nextFireTime = time + initialDelay
    }

    public mutating func keyUp(id: String) {
        guard id == heldId else { return }
        reset()
    }

    public mutating func reset() {
        heldId = nil
        combo = nil
    }

    /// At most one fire per call; the 120 Hz tick outpaces any repeat rate.
    /// Advancing from the scheduled time (not `time`) keeps the cadence even.
    public mutating func nextFire(at time: TimeInterval) -> KeyCombo? {
        guard let combo, time >= nextFireTime else { return nil }
        nextFireTime += interval
        return combo
    }
}
```

- [ ] **Step 4: Run tests** — `swift test 2>&1 | grep Executed | tail -1` — Expected: 64 tests, 0 failures
- [ ] **Step 5: Commit** — `git add Sources/AgentpadCore/KeyRepeater.swift Tests/AgentpadCoreTests/KeyRepeaterTests.swift && git commit -m "Add KeyRepeater: keyboard-style auto-repeat as pure core logic"`

---

### Task 2: Expose held layer + HUD rows (core, TDD)

**Files:**
- Modify: `Sources/AgentpadCore/LayerRouter.swift` (held-layer visibility)
- Modify: `Sources/AgentpadCore/MappingSummary.swift` (HUD rows)
- Test: extend `Tests/AgentpadCoreTests/LayerRouterTests.swift`, `Tests/AgentpadCoreTests/MappingSummaryTests.swift`

- [ ] **Step 1: Failing tests**

In `LayerRouterTests`:
```swift
    func testExposesHeldLayerId() {
        XCTAssertNil(router.heldLayer)
        _ = router.handle(id: "leftTrigger", pressed: true, buttons: buttons)
        XCTAssertEqual(router.heldLayer, "leftTrigger")
        _ = router.handle(id: "leftTrigger", pressed: false, buttons: buttons)
        XCTAssertNil(router.heldLayer)
    }
```

In `MappingSummaryTests`:
```swift
    func testOverlayRowsUseShortLabelsForTheHud() {
        let rows = MappingSummary.overlayRows(forLayer: "leftTrigger", config: .default)
        XCTAssertEqual(rows.first?.button, "A")
        XCTAssertEqual(rows.first?.action, "Cmd+Tab")
        XCTAssertTrue(rows.contains(where: { $0.button == "D-Pad ←" && $0.action == "Ctrl+Left" }))
    }

    func testOverlayRowsEmptyForNonLayerButton() {
        XCTAssertTrue(MappingSummary.overlayRows(forLayer: "a", config: .default).isEmpty)
    }
```
(`testOverlayRowsUseShortLabelsForTheHud` lands together with Task 3's 6-slot default; order Tasks 3 before 2 if preferred — they only touch tests/core and are committed together otherwise. Simplest: do Task 3 first. The plan numbers them for readability.)

- [ ] **Step 2: Verify failure** — `swift test` → `heldLayer`/`overlayRows` not found
- [ ] **Step 3: Implement**

`LayerRouter`: rename the private var and expose read-only:
```swift
    /// Id of the layer button currently held, for the HUD.
    public private(set) var heldLayer: String?
```
(All internal uses follow the rename: `heldLayerId` → `heldLayer`.)

`MappingSummary`:
```swift
    /// Short-label rows for the hold-HUD: just the overlay of one layer
    /// button, e.g. ("A", "Cmd+Tab"), in display order.
    public static func overlayRows(forLayer id: String, config: Config)
        -> [(button: String, action: String)] {
        guard case .layer(_, let overlay)? = config.buttons[id] else { return [] }
        return displayOrder.compactMap { entry in
            guard let action = overlay[entry.id] else { return nil }
            return (button: entry.label, action: describe(action))
        }
    }
```

- [ ] **Step 4: Tests green** — `swift test` → 67 tests, 0 failures
- [ ] **Step 5: Commit** — `git commit -m "Expose held layer and short-label HUD rows from the core"`

---

### Task 3: 6-slot default overlay (core, TDD)

**Files:**
- Modify: `Sources/AgentpadCore/Config.swift:~141` (default LT overlay)
- Test: `Tests/AgentpadCoreTests/ConfigTests.swift` (`testDefaultLeftTriggerIsRightClickLayer`), `Tests/AgentpadCoreTests/MappingSummaryTests.swift` (`testRowsAreOrderedAndComplete`)

- [ ] **Step 1: Update the two tests to expect 6 slots (failing first)**

```swift
    func testDefaultLeftTriggerIsRightClickLayer() {
        XCTAssertEqual(Config.default.buttons["leftTrigger"],
                       .layer(tap: .rightClick, overlay: [
                           "a": .key("cmd+tab"),
                           "b": .key("delete"),
                           "x": .key("cmd+z"),
                           "y": .key("ctrl+c"),
                           "dpadLeft": .key("ctrl+left"),
                           "dpadRight": .key("ctrl+right"),
                       ]))
    }
```

`testRowsAreOrderedAndComplete` expected buttons become:
```swift
        XCTAssertEqual(rows.map(\.button), [
            "A", "B", "X", "Y",
            "D-Pad ↑", "D-Pad ↓", "D-Pad ←", "D-Pad →",
            "LT", "LT + A", "LT + B", "LT + X", "LT + Y",
            "LT + D-Pad ←", "LT + D-Pad →",
            "RT", "LB", "RB", "L3", "R3", "Menu",
        ])
```

- [ ] **Step 2: Verify failure** — `swift test` → both tests fail on the missing slots
- [ ] **Step 3: Extend the default**

```swift
            // tap = right click; held, it layers shortcuts onto the face
            // buttons and Space switching onto the D-Pad, so plain arrows
            // stay available for menu navigation
            "leftTrigger": .layer(tap: .rightClick, overlay: [
                "a": .key("cmd+tab"),
                "b": .key("delete"),
                "x": .key("cmd+z"),
                "y": .key("ctrl+c"),
                "dpadLeft": .key("ctrl+left"),
                "dpadRight": .key("ctrl+right"),
            ]),
```

- [ ] **Step 4: Tests green**, **Step 5: Commit** — `git commit -m "Default layer ships four shortcut slots: last app, delete, undo, interrupt"`

---

### Task 4: Engine wiring (app shell — no unit tests possible)

**Files:**
- Modify: `Sources/agentpad/Engine.swift` (route through LayerRouter, drive KeyRepeater, layer callback)

- [ ] **Step 1: Add state + callback fields**

```swift
    private var router = LayerRouter()
    private var repeater = KeyRepeater(
        initialDelay: NSEvent.keyRepeatDelay,
        interval: NSEvent.keyRepeatInterval)
    /// HUD hook: fires with the layer button id on hold, nil on release.
    var onLayerHold: ((String?) -> Void)?
```

- [ ] **Step 2: Replace `handleButton` and split out `perform`**

```swift
    private func handleButton(id: String, pressed: Bool) {
        // View is the UI button: overlay toggle / capture cancel, never mapped
        if id == "view" {
            if pressed { onViewButton?() }
            return
        }
        // an active remap capture eats the event
        if let capture = captureHandler, capture(id, pressed) { return }

        // pause must always work, even while paused
        if case .pause = store.config.buttons[id] {
            if pressed { togglePause() }
            return
        }
        guard state == .active else { return }

        let heldBefore = router.heldLayer
        let event = router.handle(id: id, pressed: pressed, buttons: store.config.buttons)
        if router.heldLayer != heldBefore { onLayerHold?(router.heldLayer) }

        switch event {
        case .nothing:
            break
        case .action(let action, let isDown):
            feedRepeater(id: id, action: action, pressed: isDown)
            perform(action, pressed: isDown)
        case .tap(let action):
            perform(action, pressed: true)
            perform(action, pressed: false)
        }
    }

    /// Single key combos repeat while held, like a real keyboard key.
    /// Sequences, modifier-only taps, clicks and URLs don't repeat.
    private func feedRepeater(id: String, action: ButtonAction, pressed: Bool) {
        guard case .key(let raw) = action else { return }
        if pressed {
            guard let sequence = KeyComboParser.parseSequence(raw),
                  sequence.count == 1, let combo = sequence.first,
                  !KeyComboParser.isModifierOnly(combo) else { return }
            repeater.keyDown(id: id, combo: combo, at: Date.timeIntervalSinceReferenceDate)
        } else {
            repeater.keyUp(id: id)
        }
    }

    private func perform(_ action: ButtonAction, pressed: Bool) {
        switch action {
        case .leftClick:
            if pressed, store.config.fx.sounds {
                soundFX.playReload(variant: store.config.fx.reloadVariant)
            }
            pressed ? output.leftDown() : output.leftUp()
        case .rightClick:
            pressed ? output.rightDown() : output.rightUp()
        case .key(let raw):
            guard pressed, let sequence = KeyComboParser.parseSequence(raw) else { return }
            // western mode: Return fires the configured shot sound
            if store.config.fx.sounds, sequence.contains(where: { $0.keyCode == 36 }) {
                soundFX.playShot(variant: store.config.fx.shotVariant)
            }
            output.post(sequence: sequence)
        case .url(let urlString):
            guard pressed else { return }
            output.open(urlString: urlString)
        case .pause, .layer:
            break
        }
    }
```

- [ ] **Step 3: Drive repeats from the tick** (inside `tick()`, after the scroll block)

```swift
        if let combo = repeater.nextFire(at: now) {
            // repeats skip the FX hook on purpose: one shot per press
            output.post(combo)
        }
```

- [ ] **Step 4: Reset on every non-active state** (in `refreshState`, before logging)

```swift
        if state != .active {
            router.reset()
            repeater.reset()
            onLayerHold?(nil)
        }
```

- [ ] **Step 5: Build + full tests** — `swift build && swift test` → compiles, 67 tests green
- [ ] **Step 6: Commit** — `git commit -m "Wire the layer router and key auto-repeat into the engine"`

---

### Task 5: Hold-HUD panel (app shell)

**Files:**
- Modify: `Sources/agentpad/MapOverlayController.swift` (second panel + show/hide API)
- Modify: `Sources/agentpad/AppDelegate.swift` or `Sources/agentpad/MenuBarController.swift` — wherever Engine and MapOverlayController are wired (check at execution; expected AppDelegate)

- [ ] **Step 1: Add the HUD panel to MapOverlayController**

A second, independent panel handle so the cheat-sheet logic stays untouched:

```swift
    private var hudPanel: NSPanel?

    /// Compact hold-HUD: one pill-shaped line near the bottom of the screen
    /// listing a layer's slots. Suppressed while the full map is open.
    func showLayerHud(forLayer id: String) {
        hideLayerHud()
        guard !isShowingMap else { return }
        let rows = MappingSummary.overlayRows(forLayer: id, config: store.config)
        guard !rows.isEmpty else { return }
        let text = rows.map { "\($0.button)  \($0.action)" }.joined(separator: "   ·   ")
        let label = NSTextField(labelWithString: text)
        label.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        label.sizeToFit()
        let padding: CGFloat = 18
        let container = NSView(frame: NSRect(x: 0, y: 0,
            width: label.frame.width + padding * 2,
            height: label.frame.height + padding))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.78).cgColor
        container.layer?.cornerRadius = (label.frame.height + padding) / 2
        label.setFrameOrigin(NSPoint(x: padding, y: padding / 2))
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
            let frame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: frame.midX - container.frame.width / 2,
                                         y: frame.minY + 96))
        }
        panel.orderFrontRegardless()
        hudPanel = panel
    }

    func hideLayerHud() {
        hudPanel?.orderOut(nil)
        hudPanel = nil
    }
```

- [ ] **Step 2: Wire the 300 ms hold timer** where Engine is constructed (AppDelegate expected):

```swift
        var hudTimer: Timer?
        engine.onLayerHold = { [weak overlay] layerId in
            hudTimer?.invalidate()
            hudTimer = nil
            guard let layerId else {
                overlay?.hideLayerHud()
                return
            }
            hudTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                overlay?.showLayerHud(forLayer: layerId)
            }
        }
```
(Adapt to the actual wiring-site idiom — if closures capture differently there, follow the file's existing style. `overlay` = the MapOverlayController instance.)

- [ ] **Step 3: Build + tests** — `swift build && swift test` → green
- [ ] **Step 4: Commit** — `git commit -m "Hold-HUD: holding the layer pops a slot cheat-line after 300 ms"`

---

### Task 6: Migrate Paul's config, build, install, field test

**Files:**
- Modify: `~/.config/agentpad/mapping.json` (outside repo)

- [ ] **Step 1: Quit the running app first** (it persists config on changes — edit after quit):
`osascript -e 'quit app "agentpad"' 2>/dev/null; sleep 1; pgrep -x agentpad || echo "quit ok"`
- [ ] **Step 2: Edit `~/.config/agentpad/mapping.json`**: `dpadLeft` → `{"type":"key","value":"left"}`, `dpadRight` → `{"type":"key","value":"right"}`, `leftTrigger` → the 6-slot layer JSON (same as default). Keep `fx` (sounds=false, shotVariant=custom, reloadVariant=clack) and pointer/scroll untouched.
- [ ] **Step 3: Build + install**: `./scripts/make-app.sh && ditto dist/agentpad.app /Applications/agentpad.app && open /Applications/agentpad.app`
- [ ] **Step 4: Field test (Paul, with log stream running)**:
`/usr/bin/log stream --level debug --predicate 'subsystem == "com.paulameziane.agentpad"'`
  - D-Pad ←/→ alone = plain arrows (menu navigation works again)
  - LT tap = right click (context menu, on release)
  - LT held + D-Pad ←/→ = Space switch; release fires NO right click
  - LT held ≥300 ms = HUD line appears, vanishes on release
  - LT+A = last app · LT+B = delete · LT+X = undo · LT+Y = interrupt
  - Hold ⌫/arrows = auto-repeat at macOS tempo; new key press replaces repeat
  - Menu button pause + controller off/on: nothing sticks (no ghost layer/repeat)

---

### Task 7: Docs + v0.3.0 release

**Files:**
- Modify: `VERSION` (`0.3.0`), `CHANGELOG.md`, `README.md` (mapping table + feature bullet), `CLAUDE.md` (gotcha: layer tap fires on release; slots are JSON-only)

- [ ] **Step 1:** Update the four files; CHANGELOG entry lists: hold-layer, 4 shortcut slots, Space switch moved to LT+D-Pad, hold-HUD, key auto-repeat
- [ ] **Step 2:** `swift test` one last time → green; commit `git commit -m "Release v0.3.0: hold-layer shortcuts, HUD hint, key auto-repeat"`
- [ ] **Step 3:** Tag + push: `git tag v0.3.0 && git push origin main --tags`
- [ ] **Step 4:** Release: `ditto -c -k --keepParent dist/agentpad.app /tmp/agentpad-0.3.0.zip && gh release create v0.3.0 /tmp/agentpad-0.3.0.zip --title "v0.3.0 — hold-layer shortcuts" --notes-file <(sed -n '/^## 0.3.0/,/^## /p' CHANGELOG.md)` (include the Gatekeeper note as in v0.2.0)

---

**Execution order note:** Task 3 (6-slot default) before Task 2's `testOverlayRowsUseShortLabelsForTheHud`, or run them together — that test asserts against the 6-slot default. Tasks 4–5 depend on 1–3. Task 6 depends on 4–5.
