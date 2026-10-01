# Ironwake — Misc Tasks Backlog

Captured 2026-06-23. Unverified-in-IDE; each item is a request/bug report to be triaged.

---

## 1. Critical — Item Loss Prevention

- [x] **Vex trait trade auto-consumes item (DATA LOSS).** BUILT (verify in-IDE) — Vex trait & stat
  trades now open a shared select+confirm modal instead of auto-grabbing an item. See `SYSTEMS_ITEM_PICKER.md`.
- [x] **Audit ALL salvage / dismantle / sacrifice systems.** Done. Found 4 sites: Vex trait, Vex stat,
  Shrine item-tribute (all auto-picked → now use the shared picker), and Sable salvage (already picked
  the item; added a confirm arm). Fixed-recipe consumers (Sable Brew/Upgrade) left as-is. Alchemical
  Rebirth (not built) will reuse the picker. See `SYSTEMS_ITEM_PICKER.md`.

---

## 2. Item & Loot Systems

- [x] **Stash items leak into dungeon inventory.** FIXED (verify in-IDE). The equip picker merged
  `equipment_stash` + `carried_items` at all 3 build sites. Now the stash loop is gated by
  `room == rm_hub || room == rm_character_select` in `obj_game_controller/Step_0` (keyboard ~1306 +
  mouse ~1152) and `scr_ui` (draw ~1921), so during a run only the pack shows. Header count now reads
  "Pack: N (stash left in town)" and the empty-state text adjusts. Matches the existing unequip routing.
- [x] **Class-only items must still show their icon.** DONE (4B, verify in-IDE). The equip picker
  (`scr_ui` ~2044) only drew the icon when `!_locked`; now `ui_draw_item_icon` is called for locked
  rows too, and the name/stat text always offsets to clear the icon.
- [x] **Class-specific items should all have an ability affix** — otherwise being class-locked has no
  upside. DONE (4B, verify in-IDE). All 7 class weapons now carry a bespoke `unique_effect`/`unique_desc`
  (set in `obj_game_controller/Create_0`, propagated through `clone_item`), read into player flags in
  `obj_combat_controller/Create_0` and hooked in combat: Cracked Focus = first spell −1 AP; Vaultstone
  Wand = +12% spell dmg; Void Scepter = spell crit refunds 1 AP; Gravelstone Sword = 10% melee lifesteal;
  Ashkeeper Blade = 12 HP start shield; Shadow Sickle = +8% crit; Serpent's Reach = kill refunds 1 AP
  (kill hook in `combat_on_enemy_defeated`).
