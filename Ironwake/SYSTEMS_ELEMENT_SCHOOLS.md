# Ironwake — Element Schools

Design-locked 2026-06-25. Goal: give damage a real **element school** axis so build
identity ("a fire mage", "a shadow assassin") and school-specific gear can exist —
without inflating the power ceiling. Today the game has only **4 coarse damage
types** (physical / elemental / drain-void / blood), and "elemental" is a single
undifferentiated bucket; fire/frost/shock only exist as *status tags* on the
detonation layer, not as anything an ability **damages with**. This system adds the
missing layer.

Status: `[ ]` todo · `[x]` done (verify in-IDE).

---

## A. The schools

Eight schools. Some have little or no content yet — that's expected; an unused
school's affixes simply do nothing until abilities are tagged into it.

| School  | Mitigation bucket (`damage_type`) | Status link (detonation) | Notes |
|---------|-----------------------------------|--------------------------|-------|
| fire    | elemental (1) → el_resist         | burn                     | |
| frost   | elemental (1) → el_resist         | frost                    | |
| shock   | elemental (1) → el_resist         | shock                    | |
| arcane  | elemental (1) → el_resist         | —                        | default for untagged elemental |
| poison  | elemental (1) → el_resist*        | poison                   | *or physical; ability's own dtype wins |
| void    | drain/void (2) → unmitigated      | void                     | |
| shadow  | drain/void (2) → unmitigated      | —                        | dark flavor of void |
| blood   | blood (3) → unmitigated, INT-scaled | bleed                  | Bloodwarden self-fuel |

**Key architectural rule — school is METADATA, not mitigation.** The coarse
`damage_type` STILL governs mitigation (physical→armor, elemental→el_resist,
void→none, blood→none). The school is an additional tag layered on top. The
"Mitigation bucket" column above is only the *typical* dtype for new content in
that school; v1 changes **no** existing mitigation. (Per-school enemy resistances
are a future phase — see §F.)

**School vs. status element.** These are two distinct mechanics that ALIGN where
both exist: a fire ability deals *fire-school* damage AND tends to apply *burn*
(the status). The status layer (burn/frost/shock/poison/bleed/void) already works
from the viability + weapon-roles passes; schools are the new *damage* layer.

---

## B. `ability_school(ab)` — the resolver  [x]
A new optional `school` string field on abilities. The resolver returns it, or a
safe default inferred from `damage_type` so nothing is ever homeless:

```
ability_school(ab):
  if ab.school set and != ""   -> ab.school
  switch ab.damage_type:
    3 (blood)    -> "blood"
    2 (void)     -> "void"
    1 (elemental)-> "arcane"   // generic elemental until explicitly tagged
    else (phys)  -> ""         // physical attacks have no school
```

Then tag the real content explicitly (first pass — tunable):
- Arcanist elemental kit: assign fire/frost/shock/arcane per ability flavor
  (e.g. a firebolt→fire, a frost spell→frost, Rift→arcane or fire, etc.).
- Void/drain abilities → void; the darker ones → shadow.
- Blood abilities → blood. Poison abilities → poison.
Schools with no fitting ability yet (shadow, maybe arcane) just stay sparse.

---

## C. Flat-per-hit school-damage affixes (the build axis)  [x]
Gear can grant **"+X [school] damage"** — a flat bonus added to every damaging
ability of that school. **Flat, never % and never crit-scaled** (the deliberate
choice: a % "spell power" multiplier is exactly the compounding pattern that makes
loadouts broken; flat keeps schools a build *direction*, not a power explosion).

- Stored like other affixes via `stat_name` = `"school_<name>"` (e.g.
  `"school_fire"`), value by rarity. `_equip_apply_stat` routes these into a new
  `school_dmg` accumulator: `school_dmg.fire += value`, etc.
- `apply_equipment_stats` returns `school_dmg` (a struct keyed by the 8 schools);
  combat Create copies it onto `player.derived.school_dmg`.
