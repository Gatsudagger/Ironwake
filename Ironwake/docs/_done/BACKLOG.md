# IRONWAKE — MASTER BACKLOG (compiled 2026-08-13, priority-stamped 08-13 night; STATUS refreshed 08-16)

## ⚠ STATUS 08-16 — three commits since this file was compiled, ALL M F5 CLEAN
- `4e8fd81` (08-15): font selector end-to-end (4 fonts imported), craft wizard v2 + visual
  polish, study ladder 1/3/6, chaotic brew, elemental-rune rework (Ember=fire, 6 school runes
  + Avatar), fix-now queue cleared, 18 icon sprites imported + wired.
- `b6f692e` (08-15): notes list #4 (clicking works everywhere, Runesmithing rename, corruption
  betrayal + cure confirm, Wounded Wanderer fever, Merchant's Ghost popup shop + 6 exclusives,
  loot-curve squeeze, Weapon Shot conditional element, HUD reorder, stats-page crit split,
  bond popup hearts, tab hover quick-refs, Bone Sovereign flip), accuracy split (Hunter/Seer),
  Blazing Palm 16+Sear, Quintessence specialty brews, **NPC PROGRESSION ranks core** (11 perks),
  4 offhand icon regens imported.
- `21f3c9e` (08-16): 7 NPC first-open tours, **EVENT HORIZON** (Singularity rework), Petra two
  orders, Maren Deep Socket, all rank perks wired + SYSTEMS_NPC_PROGRESSION.md, **BAIRC'S GARDEN
  scene** (pan/pond/cairn/forage/petting/8 ornaments/[M] jukebox), 5 music tracks imported
  (Stillwater/Greenhollow/Tidesong/Garden of Ages/The Black Aria), banshee rework, Bairc
  rank-1 ledger, found-strip scroll; 08-16 fixes: carousel STATION corner chip + hover tip +
  checkout popup, station_ranks tutorial, procedural bond hearts.
- So: section **A below is COMMITTED**; **F "NPC progression tiers" is BUILT**; **G "Bairc's
  walkable garden" is BUILT**; E7 icon batch + buckler icon are DONE. Remaining open threads:
  track-name vetoes, banshee chest cap 12 (my call), pad has no hub button for [U],
  Settings garden-music row deferred, design-lock queue in memory (Arcanist spells, accuracy
  rune stacking audit, talent audit, pet treats, enemy immunities, pet move pools, mobile UI,
  SFX audit, dungeon reagents, Seer rune icon).
