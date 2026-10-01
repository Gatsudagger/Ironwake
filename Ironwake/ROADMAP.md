# Ironwake — Roadmap (the one live task board)

Rebuilt 2026-09-29 from a full review of every markdown file against the code. This is the only
list of open work: when something ships, strike it here and move its design doc to `docs/systems/`.
The previous board is archived at `docs/_done/ROADMAP_2026-07.md`.

## Where the docs live

| Place | What it holds |
|---|---|
| root | Live docs only: this board, `CLAUDE_SETTINGS.md` (session rules), the two design docs still being built (`DESIGN_IMPROVEMENT_PLAN_0924.md`, `DESIGN_BIOME_ACTIVE_0902.md`), `UI_BANDS.md` + `MOBILE_UI_PATTERNS.md` (UI rules), `UPDATE_RUNBOOK.md`, `CREDITS.md`, `PRIVACY_POLICY.md` |
| `docs/systems/` | As-built references for shipped systems (SYSTEMS_*, the built DESIGN_* docs, achievements, creature art lock). "Awaiting F5" lines inside them are historical. |
| `docs/store/` | Steam / Play tracking, store kits, localized listings, Deck notes, trailer plan |
| `docs/_done/` | Finished plans, one-off batches, audits, old checklists. History only; nothing open. |

## Reserved names (check here before naming anything new)

Shipped meanings, so new features must not reuse them:
- **Momentum** = Strike's AP refund on a kill + the Brutal/Phantom Momentum talent nodes. The planned meter is **Fervor**.
- **Overwhelm / Overwhelmed** = the 2+ distinct statuses rule (+15% damage taken) and a talent keystone. Planned auto-resolve is **Rout**.
- **Ledger** = Bairc's expedition screen (THE LEDGER). Also used by NPC history logs and *The Jailer's Ledger* event. The planned Vault gamble is **The Count's Tally**.
- **Mark** = Hunter's Marks (kill tiers) and *Marked for Death*. Elite suffixes are **affixes**.
- **Ironhide** = a Boon and an item base name. The pet Calling is **Stonehide** (save id `ironhide`).
- **Keepsake** = shelf items in Bairc's hut. Other rewards use **trinket** or **token**.
- **Storied** = the 7 Contracts finale items (rarity 4, exempt from the perm-level equip gate).
- **Guard / Staggered / Covered / Pulled / Fervor** = the P2 combat mechanics (09-29). "Guard" is also the pet stance word (Guarded) - say "guard bar" when you mean the break bar.

## 0. Waiting on M (verify, then strike)

- [ ] Contracts 7-point F5 checklist (memory `project_contracts_build_0929`)
- [ ] 09-29 audit fixes: touch/mouse entry arms Contracts cards · resume keeps Contracts state · runes come back on hand-over · Storied items wearable at any level · Bloodnose / Packmule combat echoes · Calling "Stonehide" · "Elite Affixes" wording · name fusion fallback (new drops never read "of X of Frost") · Bairc station footer rows line up with their labels · stash HOARD strip moved into the STASH header
- [ ] 09-28 stack line by line (memory `project_resume_0928`); hut interior F5 (memory `project_hut_interior_0922`)
- [ ] 09-29 BUILD BATCH (see below): the 09-28 screenshots fixed (ledger re-stack + opaque backdrop, cart pitch), Contracts leftovers, P0b, P2 combat depth - all awaiting F5
- [ ] "visual disparitiy with old mobs" = art decision: queue a re-author pass for the old enemy sprites?
- [ ] Char-select stat captions still say "+1.5% per point" (stale)
- [ ] Play 1.0.7 production verdict

## 1. Contracts leftovers  (`S`, docs/systems/DESIGN_QUESTS_0925.md)
- [x] §6 bond effects (09-29): Companion+ = 30% one card DOUBLED (coin x2 / boon armed twice / both items); Lover = the finale carries BOTH paths' affixes
- [x] The three story bounties now name three different Vault elites: Stone Golem (Dorn), Vault Guardian (Vex), The Second Count (Petra; step renamed "Collections")
- [ ] Optional: one shelf keepsake per finished chain (text + existing icons, or 7 tiny trinket sprites = ART)