- **Combat application:** in the cast resolver, after the crit roll (a SEPARATE,
  TRULY-FLAT component — mirrors System A's weapon-flat + the elemental affix):
  `var _sch = ability_school(ab);`
  `var _sb = player.derived.school_dmg[$ _sch];`
  if `_deals_damage` and `_sb > 0`: add
  `combat_resolve_damage(_sb, ab.damage_type, armor, el_resist)` to `_final_dmg`.
  (Resolved against the ability's own mitigation, once, flat — same one rule as
  all the other flat weapon/gear components.)
- **Magnitudes (M-revised 2026-06-25 — the PHASE 2 ROLLING rule):** per-affix by
  TIER — uncommon **+1**, rare **+2–4 (cap 4 per affix)**, epic **+5–6**. An item
  with 2+ affix slots may roll TWO DIFFERENT schools (e.g. +1 fire & +2 shadow =
  best-in-slot). It's a RANDOM affix, not on every item. Phase 1's plumbing already
  supports multiple `school_*` per item; Phase 2 adds the rolled pool.
- **Naming:** prefix/suffix per school, caster-flavored — e.g. fire
  "Smoldering …" / "… of Flames", frost "Rimebound …" / "… of Rime", shadow
  "Umbral …" / "… of Shadow", etc. (full table at build time).

**Does NOT touch the weapon's innate flat damage or the elemental weapon affix.**
Those are the weapon's own output (System A / §C of weapon-roles). A "+X fire
damage" gear affix buffs your fire *abilities*; it is a separate, stackable axis.

---

## D. Relationship to existing systems
- **Ember aspect rune** already grants *+% elemental (dtype-1) damage*
  (`rune_aspect_damage_pct`). That stays as the **%/multiplier** axis (rune slot).
  School-damage affixes are the **flat** axis (gear). Different acquisition,
  different math — they coexist intentionally and stack, but only the rune is a
  multiplier so the ceiling stays controlled.
- **Weapon elemental affixes** (Flaming/Frostbound/Storm-touched, §C of
  weapon-roles) already carry an element. With schools, a Flaming weapon's flat
  bonus is *fire-school* damage and it applies *burn*. They're consistent but
  remain the WEAPON's output, separate from the gear "+X fire" affix above.
- **Detonation reactions** are unchanged; schools just make "which ability builds
  which status" legible (fire abilities → burn → fire detonation, etc.).

---

## E. UI  [x]
- Ability detail / tooltip: show the school (e.g. "Fire · Ranged Spell").
- Item tooltip / `ui_item_stat_str`: show the "+X fire damage" affix line (reuse
  the affix formatter; route `school_*` stat names to a readable string).
- Compendium: a "Damage Schools" section listing the eight + how school-damage gear
  works; cross-reference Damage Types (mitigation) vs Schools (flavor/build).

---

## F. Future phases (NOT v1)
1. **Rolled affixes in the loot pool** — add the `school_*` entries to
   `global.affix_pool` (caster slots: amulet/ring/focus-offhand) so they drop;
   v1 ships the mechanic + a couple of hand-authored demo pieces only.
2. **Per-school enemy resistances** — split the single `el_resist` into per-school
   resist (or add school weaknesses), so fire enemies resist fire, etc. Big-ish;
   own pass.
3. **School status alignment** — auto-apply the linked status (fire→burn …) from
   school abilities, unifying school + detonation.
4. **School synergies / set-style bonuses** — "all-fire loadout" payoffs.
5. **Content** — fill out the sparse schools (shadow, arcane) with abilities.

---

## Build order (staged, each compiles + is testable)
1. [x] **Foundation (BUILT 2026-06-25, full compile confirmed via IDE F5):** `school` field + `ability_school()` + tag existing abilities +
   `school_dmg` plumbing (apply_equipment_stats → derived → cast resolver flat add)
   + UI (ability tooltip school, item affix line) + Compendium section + 1–2
   hand-authored demo "+X school damage" pieces. No rolled affixes yet.
2. **Loot integration:** `school_*` affixes in the pool for caster slots.
3. **Per-school resistances** (F2), then synergies/content.

Open/tunable: exact per-school ability taggings, affix magnitudes, which slots roll
school affixes, whether poison's damage sits in the elemental or physical bucket.