- [x] **New Alchemist option: "Alchemical Rebirth."** DONE (4B, verify in-IDE). New Sable tab 3 "Rebirth"
  opens the shared item-picker (`item_picker_open("alch_rebirth", …)`) on class-locked Uncommon+ gear;
  resolve sacrifices the item and grants a random different-class item of the same slot+rarity. Cost
  scales: Uncommon 3 Dust+120g, Rare 6 Dust+250g, Epic 10 Dust+500g. Affordability is checked BEFORE
  removal (no item loss if you can't pay). Helpers: `item_picker_candidates_class_specific`,
  `alch_rebirth_cost`, `alch_rebirth_make` (`scr_stats`).
- [x] **Verify "find more items" trait actually works.** VERIFIED WORKING. Lucky Find adds +5%
  consumable drop (`scr_stats` ~1013 standard 10→15%, ~1031 elite 60→65%); Prospector bumps loot
  +1 rarity tier (`scr_stats` ~751). Both fire — they *feel* invisible because +5% is small and the
  rarity bump is silent. Not a code bug; value/clarity is a §6 balance concern.
- [x] **Verify guaranteed additional item drop from traits.** VERIFIED WORKING (low-impact). Treasure
  Hunter (`obj_floor_controller/Step_0` ~243) makes plain "treasure" rooms always contain an item
  (`trait_active("Treasure Hunter") || irandom<40`). Seems dead because the other treasure variants
  (heal/vault/rare) are already guaranteed regardless, and plain rooms already roll 40% — so the
  trait's marginal effect is rarely seen. Working as designed; value is a §6 concern.
- [x] **Too many healing items dropping.** DONE (4B, verify in-IDE). New `roll_consumable_weighted`
  (`scr_stats`) down-weights heal/heal_dot (weight 1) vs utility (weight 3) — heals drop from ~25%→~14%
  of the standard pool. Wired into every random drop source (combat standard/elite/boss bonus, plain
  treasure room, event rewards); `treasure_heal` supply caches kept uniform on purpose. Combat consumable
  CHANCE now tapers with awakening: standard 10% −1%/tier (min 5%), elite 60% −4%/tier (min 40%); Lucky
  Find still adds +5% on top.

---

## 3. Combat & Abilities

- [x] **Major ability rework — redundancy problem.** Can repeat the same 3 abilities on Arcanist and Strider to deal + avoid damage, just looping one combo.
  - Brainstorm solid rebalancing + new abilities. **BUILT (verify in-IDE) — see SYSTEMS_ABILITY_REWORK.md.**
    Diagnosis: abilities are once-per-turn, so the loop is *across* turns; the AP curve was inverted
    (three 1-AP casts beat any 3-AP nuke) so expensive abilities were dead. Fix = setup→payoff combos
    ("Exposed" = vulnerable): 6 new abilities (1 free primer + 1 Vex payoff per class — Scorch/Soul Nova,
    Cleave/Rupture, Throat Slit/Assassinate) + rebalanced Arcane Burst (28→38, +40% vs Exposed),
    Marrow Crush (18→24), Flurry (+3/debuff). **Side-fix:** revived the dead `"resource"` effect path so
    Soulfire/Soul Harvest actually generate (the soul economy was broken, which forced Soulfire-spam).
  - Consider **multi-turn cooldowns** on complete-dodge abilities (blink/shadowstep style). **DONE (4A, verify in-IDE)** — built a player-side cooldown system (`player.ability_cd[]`, ticked at player-turn start in `obj_combat_controller/Step_0` ~157, gated at the cast block ~407, set on cast ~861). `ability_cooldown(ab)` (`scr_abilities` ~675) gives Blink & Shadow Step a 2-turn cooldown. Combined with the chance-based dodge below, the "loop one combo to avoid everything" no longer works.
- [x] **Abilities must label their type at end of description:** `(melee/phys)`, `(melee/spell)`, `(ranged/phys)`, `(ranged/spell)`. DONE (verify in-IDE). New `ability_attack_class_tag(ab)` (`scr_abilities` ~662) returns the compact tag; appended to the end of the effect text in the combat tooltip (`scr_ui` ~1150), the loadout list + slot rows (`obj_hub_controller/Draw_64` ~1310/~1352), and Vex's ability list.
- [x] **Stun should weaken evasion abilities.** DONE (4A, verify in-IDE). Blink/Shadow Step are no
  longer never-miss: resolution now rolls `combat_evasion_chance(player)` = `clamp(50 + WIS*2, 0, 85)`
  (`scr_combat` ~301). On a failed roll the dodge window is consumed and the attack falls through to
  normal damage (`obj_combat_controller/Step_0` ~1129/1144). Stun **halves** the chance (so you can't
  reliably dodge while stunned — covers "reduced chance" + "can't fully dodge if stunned"). The cast
  log and ability buttons now show the live %/cooldown.
- [x] **Combat log scroll-hint labels were swapped.** Log order was actually correct (newest-at-bottom); only the top/bottom scroll hints read backwards. Fixed: top now `▲ older`, bottom `▼ newer` (scr_ui.gml ~1006-1007).
- [x] **Floating combat damage number only shows one instance.** FIXED (verify in-IDE). Cause: two
  DoT stacks ticked the same frame and pushed popups at identical x/y, overlapping into one number.
  Added an optional `delay` field honored by the popup draw loop (`obj_combat_controller/Draw_64` ~217);
  the DoT tick loop (`Step_0` ~1008) now staggers each successive popup (`delay = n*14` frames + x offset)
  so stacked poison reads `6` then `6`. Combat log already showed both.

---

## 4. UI / Display

- [x] **Maren (runesmith) shop menu doesn't show player gold.** FIXED (verify in-IDE). Added a
  `c_yellow` "Gold: Ng" line at top-right under the Rune Dust readout in `ui_draw_maren_screen()` (scr_ui ~3385).
- [x] **Vex trainer text overlaps at the bottom.** FIXED (verify in-IDE). On the TRAITS tab the list
  windowed to 8 rows (8th row y=598–656) but the "Trade item ready…" readout draws at y=626, landing
  inside it. Dropped the Traits tab to 7 visible rows in both the draw (`scr_ui` ~3231) and the Step
  hit-test/scroll window (`obj_game_controller/Step_0` ~556). Abilities tab keeps 8 (it has no readout).
- [x] **Vex trainer ability descriptions are ambiguous** — need more explanation / text. DONE (verify
  in-IDE). Vex's ABILITIES tab (`scr_ui` ~3194) now renders the full-sentence `ability_effect_full(ab)`
  (+ the attack-class tag) instead of the terse `ability_summary` shorthand.
- [x] **Loot screen (post-combat equipment) shows no icons or stats.** DONE (verify in-IDE).
  `obj_combat_controller/Draw_64` loot rows now draw the gear/consumable icon badge at row-left and add
  a stat line (`ui_item_stat_str`) for equipment; text shifted right to clear the icon.
- [x] **Inventory stats screen needs an overhaul.** DONE (4C, verify in-IDE). Full redesign of the
  Stats tab (`scr_ui` ~1768): reorganized into Offense / Defense sections and filled the empty right
  third with a **portrait card** — south-facing player sprite (frame 0 of `player_combat_sprite`, the
  8-dir layout's south frame; no new art) + skin/gender caption + a Combat-Readiness summary (HP, Dodge,
  Accuracy, main-school crit). **Crit % is now correct**: the 4 schools fold in the flat gear `crit_bonus`
  + Duelist boon (the old panel showed only the stat-scaled part, under-reporting real crit), with a note
  that each ability adds its own base crit. **+Accuracy explained**: shown as "+N% to hit" with a plain
  description that it's added to each attack's hit roll vs the enemy's Dodge (capped 5–95%, lowered by Blind).
  Boons & Effects moved to the right column under the card (cap 5 rows).
- [x] **Awakening level should display on the dungeon screen and combat screen** as a reference. DONE
  (verify in-IDE). New `awakening_label()` (`scr_ui` ~74) formats "Awakening A2 — Brutal" from
  `global.selected_ascendance`; drawn top-right on the combat screen (`obj_combat_controller/Draw_64`)
  and the floor map (`obj_floor_controller/Draw_64`), tinted orange when A1+.

### Icon consistency (gear + consumables)
- [x] Consumable sprite icons only appear when examining consumables from the inventory menu.
  **Shopkeepers still show old plain-text item lists.** DONE (verify in-IDE). New reusable
  `ui_draw_consumable_icon(x,y,sz,item)` (`scr_ui` ~176) draws a cyan-bordered consumable badge;
  wired into Petra's buy rows and the shop SELL tab (consumables) + the loot screen.
- [x] **All icons (consumables AND gear) should use the sprite icons** added for the stash and
  merchants — apply everywhere (shops, loot, etc.), not just inventory examine. DONE for the shop +
  loot surfaces (gear already iconified via `ui_draw_item_icon`; consumables now via
  `ui_draw_consumable_icon`). If any other plain-text list surfaces later, reuse the same two helpers.

---

## 5. Art / Visual Assets

- [x] **Combat background screens per dungeon.** DONE — all 9 of 9 (verify in-IDE).
  Per-floor arenas (3 floors × 3 dungeons), keyed by `global.current_floor`: `spr_combatbg_<ashen|
  scorched|tundra>_<1|2|3>` (PixelLab, 400×224 stretched to 1280×720). All on disk, registered in
  `.yyp`, and in `global.__sprite_includes` (anti-strip). Render wiring + fallback live
  (`dungeon_bg_draw("combat",0.30)` in `obj_combat_controller/Draw_64`). See memory project_dungeon_backgrounds.
- [x] **Dungeon-floor "rooms" screen art, per dungeon.** DONE (verify in-IDE).
  `spr_floormap_ashen` / `_scorched` / `_tundra` generated, registered in `.yyp` + `__sprite_includes`.
  `dungeon_bg_draw("floormap",0.45)` in `obj_floor_controller/Draw_64` draws them (flat-fill fallback if missing).
- [ ] **Vael portrait-change feature.** Vael should let players change their portrait for **100g**.
  - More portrait images have been added to the folder.
  - Update **character-creation portrait selection** AND wire up **Vael's new portrait-change option**.
  - [x] **Char-creation selection DONE (verify in-IDE).** Imported all 60 new portraits from
    `Player Character Portrait/{Arcanist,Bloodwarden,Shadow Strider}` as `spr_portrait_<cls>_<m/f>N`
    sprites (downscaled 1024→512 for HTML5 VRAM; registered in Ironwake.yyp). `global.portrait_sprites`
    (`obj_game_controller/Create_0` ~622) now lists all 60 as one flat A/D cycle, replacing the old
    generic `spr_portrait_01..11` (kept as resources, just unlisted). **Requires reopening GameMaker so
    the new sprite resources ingest.**
  - [x] **Vael's 100g portrait-change option DONE (verify in-IDE).** Added a **Skins | Portrait** tab
    bar to the Vael overlay (Q/E or click to switch). New Portrait tab is a carousel over
    `global.portrait_sprites` (A/D browse, Enter to set); switching to a *different* portrait costs
    **100g**, re-picking your current one is free, and it blocks the change if you can't afford it.
    Draw: `ui_draw_vael_portrait_tab()` (`scr_ui`); input: Vael block in `obj_game_controller/Step_0`;
    state `vael_tab`/`vael_portrait_cursor` init in `Create_0` + both hub open sites. Persists via the
    existing `chosen_portrait` save field.
- [x] **Poison cloud VFX too large.** DONE (verify in-IDE). Only `spr_fx_poison` is shrunk + faded in
  `ui_draw_status_fx` (`scr_ui` ~512): poison gets `_size_mult 0.62` (~34% of enemy height vs the shared
  55%) and `_fx_alpha 0.65` so the enemy shows through; all other status FX (burn/bleed/blind/stun/weaken)
  are untouched. Root cause: poison art fills its full 64×64 canvas while the others have transparent
  padding, so at the uniform 55% size it blanketed the enemy.
- [ ] **Salvage VFX + SFX.** When salvaging an item, play a pop-up animation: puff of smoke + magical dust generated, with a sound effect.

---

## 6. Difficulty & Balance (Awakenings)

- [x] **Awakenings need to scale much harder per tier.** DONE (4A, verify in-IDE). Steeper multipliers
  in `obj_combat_controller/Create_0` ~423: HP `[1.0,1.20,1.45,1.75,2.10,2.55]` (was `…1.50,1.70`),
  dmg `[1.0,1.15,1.35,1.60,1.90,2.30]` (was `…1.30,1.40`). A4 jumps from ×1.50 HP/×1.30 dmg to
  ×2.10/×1.90. Also added `awaken_enemy_acc_bonus()` (`scr_combat` ~290) = `[0,0,5,10,18,28]` accuracy
  points folded into every enemy hit roll (`Step_0` ~1215) so stacked DODGE/DEX no longer trivializes
  high tiers — directly fixes "dodging everything, ~4 dmg on A4 as a 27-DEX Strider".
- [x] **Verify mobs actually update stats with ascension.** VERIFIED APPLIED (but weak — tuning, see
  first bullet). `obj_combat_controller/Create_0` ~420–436 multiplies every enemy's HP/damage/telegraph
  by ascendance tables — HP `[1.0,1.10,1.20,1.35,1.50,1.70]`, dmg `[1.0,1.05,1.10,1.20,1.30,1.40]`;
  bosses included (+×1.25 on the main enemy at A5). The "bosses feel the same" complaint is real but
  it's a TUNING issue (A4 is only ×1.50 HP / ×1.30 dmg), addressed by the "scale harder per tier" item above.
- [ ] **Higher risk / higher reward at higher awakenings:** worse and stronger trap rooms, more intense events.
- [x] **More random generation of room layouts and events.** Dungeon floors are very similar / often identical — increase layout + event variety. **BUILT (verify in-IDE) — see SYSTEMS_FLOOR_VARIETY.md.**
  Root cause found: `global.run_seed` was set ONCE per session and never re-rolled, so *every run built the identical floors* — fixed by re-seeding in `end_run`. Plus: replaced the 5 fixed layout templates with a seeded **procedural layered-DAG generator** (5-6 layers, 1-3 nodes/layer, guaranteed-valid: all nodes reachable + reach the boss); grew the event catalog 7→**13** with a **no-repeat-within-a-run** guard; and added a small per-floor **type-mix** injection so the decision/loot mix shifts run-to-run.

---

## 7. Affix Verification

- [x] **Confirm gold/crit/other affixes actually apply.** AUDITED + FIXED (verify in-IDE).
  - **crit_flat** ("of Ruin") — ✅ already working (`combat_roll_crit` reads `crit_bonus`, `scr_combat` ~170).
  - **dodge_flat** ("of Shadows") — ✅ already working (`player.dodge += dodge_flat`, `obj_combat_controller/Create_0` ~204).
  - **gold_find** ("of Greed"/"Lucky", +3/5/8%) — ❌ WAS BROKEN. Stored as `player.gold_find_pct`
    (`Create_0` ~208) but never read; `add_gold()` only applied Scavenger + Charisma. FIXED: `add_gold()`
    (`scr_stats` ~95) now reads the equipped gold_find total via `apply_equipment_stats({}).gold_find`
    and applies `×(1 + N/100)` on the found-gold path (item sells stay unaffected). Stale comment at ~824 updated.

---

## 8. Trait System Bugs

- [x] **Expanded Arsenal trait doesn't grant a 5th ability slot.** FIXED (verify in-IDE). Timing bug:
  the loadout screen read the *committed* traits (`global.player_traits`) for the slot cap, but you
  pick traits into the in-progress `traits_selected` list — committed only on confirm/exit. Now the
  cap reads the live `traits_selected` in both `obj_hub_controller/Step_0` (~151) and `Draw_64` (~1207),
  so slot 5 opens the moment you toggle the trait; added a trim if it's deselected with 5 abilities chosen.

---

## 9. Merchants

- [ ] **Add a shop history / buy-back option to all merchants** for items the player has sold.

---

## 10. Quality of Life (2026-06-24 batch)

- [x] **Targeting cursor under the selected enemy.** DONE (verify in-IDE). When tabbing targets it
  was only shown as a `>` next to the HP bar (top-right grid) — no way to tell which sprite. Added a
  slowly-swirling arcane rune (`spr_target_cursor`, a PixelLab top-down rune rotated in code) drawn at
  the selected foe's feet, UNDER the sprite, in the enemy sprite loop (`obj_combat_controller/Draw_64`
  ~197, gated `_espr_idx == selected_target`). Scales to the enemy footprint + gentle breathing pulse.
