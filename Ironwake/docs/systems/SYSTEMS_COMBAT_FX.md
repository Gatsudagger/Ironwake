# SYSTEMS — Combat FX (Audio rebind + Spell VFX)

> **08-04 VISUAL CONVEYANCE PASS — DESIGN-LOCKED by M ("in today's world this is a
> minimum expectation"). BUILT 08-04 (same day, later session) — AWAITING F5.**
>
> **Implementation map (for the next reader):**
> - `ability_delivery(ab)` + `ability_projectile_sprite(ab)` — scr_abilities, next to
>   ability_attack_vfx. Override table at the top of ability_delivery (Singularity/
>   Soul Nova/Arcane Burst = overhead; Void Drain/Mana Sever/Entropy = beam).
> - State: obj_combat_controller Create §6 — `combat_projectiles` / `combat_beams` /
>   `vfx_bursts` arrays; per-combatant `dodge_anim` / `hit_recoil` / `hp_hold` /
>   `hp_vis` fields ride the combatant structs (hit_flash idiom).
> - Step sites: player attack hit + miss, enemy basic attack (keys off `actor.reach`),
>   enemy spell (ability reach wins over mob reach), double strike, and the four
>   flashy evades (Blink/Vanish/Shadow Step/Phantom Step) all wired. DODGED!/MISS!
>   now floats as a popup at the defender (was log-only).
> - Draw_64: sidestep/recoil offsets (combat_slide_px, scr_ui), beam + projectile
>   renderer (before the single-slot vfx block), multi-slot `vfx_bursts` after it.
> - HP bars show EASED HP via combat_hp_vis (scr_ui, above ui_draw_hp_bar): drains
>   over ~6 frames, held by `hp_hold` while a bolt is in flight.
> - Deferral = popup `delay` fields + projectile-carried flash/recoil/shake/burst.
>   A killing blow presents INSTANTLY (foe's sprite leaves the row at resolution -
>   deferring would float a number over an empty slot).
> - KNOWN COSMETIC SEAM: the enemy row compacts when a foe dies, so a projectile
>   already in flight lands at the slot position captured at cast. Rare, tiny.
>
> **1. Dodge sidestep (transform-only):** on a dodged attack the DEFENDER slides
> ~24px away from the attacker, fast out + ease back (~14 frames), synced to the
> MISS/DODGE label. **Hit recoil:** ~8-10px knockback pulse on damage taken
> (visibly smaller than dodge so the two read differently). Both player + enemies.
>
> **2. Delivery archetypes:** every ability (player AND enemy casts) gets a
> `delivery` tag → visual: `melee` (existing lunge) | `projectile` (VFX sprite
> travels caster→target ~15 frames, image_angle faces travel; impact VFX at
> arrival) | `beam` (stretched flash line source→target, instant) | `overhead`
> (existing at-target drop — keep for lightning STRIKE, meteor-likes) | `self`
> (at caster, existing). Defaults by school + attack kind; explicit override
> table for abilities where the default reads wrong (e.g. lightning BLAST =
> projectile). Projectile sprites = shipped Gigapack VFX (0 gens).
>
> **3. Timing (M locked: damage lands on impact):** mechanics still RESOLVE
> instantly at cast (damage, riders, AP refund, kill checks — no combat-logic
> changes); what defers to projectile arrival is the PRESENTATION: damage
> number, HP-bar drain animation, impact VFX, hit recoil. Beam/melee/overhead
> stay instant. Multi-hit/AoE: one projectile per target, staggered ~4 frames.
>
> Implementation home: obj_combat_controller (projectile state array alongside
> the existing attack_anim_* / vfx_* state), delivery resolution next to
> ability_attack_vfx in scr_abilities.

> **07-29 TRIAL EXPANSION (built, awaiting F5):** 9 new one-shot VFX from owned
> packs (0 gens), resolved by `ability_attack_vfx` / `ability_support_vfx`
> (scr_abilities, after ability_school_list). Attacks now key on element
> SCHOOL: fire/arcane/void keep their sprites, physical keeps impact, NEW
> frost (`spr_vfx_frost` blue sparkle), shock (`spr_vfx_shock` zap), poison
> (`spr_vfx_poison` green skull), blood (`spr_vfx_blood` splatter), shadow
> (`spr_vfx_shadow` Necromancer crescent). Self-casts split the old
> sword+/heal pair: shield→`spr_vfx_shield` (warded shield), resource→
> `spr_vfx_gain` (absorb motes), self-debuff + blood/void/shadow status
> pacts→`spr_vfx_dark` (skull smoke), Blink/Evasive Roll/Vanish→
> `spr_vfx_haste` (clock), other buffs keep `spr_vfx_buff` (sword+). Each
> entry carries its own `ticks` so longer animations play out. Import:
> tools/import_combat_vfx_0729.py. GAP: no grey twins yet — Vael tints still
> only recolor the four original attack bursts. If the trial lands, round 2 =
> full catalogue (per-ability signatures, PixelLab bespoke where packs lack).

Goal: make combat feel more varied + fitting by keying **sound and impact VFX to the
ability itself** (damage type + effect kind) instead of a coarse per-class split. M
approved both the audio rebind and importing the Super Pixel Effects Gigapack spell
animations. Design-locked 2026-06-24.

NOTE: sound IDENTITY is a best guess — Claude can't audition the assets. Every binding
below is a single `audio_play_sound(<asset>, …)` line, trivially swapped after hearing it
in-game. Treat the specific asset picks as a first draft.

---

## Keys (from scr_abilities)

- `ab.damage_type` — `0` physical · `1` elemental · `2` drain/void · (`3` blood, reuses slash).
- `ab.effect_type` — `none·damage·heal·shield·debuff·dot·status·resource`.
- Offensive = `damage`/`dot` (and `status`/`none` that carry damage). Support = the rest.

## Part A — Audio rebind  (.gml only)

New resolver `play_ability_cast_sfx(ab, caster)` in **scr_combat** (next to the enemy-sfx
helpers). Replaces the per-class `switch` at obj_combat_controller Step ~811 AND the
self-cast block ~996. Logic (first match wins):

| condition | sound (draft) | why |
|-----------|---------------|-----|
| `effect_type == "heal"`         | `Magic`                | bright twinkle (kept) |
| `effect_type == "shield"`       | `Success_1__subtle_`   | soft defensive ward |
| `effect_type == "resource"`     | `utility2`             | arcane gain (souls) |
| `effect_type == "debuff"`       | `Harp_2__Descending_`  | ominous descending |
| support `status` (no dmg)       | `utility2`             | generic self-buff |
| offensive, `damage_type 0` phys | `attack1`              | weapon strike |
| offensive, `damage_type 1` elem | `spell1`               | elemental cast |
| offensive, `damage_type 2` void | `Obscure`              | dark whoosh |
| offensive, `damage_type 3` blood| `grunt` + `attack1`    | visceral |
| offensive, other/arcane         | `Strings_1`            | arcane |

Class flavor layer (preserve character): if `caster.class_id == 1` (Bloodwarden) add a
`grunt` on physical hits. Keep it minimal so element drives the texture.

Enemy attack/death already use the themed family system (`enemy_attack_sound`/
`enemy_death_sound` in scr_combat) — LEAVE as-is, but its fallbacks may also be enriched
from the new palette later. `hurt` stays the universal "took damage" cue.

## Part B — Spell VFX import

Source: `C:\Asset_Library\effects\Super Pixel Effects Gigapack (Free Version) v2.5.0\
…\PNG\<category>\<effect>\<effect>_large_<color>\frame0000.png …` — 128×128, ~16 frames.
Also `effects\Fire Effect 2`, `effects\electric_bolt`, `effects\hit_spark`.

Import each as a GMS sprite (hand-authored `.yy` + frame PNGs copied in + `.yyp` resource
entry + `__sprite_includes`; follow the project_skins_gender STRIP/`__sprite_includes`
gotchas). Origin = center (64,64). Bind by damage type/kind, **replacing** the four
existing `spr_vfx_*` so no draw code changes except the lookup table:

| slot | new sprite | Gigapack source (draft) |
|------|-----------|--------------------------|
| physical (0) | `spr_vfx_impact`  | Impacts/`symmetrical_impact_002` (or `hit_spark`) |
| elemental (1)| `spr_vfx_fire`    | Explosions/`stylized_explosion_002` (or Fire Effect 2) |
| drain/void (2)| `spr_vfx_void`   | Fantasy Spells/`spell_death_001` (or violet `round_light_burst`) |
| arcane (def) | `spr_vfx_arcane`  | Lightning/`lightning_strike_001` (violet) |
| heal         | `spr_vfx_heal`    | Fantasy Spells/`spell_heal_001` |
| buff         | `spr_vfx_buff`    | Fantasy Spells/`spell_attack_up_001`/`spell_haste_001` |

Binding: the `_vfx_spr_list` at obj_combat_controller ~801 keeps its damage-type indexing;
add heal/buff VFX at the heal/self-cast sites (they currently play sound but no impact
sprite). `vfx_timer` (20) drives sub-image; 16 frames over 20 ticks is fine — confirm the
VFX draw advances `image_index`/sub_img by timer fraction (check combat Draw_64 vfx block).

## Build order

1. **Audio** (Part A) — resolver + rewire the 2 cast sites. Low risk, immediate. ⬅ first
2. **VFX** (Part B) — import sprites one at a time, verify each loads/links in-IDE before
   the next; then swap the lookup table + add heal/buff sites.

## Risks / notes
- Sprite hand-import is the fragile part (frame GUIDs, `__sprite_includes`, the
  string-ref STRIP gotcha). Import + load/link-check incrementally.
- Don't reference an unimported sound/sprite by bare identifier — compile error. All Part A
  assets are already in the `.yyp`.
- The empty `Sounds` asset is already dropped from the `.yyp` (keep it out).
