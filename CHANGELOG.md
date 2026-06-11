# Changelog

All notable changes to agentpad. Format follows [Keep a Changelog](https://keepachangelog.com), versioning follows [SemVer](https://semver.org).

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