- [x] **Heal "twinkle" SFX bleeding into offensive spells (e.g. Drain).** DONE — interim with existing
  sounds (verify in-IDE). The `Magic` chime is now reserved for heals: removed it from offensive
  Arcanist casts (`obj_combat_controller/Step_0` ~787) and made self-cast play `Magic` only when
  `effect_type=="heal"`, else `spell1` (~968). **Awaiting M's new audio** to give heals + drains their
  own dedicated sounds (add new SFX to `audio_sfx_assets()` in scr_stats).
- [x] **Targeting cursor too large.** TUNED — shrunk ~2.6x (`Draw_64` scale `1.05`→`0.4`, floor
  `0.45`→`0.18`).
- [x] **Lowest enemy sprite overlapped the ability tooltip.** FIXED (verify in-IDE). Enemy sprites are
  88-124px native drawn x2 (~248px tall); the lowest staggered foe bottoms out ~y440. Moved the ability
  tooltip from y400 to **y470** (`scr_ui` ~1617) so the panel (x840-1160, y470-680) clears the cluster,
  stays right of the combat log (x<=800) and clear of the ability buttons.
- [x] **Hub Gold counter should be gold-colored.** DONE. The Gold line in the hub player-info panel
  (`obj_hub_controller/Draw_64` ~142) draws in antique gold `rgb(228,190,90)`; the other stats stay white.