- **08-17 "DO IT ALL" SESSION (uncommitted, awaits M's F5 - see SYSTEMS_BATCH_0817.md):**
  accuracy-rune cap 12 (+tip/hover), talent audit (Keen Edge / Blink bespoke / numbered durations),
  Arcanist PARALYTIC PULSE + CALL OF THE VOID (icons pending pick), enemy family IMMUNITIES
  (sweep + bestiary/inspect), pet MOVE POOLS + priority AI + log/VFX, 6 FAVORED TREATS,
  dungeon REAGENTS at Dorn's craft + 5 sell-only VALUABLES, station rank [U]/L3 inside NPC
  screens, role-aware egg gifts, Seer rune icon, SFX_VFX_AUDIT_0817.md (itch.io list),
  species art: canopy_shrew (PRO-character route, tools/progen.py) + cairn_bear (still+idle
  route, tools/ffgen.py) IMPORTED fully animated; 26 species queued per the M-locked route split
  (memory project_notes_batch_0817); PixelLab 2,390 gens left.
  Post-08-16 commits d1c8268..16f9dc2 (facing flag, Dorn bond drip, loot tier caps, offhand
  icons, Bairc legend, capstone descs, %-affix halving + STAT RESISTS) all M F5 CLEAN.
- **LAUNCH WED AUG 19 — stabilize over new systems.**

## ⚠⚠ SUPER PRIORITY — FINISH THE UNBUILT SYSTEMS (M directive 08-13 night)
Work these to DONE, in order, before anything else tomorrow:
1. ~~M's F5 verdict + ONE MEGA-COMMIT~~ ✅ DONE 08-13: `ada611d` (M F5 CLEAN, 124 files).
2. ~~Imports~~ ✅ 08-14 GM-closed sitting DONE: 4 fonts + 3 elemental summons (wired,
   pedestal placeholder gone) + 5 grey twins, all registered + anti-strip'd.
   **Bloodwarden south face: DEAD** (M ruling after regen + rotate both missed) —
   R2_IDX1/IDX2 imported instead as Vael-only Bloodwarden CLASS SKINS (Crimson
   Vanguard 600g / Winghelm Warden 750g — prices vetoable). 4 horned-knight
   candidates parked as future alt skins.
   **+ PORTRAIT GATING SHIPPED**: char creation = 3 confirmed picks per class+gender,
   full 60 at Vael's 100g tab; shadow_f4 is a stand-in M may replace by generating.
3. **Font size selector** — ✅ CODED 08-13 (awaiting F5 + the font import above):
   ui_font() resolver + 960-site sweep, Settings row 6 (all platforms, touch tap path,
   settings.ini [ui] font_size), combat-log pitch now measured (fewer rows on Large,
   never overlaps). Until the fonts are imported the selector shows but text stays
   Default. Large-mode overlap audit = M play-pass, fix per report.
4. **Vael grey twins** (5 sprites, `tools/make_vfx_grey_twins.py`, 0 gens, GM closed).
5. ~~Stats tab loot-rarity boon~~ ✅ 08-14: curse rows now show their PAY line
   (+N loot tier / +gold% / +dust%) beside the name.
6. ~~Enemy pure-debuff cast VFX~~ ✅ 08-14: baleful glyph trace at the player's
   feet (ember=DoT, violet=debuff/control) + delayed dark burst.
7. ~~SYSTEMS docs~~ ✅ 08-14: SYSTEMS_INITIATIVE / _SUMMONS / _DEPTH_WARDENS /
   _DUELIST.md written from code.
8. ~~The Bottom~~ ✅ 08-14: descent_bottom_cleared PERSISTED (was write-only),
   "the Bottom's Witness" epithet, "THE BOTTOM YIELDS" splash banner.
MISC FIXED 08-14 (M's notes sweep): pack-full popup now waits for the WHOLE
victory chain (overflow_stage_reached gate — it flashed during the victory
pause, then again after loot); Sable brew/chaos desc-vs-price collision (Devil
Wine); smelt popup 76px rows (subtext was straddling the border); per-species
enemy_size_mult hook (5 seeded, tune freely); UI_BANDS 2.5D table refreshed;
Second Wind stale cleanse comment synced.
9. **28 zero-art species** are the biggest UNBUILT-system gate: 12 already-wired innates
   are dead content until they exist (recipes locked; pro-tier, style-anchored,
   native-res + clip audit before M sees anything).
Rules in force: style anchor mandatory · canvas margin ≥8px · native-res audit ·
2-strike stop · summons face EAST (bloodwarden ask = south) · UI_BANDS 2.5D stage table.


Compiled from every open memory record + ROADMAP.md. Steam launch is **Wed Aug 19** —
six days out. Sections are ordered by how blocked-on-you they are, not by size.

---

## A. BUILT — SITTING IN THE WORKING TREE, AWAITING YOUR F5 (one mega-commit)
Everything since commit `db577e6`, all coded, none reviewed in-game:
- **Notes-list #1 fix batch** (25 items) + **class identity pass**: Shadow Step 2-charge/2-CD
  + talent nerf, Bloodwarden blood price (Gore Strike / Marrow Crush ~5% max HP),
  base 5 ability slots / Expanded Arsenal 6th, Clotted Armor trunk node.
- **All three Arcanist summons** (Magma Golem / Warding Effigy / Static Husk): cast, standing
  intercept, detonate, cooldowns, Vex pricing. *Render is a placeholder pedestal+orb.*
- **A5 boss elite summons** + Pale Archivist moved to tundra elite pool + summon crash fixes.
- **2.5D rounds 3–9**: two-plane stage, linear convergence, bbox-anchored feet + clipped
  shadows, station layouts w/ containment, frozen stations, nameplate x-ordering, pet stagger.
- **Notes-list #2 batch**: VFX targeting (projectiles no longer fly at nameplates), VFX pacing
  (2/3-AP moves get longer, bigger bursts), silence "…" bubble, per-kind debuff tints, unified
  bleed VFX, Iron Skin iron-shell, Snipe arrow, Restorative Glyph rune-trace + delayed bloom,
  heal role split (Field Dressing triage / Second Wind burst), **weapon strikes rework**
  (Weapon Strike + Weapon Shot, elemental affix gated to weapon actions + Edge-Carried talents,
  affix roll 40%→15%), description audit (primary line = authoritative), pack-full modal input
  fix, Bairc portrait fill, Whetstone dupe/no-op edges, mobile hub flavor-line clamp, title
  legend, intro-crawl sharpness.

## B. COMMITTED (db577e6) BUT NEVER REVIEWED IN-GAME
Systems that work in code and need your play-pass verdict:
- **Depth Wardens live in Descent** — all 10 hooks; sprites are STAND-INS (veto pending).
  "The Bottom" clear title/splash still owed.
- **Initiative v1**, **enemy summons**, **duelist tier kits (T1–T3)**, **awakened FX v2**
  (tuning levers: pulse cycle, echo alphas, mote count), duelist 122px size check.
- 28 innate/signature fx read sites — *12 of these are dead content until their species get art
  (section E)*.
- SYSTEMS docs for initiative/summons/wardens/duelist not yet written (code comments carry spec).

## C. BLOCKED ON YOUR PICK / VERDICT (fast to clear, mostly review sheets)
1. **Magma Golem INDEX 0–3** — `_for_review/summons_0813/SHEET_magma_golem.png`; then animate +
   import. **Effigy + Husk have no models generated at all.**
2. **2.5D continue-or-kill** after the round-9 F5 → unlocks the held prop-art run (~40–60 gens
   approved) and per-dungeon painted plane pairs.
3. Review sheets awaiting picks (`_for_review/`): awakened wave-1 bases (bone_stag /
   saber_hound / hollow_pup R2), reauthor_batch2 (ashjaw_lynx, permafrost_toad, wispfox,
   gravefox), wardens (First Door good; Weight needs a pro pass), scholar origin still A/B.
4. **Vetoable numbers**: Pattern Book fees/bands/budget, Tripline Exposed +3, Vex stat-buy
   curve, Debtor %, sell bands, minor-boon pool, mutator %s.
5. **Design Qs**: Fortune pet + Tender Egg gift does nothing (role-aware egg gifts?);
   3 round-9 screenshots to re-verify in-game.

## D. DESIGN-LOCKED, NOT YET BUILT (code work, no design needed)
1. **Font size selector** — Small/Default/Large, all platforms, overflow→scroll with visible
   bar, Large never shrinks. *First item next session.*
2. **Vael grey twins** — 5 VFX grey-twin sprites via `tools/make_vfx_grey_twins.py`
   (0 gens; GM closed + your go). Makes frost/shock/blood/shadow/poison tints actually visible.
3. Enemy **pure-debuff cast VFX** (damaging casts + heals covered now); enemy **prep-turn
   auras** (you okayed parking).

## E. THE CREATURE / ART DEBT (approved recipes, unfinished runs)
1. **16-species re-author run** (4 of 20 done: lockjaw, null_hound, pyre_bison, stormkirin).
   Remaining: 8 generic + 7 scions + sluice_otter odd-size. Recipes + import scripts ready.
2. **28 zero-art species** (22 generic + 6 scions incl. doorling, tallykeep, leviathan_calf) —
   these gate 12 already-wired innates.
3. **Idle-anim parity**: the 120 expansion sprites are single-frame beside animated originals.
   Your call was SOUTH-first pilot (few species → review → ~60-anim run, ~1,200 gens).
   Not started.
4. **19 flagged adults** read "jarringly childish" (45–64px vs 124px shipped) — judge in-game
   per species, re-author worst offenders.
5. **Awakened art** — FX-first direction shipped; bespoke stills only where the axis changes
   silhouette (e.g. bone_stag cathedral antlers). Per-species design rounds with you, no
   batch-blasting. (Luna bespoke reverted — original adult + FX is canon.)
6. **10 Warden models** (stand-ins live; init trick: img2img from stand-in at str 45–70).
7. **Icon batches (approved, not generated)**: 3 mutator ability icons, 4 mutator-legendary
   icons, 3 dueling-relic icons, **buckler/shield icon** (open screenshot).
8. Root/vine status VFX (approved, never started). Duelist per-ability anims (deferred — combat
   draws enemies at a fixed frame; no play-site yet). Compendium `_e` silhouettes self-heal as
   re-authors land.

## F. NEEDS A DESIGN-LOCK PASS WITH YOU FIRST (from your own lists)
- Pet move pools + pet intelligence.
- NPC progression tiers.
- Enemy immunities / variety pass.
- Mobile UI overhaul (beyond the font selector).
- Portrait gating folder.
- SFX audit → ElevenLabs plan (budget rules apply).

## G. PARKED — POST-LAUNCH (ROADMAP.md backlog, do not start mid-session)
Cursed items · pet divergent growth · Bairc's walkable garden · full attack/spell animation
pass (partly superseded by the VFX overhaul) · cloak/back slot · localization · mobile UI
customization.

---

### Suggested order given Aug 19
1. **F5 + mega-commit A** (everything else stacks on it).
2. Clear **C** in one review sitting (picks are minutes each).
3. **Font selector + Vael twins** (D) — small, launch-visible.
4. **B** play-pass verdicts while testing normally.
5. Creature/art debt (E) is the long pole — post-launch-safe except anything you want in the
   launch build (buckler icon, golem model are the two most player-visible).
