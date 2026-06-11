# 🎮 agentpad

**Drive your CLI coding agents from the couch — with a game controller.**

agentpad turns an Xbox controller into a macOS input device built for babysitting AI coding sessions: the left stick moves your mouse, face buttons answer permission prompts (they send keystrokes, not flaky clicks on TUI text), and a shoulder button fires voice dictation so you can talk to your agent instead of typing.

Works with **Claude Code, Codex CLI, Gemini CLI** — or any terminal program, really. agentpad only synthesizes mouse and keyboard events; it doesn't care what's running.

## Why?

AI coding agents spend a lot of time working while you wait, then suddenly need a quick "yes / no / pick an option" from you. That doesn't need a desk posture. Lean back, watch the session run, hit **A** to approve, **B** to cancel, and the right bumper to dictate your next prompt. Gamified pair programming.

## Requirements

- macOS 13+
- An Xbox controller paired via Bluetooth (Xbox One S revision or newer, incl. Series X|S). PlayStation DualShock 4 / DualSense controllers should work too — Apple's GameController framework handles both — but only Xbox is tested.

## Install

One line, no developer tools needed:

```bash
curl -fsSL https://raw.githubusercontent.com/pameziane-hub/agentpad/main/install.sh | bash
```

This downloads the latest release into `/Applications`, clears the Gatekeeper
quarantine (the build is signed but not notarized), and launches the app.
A 🎮 icon appears in your menu bar; on first launch macOS asks you to grant
the **Accessibility** permission — see below, the app cannot move your mouse
without it. Then pair your controller via Bluetooth and you're set.

<details>
<summary><b>Build from source instead</b> (needs the Swift toolchain — Xcode or the Command Line Tools)</summary>

```bash
git clone https://github.com/pameziane-hub/agentpad.git
cd agentpad
./scripts/make-app.sh        # builds dist/agentpad.app
open dist/agentpad.app       # or copy it to /Applications first
```

> **Don't run the bare `.build/release/agentpad` binary directly:** it lives and dies with your terminal window, and macOS attributes its permissions to the terminal instead of the app. The `.app` bundle is the supported way.

</details>

## Granting the Accessibility permission

macOS requires explicit permission before any app may control mouse and keyboard:

1. On first launch you'll get a system prompt → **Open System Settings** (the dropdown also has a "Grant Accessibility Permission…" shortcut), or go to **System Settings → Privacy & Security → Accessibility** manually.
2. Add (or enable) `agentpad` and toggle it **on**.
3. That's it — agentpad notices the grant within a couple of seconds, no relaunch needed. The menu bar icon switches from ⚠️ to 🎮.

**Gotchas:**

- The permission sticks to the app's identity. After **rebuilding**, macOS may treat it as a new app — remove and re-add it in the Accessibility list.
- If buttons stay silent although the cursor moves, check **System Settings → Privacy & Security → Input Monitoring** as well.

## Default mapping

