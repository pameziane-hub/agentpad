# Magnet cursor: sticky targets for pad-driven pointing

**Date:** 2026-06-11 · **Target:** v0.4.0 · **Status:** approved by Paul (design round, evening session)

## Problem

Pointing at small UI with a stick takes precision a pad doesn't naturally
have — menu bar items were the trigger complaint. Consoles solve this with
aim assist, not with snapping.

## Feel — three rules

1. **The cursor never moves on its own.** No snapping, no drifting; assist
   only ever modifies movement the user is already making.
2. **Targets are sticky, not attractive.** Inside (or within 8 pt of) a
   clickable element, cursor speed is damped to ~45 % — you stop slipping
   past. The target feels bigger than it is ("aim friction").
3. **Full speed = free flight.** Above ~600 pt/s the assist does nothing;
   it engages on approach only.

Phase 2 adds gentle steering (vector bends ≤25 % toward the target center
while moving slowly toward it). Phase 1 ships friction only.

## Probe results (2026-06-11, Paul's machine — drove this design)

- Repeated AX hit-tests: **avg 0.46 ms** → 10 Hz scanning is cheap.
- First contact with a "cold" app: 10–30 ms → scanning runs OFF the 120 Hz
  tick, always async.
- Center-screen hit returned a 4096 px `AXGroup` → **size filter is
  mandatory** (max ~320×120 pt), plus a role whitelist.
- Menu bar hit returns the `AXMenuBar` container → drill into `AXChildren`
  once to find the actual item under the point.
- `kAXErrorCannotComplete` happens routinely → scanner degrades silently
  (no target = no assist).
- Multi-display coordinates go negative on this setup → global CG
  coordinates throughout (same convention as `DisplayClamp`).

## Mechanics

- `MagnetField` (AgentpadCore, pure): `(movement, cursor, targetFrame?,
  strength, speed) → movement`. No target / high speed / strength 0 →
  unchanged. Inside frame (+8 pt margin): factor `1 − 0.55 × strength`
  (strength 0.5 → ×0.725, strength 1 → ×0.45).
- `TargetScanner` (app layer): every ~100 ms **while the stick is moving
  and the engine is active**, hit-test the cursor position; whitelist roles
  (AXButton, AXMenuBarItem, AXMenuItem, AXMenuButton, AXLink, AXCheckBox,
  AXRadioButton, AXPopUpButton, AXTextField, AXComboBox), apply the size
  filter, drill into AXMenuBar children. Publishes the latest target frame
  to the main thread; errors clear it.
- Engine tick: pass pointer movement through `MagnetField` before
  `moveCursor`. Assist disabled while dragging (left button held) — text
  selection must never fight the magnet. Scroll path untouched.
- Config: `"magnet": { "enabled": true, "strength": 0.5 }`, resilient
  decoding (legacy configs keep working). Menu toggle "Magnet Cursor".

## Non-goals (phase 1)

No snapping ever; no steering yet; no per-app exceptions; no strength
slider (config value only); no look-ahead scanning; web/Electron content
stays best-effort (native UI is the headline use case).

## Risks

Tuning is taste — plan 2–3 field-test loops (numbers above are starting
values). Scanning wakes other apps (10 Hz, likely negligible). AX from a
background queue is common practice but not formally documented as
thread-safe — keep all AX calls on the scanner's single serial queue.
