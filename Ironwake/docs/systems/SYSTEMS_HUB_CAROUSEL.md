# HUB NPC CAROUSEL — mobile legibility rework (M design-locked 2026-07-30)

The hub's stacked NPC list is the worst legibility offender on mobile (M:
"desperately in need"). Replace it with a one-NPC-at-a-time carousel that
showcases the animated NPC sprites at readable sizes. Companion to pinch zoom
(SYSTEMS_PINCH_ZOOM.md) — this fixes the root cause on the single
most-visited screen; zoom covers the rest.

## Locked decisions (M, 07-30)
1. **Carousel + JUMP STRIP** (chosen over pure carousel / bigger cards):
   - Center stage: ONE NPC, large animated sprite (idle/action), with a text
     block below — name, epithet, affinity hearts, role line, quest/badge
     banner ("! new request" etc.) — at full readable sizes.
   - `<` / `>` arrows flank the stage; horizontal swipe rotates (existing
     touch_swipe_tab pattern); wrap-around; A/D + d-pad left/right with the
     global hold-repeat nav.
   - **Jump strip** under the stage: a row of small face-chips, one per NPC,
     in list order. Tap/click jumps straight to that NPC (kills the
     "6 swipes to Bairc" carousel failure mode); hot-dot badges on chips keep
     quest notifications visible for off-stage NPCs; current NPC highlighted.
   - **THE DUNGEON GATE stays a persistent big button** outside the carousel
     (entering the dungeon is the primary verb — never N swipes away).
   - STASH / JOURNAL / HERO / SETTINGS remain chips (touch) + hotkeys.
2. **All platforms, ONE layout** — desktop/HTML5 get the carousel too (single
   layout to maintain; it's also what the trailer films). **BUT keep a
   REVERSION handy for Windows + HTML5** (M: "in case it feels worse"): the
   legacy stacked-list draw+input path stays in the code behind a flag —
   settings.ini `[ui] hub_carousel` (default 1), honored ONLY on
   desktop/HTML5 (Android is always carousel; it's the reason this exists).
   Not a player-facing Settings row for now — a quick ini/dev flip. If desktop
   sticks with the carousel after a few sessions, delete the legacy path.
3. **Scheduling:** carousel is the NEXT build session; then P1+P4, then P2
   (combat order otherwise unchanged, see COMBAT_DEEPENING_PROPOSAL.md lock).

## Must survive the rework (audit each at build time)
- Locked/undiscovered NPC presentation (silhouette + unlock hint) on stage
  AND strip; betrayed/absent NPCs (win state) — their strip chip state.
- Gate-quest badges, board/tavern requests access, affinity decay warnings,
  pet_find_notice, last-run summary overlay, camp flavor line, ending
  sequence + awakening-boost + resume-pending modals (all outrank/overlay).
- NPC list ORDER unchanged (muscle memory + existing unlock cadence).
- Coach-marks: update the "hub" tutorial copy if it references list nav; add
  a one-line swipe hint. Reference-sync any text describing the old list.

## Input parity (HARD rule, same task)
Touch: swipe, tap arrows, tap strip chip, tap stage (= engage NPC), all with
Draw-event hit-tests. Keyboard: A/D or arrows rotate, Enter engages, existing
letter hotkeys unchanged. Pad: d-pad left/right rotate, confirm engages.
Overlap audit with longest name/epithet strings; strip must fit all NPCs at
max roster (count them at build; if it ever overflows, chips shrink — no
scroll on the strip).

## Status
**BUILT 2026-07-31, awaiting M's F5 + device pass.** As-built record:

- **Flag:** `settings.ini [ui] hub_carousel` (default 1 = carousel). Read every
  hub entry (obj_hub_controller Create §9) - flip needs no restart. Android is
  forced carousel regardless of the flag; Windows/HTML5 honor it.
- **`selected_npc` keeps its exact legacy meaning** (0..7 = NPC, 8 = gate) in
  both layouts, so the interact dispatch (Step §2/§3), bond B-key, detail
  panel, portrait panel and dungeon-gate handlers are all UNCHANGED.
- **Draw** (Draw_64 §5): stage panel x630..1290 y105..945; animated idle actor
  (own `carousel_frame` state - never touches the NPC screens' shared
  `global.npc_actor`) bottom-anchored y540 at 400px, static-portrait fallback;
  tavern board art for row 7. Name = fnt_ui_title measured auto-fit (≤600px).
  Bond block: 4 heart slots (spr_heart_fx stretched 30px, filled = tier, red
  at Lover), tier line or gate-ready line, progress bar. Role line wrapped at
  600px + measured hint-y. Jump strip y822..888: 8× 66px TRADE-ICON chips
  (M 07-31: portrait thumbnails were unreadable at 66px + doubled the portrait
  on screen) - spr_icon_npc_dorn (hammer on anvil) / _sable (frothing potion) /
  _maren (rune circle) / _vex (leather tome) / _petra (grain sack + coins) /
  _vael (needle + thread) / _bairc (speckled egg) / _board (bulletin board);
  64px full-bleed PixelLab set styled from gold/egg-shard/ember icons, imported
  via tools/import_npc_chip_icons.py (M-approved picks). Pulsing hot-dots
  unchanged (gold = gate ready incl bairc, green = board turn-ins).
- **Input:** ONE dispatch path - every carousel tap simulates the key the Step
  handlers already consume (`touch_press`): arrows → vk_left/right, stage tap
  → select + vk_enter, swipe → Q/E via touch_swipe_tab → input_tab_* (pad
  shoulders rotate for free). Chip tap sets `selected_npc` directly. Step §1:
  A/D + d-pad L/R rotate (hold-repeat via key_nav), W/S/up/down hop focus to
  the gate button and back (`carousel_last` remembers the stage). Touch stage/
  arrow taps fire on clean RELEASE (touch_tap_in) so starting a swipe can't
  also engage/step; desktop clicks are press-fired.
- **Tap gating:** hits only fire when the hub owns input - ui_input_blocked +
  ui_overlay_latch (kills the close-tap fallthrough frame) + bond dialog,
  ending, zoom intro, history, awaken-boost, resume, settings, pause, item
  picker, gift popup, dungeon-select.
- **Survived-the-rework audit:** notification line (detail panel, unchanged),
  board ready-count (detail + stage banner + chip dot), bond deepen affordance
  (detail hint + stage line + chip dot), locked-NPC presentation (stage dim +
  [Locked] suffix + role swap; Step still notifies), betrayed/absent NPCs
  (ending overlay unchanged), NPC order unchanged, hub coach-mark copy is
  layout-agnostic (verified - no list-nav wording), swipe hint = persistent
  on-stage nav hint line. Hearts VFX consume point moves to the stage actor.
- **Footer** (kb): "A/D: Rotate   W/S: Gate   ..." in carousel mode; the
  Journal-badge overdraw shares the same prefix string so its measured
  position can't drift. Gate button idle hint is layout/device aware.
- Legacy list + its Step §5 row hit-tests remain byte-identical behind the
  flag. Delete after desktop verdict (a few sessions of M living with it).
