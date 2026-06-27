# Ironwake — Mobile Port (placeholder / on the docket)

**STATUS: NOT STARTED — scoping note only.** This is a parking-lot doc to capture the
idea and the key concerns. It is intentionally shallow. **Flesh this out further before
any work begins** (touch-UI mockups, input-helper inventory, per-screen plans, store
logistics). Do not treat anything here as design-locked.

---

## Verdict (first pass)
Turn-based combat is a great fit for touch (no twitch input, latency-tolerant), so a
mobile port is **very doable**. The engine side is easy; the real work is **input + UI
for touch**. Estimate: a few focused weeks, ~80% of it input/UI — no architectural
blockers found.

## One codebase, not two
GameMaker is **one project that exports to multiple targets**. Mobile = adding
Android/iOS export targets to the existing `.yyp`, NOT a second codebase. "Two versions"
means two *builds* from one source. We never fork the project.

---

## What's easy (engine side)
- GMS2 exports to Android/iOS natively — no rewrite. Mostly build config, signing,
  store accounts, icons/splash.
- Save system (`file_text` sandbox) works as-is.
- Fonts, audio, the 1920x1080 16:9 canvas all carry over; landscape fits phones.
- Performance is a non-issue (turn-based, light).

## The real work (the lift)
1. **Input is keyboard-first everywhere.** Every screen uses W/S navigate, Q/E tabs,
   Enter/Space, Esc, plus hotkeys (H/T/G/P/O/C, Tab). Touch = mouse-click, so *clickable*
   bits partly work, but all keyboard nav needs on-screen touch equivalents across hub,
   shops, loadout, stash, char-select, combat. **This is the bulk of the effort.**
2. **No hover on touch.** Lots of info lives in hover tooltips — enemy inspect panel,
   Tab ability-detail popup, status-badge tooltips, stat base/gear breakdown. All need
   to become tap / long-press.
3. **Touch-target sizing.** Dense 1080p layouts on a ~6" screen: many rows/text are
   finger-unfriendly; need bigger hit areas / layout tweaks.
4. **Store compliance** (privacy policy, ratings, possibly IAP/ads plumbing if monetized).

---

## Approach that protects the PC version
Keep PC the default and untouched in logic; mobile is **additive and wrapped**, never a
rewrite or a fork.

- **Input-abstraction layer (key move):** route the scattered inline keyboard checks
  through logical helpers — `input_confirm()`, `input_cancel()`, `input_nav_down()`,
  `input_tab_next()`, etc. PC returns the keyboard result (identical behavior); mobile
  *also* returns true on the matching on-screen tap. Both platforms feed the same logical
  actions into unchanged game logic.
- **Platform-conditional UI:** boot flag `global.is_touch = (os_type == os_android ||
  os_type == os_ios)`. Gate *extra* drawing (on-screen buttons, tap-to-inspect) behind it;
  PC draw paths are unchanged.

### Staging (so PC is never at risk)
- **Stage 0 — PC-only refactor:** introduce the `input_*` helpers and swap the inline
  keyboard checks to use them, **changing nothing about behavior**. Fully testable on PC;
  ships in normal builds; it's the foundation. If PC plays identically, we're safe.
- **Stage 1+ — mobile additive:** implement the touch side of those helpers + on-screen
  controls behind `is_touch`, on a **git feature branch** while `main` stays releasable.
  Merge only when the PC build still behaves identically.

**Risk concentration:** the work touches shared files (`scr_ui`, controller Step events).
Discipline: **wrap, don't rewrite.** Verify PC after every shared-file change.

---

## Open questions (resolve when revisited)
- iOS, Android, or both? (affects accounts, signing, test devices)
- Portrait support, or landscape-only?
- Monetization model (premium / IAP / ads) — drives store plumbing scope.
- On-screen control style: persistent button bar vs context-sensitive taps vs gestures.
- Minimum device / OS targets and the smallest screen we commit to support.
- Does the itch.io HTML5 build stay as a "smoke test on phone" path, or get retired?

---

*Created 2026-06-27 as a docket placeholder. Expand before starting work.*
