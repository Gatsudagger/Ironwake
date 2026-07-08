# Mobile UI Patterns — crib sheet for the touch port

**Purpose:** the reference rubric for grading Ironwake's screens during device tests.
Drawn from the premium PC→mobile ports closest to us in shape: **Slay the Spire**
(turn-based, card/list heavy), **Shattered Pixel Dungeon** (touch-first roguelike, the
gold standard for menu density on phones), **Slice & Dice** (dice roguelike, superb
one-thumb UX), **Balatro mobile**, **Dead Cells mobile**, **FTL iPad**, **Darkest
Dungeon mobile**. Sources: first-hand port knowledge + review verification 2026-07-08
(TouchArcade/Android Central on StS mobile, Engadget/TouchArcade on Balatro mobile).

**Strategy of record (M approved 07-08):** keep the simulated-keypress backbone
(PC byte-identical, one codebase). Adopt these patterns *selectively, per screen*,
where device testing shows the compat layer fighting fingers. No wholesale UI fork.

---

## The size math (S25 Ultra, our 1920×1080 GUI)

S25 Ultra: 6.9" 3120×1440. In landscape our 1080 GUI px span ~73mm of glass →
**1 GUI px ≈ 0.068mm**.

| Standard | Physical | In our GUI px |
|---|---|---|
| Android minimum (48dp) | 7.6mm | **~112 px** |
| Comfortable primary action | 9–10mm | ~130–150 px |
| List row minimum height | ~6mm | **~88 px** |
| Gap between adjacent targets | ≥2mm | ~30 px |

Anything tappable smaller than ~90×90 GUI px (or rows shorter than ~60px with no
gap) will miss-tap. This is the single biggest gap between a compat layer and a
real port — and it's exactly what reviewers punished **StS mobile** for: "UI for
ants" (Android Central), touch targets "don't seem to have changed much at all"
with the potion menu and everything at the top of the screen too small
(TouchArcade iOS review). StS is our cautionary tale: a beloved game, docked a
full review tier purely for shipping PC-density targets. Shattered PD and
Slice & Dice — built touch-first with fat rows — are the models.

**Thumb map (landscape, two-handed grip):** easy = bottom half + left/right edges
near corners; hard = top edge and dead center. Ports dock primary actions
bottom-left/bottom-right (StS "End Turn" bottom-right, map/deck top corners =
infrequent). Our chips currently ride the old legend line — check reach in hand.

---

## Pattern catalog

Each entry: what it is → who does it → where Ironwake stands.

### P1. Direct manipulation — tap the entity, not a cursor
Every port. No visible list cursor on touch; the tap IS the selection.
**Ironwake:** shipped (tap-row = cursor + simulated key underneath — invisible to
the player, which is fine). *Test:* does any screen still require arrowing?

### P2. Two-step commit — first tap selects/inspects, second tap (or button) acts
StS: touching a card raises + zooms it, release outside = cancel. Shattered PD:
tap once = examine, tap again = act. Prevents fat-finger disasters without
confirm-dialog spam.
**Ironwake:** shipped on board notes, Bairc rows, shrine curses, floor nodes,
title slots. *Test:* is the SELECTED state visually loud enough that the second
tap feels intentional? (PC cursor highlight was designed for a mouse-precision
world.)

### P3. Long-press = detail/tooltip (hover replacement)
StS holds a card to read keywords; Shattered PD long-press = examine anything.
400–500ms is the industry band; ours is 450ms — in band.
**Ironwake:** shipped (loadout rows → Tab detail, combat abilities → V examine).
*Test:* discoverability — ports show a brief "hold for details" hint the first
time. We have no hint anywhere. Candidate coach-mark.

### P4. Persistent docked action bar (the legend contract → buttons)
Every port replaces key legends with always-visible buttons. Slice & Dice's whole
bottom edge is buttons; StS docks End Turn / map / deck.
**Ironwake:** shipped as chips (hub/floor/board). *Test:* thumb reach + are chips
≥112px? Do they have pressed-state feedback (see P8)?

