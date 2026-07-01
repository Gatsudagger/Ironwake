#!/usr/bin/env python
# Import keeper (bonehound + hollow_pup, 3-stage, dog template idle 8f) and re-import
# bone_stag (horse rest-idle 9f) animated sprites. RUN FROM IRONWAKE ROOT.
import build_pets

# (species, stage, char_id, south_group, east_group)
KEEPERS = [  # 8 frames (dog template idle)
 ("bonehound","baby",       "d19d975e-fda3-4fb8-8299-d6b3b32880cd","f48b5ff2-ff3d-4ab6-b582-332b982feb3a","045fbd53-e0fa-46bb-8599-25b427030c21"),
 ("bonehound","youngadult", "b0253c32-89c8-4e10-aa7f-6ffb95f76004","9d5c6b23-1e42-4639-82e3-3bbbc500c357","ce1a6811-cc79-4950-97ee-93ef373bc283"),
 ("bonehound","adult",      "a837dcc4-30e5-4436-836d-d0a316f1f5ec","f41ecb7e-74aa-49f6-99bb-41577cde4279","07048f50-d0bf-484a-acfe-a40e9f0c9757"),
 ("hollow_pup","baby",       "5daca96d-00ad-4de3-8068-9566c301850d","7f398ed2-c15e-46d2-b497-48bc36aa5e4d","bd837dab-814d-4f01-adc5-f658b9f22d22"),
 ("hollow_pup","youngadult", "79639b66-3864-48f7-872b-132ca8e5247b","22569abc-23c5-4b94-92ef-eba1876758b5","895fd5bc-b83d-4db0-ae7e-b9078cb18bb0"),
 ("hollow_pup","adult",      "8d0865fc-70a1-4761-9151-3a6c45b47b06","30cacf2a-eafc-4400-9d88-67fa7fc113cb","0d0fdf0b-3123-4f6d-bc34-edeae1b365db"),
]
BONESTAG = [  # 9 frames (horse rest-idle)
 ("bone_stag","baby",       "3c5dc111-5f76-4bdf-98c2-84072af0daeb","a37dac95-446f-4209-b015-527153433a94","24c839ad-2d78-4d60-8173-bdb5aa654f2e"),
 ("bone_stag","youngadult", "23e2a203-4b39-43d7-8daf-4c280dfcb640","0293f95f-47e0-4888-868a-08e98bdac65b","adf82276-7f83-46be-a1ed-90e5cc722ded"),
 ("bone_stag","adult",      "55234923-f020-4b45-bc00-413f4d47d386","3ba2eeeb-3865-442b-a8fd-474c55ada8ff","3ecc9aae-4bcd-4391-93be-7b7205333bfb"),
]

def run(rows, nframes):
    build_pets.NFRAMES = nframes
    for species, stage, cid, sg, eg in rows:
        build_pets.build(f"spr_pet_{species}_{stage}_s", "char", cid, sg, "south")
        build_pets.build(f"spr_pet_{species}_{stage}_e", "char", cid, eg, "east")

if __name__ == "__main__":
    run(KEEPERS, 8)
    run(BONESTAG, 9)
