# Magnet Cursor Phase 1 (Friction) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sticky-target friction per the spec (`2026-06-11-magnet-cursor-design.md`): damped cursor speed over whitelisted UI elements, async AX scanner, menu toggle. No steering, no release — field test first.

**Architecture:** Pure `MagnetField` + `MagnetConfig` in AgentpadCore (TDD); `TargetScanner` in the app shell (single serial queue, publishes to main); one-line engine integration; native menu toggle.

**Status note:** built same-session as the spec with full context; tasks kept terse.

### Task 1: MagnetConfig (core, TDD)
- [ ] RED: decode `{"enabled":false,"strength":0.8}`; legacy config without `magnet` section → enabled=true, strength=0.5; strength clamps to 0…1; roundtrip; `ConfigStore.setMagnetEnabled` persists (style: FxConfigTests)
- [ ] GREEN: `MagnetConfig` struct + `Config.magnet` (resilient decoding like `fx`) + store setter
- [ ] Commit

### Task 2: MagnetField (core, TDD)
- [ ] RED (LayerRouter-test style): no target → unchanged · speed above 600 → unchanged · cursor inside frame → scaled by `1 − 0.55×strength` · inside 8 pt margin → scaled · outside margin → unchanged · strength 0 → unchanged
- [ ] GREEN: `MagnetField.adjust(movement:cursor:target:strength:speed:) -> CGVector` (pure, CoreGraphics-geometry import like DisplayClamp)
- [ ] Commit

### Task 3: TargetScanner (app shell)
- [ ] `TargetScanner.swift`: serial utility queue + 100 ms `DispatchSourceTimer`, runs only while `isActive` (engine sets it from stick movement); hit-test cursor position via `AXUIElementCopyElementAtPosition`, role whitelist + ≤320×120 size filter, AXMenuBar → children drill-down; publishes `currentTarget: CGRect?` via `DispatchQueue.main.async`; os_log category "magnet"
- [ ] Build + commit

### Task 4: Engine + menu + wiring
- [ ] Engine tick: compute speed (pt/s) from shaped movement; skip assist while `output.isDragging` (expose `leftButtonHeld` read-only); `MagnetField.adjust` before `moveCursor`; feed scanner `isActive` = stick moving && state active
- [ ] MenuBarController: native "Magnet Cursor" toggle item (checkmark from `store.config.magnet.enabled`)
- [ ] AppDelegate: construct scanner, wire into engine
- [ ] `swift test` green, build, install, relaunch
- [ ] Commit

### Task 5: Field test (Paul) — release only after the feel is confirmed
Menu bar items · Claude Code permission buttons · Finder toolbar · drag/text-selection unaffected · toggle off = old feel. Tuning loop expected (factor/margin/speed limit). Version bump to v0.4.0 happens after sign-off, not in this plan.