| Controller | Action |
|---|---|
| Left stick | Move mouse (deadzone + expo curve) |
| Right stick | Scroll |
| **A** | Left click — hold + stick = drag & drop *(A is "select" on Xbox, it should click)* |
| **B** | Escape — *cancel* |
| **X** | Tab |
| **Y** | Shift+Tab — *cycles Claude Code's permission modes* |
| **RT** (right trigger) | Return — *fire off the prompt* |
| **LT** (left trigger) | Tap = right click · **hold = shortcut layer** (see below) |
| D-Pad | Arrow keys — *navigate prompt options; held keys auto-repeat* |
| **RB** (right bumper) | 🎙 Dictation (configurable, see below) |
| **LB** (left bumper) | Cmd+` — cycle windows of the frontmost app |
| **L3 / R3** (stick click) | Cmd+C / Cmd+V — copy & paste |
| Menu (☰) | Open the agentpad menu — *navigate it with the D-Pad; Pause sits inside* |
| **View** (⧉, small left button) | Toggle the on-screen mapping overlay (reserved, not remappable) |

## The shortcut layer (hold LT)

A Steam-Input-style hold layer puts the essential desktop shortcuts on the pad:

- **Tap LT** (short): right click, as always.
- **Hold LT** (~0.3 s): a slot menu pops up top-center. Press slots while
  holding — or release and pick at your own pace, the menu stays open.
  **HUD visible = slots active.**

| Slot | Does |
|---|---|
| LT + **A** | Last App (Cmd+Tab) |
| LT + **B** | Delete ⌫ — *the eraser for dictation typos* |
| LT + **X** | Undo (Cmd+Z) |
| LT + **Y** | Interrupt (Ctrl+C) — *stop a runaway terminal process* |
| LT + **D-Pad ↑** | Select All (Cmd+A) |
| LT + **D-Pad ←/→** | Switch macOS Spaces |

Picks keep the menu open so you can chain them; tap LT again (or press any
non-slot button) to close it, or let the 6-second timeout fold it away.
Held keys repeat at your macOS keyboard rate — except Cmd/Ctrl/Opt shortcuts,
which deliberately fire once per press (no accidental Cmd+Z machine gun).

## Rebinding without editing JSON

Click any mapping row in the menu bar dropdown, then press the button that should own that action — done. The two buttons **swap** their actions (nothing gets lost), the change is saved to your config immediately, and a translucent overlay guides you through it. Press **View** to cancel, or wait out the 6-second timeout.

The same overlay doubles as a cheat sheet: tap **View** anytime to see the full current mapping mid-session — it's click-through and never steals focus.

## Western mode 🔫

Optional sound effects, off by default: firing a prompt with Return plays a shot, left click plays a reload. The **Sound FX** submenu in the dropdown toggles them, has a volume slider, and offers flavors per event — synthesized ones (shot: Revolver / Laser / 8-Bit / Silenced, reload: Clack / Pop / Thock / Tick) plus the built-in macOS alert sounds (Tink, Glass, Morse, Purr, Hero, Submarine — mastered audio, nothing bundled). **Walking the list plays each flavor** (arrow keys or hover, like the macOS font menu); clicking commits. Drop your own `shot.wav` / `reload.wav` into `~/.config/agentpad/` and a "Custom" entry appears.

## Configuration

On first run agentpad writes its defaults to `~/.config/agentpad/mapping.json` ("Open Config" in the menu bar gets you there). Pointer feel:

```json
"pointer": { "deadzone": 0.12, "expo": 0.6, "maxSpeed": 1400 }
```

Higher `expo` = finer control near the center. `maxSpeed` is in points per second.

Every button takes one of these actions:

```json
{ "type": "key",  "value": "shift+tab" }     // combo: cmd, shift, ctrl, opt + key
{ "type": "key",  "value": "ctrl ctrl" }     // space-separated = sequence (double-tap)
{ "type": "url",  "value": "superwhisper://record" }
{ "type": "leftClick" } | { "type": "rightClick" } | { "type": "pause" } | { "type": "statusMenu" }
{ "type": "layer", "tap": { "type": "rightClick" },   // hold-layer: tap action +
  "overlay": { "a": { "type": "key", "value": "cmd+tab" } } }  // per-button slots
```

### Dictation recipes

The right bumper defaults to double-tapping **Control** — the stock macOS dictation shortcut, so it works on every Mac with nothing installed:

```json
"rightShoulder": { "type": "key", "value": "ctrl ctrl" }
```

**[Superwhisper](https://superwhisper.com)** (what this project was built for) has a deep link:

```json
"rightShoulder": { "type": "url", "value": "superwhisper://record" }
```

**Open-source alternatives** (e.g. [VoiceInk](https://github.com/Beingpax/VoiceInk), local whisper.cpp): set a global shortcut in the app, then map it:

```json
"rightShoulder": { "type": "key", "value": "cmd+shift+space" }
```

> Synthetic modifier double-taps don't reach every low-level listener on all macOS versions. If `ctrl ctrl` doesn't trigger dictation on your machine, give your dictation app a regular shortcut and map that instead.

## Notes

- **Non-US keyboard layouts:** key codes are position-based. `cmd+\`` lands on the key next to left Shift on ISO (e.g. German) keyboards — usually still the window-cycling shortcut, but adjust your config if not.
- **Gatekeeper:** prebuilt releases are signed but not notarized. `install.sh` clears the quarantine flag for you; if you download the zip manually and macOS warns, right-click the app → **Open** once.

## License

[MIT](LICENSE)
