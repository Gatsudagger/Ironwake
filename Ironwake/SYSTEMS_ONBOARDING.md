# SYSTEMS — Onboarding / First-Run Guidance

ROADMAP §5. New players hit AP combat, traits, loadout, Vex, and ascendance all at once
with no teaching. This adds a lightweight **contextual coach-mark** layer that teaches
each surface the first time it's reached, then never again — without blocking veterans.

**Design-locked 2026-06-24** (M approved both forks):
- **Style:** contextual coach-marks — a one-time dismissable tip box per surface, gated
  by saved "seen" flags. Layers onto existing screens; no scripted state machine; can't
  soft-lock a run. (Rejected: scripted forced first-run; static how-to screen.)
- **Control:** a Settings entry to **Reset tutorial** (re-see all tips) and **Disable
  tips**. Saved profiles keep their seen-state; new profiles get the full set.

---

## Core

- `global.tutorial_seen` = struct/array of tip ids already shown. Persisted in scr_save
  (serialize + guarded restore), init in obj_game_controller/Create (`{}` / `[]`).
- `global.tutorial_enabled` = bool (default true). Persisted. Settings toggle flips it;
  "Reset tutorial" clears `tutorial_seen`.
- `tutorial_catalog()` (scr_stats) — array of `{ id, title, body }` (body = short
  plain-English string, reuse Compendium copy). One entry per coverage moment below.
- `tutorial_seen_has(id)` / `tutorial_mark_seen(id)` — flag helpers (save on mark).
- `tutorial_try_show(id)` — if `tutorial_enabled` && !seen(id): set
  `global.tutorial_active = id` (the tip to draw) and return true; else false. Marks
  seen when dismissed (not when shown) so an interrupted show still re-shows.
- State: `global.tutorial_active` = "" when nothing showing, else the active tip id.

## Display

`ui_draw_tutorial_tip()` (scr_ui) — no-op when `tutorial_active == ""`. Draws a dimmed
backdrop + a gothic-framed tip box (reuse `ui_draw_gothic_frame`), title + wrapped body
(`draw_text_ext`, width-constrained so it never overflows — cf. the hub-flavor/pause-menu
collision fixes), and a "Press any key / click to continue" line. Anchored center or
clear of the triggering screen's existing UI. Called LAST in each surface's Draw so it
sits on top.

## Input

A single dismiss handler (in the relevant controllers, or a shared `tutorial_step()`
called early in their Step): when `tutorial_active != ""`, ANY key / click dismisses it
— `tutorial_mark_seen(active)`, clear `tutorial_active`, and **consume the input**
(exit/return) so the dismiss press doesn't also act on the screen beneath. This mirrors
how the shrine/event overlays intercept input at the top of Step.

## Coverage (~7 tips)

| id | trigger surface | teaches |
|----|-----------------|---------|
| `hub`        | first enter rm_hub                      | the camp, NPCs, how to start a run |
| `loadout`    | first open the dungeon-gate loadout     | equip gear + pick abilities/traits before descending |
| `ascendance` | first open the awakening selector       | awakening tiers = harder + better loot |
| `combat_ap`  | first combat, player's first turn       | 3-AP economy; abilities cost AP; basic attack is free |
| `targeting`  | first combat with >1 enemy              | tab/click to pick a foe; rune cursor shows the target |
| `vex`        | first open Vex                          | spend gold to learn abilities/traits |
| `shrine`     | first enter a Shrine                    | blessing altar (boons) vs cursed altar (curses) |

Each `tutorial_try_show(id)` call sits at the existing entry point for that surface
(hub controller Create/room-enter, floor controller shrine entry, combat first-turn
block, the hub NPC open sites). Tips fire one-at-a-time; if two could trigger together,
the first wins and the next shows on its next natural trigger.

## Settings integration

Add to the Settings overlay (`ui_draw_settings_overlay` + `audio_settings_handle_input`
or its sibling): a "Tutorial" row group with **Disable/Enable tips** (toggles
`tutorial_enabled`) and **Reset tutorial** (clears `tutorial_seen`). Persist alongside
the existing settings.ini / save fields.

## Build order (incremental)

1. Core helpers + globals + save/load + `tutorial_catalog` (2-3 tips to start).  ✅ DONE
2. `ui_draw_tutorial_tip` + shared dismiss/intercept.  ✅ DONE
3. Wire the 2-3 triggers; verify the once-only + dismiss-consume behavior in-IDE.  ✅ DONE (all 7)
4. Fill remaining tips + the Settings toggle.  ✅ DONE

**STATUS 2026-06-24: feature-complete in code, NOT compile-tested.** All 7 tips authored
+ triggered; Settings overlay grew two rows (Tutorial Tips ON/OFF + Reset Tutorial).
Implementation notes that diverged from this doc:
- **No gc Draw call.** gc's Draw_64 is a dead no-op (persistent + no-sprite GMS2 quirk —
  doesn't fire). The loadout/dungeon-select(ascendance)/vex overlays are drawn by the HUB
  controller's own Draw_64, so the hub's existing `ui_draw_tutorial_tip()` at the end of its
  Draw already sits on top of them. Tips draw from hub/floor/combat controllers only.
- **`tutorial_enabled` lives in settings.ini** (`[ui] tutorial_tips`), not the per-slot save
  — it's a global preference (persists from the title, shared across profiles). Only
  `tutorial_seen` is per-slot in scr_save. Reset from the title is a safe no-op for the slot.

## Tunable / deferred
All tip copy is editable in `tutorial_catalog`. Deferred: §4b stretch "context tooltips
that link combat terms back to the Compendium"; richer art per tip. Reuses the
Compendium ([ROADMAP §4b]) as the always-available reference companion to these tips.
