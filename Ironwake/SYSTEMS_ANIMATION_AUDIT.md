# Animation Audit — 2026-08-08

> **UPDATE 2026-08-09 — GAP 1 IS CLOSED, at 0 generations.**
> M: *"if youre saying we have a lot of gigapack thats unused then lets use and
> wire as many as it provides where appropriate"*. The audit's 48-gen estimate
> was wrong: the owned unTied Games Gigapack ships **9 impact animations and we
> had wired exactly one**. All four physical archetypes came straight out of it,
> luminance-tinted to Ironwake's palette. See `tools/import_phys_vfx_0809.py`.
>
> | archetype | sprite | pack source | frames |
> |---|---|---|---|
> | slash  | `spr_vfx_slash` (replaced the 1-frame orphan) | directional_impact_001 | 7 |
> | pierce | `spr_vfx_pierce` | directional_impact_004 | 5 |
> | crush  | `spr_vfx_crush`  | symmetrical_impact_004 | 8 |
> | snap   | `spr_vfx_snap`   | symmetrical_impact_001 | 7 |
>
> Resolved by `ability_phys_shape(ab)` / `phys_shape_vfx(shape)` in
> `scr_abilities.gml`. Named abilities are keyed explicitly; anything added later
> falls through to a `crit_type` default (0=power→crush, 1=precision→pierce,
> else slash), so the switch never has to be maintained to stay correct.
> `snap` is not reachable from a cast — it belongs to trap springs.
>
> **Also wired from the same unused pack (still 0 gens):**
> - `spr_vfx_rage` — the 08-08 boss combo-breaker shipped as a *text popup with
>   no visual*. Now an explosion on the raging foe.
> - `spr_vfx_boom` — boss/elite/duel deaths only. Trash mobs deliberately do not
>   detonate; if every kill explodes, none of them land.
> - `spr_vfx_snap` also fires **on the trap's own ground position**, not on the
>   enemy — the point of the trap rework is that the trap is a thing standing
>   between the two of you.
>
> **Rejected on style review, do not re-add without M:** `spell_death_001` is a
> red Japanese kanji + skull (hard clash — nothing else in Ironwake uses
> glyph-language VFX); `spell_attack_up_001` duplicates the shipped
> `spr_vfx_buff`, which is already the sword+ burst.
>
> **The orphan is gone.** `spr_vfx_slash` was 1 frame and referenced nowhere; it
> is now the real 7-frame slash.
>
> Gaps 2 (traps) and 3 (player attack poses) are **unchanged** — still open,
> still costed below.


**No art has been generated. This is the costed menu M approves from.**

M: *"we need to finish building animations for a lot of things still"* and earlier
*"many dont make sense like traps"*. This is what's actually there, what's
actually missing, and what each fix costs.

---

## What already exists (better than expected)

| Layer | State |
|---|---|
| Elemental spell VFX | **DONE.** 8 schools, all genuinely animated: fire 11f, frost 14f, void 10f, blood 10f, shock 9f, arcane 7f, shadow 7f, poison 17f. |
| Self-cast VFX | **DONE.** heal 16f, shield 18f, buff 18f, haste 16f, gain 16f, dark 12f. |
| Ability icons | **DONE.** 64 `spr_ability_*`. |
| Player attack motion | Positional **lunge + hit flash + screen shake** (`attack_anim_timer`, 20 frames). Not a sprite animation, but it does read as an attack. |

So the *spell* side is largely finished. The gaps are concentrated in three
places, and they explain the "many don't make sense" complaint precisely.

---

## GAP 1 — every physical ability shares one generic burst  ← biggest

`ability_vfx_for()` maps VFX **by elemental school**. An ability with no school
falls through to a single default:

```gml
return { spr: spr_vfx_impact, ticks: 20 };
```

**24 abilities are physical (`dtype 0`)** and therefore all look identical.
Snipe, Cleave, Assassinate, Gore Strike, Bonebreaker, Throat Slit, Bear Trap —
one shared puff. This is not a missing-asset problem so much as a
missing-*distinction* problem, and it is why the physical classes feel flatter
than the casters.

**Fix:** add a small set of physical *motion archetypes* and key them by the
ability's weapon role / attack shape rather than by name — the same way schools
already work, so it stays data-driven and never needs a per-ability switch.

| Archetype | Covers |
|---|---|
| `slash` | Cleave, Throat Slit, Gore Strike, Winter's Bite… |
| `pierce` | Snipe, Assassinate, Poison Dart, Frost Shot… |
| `crush` | Bonebreaker, Marrow Crush, Bulwark Slam… |
| `snap` | the trap springs (see Gap 2) |

**4 archetypes × ~12 frames ≈ 48 gens.**

> Note: `spr_vfx_slash` already exists as a sprite folder, is **1 frame**, and is
> **referenced nowhere in any .gml**. It is an orphan. Either it becomes the
> seed for the `slash` archetype or it should be deleted — right now it is dead
> weight in the project and a trap for the next person who greps for it.

## GAP 2 — traps have no visual at all

Post-rework (08-08) traps are self-targeted and resolve on a *later* turn, so
they never touch the VFX path. Today a deploy and a spring are **text in the
combat log plus a chip flash on the trap strip**. Full spec in
`SYSTEMS_TRAPS.md` §8.

**1 throw arc + 7 deployed idles + 3 spring bursts ≈ 60–90 gens.**
Sized to the 176×72 trap chip, so idles read at ~64×48 — props, not actors.
**Sequencing: blocked on M playing one Shadowstrider fight.** If a trap gets cut
or changes filter, its idle is wasted art.

## GAP 3 — no player attack sprite animation

The lunge carries the hit, but the character sprite itself never changes pose.
This is the **most expensive** item by far: it is per-class × per-skin, and the
project ships 20 skins × a gender axis. A single attack pose for one class is
not shippable on its own — it would make that one class look inconsistent with
the rest rather than better.

**Estimate: 200+ gens minimum, realistically its own multi-session project.**
Recommend **NOT** doing this now. It is a post-launch item.

---

## Recommended order

1. **Gap 1** — best value in the game. 48 gens fixes 24 abilities at once, needs
   no playtest to de-risk, and directly answers "many don't make sense".
2. **Gap 2** — after one Shadowstrider fight confirms the trap list is final.
3. **Gap 3** — post-launch.

## Before any generation (house rules, non-negotiable)

- Style-verify against the closest **shipped** assets — for Gap 1 that is the
  existing `spr_vfx_impact` / `spr_vfx_fire` frames, whose palette and burst
  timing the new archetypes must match.
- Confirm canvas + pipeline against those same sprites; do not invent a size.
- M's explicit yes on the gen count. 2 bad rolls = stop and report.
- ~100 gens/session cap. **Gap 1 alone fits. Gap 1 + Gap 2 does not.**
