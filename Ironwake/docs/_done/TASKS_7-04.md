# Task Batch 2026-07-04

**STATUS: ALL BUILT 2026-07-04 (same day), UNCOMMITTED — see CHECKLIST_7-04.txt for M's review list.**
Everything below is implemented except E1 (two base-art candidates staged in screenshots/ awaiting M's pick before upscale+import). A7 closed as no-bug. B7 deposit replaced by at-risk HUD split + tutorial tip (deposit is mechanically unnecessary — pre-run gold is already death-safe; flagged to M).

Source: M's task list. Investigation verdicts recorded inline. Design-locked once numbers are agreed.

## Batch A — Combat UI / clarity fixes
- [ ] A1. Damage popup position: move over the player sprite (currently off to the side).
- [ ] A2. Pet sprite partially hidden behind the combat text log — reposition pet or log so both read.
- [ ] A3. Turn-order strip obstructs the new intent (atk) indicator above enemy nameplates — restack.
- [ ] A4. Enemy nameplate debuff rows collide with the nameplate below when stacked — tighten layout / clamp icon rows so each enemy's debuffs are inspectable.
- [ ] A5. Loadout ability-select scroll: view scrolls while selector sits at 2nd-from-bottom instead of scrolling at list edges (both directions); make selector highlight bolder, and make focus vs "Enter Dungeon" button state obvious.
- [ ] A6. Hit preview accuracy (VERIFIED partial): `combat_estimate_hit` omits Vanish +12, Aspect rune %, detonation bonuses, school flat damage, ability riders (Arcane Echo/Killing Spree), and previews the HOVERED target which can differ from the actual hit. Fix: fold in all deterministic pre-cast modifiers (vanish primed, aspect %, school dmg, riders, detonation base) so the number is honest; keep "approx." for crit/roll variance. Also add the missing "Vanish +12" line to the combat-log hover breakdown popup so components sum to the total.
- [ ] A7. Hit chance display (VERIFIED NO BUG): display math exactly matches combat_roll_hit two-stage roll (Acc% then Dodge%). 91% ≈ 1 miss in 11; streaks are RNG. No change unless M wants a "recent rolls" debug readout.

## Batch B — Systems / bugs
- [ ] B1. Shrine sacrifice: show the actual item (icon + hover-inspect tooltip) when offered; on confirm play a sparkle flutter + result popup ("Offered X — received Y").
- [ ] B2. Post-combat HP display shift during extract/descend prompt (suspected visual-only, HP bar seems to show base HP). INVESTIGATE: likely the bar reads max_hp from a struct rebuilt without gear bonuses, or out_of_combat vs in-combat HP source mismatch.
- [ ] B3. Unequip HP rule: unequipping +HP gear must NOT reduce current HP below current value — only clamp when current > new max (20/40 minus 10 max-HP item ⇒ 20/30). Guard heal-cheat: equipping +HP gear raises MAX only, never current.
- [ ] B4. Pet stage-up bug (Luna moth READY, run completed, no evolve): wiring end_run→pet_run_complete looks correct; suspects = result code on the extraction path M used, pet_active() lookup, or notice shown but sprite/stage not refreshed. NEEDS DEEPER TRACE.
- [ ] B5. Rest sites scale with Awakening — LOCKED: heal = 15 + 4×tier + 5% max HP (A0: 15+5%; A4: 31+5% ≈ 41 @ 200 HP).
- [ ] B6. Enemy count RNG — LOCKED: awakening-shifted weights. A0-A1: mostly 2-3, 4-pack ~10%. A2-A3: 3 common, 4-pack ~25%. A4-A5: 4-pack ~40% + occasional 5-pack.
- [ ] B7. Run gold display: show gold FOUND THIS RUN (not total). Gold-deposit-to-stash option (verify whether it exists; add if not) + tutorial coach-mark ("Deposit your gold — you can lose what you carry!").

## Batch C — Items / features
- [ ] C1. Genie Lamp — LOCKED: ~1.5% drop from elite/boss kills only; usable mid-run (not at post-boss prompt) = free escape to hub with all run loot, as an extraction; logs boss clears already earned.
- [ ] C2. Devil Wine — LOCKED: Alchemist elixir @ 1200g; on drink: permanently lose 3 random stat points, extract to hub with all items (reliable, controllable lamp-equivalent with a real cost).
- [ ] C3. Eggs as items: remove "creatures found" from equipment tab; eggs appear in the Found items list with egg icon, named "Mysterious <Egg Type>", all other info "??" until identified (paid) at Bairc.

## Batch D — Journal consolidation
- [ ] D1. Move Compendium into Journal.
- [ ] D2. Move Item Codex (hub menu option) into Journal.
- [ ] D3. New Bestiary tab in Journal: brief lore description per enemy species.

## Batch E — Art (PixelLab, base-image approval required before animating/import)
- [ ] E1. New "Enter the Dungeon" screen: keep the retro blue-demon-over-treasure-chest concept but more gothic / retro-fantasy to match the game's aesthetic.

## Investigation verdicts (done 7-04)
- Snipe 17-vs-52 (screenshot): preview showed Stone Golem (high armor) while the 52 hit landed on Vault Crawler, with Vanish +12 active; estimate also skips aspect rune +20% and detonation. Preview under-reports by design gaps → fix via A6.
- Hit chance: display and roll use identical math; no bug (A7).
- Awakening does NOT scale the player anywhere in code — only enemies (acc/heal/stats) and loot. Lower-awakening damage feel = likely detonation uptime / signature-pet acquisition bonus, not a bug.
- Pet stage-up: no obvious wiring fault; needs trace (B4).
