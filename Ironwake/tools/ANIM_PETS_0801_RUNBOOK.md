# Pet expansion animation runbook — ✅ EXECUTED 08-01 (280 gens, well under the ~350-500 pre-approval)

STATUS: all 12 south states + 24 idle animations generated, all 24 sprites
imported via tools/build_pets_expansion.py (--register ran with GM closed;
.yyp +24). Awaiting M's F5 + garden screenshot check, then clean
_for_review/pet_bases_0731. REMIND: git add sprites/ Ironwake.yyp tools/.

Goal: animate + import the 4 M-approved species (crypt_bat, hoarfrost_drake,
duskraven, voidkit) as `spr_pet_<species>_<stage>_<s|e>` animated sprites,
matching the shipped pets. All BASES are approved; nothing else needs M until
the final imported result (show a garden screenshot after F5).

## Approved base objects (side-profile = EAST source)
| species          | baby                                   | youngadult                             | adult                                  |
|------------------|----------------------------------------|----------------------------------------|----------------------------------------|
| crypt_bat        | d8949408-fd72-46fa-b363-15d078ec5de7   | 75ce5d70-f85a-433a-bcce-80aa2fc15b61   | 72c43384-c4cc-436c-ac4d-7ca2516b0497   |
| hoarfrost_drake  | 0fd035dd-4e50-4295-a3bb-e91633453b58   | 5d471212-383e-4802-accb-2361f6f9c946   | 4e2f0803-359d-4dee-af1a-7162a2ca5c2a   |
| duskraven        | ed669572-40c4-4312-9177-63b20ae4462f   | 2c355969-0722-451f-8025-3245f2acaea1   | b5dd6bf6-748f-404c-8b74-7635ba1ab40d   |
| voidkit          | 7b42e5c3-3111-4db9-8326-1c93621e5aef   | c9b8d2d9-b18c-440c-a7af-e0df5b40302c   | 022bd9c8-b9d5-4ab2-b98c-37b3ca69d312   |

(hoarfrost: ya = "youngadult_v2", adult = "elder_adult" — the M-corrected
lineup, see _for_review/pet_bases_0731/_HOARFROST_LINEUP.png. Objects 0b7dee16
and 4de8e7fc are sources/rejects — do NOT import them.)

## Step 1 — SOUTH states (12 × create_object_state, ~20 gens each)
For each of the 12 base objects:
  create_object_state(object_id=<base>,
    edit_description="same creature turned to face the viewer, front-facing
    south view, same pose weight, same palette",
    state_name="south")
Record the 12 new IDs in this file as they return.

### SOUTH state IDs (queued 08-01)
| species          | baby south                             | youngadult south                       | adult south                            |
|------------------|----------------------------------------|----------------------------------------|----------------------------------------|
| crypt_bat        | 9a188d5e-0127-498b-9770-62217505e285   | ba12678a-247a-44e1-880d-af89af4e7a15   | ec4ff8e4-e943-4bc3-8906-a7d2b5484fa0   |
| hoarfrost_drake  | 7f976af2-3276-4f34-b758-fa0829bb9c1d   | b3cf4e44-d8bd-4177-949e-cc9c95ffc258   | 1a365761-aeb9-4fd9-88c7-34b0348423ea   |
| duskraven        | 622894cb-2fda-4c2f-b0ed-af2bf8f0ae5c   | 3189f739-e48c-4fa3-bef1-a35d43521a16   | 09c807e5-8957-4610-90f1-9257723d928f   |
| voidkit          | 14c217ca-9076-4ed1-97c2-9117bc896152   | 251997a0-73b9-4e14-a133-8576718c468f   | 2d806f23-5b04-4ea6-84ff-7fb61382c3f2   |

## Step 2 — idle animations (24 × animate_object, mode v3 = cheap)
Animate BOTH the base (east) and its south state, per species flavor:
- crypt_bat:       "gentle idle: breathing bob, wings ruffle and resettle, ears twitch"
- hoarfrost_drake: "gentle idle: slow breathing, frost mist puff from nostrils, wing crystals shimmer"
- duskraven:       "gentle idle: feathers ruffle, head tilt, slow blink"
- voidkit:         "gentle idle: tail sway, ear flick, star speckles twinkle"
mode="v3" (do NOT use pro), omit directions (1-direction objects), default
frame_count (8 + ref = 9 stored; the import consumes whatever the ZIP has).

## Step 3 — import (GM MUST BE CLOSED)
Model on tools/build_pets_signature.py (read its FULL body first — it already
consumes each object's download ZIP: rotations/ + animations/<name>/<dir>/
frame_XXX.png and builds the .yy + registers). Differences for this batch:
- TWO objects per stage: east frames from the BASE object's ZIP (its single
  direction folder may be named "unknown"), south frames from the SOUTH-state
  object's ZIP.
- Output sprite names: spr_pet_<species>_<stage>_<s|e>, stages baby /
  youngadult / adult. Bottom-center origin like the other pets.
- ~24 new sprite folders → .yyp register → remind M: git add sprites/ Ironwake.yyp.

## Step 4 — verify
F5 → F12 dev eggs on the test save → hatch → roster icons, Bairc profile,
garden wander + hub carousel stage all animate; "?" placeholders gone for
these 4. pet_species_has_art now passes → duskraven/voidkit enter generic
rolls; crypt_bat/hoarfrost_drake signature drops finally render.
Then clean _for_review/pet_bases_0731 (keep _HOARFROST_LINEUP.png until F5).

Remaining after this: 6 more new species (pale_widow, shellback, thorn_boar,
glimmer_slime, sporeling, ironshell_beetle) — bases from scratch, ~2/session;
then feed icons (spr_pet_feed_pref_<species>) for all 8 eventually.
