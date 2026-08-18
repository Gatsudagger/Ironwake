# SYSTEMS — 2026-08-17 batch (M design-locked in-session; ALL AWAIT M's F5)

Everything below was built 08-17 from the "do it all today" list. Numbers are M-locked unless
tagged *(my call)*. Code sites named so the next session can find them without grepping.

## 1. Accuracy-rune cap (`RUNE_ACC_CAP` = 12, scr_stats)
- Hunter (ranged attacks) and Seer (spells) rune totals are each capped at +12% —
  `rune_aspect_ranged_acc()` clamps, `rune_acc_total(key)` for UI.
- Surfaced: rune blurbs say "(rune total caps at +12%)"; STATS page Accuracy row hover popup
  (`ui_acc_cap_popup`, both layouts) shows Hunter/Seer totals vs cap; Maren's ASPECTS tab fires
  the `rune_caps` tutorial once (Step gc, Maren block head).

## 2. Talent audit (scr_abilities)
- Keen Edge (generic P1 on damage abilities): **+4 base dmg AND +2% crit** (mods `dmg4`, `crit2`).
- Blink: generic P-side was dead (nothing reads Blink's effect_value/duration) → bespoke:
  P1 Steady Fade (3rd hit softened like the 2nd, rider `blink_even`), P2 Soul Flicker (+1 Soul on
  cast, `blink_soul`), PK Phase Cascade (4 charges = two full dodges, `blink_double`). Combat:
  Step blink cast/consume sites.
- Duration nodes (Lingering Grip / Endurance / Lasting Mark) now name the effect and print
  `N -> N+x` (`ability_web_dur_noun`).
- Sweep result (no other change made): the generic templates have no strictly-dominated
  sibling pairs left; the only "feels worse" pair was Keen Edge vs Heavy Hand (fixed above).
  Instant-effect template p1 "+2" vs p2 "+20%" is tier-ordered by design (p1 wins below 10).

## 3. Arcanist control pair (scr_abilities defs after Soul Engine; combat Step cast block)
- **Paralytic Pulse** — 2 AP, dtype 1 (spell), 0 dmg, is_aoe. EVERY enemy rolls its own 40%
  to be Stunned 1t (control-resist ramp applies). Web: P1 Wider Pulse +10%, P2 Resonant Pulse
  +20% vs already-debuffed foes, PK Lingering Paralysis +1t (`dur`); T-side generic.
  Vex 250g. Category control. SFX school arcane.
- **Call of the Void** — 2 AP + 1 Soul, 10 Void (dtype 2), then ONE random debuff 2t from
  {weaken -20%, silence, root, vulnerable +3, blind -30%} (`element:"void"`). Web PK **Chorus**
  = two different debuffs on the target (`void_chorus`); TK **Spreading Dark** = 2-3 random
  living foes incl. the selected one, damage + independent roll each (`void_spread` → dynamic
  AoE in the target-list build). Vex 400g.
- Icons: string-resolved `spr_ability_paralytic_pulse` / `spr_ability_call_of_the_void`
  (fallback Static Arc / Curse until imported); candidates in `_for_review/icons_arcanist_0817`
  awaiting M's index picks.

## 4. Enemy family immunities (scr_enemies `enemy_immunities(name)`, scr_combat `combat_immune_sweep`)
- UNDEAD → Poison; CONSTRUCT (golem/sentinel/colossus/archon) → Bleed + Stun; SPIRIT
  (wraith/specter/shade/phantom/hollowlight) → Root + Bleed; FIRE-KIN → Burn + Sear; FROST-KIN
  → Chill. (M: undead NOT bleed-immune.)
- Enforced by a per-frame sweep at the top of combat Step (one hook instead of ~40 push
  sites): matching status stripped the frame it lands, "IMMUNE" popup + log line.
- Shown: enemy inspect tooltip ("IMMUNE to …"), Bestiary header line, `inspect` tutorial copy.
- Pet Rend skips bleed-immune targets.

## 5. Pet move pools + priority AI (scr_combat `combat_pet_act`)
- COMBATANT: **Pounce** (target <35% HP, +50%) → **Rend** (no bleed on target: 75% dmg + bleed
  3/2t adult, 2/2t ya, `element:"bleed"`, name "Rend") → **Strike**.
- GUARDIAN priority (unless fulfilled / Guardian Angel do-both): **Mend** if you <40% HP →
  **Cleanse** a harmful status (not in mender/warder stance) → **Snarl** an undebuffed foe
  (Weakened -15% 2t, only while you ≥70% HP) → existing Ward/Mend heuristic + stances.
- Every move is NAMED in the log ("uses REND …") and pushes its own VFX burst
  (`combat_pet_vfx`: blood / slash / impact / heal / buff / fx_weaken).
- Pet detail flavour line lists the pool: `pet_move_pool_text()`.

## 6. Favored pet treats (scr_stats `pet_treat_catalog`)
- 6 new treats (60g) each `favored:[species…]`: Ember Chestnut, Grave-Lily Sugar, Moonpetal
  Wafer, Brine Jerky, Frost-Root Chew, Iron Grub. Favored = **+2 bond** (`pet_treat_bond_for`),
  else +1. Legacy Honeycomb / Candied Marrow stay generic.
- Petra stocks a favored treat only while a LIVING pet that loves it is in the roster
  (`pet_feed_shop_list`). Bairc feed rows: favored treats glow gold + heart + "a favored treat!".
- Icons: new treats borrow the honeycomb icon until an icon batch (`pet_feed_icon` fallback).

## 7. Dungeon crafting reagents + valuables (scr_stats, before `pattern_craft_fee`)
- Reagents: Vault Ash / Cinder Marrow / Rime Salt / Void Silt (one per dungeon,
  `reagent_catalog`). Drops: elites 40% x1, bosses x2 always (of the current dungeon), in the
  drop log as "[Reagent]". `global.reagents` struct persisted (main save + checkpoint + load +
  new game).
- Dorn CRAFT wizard asks **1 / 2 / 3 reagents of any kind** for Uncommon / Rare / Epic on top of
  gold + dust + ingot (`pattern_craft_reagents`); quality rows + checkout show counts;
  `reagent_spend_any` spends largest stacks first. *(numbers my call — vetoable)*
- Valuables (sell-only): Tarnished Locket 40g / Silver Reliquary 120g / Sovereign's Signet 320g /
  Star-Iron Idol 750g / Crown Shard of Ironwake 1600g (`valuable_catalog`, effect_type
  "valuable", rarity stamped). Drop 3% / 8% / 15% (standard/elite/boss), weights common-heavy
  (`valuable_roll`). Both use paths refuse them ("sell it at camp") and never consume them; they
  sell through Petra's existing SELL tab at the normal 40% ratio.

## 8. Station rank from inside NPC screens (pad parity)
- `npc_station_arm(npc_id)` (scr_stats) is the shared arm path (hub carousel [U]/chip AND
  in-screen); `hub_checkout_up()` makes every NPC block stand down while the popup is up.
- In any NPC screen: keyboard **[U]** or pad **L3** (`shop` + `bairc` hotkey maps) arms the same
  checkout; refusals ("already at the top rank") land in the bond dialog. Legends updated
  (Dorn / Vex / Maren / Sable / Vael / Petra / Bairc). Touch keeps the carousel STATION chip.

## 9. Role-aware egg gifts (`pet_egg_effect_for`)
- Savage/Tender eggs CONVERT when the hatchling's role can't use them: Boon (Fortune) pets get
  +5% gold, Guardians turn Savage into +5% heal & shield, Warriors turn Tender into +5% dmg.
  Pet detail shows the converted effect + "(converted for a …)" note.

## 10. Seer rune icon
- `spr_icon_rune_seer` = 0-gen arcane-blue hue-map of the ember crystal, imported + anti-strip.

## 11. Species art pipeline (tools/ffgen.py, tools/import_species_ff_0817.py, tools/gm_import.py)
- FF-style 64px pro recipe (adult_s from text → M pick → adult_e / youngadult / baby from the
  pick as character base). Sheets + M picks tracked in `_for_review/species_ff_0817/`
  (JOBS.json, CURATED.json). Imported so far: cairn_bear (6 sprites).

## 12. Species art gate = ALL 3 STAGES present + east mirrors south (08-17 late)
- M rule: "if there are all 3 visual stages they can be in game if the e and s match or if it
  just uses one; animations later; we can't have MISSING art." `pet_species_has_art()` now =
  baby + youngadult + adult south sprites all exist (static stills count; east falls back to
  south in pet_sprite). 47 species LIVE; 26 with no/partial art excluded (ember_ram salt_hare
  mire_heron gravel_tick glass_eel chapel_bat barrow_mole tallow_moth gravemask bristleback
  crypt_gryphon threehunger wing_hare drowned_lamp honeymaw bark_hound pressure_snail
  flicker_finch rust_vole paleswimmer doorling tallykeep sum_moth mimicling chorister_fry
  leviathan_calf).
- Boss eggs (`pet_try_boss_egg`) and Depth-Warden drops (scr_combat `combat_on_enemy_defeated`)
  were NOT art-gated: Descent Wardens 5/15/30/40 (doorling/tallykeep/sum_moth/mimicling) could
  drop eggs hatching into invisible pets. Now: unfinished signature -> generic art-gated egg,
  scion NOT marked in pet_sig_history (still catchable once its art lands).
- 08-06 static wave (16 species: ashjaw_lynx wispfox gravefox frostmarten snowmaw permafrost_toad
  icewing_skua witchwood_fawn fathom_squid lantern_wyrm deepclaw griefwisp sluice_otter graftling
  thornlet whispervine): the `_e` renders carried baked "BABY"/"ADULT" text + mismatched designs
  -> tools/mirror_e_from_s.py rebuilt all 48 `_e` sprites as exact clones of `_s` (0 gens).
  Known oddity left for M: griefwisp stages read ghost -> tombstone -> tombstone.
- Egg types: all 10 have still + 9f hatch art - nothing to generate.
- Cairn bear ADULT idle = tools/cairn_bear_breath.py (0 gens): 56f @ 20 fps slow exhale (PixelLab
  heave cross-faded + procedural breath cloud). `pet_anim_frame` honours a sprite fps > 8 (else
  the shared 120 ms); `gm_import.build_anim_sprite(fps=)`. M approved ("good enough").

## F5 VERIFY LIST (M)
Aspects tab tip + Accuracy hover; Keen Edge/Blink nodes in a web; Paralytic Pulse on a pack
(popups STUNNED! / shrug lines) + Call of the Void with Chorus/Spreading Dark; IMMUNE popup on a
golem hit with a bleed; pet log lines "uses REND/POUNCE/MEND/CLEANSE/SNARL" + bursts; Petra shows
a favored treat only with a matching pet; Dorn craft asks reagents (rows + checkout) after an
elite drops one; a valuable drops and sells; [U]/L3 inside Maren arms the STATION popup; a Tender
Egg on a Fortune pet reads +5% gold; Seer rune icon in Maren's lists; cairn_bear rolls at Bairc.
- [ ] Bairc/garden: cairn bear ADULT breathes at 20 fps (slow exhale, closed mouth); other pets unchanged pace.
- [ ] Static-wave pets (e.g. wispfox) face right in combat with the SAME still as front (no BABY/ADULT text).
- [ ] Descent Warden 5/10 kill with drop -> generic egg (no invisible Doorkeeper's Cat / Fathom Squid).
