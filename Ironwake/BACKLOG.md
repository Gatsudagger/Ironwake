# IRONWAKE — MASTER BACKLOG (compiled 2026-08-13, priority-stamped 08-13 night)

## ⚠⚠ SUPER PRIORITY — FINISH THE UNBUILT SYSTEMS (M directive 08-13 night)
Work these to DONE, in order, before anything else tomorrow:
1. **M's F5 verdict on round 12** (subtle forced perspective, VFX binding) + fix fallout,
   then ONE MEGA-COMMIT of everything since db577e6.
2. **Imports (GM CLOSED, one sitting)**: 3 elemental summons (magma_IDX0 / ward_IDX3 /
   storm_IDX2 → replace the pedestal placeholder in combat Draw "THE STANDING SUMMON")
   + bone_sovereign_IDX3 · WALL_D+FLOOR_D plane pilot · bloodwarden_m_R2_IDX3 needs a
   SOUTH-FACING regen first (1 pro call, ≥8px canvas margin — clip rule).
3. **Font size selector** (design locked: Small/Default/Large all platforms,
   overflow→scroll w/ visible bar, never shrink Large).
4. **Vael grey twins** (5 sprites, `tools/make_vfx_grey_twins.py`, 0 gens, GM closed).
5. **Stats tab: +1 loot-rarity-tier boon missing** from Boons & Effects list.
6. **Enemy pure-debuff cast VFX** (last VFX-less category).
7. **SYSTEMS docs** for initiative / summons / wardens / duelist tiers (spec lives only
   in code comments today).
8. **The Bottom** clear title/splash (descent floor 50 — owed since Wardens went live).
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
