#!/usr/bin/env python
# Re-import saber_hound idle sprites with the CLEAN template idle (8 frames), overwriting
# the grotesque v3 ones. Sprite names already registered in yyp/__sprite_includes. Run from root.
import build_pets
build_pets.NFRAMES = 8

# (stage, char_id, south_group, east_group)
CFG = [
 ("baby",       "1ac9ea0d-bdd4-4b84-ad3b-68b209a1cab6", "ebf27993-3279-4d93-bd61-cbf839fd4085", "a3796b6d-1bca-4553-bffb-cc78fef1bac1"),
 ("youngadult", "96c8c0c5-5473-4014-972b-26543d2c47d4", "98ea9e5f-c260-4771-81ee-6660c1a852b7", "de53a02f-b6f5-425f-8532-3b2d72b4febf"),
 ("adult",      "2346112d-f076-42b1-9d6c-3f20c3980f61", "a0187d13-d126-4e58-acc1-9ea40885fa0a", "e69702ad-b4cb-4ee9-bf5e-cd7c30486e44"),
]
for stage, cid, sg, eg in CFG:
    build_pets.build(f"spr_pet_saber_hound_{stage}_s", "char", cid, sg, "south")
    build_pets.build(f"spr_pet_saber_hound_{stage}_e", "char", cid, eg, "east")