## 2. Improvement plan P0b  (`S` each, DESIGN_IMPROVEMENT_PLAN_0924.md §4)
- [x] Stash filters (09-29): SLOT [F] / RARITY [R] / SOCKETED [G] / SEARCH [/] on the equipment tab, chips on touch + mouse, pad X / Y / R3 (no "cursed" filter until cursed items exist)
- [x] Touch: hold-to-preview on the ability bar (already built: long-press = detail); long-press an enemy bar or model PINS its inspect panel, any tap unpins
- [ ] Bottom-docked End Turn on touch (revisit with an S25 pass - the touch layout is M-tuned)
- [ ] Standard compare tooltip everywhere · codex completion bars (`seen / total`) + 3 achievements · floor-map route preview

## 3. P2 — combat depth  (`L`, plan §2)
- [x] 2.1 Cover (09-29): role-based lines (ranged/caster = back), melee gate, -10 ranged acc, COVERED/PULLED tags, Bear Trap + Tripline pull on spring. NOT built: the Heel "go through the pet" rule (§8.7), the Shrouded affix
- [x] 2.2 Break bar (09-29): guard 25% on elite/boss headliners, weakness x2 / DoT x0.5 chip, STAGGERED = lose a turn + 30% taken, refill 60%. NOT built: the T2 finisher ring on stagger
- [x] 2.4 Fervor (09-29): +15 per new category / +10 parry / +20 interrupt / +10 stagger, -20 per turn, 100 = +1 AP. Finishers come with Oaths in P3
- [ ] 2.7 Coup de grâce ring · Rout (auto-resolve trash, A2+) · Warcry pack-leader intent
- [ ] 2.6 Battlefield props per biome (ART: 5 props, ~10 gens, needs M's YES)

## 4. Biome active mechanics  (`L`, DESIGN_BIOME_ACTIVE_0902.md §2-§7)
- [ ] Hollow Canopy: vertical climb map, breaking bridges → drop + 2-3 node spur, Cut the Vine ring
- [ ] Tundra Tomb: control rings (Tundra only) + roster riders (Glacial Beast, Frozen Sentinel, Glacial Warden freeze phase)
- [ ] Scorched Depths: vent rhythm on the floor map + The Quench
- [ ] Ashen Vault: The Count's Tally (Settle / Carry + Candle Thief ambush)
- [ ] Biome events for the above (Rope-Wright, Long Way Round, Bellows rhythm, a Tundra practice event, Jailer's Ledger as the Tally explainer) + coach-marks + lore

## 5. P3 — character identity  (`L`, plan §3 + §4.6)
- [ ] 3.1 Oaths (2 per class, at Vex) + 6 Finishers
- [ ] 3.2 Heirloom slot + cursed items (Sable) — covers the old "CURSED ITEMS" backlog item
- [ ] 3.3 Dye tints (palette shader, Vael) · 3.4 Scars · 3.6 Heraldry
- [ ] 4.6 Settings: colorblind palettes, reduce flashes, auto-end turn, damage-number size, shake slider, replay tutorials

## 6. P4 — content  (`L`, plan §5)
- [ ] 5.2 Nemesis (built on the Contracts bounty plumbing)
- [ ] 5.3 Weekly Anomalies + Steam leaderboards (Android: local score)
- [ ] 5.6 Keys, secret rooms, relic consumables · 5.7 Descent Trials · 5.8 Ledger Egg + rescue arrivals

## 7. Parked backlog (needs a design pass before building)
- Cloak / back slot (full item family + icons; touches save/equip/shop/reforge)
- Crit split phase 2 (ranged vs melee channels)
- Rune set bonuses; add-socket service
- Boon rarities / deeper-floor boon tiers; higher-tier brewing at Sable
- Enemy AoE / multi-target abilities; telegraphed control; abilities for the remaining basic attackers
- Loot: per-source legendary pity timers; drop-quantity tuning
- Higher risk at higher Awakening (harsher traps, more intense events)
- Hardcore achievement set (docs/systems/ACHIEVEMENTS_FUTURE_IDEAS.md)
- 8-direction skins + idle, inventory character viewer
- Salvage VFX + SFX (puff + dust + sound)
- Stormcrag as a real dungeon, or delete the name (`dungeon_display_name`)
- Code tidy: dead `desc_short` / `desc_full` arrays in scr_abilities; decide Plague Touch's `mortality` now that some enemies heal

## 8. Art / audio debt (every item needs M's per-batch YES; see CLAUDE_SETTINGS cost rules)
- 26 species without adult art (they stay gated); idle-animation parity for the single-frame expansion sprites
- Depth Warden models (stand-ins live)
- Old-enemy visual disparity (screenshot above)
- Biome ambience beds: Drowned Reach and Hollow Canopy borrow Tundra / Vault air (`dungeon_ambience_bed`)
- Pet walk cycles for the garden (idle-hop today)
