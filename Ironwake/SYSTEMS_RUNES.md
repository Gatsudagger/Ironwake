# SYSTEMS — Rune System (Maren the Runesmith)

**Status: Phases 1-3 BUILT (verify in-IDE). Rune system feature-complete. Confirmed by M.**
Phase 2: 8 standard aspect runes + Aspects tab + slot unlock + dust trickle.
Phase 3: Maren's **Forge** tab (Combine / Split / Craft Flagship), and the two
flagship runes (Quickcast/Echo) are now obtainable + wired:
- **Quickcast** — first spell each combat costs −1 AP (per-combat flag).
- **Echo** — first AoE each combat deals a **50% second instance** to every enemy hit
  (locked w/ M after auditing AoEs: Rift/Singularity are pure-damage, Smoke Bomb
  rider-only — the 50% echo serves the two damage nukes; "+2 turns on rider" would have
  no-op'd them).
Anchor's Weaken magnitude = **0.20** (vs 0.30 for dedicated weaken abilities).
The shared **dust faucet** is finalized by **Sable salvage** (built same session, own doc).
Owner NPC: **Maren the Runesmith** (hub, currently `[Locked]`).
Related: shares the **rune dust** economy with **Sable the Alchemist** (see §8).
Built on the existing **attack-classification system** (`SYSTEMS_ATTACK_CLASS.md`) —
Aspect runes target action *categories*, not individual abilities.

---

## 1. Core idea — two rune domains

Runes never socket into a *specific ability* (messy: per-ability state, fights future
ability-leveling, heavy UI). Instead there are two clean domains:

| Domain | Sockets into | Purpose |
|---|---|---|
| **Gear runes** | Sockets on equipped gear | Flat/stat bonuses (HP, STR, crit%, resist…) |
| **Aspect runes** | Character-level **Aspect slots** | Behavior/affinity buffs keyed to **attack-class + damage-type** categories — the ability-augment layer |

Aspect runes survive ability leveling because they buff a *category* ("all elemental
spells", "melee attacks", "ranged accuracy"), never a named ability.

---

## 2. Data model

```
// A rune instance
rune = {
    id:     "ember",        // unique key into the rune catalog
    name:   "Ember",
    domain: "gear" | "aspect",
    tier:   1 | 2 | 3,
}
```

New globals (added in obj_game_controller Create, with save backfill — mirror the
traits_unlocked backfill loop pattern):

```
global.rune_inventory = [];    // unsocketed runes the player owns (array of rune structs)
global.rune_dust      = 0;     // shared reagent currency (Maren + Sable)
global.aspect_slots   = 2;     // unlocked character Aspect slots (start 2, cap 4)
global.aspect_runes   = [];    // socketed Aspect runes, length <= aspect_slots
```

Gear runes are stored **on the item struct**:
```
item.socket_count = <int>   // capacity, set at item generation by rarity (see §3)
item.runes        = []      // socketed gear-rune structs, length <= socket_count
```
Items already persist in `global.inventory` / `global.equipment_stash` /
`global.carried_items`, so socketed runes ride along with them. Save schema +
backfill must default `socket_count`/`runes` on legacy items.

---

## 3. Sockets

**Gear socket count by rarity** (set when the item is generated):

| Rarity | Sockets |
|---|---|
| Common | 0 |
| Uncommon | 1 |
| Rare | 1 |
| Epic | 2 |
| Legendary | 3 |

- Items generate with `socket_count` = their rarity cap above.
- (Phase 2 nicety) Maren can *add* a socket to an item that has fewer than its cap, for
  gold + dust. Deferred — Phase 1 just uses the generated count.

**Aspect slots:** start **2**, expandable to **4**. +1 unlocked via Maren (gold + dust,
escalating) and/or ascendance — exact unlock cost set in Phase 2.

---

## 4. Rune catalog — GEAR runes

Numeric bonuses fold into the equipment bonus pipeline (`apply_equipment_stats` in
scr_stats). Magnitudes scale by tier I / II / III:

| id | Name | Effect | I | II | III |
|---|---|---|---|---|---|
| `vitality` | Vitality | +Max HP | +15 | +35 | +70 |
| `might`    | Might    | +STR | +1 | +2 | +4 |
| `finesse`  | Finesse  | +DEX | +1 | +2 | +4 |
| `fortitude`| Fortitude| +CON | +1 | +2 | +4 |
| `insight`  | Insight  | +INT | +1 | +2 | +4 |
| `keen`     | Keen     | +Crit chance | +3% | +6% | +12% |
| `warding`  | Warding  | +Elemental resist | +5% | +10% | +18% |
| `evasion`  | Evasion  | +Dodge | +2 | +4 | +8 |

> Implementation note: exact stat hooks (e.g. how resist/dodge are stored) get verified
> against scr_stats during Phase 1; magnitudes above are the design-locked intent. If a
> stat hook doesn't exist yet, flag to M rather than inventing one.

---

## 5. Rune catalog — ASPECT runes (the ability-augment layer)

Each Aspect rune buffs an action **category** derived from the attack-class system
(melee/ranged × attack/spell) and/or damage type (0 physical / 1 elemental / 2 drain /
3 blood). Queried at combat resolution via a new `rune_aspect_bonus(...)` helper.

| id | Name | Category it affects | I | II | III |
|---|---|---|---|---|---|
| `ember`     | Ember     | Elemental damage (dtype 1) | +10% | +18% | +30% |
| `serration` | Serration | Physical **attacks** (melee+ranged attack, dtype 0) | +10% | +18% | +30% |
| `hemorrhage`| Hemorrhage| Blood damage (dtype 3) | +12% | +20% | +34% |
| `hunter`    | Hunter    | **Ranged** action accuracy | +8% | +14% | +22% |
| `bulwark`   | Bulwark   | On **melee attack** hit → gain shield | +2 | +4 | +7 |
| `leech`     | Leech     | **Drain** (dtype 2) abilities heal extra | +20% | +35% | +60% |
| `surge`     | Surge     | **Spell** crit chance | +4% | +8% | +14% |
| `anchor`    | Anchor    | **Melee attacks** apply Weaken (turns) | 1t | 1t | 2t |

**Flagship (tier-III-only, rare):** craft or legendary-drop only.
| id | Name | Effect |
|---|---|---|
| `quickcast` | Quickcast | Your **first spell each combat** costs −1 AP |
| `echo`      | Echo      | Your **first AoE each combat** also applies its rider effect at full duration |

---

## 6. Combine / Split (Maren's Forge)

- **Combine:** 3× identical runes (same `id` AND `tier`) → 1× same id, tier+1.
  - Cost: Tier I→II = **50g + 10 dust**. Tier II→III = **150g + 30 dust**.
- **Split:** 1× tier-N rune → 1× tier-(N−1) of the same id **+ dust refund** (lossy: you
  lose 2 of the 3 that would've made it). Tier I split → dust only.
  - Cost: small gold (**20g**), no dust cost (it *returns* dust).
- Tier III runes are reachable only via Combine or rare drops — never common loot.

---

## 7. Rune drops

- Runes drop **rarely** alongside gear, mostly **Tier I**:
  - Standard kills: no rune.
  - Elite: small chance (~6%) of a Tier I rune.
  - Boss: guaranteed 1 rune (Tier I, small chance Tier II).
  - Chests/treasure/reliquary: chance to contain a rune, biased by room richness.
- Tier II is an uncommon boss/chest drop; **Tier III is craft-or-legendary only**.
- Exact rates tuned in Phase 1 against the existing loot tables in scr_stats /
  obj_floor_controller (kept conservative — consistent with the recent loot nerf).

---

## 8. Reagent economy — rune dust (Sable tie-in)

`rune_dust` is the shared crafting reagent. **Faucets:**
- **Sable salvage** (primary, Phase 3): convert unwanted gear/items → dust, scaled by
  rarity (e.g. Common 1 / Uncommon 2 / Rare 5 / Epic 10 / Legendary 20). This is Sable's
  "loot transmute" role; her consumable-crafting half also spends dust.
- **Rune split** returns dust (Phase 3).
- **Small dust trickle from combat/chests (Phase 2):** a few dust per elite/boss kill
  (and chest reward). This is the *minimal* faucet that makes the Phase 2 Aspect-slot
  unlock self-testable before Sable exists. It stays in as the secondary faucet once
  Sable lands (Sable = primary, trickle = passive baseline) — no rewiring needed.

> **Faucet/sink ordering (locked w/ M):** the first dust *sink* (Aspect-slot unlock)
> ships in Phase 2; the primary faucet (Sable) ships in Phase 3. To avoid a sink with no
> faucet, Phase 2 adds the small combat/chest trickle above *and* wires the Aspect-slot
> unlock to its final gold+dust cost. No throwaway code — the trickle is a permanent
> secondary faucet, not a stopgap.

**Sinks:** Combine, add-socket, Aspect-slot unlock (all at Maren); Sable's consumable
crafting. Sable gets her own `SYSTEMS_SABLE.md` later; this doc only establishes that
dust is the shared currency and Sable is its main faucet.

---

## 9. Maren hub UI

New tabbed screen (mirror the existing Vex/shop tabbed UI pattern — 5-tab layout, Q/E +
click). Proposed tabs:
1. **Socket** — pick an item (equipped or stash) → slot/unsocket gear runes.
2. **Aspects** — view Aspect slots → slot/unsocket Aspect runes; unlock +1 slot.
3. **Forge** — Combine / Split.
4. **Runes** — browse owned `rune_inventory` with full descriptions (uses a
   `rune_describe(rune)` generator, same philosophy as `ability_describe`).

---

## 10. Integration points (where code touches)

- **scr_stats `apply_equipment_stats`** — sum socketed gear-rune bonuses into the
  returned bonus struct (HP/STR/DEX/CON/INT/crit/resist/dodge).
- **scr_combat** — new `rune_aspect_bonus(domain_query)` helpers, queried in:
  - damage calc (Ember/Serration/Hemorrhage % by dtype/class),
  - accuracy calc (Hunter, for ranged actions),
  - heal calc (Leech, for drain),
  - on-hit hooks (Bulwark shield, Anchor weaken),
  - crit calc (Surge, for spells),
  - AP/cast (Quickcast first-spell discount), AoE (Echo).
- **Combat Create** — reset per-combat flags (`rune_first_spell_used`,
  `rune_first_aoe_used`) for Quickcast/Echo.
- **Item generation** — set `socket_count` by rarity; init `runes = []`.
- **Loot** — rune drop rolls (scr_stats drops + floor room rewards).
- **Save/load** — persist the 4 new globals + per-item `socket_count`/`runes`; backfill
  defaults on legacy saves (traits backfill loop is the template).
- **Hub NPC list** — wire Maren from `[Locked]` to functional; open the Maren screen.

---

## 11. Build phases (each = its own implementation pass + in-IDE compile test)

- **Phase 1 — Foundation + Gear runes:** globals + save backfill; rune catalog +
  `rune_get`/`rune_describe`; `socket_count` on item gen; gear-rune bonuses in
  `apply_equipment_stats`; Maren **Socket** + **Runes** tabs; basic rune drops. Playable:
  socket stat runes into gear and feel the bonus.
- **Phase 2 — Aspect runes:** `global.aspect_runes`/`aspect_slots`; `rune_aspect_bonus`
  + all combat hooks (§10); Maren **Aspects** tab + slot unlock (final gold+dust cost);
  **small dust trickle** from elite/boss kills + chests (the minimal faucet, §8).
  Playable: category buffs, and the slot unlock is self-testable.
- **Phase 3 — Forge + dust economy:** Combine/Split; `rune_dust`; Sable salvage faucet
  (minimal); Maren **Forge** tab. Closes the full-system loop.

---

## 12. Deferred / out of scope (v1)

- Per-item in-world visual display of runes (Vael territory — see Vael notes).
- Add-socket service beyond generated counts (Phase 2 nicety, may slip).
- Sable's full consumable-crafting design (own doc).
- Rune set bonuses / multi-rune synergies (future depth).
