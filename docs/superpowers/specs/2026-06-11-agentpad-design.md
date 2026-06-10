# agentpad — Game Controller Control for CLI Coding Agents

**Date:** 2026-06-11 · **Status:** Approved by Paul · **Working title:** `agentpad` (final name TBD before public release)

## Purpose

Control CLI coding-agent sessions (Claude Code, Codex CLI, Gemini CLI, any TUI) on macOS with an Xbox controller: move the mouse with the stick, answer permission prompts with buttons, trigger voice dictation with a bumper. Gamified, couch-friendly session babysitting. Ships as a public GitHub repo.

## Decisions Made (with Paul)

1. **Hybrid input model:** stick drives the mouse cursor; buttons send *keystrokes* (terminal prompts are keyboard-driven, mouse clicks on TUI options are unreliable).
2. **Stack:** native Swift. Apple's GameController framework reads Xbox controllers over Bluetooth out of the box; CGEvent (Quartz) synthesizes mouse/keyboard events. Result: one dependency-free binary.
3. **Form:** menubar app (no Dock icon). Status icon shows connected / disconnected / paused.
4. **Dictation is pluggable, not hardcoded.** The mic button fires a *configurable action* — either a URL (deep link) or a key sequence. Default: macOS built-in dictation shortcut (works on every Mac). README documents drop-in configs for Superwhisper (`superwhisper://record`, verified against official docs 2026-06-11) and an open-source alternative (e.g. VoiceInk — verify exact trigger during README writing).
5. **Agent-agnostic positioning:** the tool only sends mouse/key events; it works with any CLI agent. README markets it as "gamepad control for CLI coding agents", not Claude-Code-only.

## Architecture

Swift Package Manager executable target (AppKit, `NSApplication` with `.accessory` activation policy — no Xcode project required). Three modules:

| Module | Responsibility | Key APIs |
|---|---|---|
| `ControllerService` | Discover Xbox controller, observe connect/disconnect, expose button/stick state | `GCController`, `extendedGamepad`, value-changed handlers |
| `OutputService` | Move/click/drag mouse, scroll, post key events | `CGEvent` posting; ~120 Hz timer loop for stick→cursor with deadzone + expo acceleration curve |
| `ActionMap` | Map controller inputs to actions; load/merge user config | Codable config at `~/.config/agentpad/mapping.json`, baked-in defaults written on first run |

Plus a thin `MenuBarController` (NSStatusItem: status icon, Pause toggle, controller name, "Open config", Quit).

## Default Mapping

| Input | Action |
|---|---|
| Left stick | Move mouse (deadzone ~0.12, expo curve, max speed configurable) |
| Right stick | Scroll |
| RT (right trigger) | Left click (hold = drag: mouseDown on press, dragged events while moving, mouseUp on release) |
| LT | Right click |
| A | Return (accept prompt) |
| B | Escape (cancel) |
| D-Pad | Arrow keys (navigate options) |
| Y | Shift+Tab (Claude Code permission-mode cycle) |
| X | Tab |
| RB | 🎙 Dictation action (configurable: URL or key sequence; default macOS dictation, Paul's config: `superwhisper://record`) |
| LB | Cmd+` (cycle windows of frontmost app) |
| Menu button | Pause/resume all mapping |

## Error Handling & Permissions

- **Accessibility permission** is required for CGEvent posting. On launch: `AXIsProcessTrustedWithOptions` with prompt; menubar icon signals "no permission" state. Prominent README section (incl. the gotcha that rebuilding the binary can require re-granting, and that launching from Terminal may attribute the permission to Terminal).
- **Controller disconnect:** icon goes gray; reconnect handled automatically via `GCController` notifications. No crash, no stale event loop.
- **Config errors:** malformed JSON → log warning, fall back to defaults (never crash on user config).

## Testing

- Unit tests (XCTest via SPM): deadzone/expo curve math, config decode + default-merge, key-sequence parsing.
- Manual verification with Paul's Xbox Series X|S controller over Bluetooth: cursor feel, prompt answering in a live Claude Code session, dictation trigger, pause toggle, disconnect/reconnect.
- Open question to verify on hardware: whether `superwhisper://record` also *stops* a recording (toggle). Fallback: simulate Superwhisper's keyboard shortcut instead.

## Repo / Release (v1)

- Public GitHub repo (push happens after Paul tested locally and picked the final name).
- English README: demo GIF, install (build from source via `swift build`), Accessibility setup walkthrough, mapping table, dictation config recipes, "works with any CLI agent" positioning.
- MIT license.
- Note in README: release binaries are unsigned → Gatekeeper warning on first launch.

## Not in v1 (YAGNI)

No context-aware prompt detection, no rumble feedback, no settings UI (config is JSON), no launch-at-login, no Windows/Linux.
