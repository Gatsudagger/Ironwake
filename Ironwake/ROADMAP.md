# Ironwake — Roadmap / Task Board

Working task list, split by area. Check items off as we knock them out. Design-lock
bigger items into their own `SYSTEMS_*.md` before building (see existing ones).

Status legend: `[ ]` todo · `[~]` partial/needs decision · `[x]` done (verify in IDE)

---

## 0. Recently shipped — verify in-IDE (see TEST_CHECKLIST.md)
- [x] AoE + typed status system (vulnerable/weaken/blind/mortality/stun/root) — `SYSTEMS_AOE_STATUS.md`
- [x] Vex rework: abilities gold-only (100/250/400), Traits tab (gold+item) — `SYSTEMS_VEX_REWORK.md`
- [x] Abilities expansion (+13 abilities, +2 traits) — `ABILITIES_EXPANSION.md`
- [x] Floor map: spatial nav, unreachable-room fade, node-overlap fix; loot nerf (Medium)
- [x] UI fixes: equipment text collision, dungeon-select overlap, portrait cover-crop, en-dash bug
- [x] 29 icon/gate sprites built + wired (direct asset refs, not asset_get_index)
- [x] Stray-human enemy art fixed: spr_magma_slug, spr_ice_specter

---

## 1. Hub NPCs — advertised but not built (HIGH leverage)
Three of six hub NPCs are `[Locked]` placeholders with no system behind them. They're
visible to players, so they read as promises. Each needs design-lock first.
- [~] **Maren the Runesmith → RUNE SYSTEM.** DESIGN-LOCKED in `SYSTEMS_RUNES.md` (full
      system). Two domains: **Gear runes** (sockets on gear, stat bonuses) + **Aspect runes**
      (character slots, category buffs keyed to attack-class/damage-type — replaces messy
      per-ability sockets). Combine/split + rune-dust economy shared with Sable. 3 phases.
  - [x] **Phase 1 — Foundation + Gear runes (built, verify in-IDE):** rune catalog +
        helpers (`rune_catalog/get/value/make/describe/random` in scr_stats); globals
        (rune_inventory/rune_dust/aspect_slots/aspect_runes) + save/load; item `socket_count`
        by rarity (create_item/clone_item/drop_equipment); gear-rune bonuses fold into
        `apply_equipment_stats`; rune drops in `handle_enemy_drops` (elite ~6% T1, boss
        guaranteed T1/20% T2); **Maren hub screen** (Socket + Runes tabs) wired + unlocked.
  - [x] **Phase 2 — Aspect runes (built, verify in-IDE):** `rune_aspect_*` helpers +
        6 combat hooks (Ember/Serration/Hemorrhage dmg%, Hunter ranged acc, Surge spell
        crit, Leech drain heal, Bulwark melee shield, Anchor melee Weaken@0.2);
        **Aspects tab** (slot socket/unsocket + "Unlock +1 Slot" for gold+dust);
        **dust trickle** (elite +2 / boss +6). Quickcast/Echo deferred to Phase 3
        (tier3-only, unobtainable until the Forge — avoids unreachable code).
  - [x] **Phase 3 — Forge + flagships (built, verify in-IDE):** Maren **Forge tab**
        (Combine 3→1 next tier 50g+10/150g+30 dust; Split 1→tier-lower + dust refund
        5/15, T1 scrap=3 dust, 20g; Craft Flagship 300g+60 dust → tier-III Quickcast/Echo).
        **Quickcast** (first spell each combat −1 AP) + **Echo** (first AoE each combat
        deals a 50% second instance to all hit) now obtainable & wired. Dust faucet
        finalized by Sable salvage (below).
  - [x] DECIDED: all hub NPCs (incl. Maren) are **permanently unlocked from start** — no
        gate. `npc_unlocked` is all-true and not persisted (re-init each hub load).
