# Lockjaw turtle re-author pilot — 08-11 (species 1 of 20)
# STATUS: ALL 6 IDLE ANIMS DONE + QC CLEAN (shell pattern holds, head-duck reads).
# GIFs in _for_review/lockjaw_reauthor_0811/. Import = GM CLOSED, then:
#   python tools/build_pets_expansion.py lockjaw_turtle
# (CFG entry added; replaces stills in place, no .yyp change.)

The pilot for re-authoring the 20 expansion species at proper canvas so they
can be ANIMATED (stills churn when animated — see
_for_review/pet_anim_pilot_0811/_REVIEW_NOTES.md). Recipe = the 08-01 pet
expansion runbook: east base object → south state → animate_object v3 both →
import as spr_pet_<species>_<stage>_<s|e>, REPLACING the small stills
(sprite names already registered in .yyp — frame swap only, no .yyp edit).

M approved the re-author pilot + picked every base 08-11 (candidates in
_for_review/lockjaw_reauthor_0811/).

## Object IDs
| stage | east base (M's pick) | south state |
|---|---|---|
| baby (85px) | 04afe5cc-a866-4359-b1a5-10b25654b6e3 (was [8]) | 52ecfe38-b885-413e-a524-d170679be28e |
| youngadult (124px) | 473a4aff-1db0-45eb-a549-de7914ab1beb (was [0]) | 1af936dc-d687-412d-9d4e-ec2627c19ba7 |
| adult (124px) | ebe11ccb-f90f-401a-801f-9998689c3985 (was [1]) | c2821797-d1e9-43a0-975c-c89913e0e345 |

Review-pack sources (deleted once all frames selected): baby c1ece1ca [8],
ya 4bd177f0 [0], adult 9ad242e8 [1].

## Idle animation (v3, both objects per stage)
M's flavor ask: "a little unique thing like the turtle going in his shell" —
folded INTO the idle loop (no new game code needed):
  "gentle idle: slow breathing; head pulls back toward the shell briefly,
   then slides back out; slow blink"

## Import
Model on tools/build_pets_expansion.py. GM MUST BE CLOSED. Output replaces
frames of the EXISTING spr_pet_lockjaw_turtle_<stage>_<s|e> sprites
(new frame UUIDs + .yy rewrite, bottom-center origin, fps 8). No .yyp change.

## Remaining after this species
19 more expansion species same recipe (~100-130 gens each), then the
maturity-flagged adults get judged in-game at F5.

## Duelist (same sitting)
Redesign candidate [0] approved → character 77b28522-59db-49b7-a95a-5862a4ce51d2
"Ashen Duelist Spectral v2" (v3 rotate of the pick, 124px 8-dir). Next: 4-frame
idle south, M review, then t1-t3 via create_character_state.