### P5. Drag = scroll, with slop threshold; tap-on-release
Universal. Android's system slop is 8dp ≈ **~19 GUI px** at our scale — our 27px
is slightly conservative (safer against accidental scroll-cancel; may make short
flicks feel dead). Momentum/kinetic scroll is standard but NOT required at our
list lengths.
**Ironwake:** shipped (drag simulates arrow steps into existing edge-scroll).
*Test:* tune 27px live; does step-scroll (row-snap) feel OK vs pixel-smooth?
Row-snap is acceptable — Shattered PD's inventory scrolls in steps too.

### P6. Drag-to-target casting
StS's signature: drag card onto enemy to play it. The mobile-native way to do
"select ability, then select target" in ONE gesture.
**Ironwake:** NOT built — we tap ability (release-cast) then V-cycle/tap targets.
Post-EA candidate only; the two-tap flow is functional, StS's is just nicer.

### P7. Density cut — fewer rows, bigger everything, per-screen reflow
The expensive pattern, and what separates "port" from "compat layer." StS mobile
reflowed shop/map/deck screens; Balatro mobile went portrait with a full relayout;
Darkest Dungeon mobile rebuilt the hamlet menus. Done per-screen, driven by pain.
**Ironwake:** NOT built (this is the selective-adoption backlog). 8b's
height-locked GUI_W flex is the prerequisite (real estate first, then reflow).
*Test output:* the graded screen list below decides which screens ever need this.

### P8. Pressed-state feedback on every tappable
Touch has no hover and no key-click; ports flash/depress/haptic every hit so the
player knows the tap landed. **Balatro mobile leans hard on this** — light force
feedback on every card tap, button press, and hand played; reviewers called out
that it "feels clicky and responsive without physical buttons" and rated it one
of the best conversions in years. Misses cause the "spam tap until it works"
behavior M described pre-8d.
**Ironwake:** UNKNOWN coverage — chips/buttons may draw no pressed state. *Test:*
tap each chip/button watching for visual acknowledgment. Cheap global win if
missing (flash frame on touch-down in the chip/button draw helpers). Haptics
would need a GM extension (no built-in GML vibrate) — visual flash first,
haptics a post-EA nice-to-have.

### P9. Safe areas + camera punch-hole
Ports inset interactive UI from display cutouts and rounded corners.
**Ironwake:** 8b chunk (planned, ANDROID_PORT_PLAN.md §2). Note the S25's
punch-hole is top-center in landscape-left — our top-edge labels may collide.

### P10. Confirmation on destructive/irreversible taps only
Ports add confirms where a stray tap costs a run (StS: potion discard, card
removal) and NOWHERE else. Our two-step commit (P2) already covers most cases.
*Test:* any single-tap action that spends resources or is irreversible? (Shrine
price labels pay on one tap — watch it in hand.)

### P11. OSK: lift UI, DONE button, never require typing mid-flow
**Ironwake:** shipped (naming modals lift, DONE buttons, gc OSK pump).

### P12. Orientation + one-hand reality
Balatro mobile, StS, and Dead Cells all shipped landscape-only (Balatro reviewers
noted portrait isn't even available). We are locked landscape — matches the
category norm; no action, just noting the decision is deliberate.

---

## Device-test rubric (grade each screen A/B/C)

- **A — compat layer fine:** targets big enough, no miss-taps, flow obvious.
- **B — needs polish, not reflow:** bigger hit zone / pressed-state / hint text /
  threshold tune. Fix in 8d follow-up.
- **C — needs the mobile treatment:** density cut / reflow / docked actions
  (P7). Goes on the post-8b selective-reflow backlog.

Screens to grade: title/slots · char create (class/stat, portrait, naming) · hub
walkabout + NPC talk · stash tabs · loadout (rows, tabs, confirm bar) · char
menu/journal/history/settings overlays · dungeon select · floor map · combat
(abilities, log, targeting, End Turn) · loot/extract · shrines/curses · Bairc
(roster, submenu, hatch) · tavern board · level-alloc overlay · Sable/Vex/Dorn/
Petra vendor screens · codex · pause menu.