- [x] **Sable the Alchemist (built, verify in-IDE)** — `SYSTEMS_SABLE.md`. Hub slot 1,
      unlocked from start (testing). 3 tabs: **Salvage** (gear by rarity 1/2/5/10/20 +
      runes by tier 6/16/40 → dust; the primary dust faucet, distinct from Maren's Split),
      **Brew** (5 alchemy potions incl. new `shield` consumable effect), **Upgrade**
      (3× standard potion → elite, 10 dust+20g). Salvage targets carried_items +
      equipment_stash + unsocketed runes only.
- [x] **Vael the Aesthete (built, verify in-IDE)** — `SYSTEMS_VAEL.md`. Hub slot 5,
      unlocked from start. Transmog: full sprite-replacement combat skins bought with gold
      (`vael_skin_catalog` + `player_combat_sprite`). 3 PixelLab skins (spr_skin_ashen 150g /
      ember 250g / tide 250g, 92×92 side-view, registered in .yyp). Registry shape is the
      forward hook for future per-item visual layers. player_skin/unlocked_skins persisted.
- [x] All six hub NPCs unlocked & functional (npc_unlocked all true) — **permanent design
      decision, no unlock gating** (confirmed 2026-06-25). Not persisted; re-init each hub load.

**Open question:** which (if any) are real planned systems vs vestigial names to repurpose/remove?

---

## 2. Ability & status correctness
- [x] **Ability text audit — DONE via a DYNAMIC DESCRIPTION ENGINE** (Option B). Descriptions
      are now GENERATED from each ability's live fields (`ability_describe` / `ability_effect_full`
      / `ability_summary` in scr_abilities), so they auto-update with progression (future ability
      leveling) and can't drift. One source feeds the combat tooltip, loadout box, and list rows.
      Deleted the ~40 hardcoded tooltip strings. Covers all standard effects (via status-kind) +
      name-keyed riders for the ~17 bespoke abilities; pluralization via `ability_turns`.
  - [ ] (cleanup, low-pri) Remove the now-dead `desc_short`/`desc_full` author arrays in
        scr_abilities (kept for now as a potential flavor-text source).
  - [ ] (optional) Add a static **flavor** line per ability ("when to use it") under the
        generated mechanics.
