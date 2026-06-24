# SYSTEMS — Combat Feedback & Clarity Pass

**Status: BUILT (2026-06-23), not yet compile-tested in IDE.** All five areas built in one pass.
Build notes: 7 PixelLab VFX sprites generated via `tools/build_fx_sprite.py` (1-direction
object review packs → curated frame subsets), registered in Ironwake.yyp, added to
`global.__sprite_includes`. Frame picks: poison 9,0,8,15,4,7 · burn 0,9,13,4 · bleed 1,9,13,5 ·
blind 0,4,8,2 · stun 0,1,8,14 · weaken 0,5,6,9 · impact 1,0,9,5 (frame 0 = main burst).
Object ids in `tools/` run history. Code lives where "Integration points" says below.

**Status: DESIGN-LOCKED (2026-06-23).** Five areas, built in one pass.
Goal: make statuses/boons/event choices legible. Player feedback: debuffs on the player
(e.g. "Sight Clouded") show nowhere; no idea how long buffs last; event options (Cursed
Idol "Pray before it — WIS check") don't explain odds or outcomes; Dorn's rows omit slot.

Decisions confirmed by M: VFX = **PixelLab effect sprites** (animated, not code-drawn);
build **all five areas in one pass**.

---

## Existing systems (do not rebuild — extend)
- **Status data:** each combatant has `status_effects[]` of structs `{ name, effect_type,
  effect_value, duration, kind? }`. `kind` ∈ dot / vulnerable / weaken / blind / mortality /
  stun / root / silence (see scr_combat STATUS LAYER). `combat_status_kind_of(se)` resolves it.
- **Enemy status badges:** `ui_draw_enemy_status_icons(x,y,se[])` → `ui_draw_status_icon_row`
  draws 26×16 badges (abbr + duration counter below). Abbrevs/colors via `status_icon_label`
  / `status_icon_color` — currently keyed off ABILITY NAME (unknown → "?"). scr_ui ~309-401.
- **Boon HUD strip:** `ui_draw_active_boons(x,y)` (scr_ui ~1065) + `ui_boon_style(id)` — combat
  only. `global.run_boons` = active boon ids; `boon_get(id)`, `boon_value(id)`, `boon_active(id)`
  (scr_stats/SYSTEMS_BOONS). **Boons last the whole run** (cleared in end_run).
- **Events:** `event_catalog()` (scr_stats ~2171), `event_check_chance(stat,base,per,ref)`,
  `event_choice_cost/unlocked`, `event_resolve_choice`, `event_apply_effects`. Drawn by
  obj_floor_controller. Each choice: `{ label, hint, cost?, req?, check?, success?, fail?, outcomes[] }`.
- **Dorn shop:** rows drawn in scr_ui shop renderer; item has `.slot` ("weapon"/"offhand"/
  "helm"/"chest"/"gloves"/"boots"/"amulet"/"ring"). `ui_draw_item_icon` already switches on slot.

---

## A. Status visibility (combat HUD)
1. **Player status row** — draw the same badge row for the PLAYER near the player HP bar
   (obj_combat_controller Draw_64; player bar is top-left ~20,20). New `ui_draw_player_status_icons`
   (or reuse `ui_draw_enemy_status_icons` at the player anchor). This is the core "Sight Clouded
   shows nowhere" fix.
2. **Kind-based abbreviations/colors** — rewrite `status_icon_label`/`status_icon_color` to switch
   on `combat_status_kind_of(se)` FIRST (name only for flavor variants), so every status tags:
   | kind | abbr | color |
   |---|---|---|
   | dot (poison/plague) | PSN | green |
   | dot (bleed/gore) | BLEED | dark red |
   | dot (burn/cinder) | BRN | orange |
   | dot (other) | DOT | amber |
   | blind | BLND | slate grey |
   | weaken | WKN | brown-orange |
   | vulnerable | VUL | purple-red |
   | mortality | MORT | sick green |
   | stun | STUN | yellow |
   | root | ROOT | teal |
   | silence | SIL | blue-violet |
   Badge shows `ABBR` + the duration number (already supported). DoT sub-type chosen by name
   keyword (poison/plague/venom→PSN, bleed/gore/rend→BLEED, burn/cinder/scorch→BRN).

