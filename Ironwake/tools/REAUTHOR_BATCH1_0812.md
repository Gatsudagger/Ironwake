# Species re-author batch 1 — null_hound / pyre_bison / stormkirin (08-12)
# STATUS: ✅ COMPLETE + IMPORTED (18 sprites incl. lockjaw = 24 total live).
# Final picks: bison ya = "[B] ember eyes" (58b9bc4b / south d7eafcf2, anims
# a92c6722 / 2383d3fd), kirin all-6 approved, nullhound adult_s anim Roll 2.
# Import scripts: tools/import_reauthor_images.py (image pipeline) +
# build_pets_expansion.py CFG (object pipeline). Review pack:
# _for_review/species_batch1_0812/FINAL/. 16 species remain — see
# memory project_handoff_0813.

Anchored-recipe batch (img2img strength 300 from approved stills — see
feedback_game_is_the_art_baseline addendum). M approved all EXCEPT kirin
(coherence fix in flight). M's progression rule: baby→ya→adult must mature in
ONE direction, no reverting; e and s facings must be the same creature.

## Anchored re-renders (image job ids, api.pixellab.ai/mcp/images/<id>/download)
| sprite | image job | anim job (idle, 8f seamless) |
|---|---|---|
| null_hound_adult_e | a77be687-1620-4a5c-b115-0330de43afa6 | 3232ea9f-4965-4bae-89c9-34a2a980b6fd |
| null_hound_adult_s | 4f5e4c06-13b1-4a26-985d-18ec2ce97e63 (R2; R1 ba716a21 = two dogs) | 912bd352-1a1e-442a-92d8-f6baf8e8c0cb |
| null_hound_baby_e | 0fec779c-1d76-470f-a65b-6381e3036b26 | 9533026a-ec42-4d57-998e-82d7ac2b61ee |
| null_hound_baby_s | 7bc6ace7-f40d-49e9-9ed1-85edec5a002d | 4321abb4-d771-4ccc-adbc-6d63e029a508 |
| pyre_bison_youngadult_e | ea730435-3faa-4b8d-ad88-2af73dfe157b | fb22a911-fd20-4719-bbae-c3f18e450e13 |
| pyre_bison_youngadult_s | 1e061521-f9dd-4ff8-bd4c-2e471915f1cd | 0d2134d9-543a-4371-b3ab-815e10df842b |
| pyre_bison_baby_e | 1a69feba-bf02-4d5a-8236-bc58d449f605 | 5134cacc-25a1-4504-a9c7-03e4f02756a6 |
| pyre_bison_baby_s | 15c23b43-5122-48c8-8956-0a1976dd9759 | b4e4f6d6-15b2-49bb-a339-a0b0da13b317 |

Baby canvases are 84x84 (pixflux grid rule) — pad to 85 at import to match
the shipped baby convention.

## Object-pipeline pieces (M's candidate picks, kept)
- pyre_bison ADULT: object 664e66c9-49b2-4fb7-9cf8-0ab2fd3c04f8 (east base),
  south state 87d9d4c4-1d90-4f32-8e01-364878772d0a. Anims TBQ after states.
- null_hound YA: object 65038238-ce6a-4ccf-be07-62d619d505db (east base),
  south state 350485c7-3f94-45c0-9c1e-4982f84e37b8. Anims TBQ.

## Kirin coherence fix (M's one concern, in flight)
Canonical ladder: baby lavender-grey (curled) -> ya storm-grey shift -> adult
blue-grey kirin. ya_e storm-shift candidates: b6b5abe9 (strength 250) /
62f72b72 (strength 180) — M picks. Then souths derive from EAST designs via
create_character v3 reference rotation (NOT from the mismatched s stills).
Approved anchored kirin pieces so far: baby_e 58d21dbf, adult_e bb5f5c27.
Discards: old ya_e d5e32fa8 (brown), all s-anchored renders (6039c67c baby_s,
14dbea5f ya_s, 61057e26 adult_s — matched mismatched stills).

## Import
NEW image-based script needed (fetch anim job frames via
api.pixellab.ai/mcp/images/<job>/download?index=N, frame 0 = input re-render).
Object-pipeline pieces use the build_pets_expansion.py zip route (add CFG).
Sprite names exist in .yyp — pure frame swaps.
