#!/usr/bin/env python
# Build GameMaker sprites for the 6 EXPANSION hatch eggs (vital/ley/scholar/dust/warding/keen):
#   spr_pet_egg_<type>        - 1-frame static egg (rotations/unknown.png)
#   spr_pet_egg_<type>_hatch  - 9-frame crack/hatch animation
# Bottom-center origin, matching the original 4 eggs. Run from the Ironwake root.
# Reuses the .yy writer from build_eggs.py.
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_eggs import build, STATIC, ANIM, HATCH_FRAMES

PROJECT = "c50e1365-1a8c-44be-a773-5ee635581147"

# (type, object_id, hatch_url_subgroup)  -- NOTE: the subgroup in the frame URL differs
# from the animation_group_id returned by animate_object; harvest it from get_object.
EGGS = [
 ("vital",   "4207ea8b-e257-450a-923a-75167a661499", "3e3a577a-6c2c-41fb-8ca7-2e77d203d8ef"),
 ("ley",     "90eb1fbe-3413-4644-95e9-7c99d7b04a38", "523f6e5c-c849-4950-9bb9-aa06840e42f8"),
 ("scholar", "ea6cccab-d0ae-4d3d-a84a-3f3dffb37d87", "615ca11a-91cf-45fc-8535-be680f608051"),
 ("dust",    "b9c3d34c-f71f-4bfa-865a-ecec74682e5b", "750f183a-4056-4cbc-b318-0704d78e521f"),
 ("keen",    "02eb5475-ba84-4e8b-983e-72f4133a99f6", "a1287b37-7882-4a11-b2ea-43fe6afb9843"),
 # warding hatch still rendering; static-only for now, hatch filled in a second pass:
 ("warding", "775e8485-5643-42a4-80dd-2c9948d9645c", None),
]

if __name__ == "__main__":
    for etype, oid, grp in EGGS:
        build(f"spr_pet_egg_{etype}", [STATIC.format(proj=PROJECT, id=oid)])
        if grp is None:
            print(f"SKIP {etype} hatch (still rendering)")
            continue
        build(f"spr_pet_egg_{etype}_hatch",
              [ANIM.format(proj=PROJECT, id=oid, grp=grp, i=i) for i in range(HATCH_FRAMES)])
