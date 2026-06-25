# Ironwake — Weapon Roles (melee/ranged slots, elemental affix, 2H)

Design-locked 2026-06-25. Goal: turn weapons from stat-holders into role-defining gear.
Two weapon slots (Melee + Ranged) that strictly augment their reach-class of abilities, a
new elemental affix that adds small damage AND applies an elemental status (feeding the
detonation reactions), and two-handed weapons that trade the offhand slot for more power.

Status: `[ ]` todo · `[x]` done (verify in-IDE).

---

## A. Two weapon slots  [ ]
- Slot 0 "weapon" → display **"Melee Weapon"** (item.slot stays `"weapon"` = melee; avoids
  churning every `slot=="weapon"` check). Add slot index 8 **"Ranged Weapon"**
  (item.slot `"ranged_weapon"`). **Append at index 8** so existing inventory[0..7] indices and
  saves stay valid; inventory array grows 8→9.
- Touch points: the hardcoded `_slot_keys/_slot_names` arrays (scr_ui ~2733/2734, gc Step
  ~1340/1478), `equip_slot_index`, `array_create(8,...)` for global.inventory, save/load
  (inventory length), equip UI grid (9 cells), equip picker slot filter, icon resolver.
- **Save migration:** on load, if inventory length < 9, grow to 9 with index 8 = undefined
  (empty ranged slot). Old weapon stays in the melee slot. No data loss.

## B. Strict reach-gating (role identity)  [ ]
- Weapons no longer dump their damage into the global bonus. Instead:
  - **Melee Weapon** flat damage + its affixes apply ONLY to melee abilities
    (`ability_class_is_melee` = melee_attack / melee_spell).
  - **Ranged Weapon** applies ONLY to ranged abilities (ranged_attack / ranged_spell).
- Implement as reach-gated derived bonuses: `apply_equipment_stats` produces
  `melee_dmg_bonus` / `ranged_dmg_bonus` (from each weapon's stat + flat affixes), summed into
  `_dmg` in the cast resolver based on `ability_attack_class(ab)`. Non-weapon gear (rings,
  amulet, armor) keeps contributing globally as today.
- Class starters seed the correct slot: Bloodwarden blade → melee; Strider bow + Arcanist
  focus → ranged. The other weapon slot starts empty (progression hook). Strider's melee
  options (Shadow Sickle) go in the melee slot.
- Weapon→slot tagging by family: melee = sword/blade/axe/mace/spear/sickle; ranged =
  bow/wand/focus/scepter/staff. Stored as an explicit `slot` on each weapon item.

## C. Elemental affix (+dmg + status, feeds reactions)  [ ]
- New affix family, prefix/suffix pairs:
  - **Flaming / of Embers** → fire: +N elemental dmg, applies **burn**.
  - **Frostbound / of Frost** → ice: +N elemental dmg, applies **frost**.
  - **Storm-touched / of Storms** → shock: +N elemental dmg, applies **shock**.
- The affix lives on a weapon; the **slot decides reach** (Flaming melee weapon → melee
  abilities; Flaming ranged weapon → ranged). No melee/ranged variant of the affix needed.
- On a damaging ability of the weapon's reach class: add +N elemental damage (its own type,
  resisted by el_resist) AND apply a light stack of the element's status to the target.
- **New statuses (extends the reaction layer from SYSTEMS_VIABILITY_PASS.md):**
  - `burn`  — small fire DoT; detonation reaction = +40% crit (already defined, was "future").
  - `frost` — slows/marks; detonation reaction = +30% damage / shatter (already defined).
  - `shock` — NEW reaction: detonating shock = chain a small hit to another enemy (or +crit).
    Define shock's passive (e.g. minor accuracy/▲ vuln) + its detonation in the reaction table.
  - Add all three to `combat_status_element`, `ability_status_element`, the reaction table,
    the Compendium "Status Reactions" + "Status Effects" sections, and the status-VFX/icon row.
- Affix magnitudes by rarity (u/r/e): elemental dmg ~ +2/+4/+6; status applied at a low,
  short stack so it's a *setup*, not the main damage. Numbers first-pass/tunable.

## D. Two-handed weapons  [ ]
- Weapons get `two_handed: true/false` (default false). 2H = greatswords / longbows / staves;
  bigger base damage + affix budget than 1H of the same rarity.
- **Rule:** any equipped 2H weapon (melee OR ranged) LOCKS the single offhand slot:
  - Equipping a 2H auto-returns any equipped offhand to the pack.
  - The offhand slot draws **faded** with "Two-handed: offhand locked"; equipping an offhand
    is blocked while any 2H is equipped.
  - `apply_equipment_stats` ignores the offhand whenever a 2H is equipped (belt-and-suspenders;
    it should already be empty).
- Trade: 1H weapon + offhand utility  vs  2H power, no offhand. You may run 2H in both weapon
  slots (offhand stays locked).

## D2. Offhands carry real defense  [ ]
- To make the 2H offhand-lock a genuine sacrifice, offhands must provide meaningful DEFENSIVE
  value (armor / dodge / max HP / block) — not just utility. Audit offhand drops/affixes so a
  shield-type offhand is the clear "defense" choice vs a 2H weapon's "offense." 2H weapons get a
  larger damage/affix budget precisely because they forgo this defense.

## D3. Gear stat requirements (class identity)  [ ]
- Gear can carry a stat requirement (e.g. heavy armor → STR, bows → DEX, focus/wand → INT,
  plate → CON). If the wearer doesn't meet it, the item can't be equipped (blocked at the equip
  step with a clear "Requires N STR" message), OR equips at reduced effect — DECIDE (recommend
  hard block for clarity). Keeps a low-STR Arcanist out of heavy plate, etc. — gear choices
  reinforce class identity instead of anyone wearing anything.
- Requirement scales with item rarity/tier. Stored as `req_stat` / `req_value` on the item;
  checked in the equip path (keyboard + mouse + picker) and shown on the item detail/tooltip.

## E. UI  [ ]
- Equipment tab: show 9 slots; Melee Weapon + Ranged Weapon labeled; offhand faded when 2H.
- Item detail / tooltips: weapons show their slot (Melee/Ranged), 1H/2H, and the elemental
  affix's damage + status.
- Ability detail popup + descriptions already surface reactions; burn/frost/shock auto-appear
  once added to the element helpers.

---

## Build order (staged, each compiles + is testable)
1. **B+A foundation:** add the ranged slot (arrays, inventory, save migration, equip UI/picker)
   + reach-gated weapon damage. Weapons become role gear even before affix/2H.
2. **D two-handed:** the offhand-lock rule + a couple of 2H weapons.
3. **C elemental affix + statuses:** burn/frost/shock + the affix + reaction wiring + compendium.

Open/tunable later: exact affix numbers, shock's reaction, which dropped weapons are 2H,
per-class weapon pools for the new slot.