- [~] **Gothic ornate borders on UI panels.** IN PROGRESS — frame asset + helper built, 2 panels done.
  `spr_ui_frame` (PixelLab ornate gold-filigree frame) drawn via manual 9-slice helper
  `ui_draw_gothic_frame(x1,y1,x2,y2,band)` (`scr_ui`, SURROUNDS the rect outward so content is never
  covered; corners undistorted, edges stretched, center skipped). APPLIED: hub player-info panel +
  combat ability tooltip. EXPANDED 2026-06-24 (user loved it) to portraits + NPC/selection frames: hub
  player portrait + selected NPC row + NPC detail panel (`obj_hub_controller/Draw_64`), char-menu portrait
  card + Vael carousel (`scr_ui`), char-select portrait (`obj_char_select/Draw_64`). Use a smaller `band`
  for portraits/rows (10-24) vs panels (26). REMAINING: inventory-menu frames (Equipment-tab gear slots
  ~scr_ui 2098, item detail panes, stash, equip picker), shop panels (Petra/Dorn/Maren/Sable/Vex), loadout,
  combat log, floor overlays, title. See memory project_dungeon_backgrounds.
- [x] **ESC to exit a hub menu also opened the pause menu.** FIXED (verify in-IDE). Cross-object step
  order: gc closed the overlay (flag false), then `obj_hub_controller`'s pause trigger saw nothing open
  + ESC still down → opened pause. Added `global.ui_overlay_latch` (set at the top of
  `obj_game_controller/Step_0` from `ui_input_blocked() || item_picker.open || comparison_open`, init in
  Create_0) and gated the hub trigger on `!global.ui_overlay_latch`. Floor/combat already exit their
  popups before their pause trigger, so only the hub needed it.