- [x] **Attack classification system** — DONE, see `SYSTEMS_ATTACK_CLASS.md`. reach (melee/
      ranged) × kind (attack/spell). `ability_attack_class()` derives it; enemies tagged
      reach+kind (`enemy_is_ranged`/`enemy_is_spellcaster`).
  - [x] **Root** blocks melee actions (rooted melee enemy skips; ranged enemy still attacks).
  - [x] **Silence** built functionally — blocks spell actions; **Mana Sever** now applies it.
  - [x] **Stun** blocks all (Death Snare). Player cast-guard added (dormant until enemies get
        control abilities — that's a future content item).
  - [x] Text + tooltips updated for Bear Trap (root), Mana Sever (silence), Death Snare (stun);
        attack-class label shown in the combat tooltip; debuff tooltips now kind-aware.
- [x] **Enemy→player control + abilities (built, verify in-IDE)** — `SYSTEMS_ENEMY_DIFFICULTY.md`.
      Enemies can now use one ability/turn (spell/debuff/dot/control/heal) instead of basic-attacking;
      enemy-applied statuses ride the typed layer (duration+1 for the player-tick timing; Iron Will
      absorbs first). Control (stun/root/silence on YOU) is sparing (low chance, cd 4, short). 7 enemies
      + all 9 bosses authored. Plus moderate stat buff (+15% baseline) and per-floor scaling (×1/1.15/1.30
      standard/elite). All numbers first-pass/tunable.
- [x] **Dead `"resource"` effect type.** FIXED 2026-06-23 (verify in-IDE) as part of the §3 ability
      rework. obj_combat_controller/Step_0 now reads `effect_type:"resource"` generically on both the
      on-hit and self-targeted paths, granting `effect_value` of the caster's secondary resource.
      Revived Soulfire (+2 Souls) and Soul Harvest, which previously never generated. See
      SYSTEMS_ABILITY_REWORK.md. (Hard-coded name hooks for Void Drain/Blood Leech/Second Wind/Soul
      Siphon left as-is — they grant a fixed +1 outside the data path.)
- [ ] **Latent statuses.** Plague Touch's `mortality` (−% healing) does nothing because enemies
      never heal mid-combat. Decide: give some enemies a heal (Magma Slug/Smoldering Revenant
      already "regen" — route regen through mortality), or cut the effect.
- [ ] Confirm `"debuff"` magnitude amplifies where intended (vulnerable now does; audit others).

---

## 3. Roguelite run variety / depth (decisions, not just loot)
Rooms today are combat/elite/treasure/rest/trap/boss — fight-and-loot, light on *choices*.
- [x] **Mid-run boons (built, verify in-IDE)** — `SYSTEMS_BOONS.md`. Run-scoped modifiers
      bought with **tribute** (gold/dust/sacrificed item) at new **Shrine rooms**. 10 boons
      (Bloodlust/Ironhide/Duelist/Vampirism/Warding/Greed/Runic/Executioner/Aegis/Glass Cannon),
      reset each run, persisted mid-run. Interactive shrine overlay in the floor controller.
  - [x] **Active-boon display (built, verify in-IDE)** — combat HUD strip
        (`ui_draw_active_boons`, abbr-badge + name at left col y=185) + character-menu Stats
        tab right-column list. Static legend (boons have no duration). `ui_boon_style` shared.
- [x] **Event rooms (built, verify in-IDE)** — `SYSTEMS_EVENTS.md`. New `"event"` room type:
      interactive, stat-gated risk/reward choice overlay (modeled on the Shrine). Data-driven
      7-event catalog in scr_stats (`event_catalog`/`event_roll`/`event_resolve_choice`/
      `event_apply_effects` + helpers). **Folded the old passive `trap` room in** (Trapped
      Corridor event; trap removed from pools/handlers). Stat checks (STR/DEX/CON/WIS/CHA) gate
      and scale choices — first time stats matter outside combat. Outcomes: gold/HP/items/
      consumables/dust + rare boon jackpot. Reuses pending-damage/heal hooks; no new script
      resource. Overlay: floor Create vars + Step §2c + Draw §6c.
- [ ] **Curses / risk tradeoffs** (opt-in difficulty for better loot) — pairs with boons (devil's bargain).
- [ ] Consider per-run modifiers tied to ascendance beyond stat scaling.
- [x] **Awakening-gated loot rarity (built, verify in-IDE)** — `drop_weights(source, asc)`
      lerps rarity from a common-heavy A0 baseline to an A5 ceiling for every drop source
      (standard/elite/boss/chest/vault/reliquary); rares ~1-5% & legendaries ~1% at A0
      (boss/reliquary only). Dorn scales with `highest_awakening_unlocked()` (permanent),
      now stocks affixed gear (3→5 items). Rarity-tier only; drop rates unchanged.
      See SYSTEMS_LOOT_SCALING.md.

---

## 4. Content breadth
- [ ] More dungeons / biomes beyond the 3 (Ashen Vault, Scorched Depths, Tundra Tomb).
- [ ] More enemies + enemy mechanics per dungeon; verify all existing mechanics fire
      (double_strike, regen, phase_shift, charge, fortify, death_burst, retribution).
- [ ] More bosses / multi-phase boss fights.
- [ ] More items, affixes, legendaries; more abilities/traits as needed.

---

## 4b. Game Compendium / Help tab (DONE — verify in-IDE)
A "help menu" so players can read brief breakdowns of the game's mechanics.
- [x] New **Compendium** tab in the character menu (5th tab, alongside Stats/Equipment/
      Abilities/Consumables). Tab bar re-centered for 5 tabs.
- [x] Sections with short plain-English entries: Damage Types, **Attack Classes** (melee/ranged
      × attack/spell), **Status Effects** (DoT, vulnerable, weaken, blind, mortality, stun, root,
      silence), AP/Turn Economy, Hit & Crit, Progression (ascendance/leveling/traits), Item Rarities.
- [x] Left section list + right detail pane; data-driven via `ui_compendium_sections()` in
      scr_ui — append a section there and it appears automatically. W/S or click to browse.
- [ ] (Stretch) context tooltips that link combat terms back to the compendium.

---

## 5. Onboarding & game feel
- [ ] **Tutorial / first-run guidance** — new players hit AP combat, traits, loadout, Vex,
      ascendance all at once with no teaching.
- [~] Combat juice pass — status icons on combatants + looping status VFX sprites +
      damage-shake **shipped** (combat-feedback pass). Remaining: hit-feedback polish,
      telegraph clarity, salvage VFX/SFX (MISC §5).
- [x] **Sound settings (built, verify in-IDE)** — Music + SFX volume sliders, reachable from
      title + hub (`O`), persisted in settings.ini. Per-asset gain (no audio groups).
      Master volume / mute deferred.
- [~] **Enemy family-themed SFX — framework built, awaiting real audio.** Death/attack sounds
      keyword-classified into 7 families with best-fit fallbacks; M drops in
      `snd_death_/snd_attack_<family>` files, then they're registered in `audio_sfx_assets()`.
- [ ] Audio coverage audit (any actions missing SFX).

---

## 6. Polish & known bugs
- [x] **Item Codex overhaul (built, verify in-IDE)** — `SYSTEMS_ITEM_CODEX.md`.
      FIXED discovery tracking (affixes mutated `name` so nothing above Common registered → now
      keys on immutable `base_name`). Added: legendary `lore`, auto `item_generic_desc`,
      `item_stat_ranges_text` (base stat + per-tier affix ranges), redesigned detail pane with a
      splash-art box. **PixelLab splash art generated + wired for ALL 62 base items**
      (`spr_item_art_*`, `tools/gen_item_art.py`).
- [x] **Consumable menus + combat log scroll (built, verify in-IDE)** — both consumable
      lists (character-menu Consumables tab + in-combat quick menu) now WINDOW around the
      cursor (`ui_list_window_first`) so the selection is always on screen, with ▲/▼ "more"
      hints; mouse hit-testing uses the same window. Combat log rewritten: compact one-line
      entries (≈6 visible vs 3), mouse-wheel scrollback (`combat_log_scroll`, snaps to newest
      on new entries) + scrollbar. All combat events were already logged (DoT dmg, "wore off"
      expiry, status applied, splash/echo) — they were just scrolled off; now visible.
- [x] **AP-restore item fix (built, verify in-IDE)** — "energy" IS AP; items used to hit a
      `min(3)` cap AND pay the 1-AP use fee, so Adrenaline Vial netted ≤0. Now AP items
      (Energy Tonic / Adrenaline Vial / Ley Battery) are **free to use** and **burst above the
      3-AP cap**; pips render surplus AP in orange. All "energy" text → "AP".
- [x] **Run history shows Awakening tier (built, verify in-IDE)** — run record stores
      `ascendance` (= `global.selected_ascendance`); new AWK column shows `A#` (— for old runs).
- [ ] Run the full TEST_CHECKLIST.md after the recent batch (AoE/status, Vex, floor map, UI).
- [ ] Watch for any remaining text-box collisions / missing-glyph (en-dash fixed; em-dash renders).
- [ ] Tidy stray files: `Ironwake.yyp.bak`, source PNGs in `sprite_imports/` (now imported).

---

## 7. Art pipeline (notes)
- Agent CAN create sprite assets on disk (build `sprites/<name>/` + `.yy`, register in `.yyp`),
  and swap enemy art in-place by overwriting frame PNGs (same dims). Use **direct asset refs**
  in code, NOT `asset_get_index` (the latter didn't resolve agent-made sprites at runtime).
- PixelLab available (side-view ~96px to match enemies; resize to 97×97 via PIL NEAREST).
- [ ] Any other sprites that need real art (e.g. remaining placeholder enemies, room/biome art).

---

## 8. Deferred backlog (folded in from retired SYSTEMS_*.md specs)
These were the "deferred / out of scope" tails of now-deleted spec docs (each system is built;
durable details live in the `project_*` memories). Captured here so they aren't lost.

- **Enemies (from enemy-difficulty):** enemy AoE / multi-target abilities; enemy buffs to allied
      enemies (only self-heal today); telegraphed control (wind-up → control); give abilities to
      the remaining basic-attacker enemies.
- **Skins / character (from skins-gender + Vael):** 8-directional skins + idle animation;
      inventory **character viewer** (rotating model + idle anim to show off skin) — both M-wanted;
      female / gender-filtered portrait set (combat-sprite-only for now).
- **Runes (from runes):** add-socket service beyond an item's generated socket count; rune set
      bonuses / multi-rune synergies.
- **Boons (from boons):** boon rarities / weighted offers; higher-tier boons at deeper floors.
- **Alchemy (from Sable):** higher-tier brewing beyond standard→elite.
- **Item Codex (from codex):** per-item hand-written lore beyond legendaries; "New!" badge on
      newly-discovered items; re-roll any splash art that reads poorly (swap PNG, same dims).
- **Loot (from loot-scaling):** drop-*quantity* tuning if still over-geared at low awakening;
      per-source legendary pity timers.
- **Events (from events):** per-item "pick 1 of 2" treasure agency (M declined for v1);
      hand-written art per event.

---

## Suggested order (proposal — adjust)
1. **Quick wins:** ability text audit + Bear Trap→stun + root/stun decision (§2).
2. **Define the 3 NPCs** (§1) — pick what they are; design-lock the Rune system first (biggest).
3. **Run variety** (§3) — boons/events to make it feel like a roguelite.
4. Content + onboarding (§4, §5) as the base fills out.