## B. Status VFX (PixelLab effect sprites)
Generate small looping effect spritesheets (transparent bg) and play them over the afflicted
combatant every frame while the matching status is active. Effects needed (one sprite each,
~4-6 frame loop, single direction, ~48-64px):
- `spr_fx_poison`  — rising green gas puffs (kind dot/poison, also mortality tint)
- `spr_fx_burn`    — orange flame flicker at the feet (dot/burn)
- `spr_fx_bleed`   — red droplets (dot/bleed)
- `spr_fx_blind`   — grey mist swirling around the head (blind)
- `spr_fx_stun`    — yellow lightning/stars circling head (stun; also paralyze flavor)
- `spr_fx_weaken`  — dull downward aura (weaken/vulnerable/curse — colored per kind via blend)
- `spr_fx_impact`  — white/yellow hit spark (played once when damage lands)
Draw: positioned on the combatant (head-anchored for blind/stun, feet for burn, center for
others), looped via `image_index`-style frame cycle from `current_time`. Alpha ~0.85.
**Damage shake:** when a combatant takes damage, offset its draw x by a decaying `sin` jitter
for ~12 frames (code-driven; reuse existing `hit_flash`/screen_shake pattern). Paralyze/stun
adds a brief jitter while active.
Pipeline: PixelLab object/animation tools → build as GM sprite resources (Claude-created art
exception) → register in yyp → add to `global.__sprite_includes` (string-ref strip guard!).

## C. Boons & effects in the character menu
3. Add a **"Boons & Effects"** panel to the character menu Stats tab (obj_game_controller
   menu_tab 0 / scr_ui). Lists:
   - Active **boons**: badge + name + plain effect text (e.g. "+15% damage") + "Active all run".
     Pull name/value from `boon_get`. Lore-flavored one-liner + explicit mechanic.
   - (In combat) active **statuses** with turns-left + what they do.
   This is where "how long does +15% dmg last?" gets answered → boons = whole run; statuses = N turns.

## D. Event / shrine option clarity
4. Rewrite event choice presentation to a **two-line** format: keep the short lore `hint`, and
   add a generated **mechanics line**: the stat check + success chance at the player's current
   stat (via `event_check_chance`) + what success/failure do. e.g. Cursed Idol "Pray before it":
   `"Offer devotion to the idol."` / `"WIS check (~50% at your WIS) · Success: gain its favor (a boon) · Fail: nothing."`
   Apply to every `event_catalog()` choice with a check, and to Shrine tribute (show the boon
   it grants + tribute cost clearly). Implement as a helper `event_choice_mechanics_text(choice)`
   used by the floor-controller draw, so catalog data stays lean.

## E. Dorn's shop slot labels
5. Show each item's slot on Dorn's buy rows (e.g. "Weapon", "Boots"). Map `.slot` → display
   label (reuse/extend any existing slot-name helper); render in the row next to name/price.

---

## Integration points (files)
- **scr_ui**: `status_icon_label`/`status_icon_color` (kind-based), new player-status draw,
  boon/effects menu panel, Dorn row slot label, VFX draw helper.
- **obj_combat_controller/Draw_64**: player status row, VFX sprite playback, damage-shake offset.
- **obj_combat_controller/Step_0**: set shake/last-hit timers when damage lands.
- **scr_stats**: `event_choice_mechanics_text()` helper; event_catalog hints reviewed.
- **obj_floor_controller/Draw_64**: render the mechanics line under each event option.
- **obj_game_controller** Create: add VFX sprites to `__sprite_includes`.
- **sprites/** + **Ironwake.yyp**: new spr_fx_* resources.

## Build order
1. C-code-only wins first (A status row+abbrev, C menu panel, D event text, E Dorn) — testable immediately.
2. Fire PixelLab VFX gens early (parallel), build spr_fx_*, wire B (VFX + shake) last.
