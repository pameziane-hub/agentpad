# Changelog

All notable changes to agentpad. Format follows [Keep a Changelog](https://keepachangelog.com), versioning follows [SemVer](https://semver.org).

## [Unreleased]

### Fixed
- Picking a sound flavor no longer slams the menu shut: the sound menu re-opens in place with the checkmark visibly set on your pick, so you can keep trying flavors and click elsewhere when happy. (AppKit closes menus on click unconditionally; the re-open is the workaround.)

## [0.3.0] — 2026-06-11

### Added
- **Shortcut layer on LT:** tap = right click as before; holding opens a slot menu — A = Last App, B = Delete, X = Undo, Y = Interrupt, D-Pad ↑ = Select All, D-Pad ←/→ = switch Spaces. The D-Pad's plain arrows are back for menu navigation.
- **Sticky slot menu with HUD:** the menu survives releasing LT and stays open across picks (each pick restarts the 6 s timeout); a translucent cheat-line top-center shows the slots in plain words. HUD visible = slots active. Tap LT to close.
- **Keyboard-style auto-repeat:** held buttons mapped to a single key repeat at your macOS keyboard rate. Cmd/Ctrl/Opt shortcuts deliberately fire once per press.
- **System sound flavors:** the built-in macOS alert sounds (Tink, Glass, Morse, Purr, Hero, Submarine) join the synthesized ones for both events — mastered audio, nothing bundled.
- **Volume slider** in the Sound FX menu; all FX respect it (default 50 %).
- **Audition on highlight:** walking the sound lists (arrows or hover) plays each flavor before you commit, macOS-font-menu style. Enabling sounds plays an audible proof.
- **Start opens the menu:** the Menu (☰) button now opens the status-bar dropdown (console convention), so everything is configurable from the pad. Pause moved inside the menu; the `pause` action remains mappable.
- **Quick install:** `curl -fsSL https://raw.githubusercontent.com/pameziane-hub/agentpad/main/install.sh | bash` — downloads the latest release, clears quarantine, installs to /Applications.

### Fixed
- Overshooting a secondary display's edge no longer teleports the cursor to the main screen — it clamps to the nearest display edge (menu bars on a MacBook panel are reachable again).
- The sound menu is navigable with arrow keys / the D-Pad again.
- Left clicks log click count, position and frontmost app at debug level to chase reliability reports.

## [0.2.0] — 2026-06-11

### Added
- **In-app rebinding:** click a mapping row in the dropdown, press the new button — actions swap and persist.
- **Mapping overlay:** the View button toggles a translucent, click-through cheat sheet; doubles as the rebind prompt.
- **Sound FX with variants:** four shot flavors (Revolver/Laser/8-Bit/Silenced) and four reload flavors (Clack/Pop/Thock/Tick), instant preview from the menu, custom `shot.wav`/`reload.wav` slot.
- **Multi-click support:** synthetic clicks carry click counts — double-click selects a word, triple-click a line, double-click-drag extends word-wise.
- **Stick-click copy/paste** (L3 = Cmd+C, R3 = Cmd+V) and letter key codes for arbitrary shortcuts.
- Menu bar dropdown with status header (controller name, battery, state) and live mapping.
- App version shown in the dropdown header.

### Fixed
- Controller input now reaches the app while it's in the background (`GCController.shouldMonitorBackgroundEvents`).
- Stable code-signing identity so the Accessibility grant survives rebuilds.
- Dictation deep links open without activating the handler app — auto-paste lands in your session instead of the void.
- Arrow-key events carry hardware-accurate flags so system shortcuts (Mission Control space switching) fire.
- Click-vs-drag threshold: clicking with a slightly deflected stick no longer drag-selects text.

## [0.1.0] — 2026-06-11

Initial build: stick-driven cursor with deadzone + expo curve, scroll on the right stick, buttons mapped to keystrokes/clicks via JSON config, menu bar app with Accessibility handling.
