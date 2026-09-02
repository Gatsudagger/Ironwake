#!/usr/bin/env python
"""Round-2 stage-still re-rolls with per-item failure fixes (M vet 08-27). Each is 1 gen
(pixflux fresh + adult-palette lock). Submits under the 10-job cap, polls until all land."""
import os, sys, json, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ffgen, missgen

# (species, stage): fix text appended after the standard stage prompt
FIX = {
 ("salt_hare","youngadult"):    "Standing FREE in mid-air pose - absolutely no rock, no salt mound, no ground.",
 ("mire_heron","youngadult"):   "A tall thin young HERON bird, long legs hanging free - absolutely no grass, no mound, no ground.",
 ("gravel_tick","baby"):        "A tiny round pebble-shelled TICK, six stubby chitin legs, one small red eye - an insect, not a mammal.",
 ("glass_eel","youngadult"):    "A coiled TRANSLUCENT GLASS EEL - serpentine fish, NO legs, NO wings, glassy pale body showing a silver spine thread.",
 ("glass_eel","baby"):          "A tiny coiled glass eel hatchling - a translucent serpentine FISH, NO legs, NO wings, NO dragon features.",
 ("barrow_mole","youngadult"):  "A mole ON ALL FOURS in digging posture, enormous bone shovel-claws, shroud-black fur - never upright.",
 ("barrow_mole","baby"):        "A mole pup ON ALL FOURS with oversized bone claws and blind eyes - NO horns, a MOLE not an imp.",
 ("tallow_moth","youngadult"):  "The body is a CREAM-WHITE melting candle like the adult, pale cream wings - not brown, not a wasp.",
 ("crypt_gryphon","youngadult"):"A QUADRUPED undead gryphon (lion body, eagle head, bone-tipped wings) - absolutely no grass, no mound, no ground.",
 ("threehunger","youngadult"):  "Same DARK near-black body as the adult with the tri-colour elemental mane (fire red, ice blue, storm violet) - not yellow, not bright.",
 ("threehunger","baby"):        "A DARK near-black lion cub with small wisps of tri-colour elemental mane (fire red, ice blue, storm violet) - not pink.",
 ("wing_hare","youngadult"):    "A young HARE (rabbit, not a deer) with small antler nubs between long ears - absolutely no dirt, no mound, no ground.",
 ("drowned_lamp","youngadult"): "A SWIMMING skeletal fish seen side-on - NO legs, NOT standing, the caged amber lantern hangs from its brow stalk.",
 ("honeymaw","youngadult"):     "ON ALL FOURS like a real badger - never upright, never plush-toy-like; two small honey-dripping hive lumps on the shoulders.",
 ("flicker_finch","baby"):      "A small dusky purple-grey FINCH chick - a bird only, no horns, no tufted imp features.",
 ("paleswimmer","youngadult"):  "An EYELESS bone-white cave FISH - smooth featureless head with NO eyes and NO face, fins only, NO limbs.",
 ("paleswimmer","baby"):        "A tiny EYELESS bone-white fish larva - NO eyes, NO face, NO limbs, translucent fins.",
 ("sum_moth","youngadult"):     "Flying with wings spread, legs tucked - absolutely no mound, no perch, no ground.",
 ("sum_moth","baby"):           "A tiny plump young MOTH with stubby undersized wings and faint glowing patterns - an insect, no horns, no imp.",
 ("mimicling","youngadult"):    "Standing free - absolutely no pedestal, no statue base, no ground.",
 ("chorister_fry","baby"):      "ONE single tiny deep-sea FISH with a rounded open mouth as if singing, blue-black scales - a fish, no legs.",
 ("leviathan_calf","baby"):     "A tiny cosmic space-whale calf floating in the air, grey-blue hide flecked with glowing stars - one whole whale, clearly drawn.",
}

def submit_one(sp, st):
    picks = json.load(open(missgen.PICKS))
    ap = picks[sp]["adult"]
    base = ap if os.path.isabs(ap) else os.path.join(missgen.REVIEW, sp, ap)
    name, vis = ffgen.SPECIES[sp]
    vis = missgen.REDIRECT.get(sp, vis)
    desc = ("Pixel art creature sprite, bold black outline, flat limited colours, chunky pixels. %s (%s - %s). "
            "ONLY the creature on a fully transparent background - no props, no text. Dark gothic fantasy, "
            "natural animal posture - never humanoid.%s %s"
            % (missgen.STAGE_PROMPT[st], name, vis, missgen.NOGROUND, FIX[(sp, st)]))
    args = {"description": desc, "width": 64, "height": 64, "no_background": True,
            "direction": "south", "view": "low top-down", "outline": "single color black outline",
            "color_image_base64": ffgen.b64file(base)}
    txt, _ = ffgen.call_tool("create_image_pixflux", args)
    jid = missgen._jid(txt)
    if jid:
        rows = missgen._load(missgen.STAGEJ)
        rows.append({"species": sp, "stage": st, "mode": "fresh", "job": jid, "done": False, "raw": txt[:150]})
        missgen._save(missgen.STAGEJ, rows)
    print(("queued" if jid else "DEFER"), sp, st, flush=True)
    return jid is not None

if __name__ == "__main__":
    todo = list(FIX.keys())
    for rnd in range(40):
        todo = [k for k in todo if not submit_one(*k)]
        time.sleep(25)
        try:
            pending = missgen.stagepoll()
        except Exception as e:
            print("poll err", e, flush=True); pending = 99
        print("round", rnd, "left to submit", len(todo), "pending", pending, flush=True)
        if not todo and pending == 0:
            break
    print("REROLLS DONE", flush=True)
