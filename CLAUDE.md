# agentpad — notes for AI agents and contributors

macOS menu bar app (Swift, SPM, no Xcode project) that turns a game controller into a mouse/keyboard driver for CLI coding agents.

## Build & test

```bash
swift test                # 36 unit tests, core logic only
./scripts/make-app.sh     # builds + signs dist/agentpad.app (the only supported way to run)
```

Never run the bare `.build/*/agentpad` binary for real use — it dies with its terminal and confuses macOS permissions. Always go through the `.app` bundle.

## Architecture

- `Sources/AgentpadCore/` — pure, fully unit-tested logic: stick curves, key-combo parsing, Codable config, ConfigStore (swap-semantics rebinding + persistence), mapping display rows. **No AppKit imports here.**
- `Sources/agentpad/` — the app shell: GameController input, CGEvent output, 120 Hz engine tick, menu bar UI, HUD overlay, remap capture, synthesized sound FX. Not unit-testable (needs hardware + permissions); verify via the os_log instrumentation below.

## Debugging on a real machine

```bash
/usr/bin/log stream --level debug --predicate 'subsystem == "com.paulameziane.agentpad"'
```

(Full path matters — `log` collides with a zsh builtin. `log show` does NOT persist the info/debug levels; you must stream live.)

## Hard-won gotchas (do not re-learn these)

- `GCController.shouldMonitorBackgroundEvents = true` is load-bearing: menu bar apps are never frontmost, without it the framework delivers connect notifications but **zero input events**.
- The Accessibility grant sticks to the code-signing identity. `make-app.sh` auto-signs with an "Apple Development" identity when present so grants survive rebuilds; ad-hoc fallback means re-granting after every build.
- URL actions (dictation deep links) must open with `NSWorkspace.OpenConfiguration.activates = false`, otherwise the dictation app steals focus and pastes into the void.
- The View button is reserved for the overlay/remap UI and is intentionally not remappable.
- User config lives at `~/.config/agentpad/mapping.json`; configs are loaded at launch (restart after manual edits). Legacy configs without the `fx` section must keep decoding — see `FxConfigTests`.
- `NSMenuItem.view` breaks arrow-key navigation (and thus D-Pad menu walking). View-based items are for the volume slider ONLY; selectable rows stay native. Sound auditioning runs through `menu(_:willHighlight:)` instead.
- `keepsMenuPresented` is UIKit/iOS-only — AppKit has no equivalent; don't reach for it.
- Layer invariant: HUD visible == slots active (`LayerRouter.hudLayer`). Timing-window designs for the layer failed twice in field tests (users pick 0.6–4 s after release); the menu is state-based on purpose.
- Release flow: the GitHub release asset is always named `agentpad.zip` (no version in the name) — `install.sh` depends on the stable `/releases/latest/download/agentpad.zip` URL.
