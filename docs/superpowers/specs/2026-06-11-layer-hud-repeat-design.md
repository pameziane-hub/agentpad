# LT hold-layer: shortcut slots, HUD hint, key auto-repeat

**Date:** 2026-06-11 · **Target version:** v0.3.0 · **Status:** approved by Paul

## Problem

All physical buttons are taken, yet two needs keep coming up:

1. macOS Space switching (`ctrl+←/→`) had squatted on the D-Pad, stealing the
   plain arrow keys needed for menu navigation.
2. Essential desktop shortcuts (app switch, delete, undo, terminal interrupt)
   have no home on the pad at all.

Double-tap and long-press triggers were rejected: both fight the arrow keys'
primary job (instant response, key repeat in menus).

## Solution overview

A Steam-Input-style **hold layer** on LT, in four parts:

### 1. Layer mechanics (built, tested — `LayerRouter` in AgentpadCore)

- `ButtonAction.layer(tap:overlay:)` — while the layer button is held,
  buttons listed in `overlay` swap to their overlay actions.
- Press + release with no overlay use fires the `tap` action, so LT keeps
  right-click. The click fires on release; right-click-drag is knowingly
  sacrificed.
- Buttons not in the overlay act normally during a hold and do not consume
  the tap. A press/release pair never splits across two actions.
- `reset()` clears held state on pause and controller disconnect.

### 2. Default slot assignment

| Input | Action | Rationale |
|-------|--------|-----------|
| LT tap | right click | unchanged primary |
| LT + D-Pad ←/→ | `ctrl+left` / `ctrl+right` | Space switching |
| LT + A | `cmd+tab` | jump to last app — unreachable from a pad otherwise |
| LT + B | `delete` (⌫) | the eraser for the dictation workflow; B escalates Esc |
| LT + X | `cmd+z` | undo |
| LT + Y | `ctrl+c` | terminal interrupt — deliberate reach, top button |

D-Pad ←/→ return to plain `left`/`right` in the base mapping. LT + D-Pad
↑/↓ stay free. This becomes `Config.default` and Paul's `mapping.json`.

### 3. Layer HUD

- Holding LT for ~300 ms pops a compact translucent panel (bottom-center)
  listing the overlay slots, rendered from `MappingSummary` rows.
- Releasing LT hides it. The delay keeps quick taps/Space flicks flicker-free.
- Implemented as a third mode of the existing `MapOverlayController` panel
  mechanics (non-activating, click-through, joins all Spaces). The Engine
  exposes a layer-active callback; the 300 ms timer lives in the app layer.
- The HUD is a memory aid only — slot presses work immediately, no waiting.

### 4. Key auto-repeat

- A held button whose action is a **single key combo** re-fires like a real
  keyboard key: initial delay then steady repeat, using the user's macOS
  settings (`NSEvent.keyRepeatDelay` / `.keyRepeatInterval`).
- Matches keyboard semantics: only the most recently pressed key repeats;
  pressing another key replaces the repeat; release stops it.
- Sequences (`ctrl ctrl`) and modifier-only taps do not repeat. URL, click,
  pause, and layer actions do not repeat.
- Applies everywhere: D-Pad arrows, Delete in the layer, Return on RT.
- Logic lives in AgentpadCore as a pure `KeyRepeater` (time passed in,
  fully unit-testable); the 120 Hz engine tick drives it and posts fires.
- Pause and disconnect reset the repeater.

## Engine wiring

`Engine.handleButton` routes every event through `LayerRouter` (after the
View-button and remap-capture short-circuits, and the always-on pause check).
The returned event drives a `perform(action,pressed)` executor; `.tap`
performs press + release back-to-back. Sound FX hooks stay in the executor.
Pause toggling and disconnect call `router.reset()` and `repeater.reset()`.

## Testing

- AgentpadCore: `LayerRouterTests` (12 tests, green), `KeyRepeaterTests`
  (new), config decode/encode + default-mapping tests (green, extended for
  the 6-slot overlay), `MappingSummary` layer rows (green).
- App layer (Engine/HUD): not unit-testable — verify via os_log streaming
  and Paul's field test (checklist in the plan).

## Non-goals

- No radial weapon-wheel selection (v2 candidate).
- No held app-switcher (Cmd held across multiple Tab presses).
- No remap UI for layer slots — JSON config only.
- No second layer button and no layer stacking.

## Versioning

Ships as **v0.3.0** (feature MINOR): layer system + slots + HUD + repeat.
CHANGELOG entry, git tag, GitHub release with zipped binary.
