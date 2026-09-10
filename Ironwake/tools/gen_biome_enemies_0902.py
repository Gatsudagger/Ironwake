#!/usr/bin/env python
"""09-02 BIOME ENEMY ART RUN - Drowned Reach (15) + Hollow Canopy (15) + identity-pass (9).
The M-locked 08-16 enemy recipe (create_image_pro, 64x64 canvas, ~54px figure, 3/4-front,
style = _refs/style_ff_single.png, 16 candidates / ~20 gens per call). Bosses on 80x80 (~66px).
New designs have no legacy sprite, so the "character base" slot instead carries a shipped
_ff sprite of the same class as a PIXEL-DENSITY reference (labelled "not the subject").
  python tools/gen_biome_enemies_0902.py submit <key> [<key> ...]   # queue jobs
  python tools/gen_biome_enemies_0902.py poll                        # download + SHEET_<key>.png
  python tools/gen_biome_enemies_0902.py sheet <key>                 # rebuild one sheet
Output: _for_review/biome_enemies_0902/ (JOBS.json, <key>_<i>.png, SHEET_<key>.png)
"""
import os, sys, json, glob, urllib.request
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ffgen
from PIL import Image, ImageDraw

ROOT = ffgen.ROOT
REVIEW = os.path.join(ROOT, "_for_review", "biome_enemies_0902")
JOBS = os.path.join(REVIEW, "JOBS.json")
STYLE = os.path.join(ROOT, "_for_review", "enemies_hd_0816", "_refs", "style_ff_single.png")
os.makedirs(REVIEW, exist_ok=True)

# key: (display name, sprite name, size class, density-ref sprite, visual brief)
# size: "std" = 64x64 ~54px tall, "boss" = 80x80 ~66px tall
DENS = {"human": "spr_skeleton_soldier_ff", "beast": "spr_glacial_lurker_ff",
        "wraith": "spr_dungeon_wraith_ff", "golem": "spr_stone_golem_ff",
        "small": "spr_cinder_imp_ff", "crawler": "spr_vault_crawler_ff"}

ENEMIES = {
 # ---- DROWNED REACH (green-black + lantern gold; everything DRIPS) ----
 "drowned_deckhand": ("Drowned Deckhand", "std", "human",
   "a drowned dockhand corpse, bloated grey-green waterlogged skin, sodden dark sailor's coat and rope belt, seaweed hanging off him, water dripping from every edge, holding a long iron boat-hook raised overhead in both hands, hollow pale lantern-gold eyes"),
 "reach_eel": ("Reach Eel", "std", "beast",
   "a long silver-green eel rearing up out of dark water in an S-curve, slick wet scales catching lantern-gold light, needle-toothed open mouth, one pale glowing eye, water dripping"),
 "bloatling": ("Bloatling", "std", "small",
   "a small round drowned corpse-thing swollen like a bladder with gas, grey-green skin stretched tight and shiny, tiny useless limbs, bulging cloudy eyes, floating slightly off the ground, dripping"),
 "silt_wraith": ("Silt Wraith", "std", "wraith",
   "a hooded spectre made of grey silt and dark water rising upward, robes dissolving downward into drifting sediment, no legs, dim lantern-gold eyes in the hood, drips falling from it"),
 "barnacle_thrall": ("Barnacle Thrall", "std", "human",
   "a drowned man encrusted head to foot in barnacles and broken ship-hull planking worn like armour, hunched heavy stance, one arm swollen into a plated club, seaweed, water dripping, dull gold eyes"),
 "tide_crawler": ("Tide Crawler", "std", "crawler",
   "a huge dark green-black crab wearing a broken wooden door as its shell, a rusted iron hinge still bolted to it, two heavy claws raised, lantern-gold eyes on stalks, dripping"),
 "sunken_chorister": ("Sunken Chorister", "std", "human",
   "a drowned choir singer in a sodden dark hooded choir robe, mouth open wide in song, hands clasped at the chest, a soft lantern-gold glow inside the throat, small bubbles, water dripping from the hem"),
 "kelp_hound": ("Kelp Hound", "std", "beast",
   "a hound whose body is woven from dark tangled kelp and driftwood, low prowling stance, glowing lantern-gold eyes, strands of wet weed hanging and dripping, no fur"),
 "the_long_drink": ("The Long Drink", "std", "wraith",
   "a tall gaunt drowned thing with a round lamprey sucker-mouth for a face ringed with teeth, elongated arms with long fingers, green-black slick skin, pale lantern-gold eye spots, water dripping"),
 "anchor_revenant": ("Anchor Revenant", "std", "human",
   "a huge drowned corpse in rusted naval half-armour dragging a massive rusted ship's anchor on a heavy chain over one shoulder, seaweed hanging from it, water dripping, dull gold eyes"),
 "deepwater_sentinel": ("Deepwater Sentinel", "std", "human",
   "an armoured drowned gate-guard in verdigris-green bronze plate and a full closed helm, a tall tower shield and a spear, lantern-gold light in the visor slit, seaweed and dripping water on the armour"),
 "pale_fisher": ("Pale Fisher", "std", "human",
   "a tall skeletal-thin bone-white hooded figure with too-long arms, holding a long fishing rod of bone with a braided sinew line and a hook hanging from it, dark hollow face, dripping"),
 "the_tidewright": ("The Tidewright", "boss", "golem",
   "a hulking drowned lock-keeper: a broad armoured corpse fused with rusted iron lock-gate machinery, a great gear wheel on his back, a huge iron wrench-key in one hand, green-black and rust, lantern-gold glow in the eyes, water pouring off him"),
 "choirmother": ("Choirmother of the Deep", "boss", "wraith",
   "a towering drowned abbess in flowing dark choir vestments trailing water, a tall mitre, both arms raised to conduct, mouth open in a hymn, lantern-gold glow at the throat and eyes, bubbles and dripping water"),
 "leviathan_below": ("Leviathan Below", "boss", "beast",
   "the surfacing head and one great clawed forelimb of a colossal deep-sea leviathan, barnacled black-green hide, rows of pale teeth in a wide jaw, one huge lantern-gold eye, water cascading off it"),
 # ---- HOLLOW CANOPY (deep green + bone + gold light; everything BLOOMS) ----
 "bramble_husk": ("Bramble Husk", "std", "human",
   "a man-shape woven entirely from thorny briar, hollow inside, bone twigs for fingers, a few pale blossoms blooming on its shoulders, glowing gold eyes in the hollow head, dark green and bone"),
 "rootbound_corpse": ("Rootbound Corpse", "std", "human",
   "a corpse held upright by roots grown through it, root tendrils replacing its lower limbs, moss over the chest, small white flowers blooming from its wounds, hollow eye sockets with faint gold light"),
 "spore_moth": ("Spore Moth", "std", "small",
   "a large moth with dusty bone-white wings spread, dark furred thorax, puffs of green spore cloud drifting off its body, faint gold glowing eyes"),
 "canopy_stalker": ("Canopy Stalker", "std", "beast",
   "a lean panther-like beast made of dark bark and shadow, crouched low to pounce, thorn claws, moss along the spine, two glowing gold eyes, a few pale blossoms in the bark"),
 "thicket_boar": ("Thicket Boar", "std", "beast",
   "a huge dark boar with bramble and moss grown into its bristles, bone-yellow tusks, a few small flowers in the thicket on its back, planted charging stance, gold eyes"),
 "witchwood_sapling": ("Witchwood Sapling", "std", "small",
   "a small young witchwood tree-creature, gnarled dark trunk for a body, a face of knot-holes, root feet, pale blossoms in its crown of twigs, gold light in the eyes"),
 "moss_wraith": ("Moss Wraith", "std", "wraith",
   "a drifting hooded spectre draped in thick green moss and hanging vines, no legs, small white flowers blooming on the moss, faint gold eyes deep in the hood"),
 "hollow_nester": ("Hollow Nester", "std", "beast",
   "a spindly raptor-like bird creature of twig and bone, wearing a large animal ribcage around its body like armour, long raking talons, gold eyes, a few blossoms tucked in the ribs"),
 "grafted_knight": ("The Grafted Knight", "std", "human",
   "an armoured knight whose plate has grown into living dark bark, branches sprouting from the pauldrons, roots at the feet, a sword of dark wood, pale blossoms on the branches, gold light in the visor"),
 "sporemind": ("Sporemind", "std", "golem",
   "a hunched humanoid mass of fungus, a huge bracket-mushroom cap for a head, glowing gold gills under the cap, spore mist drifting, pale mycelium hands, deep green and bone tones"),
 "old_growth": ("Old Growth", "std", "golem",
   "a massive ancient treant, bark like weathered ruin-stone, a face of dark hollows, thick moss and gold light in its crown of branches, heavy root feet, blossoms on the upper branches"),
 "the_nest": ("The Nest", "std", "crawler",
   "a large hive-nest woven of thorn and bone, many gold eyes glaring out of dark holes, a few hatchling beaks poking out, roots gripping under it, dark green and bone"),
 "grafted_stag": ("The Grafted Stag", "boss", "beast",
   "a great dark stag crowned with an enormous grafted antler rack of bone and living branches in pale bloom, moss coat, gold light from the eyes and the antler tips, proud standing pose"),
 "mother_bramble": ("Mother Bramble", "boss", "wraith",
   "a towering hedge-woman: a long-limbed figure of interlocking thorn briar walls, a crown of pale roses, thorn fingers spread, gold light in her eyes, deep green and bone"),
 "green_silence": ("The Green Silence", "boss", "wraith",
   "a tall faceless hooded figure of deep green shadow and hanging leaves, no face at all, arms folded into its long sleeves, faint gold light at the throat, a few leaves drifting off it"),
 # ---- BIOME IDENTITY PASS ----
 "candle_thief": ("Candle Thief", "std", "wraith",
   "a hunched shade in a tattered grey cowl clutching an armful of stolen candles, its face a snuffed wick with a thread of smoke, thin grasping fingers, one amber flame glow, amber and bone tones"),
 "rustkeeper": ("Rustkeeper", "std", "golem",
   "a squat rusted-iron jailer construct, prison bars and hinges riveted into its body, a maul made of fused iron keys, one amber lens eye, rust-brown and dark iron"),
 "second_count": ("The Second Count", "std", "human",
   "a robed skeleton auditor in a long black scholar's robe, holding an open ledger in one hand and a quill in the other, bone spectacles, amber glow in the eye sockets"),
 "pyre_dancer": ("Pyre Dancer", "std", "human",
   "a lithe dancing figure of living flame over blackened bone, caught mid-pirouette, an ember trail behind one arm, white-hot core, ember-orange on black"),
 "slagback_tortoise": ("Slagback Tortoise", "std", "crawler",
   "a huge tortoise whose shell is a cracked kiln of glowing slag and embers, molten orange cracks, black stone legs and head, smoke wisps"),
 "the_unquenched": ("The Unquenched", "std", "human",
   "a burning smith corpse in a scorched leather apron, a great forge hammer in both hands, its own ribcage a furnace of embers, white-hot eyes, ember-orange on black"),
 "mourner_in_ice": ("Mourner in Ice", "std", "wraith",
   "a veiled mourner in black funeral dress encased in a shell of clear ice, frost mist around it, frozen tears, hands clasped, pale blue-white and black"),
 "barrow_wight": ("Barrow Wight", "std", "human",
   "a gaunt barrow-dead warrior in ancient rime-covered mail with a crown of ice, a notched sword, frost-blue glowing eyes, frost mist, blue-white and black"),
 "cortege_bearer": ("Cortege Bearer", "std", "golem",
   "a tall stooped ice-armoured corpse-bearer carrying a stack of small coffins strapped to its back, long arms, frost mist, blue glowing eyes, blue-white and black-ice"),
 # ---- DEPTH WARDENS (09-02 late, M: "no recycled sprites") - the ladder bosses ----
 "first_door": ("The First Door", "boss", "golem",
   "a colossal ancient door that stands on its own as a creature: iron-bound black stone door slightly ajar with cold pale light leaking from the dark gap, hinges like ribs, hanging chains, a carved grim face in the stone arch above it, no bearer, no wall around it"),
 "sister_fathom": ("Sister Fathom", "boss", "wraith",
   "a tall drowned nun in a dark sodden habit and veil whose lower body is a coil of pale squid tentacles, holding a plumb-line weight on a cord in one hand, faint pale measuring marks glowing along her sleeves, dripping"),
 "the_tally": ("The Tally", "boss", "beast",
   "a gaunt hunched reptilian keeper-beast crouched on all fours, grey scaled hide scratched all over with countless tally-mark scars, long thin counting claws, one watchful pale eye, dark and patient"),
 "hollowlight": ("Hollowlight", "boss", "wraith",
   "a large ornate caged iron lantern floating in the air with nothing holding it, shedding a warm sickly gold light, a serpentine wyrm of pale smoke coiled around the cage, no bearer, no chain to anything"),
 "weight_of_ironwake": ("The Weight of Ironwake", "boss", "golem",
   "a hulking crab-like creature crushed under an enormous load it carries on its back: a mound of rusted tools, chains, cart wheels, broken furniture and bones all fused together, its thick clawed legs straining, dull eyes under the weight"),
 "long_arithmetic": ("The Long Arithmetic", "boss", "wraith",
   "a tall gaunt robed auditor with great dark moth wings folded behind it, a blank featureless slate for a face, long fingers working a bone abacus held at its chest, dusty violet and bone tones, no writing anywhere"),
 "nothing_in_particular": ("Nothing In Particular", "boss", "beast",
   "a huge hound made of black void and negative space, its body barely there - a faint pale edge outline around emptiness, one cold pale eye, a few wisps of dark smoke, prowling low"),
 "the_understudy": ("The Understudy", "boss", "human",
   "a featureless grey clay-flesh figure mid-mimicry, wearing a half-copied set of adventurer's plate armour that is still forming from its body, a copied sword in one hand, a smooth blank mask for a face with two faint eye-lights"),
 "hollow_crown": ("The Hollow Crown", "boss", "wraith",
   "a colossal circlet of black iron and bone, the size of a gate, hovering upright in the air with no wearer, faint grieving pale wisps of light drifting inside its ring, cold and silent"),
 "the_bottom": ("The Bottom", "boss", "golem",
   "a vast hulking heap-golem made of everything that ever fell: stone slabs, broken weapons, bones and rusted iron, all arranged neatly and deliberately into a towering body, a face of dark hollows, very heavy and very still"),
}
SIZE = {"std": (64, "about 54 pixels tall"), "boss": (80, "about 66 pixels tall")}


def dens_png(spr):
    f = sorted(glob.glob(os.path.join(ROOT, "sprites", spr, "*.png")))[0]
    im = Image.open(f).convert("RGBA")
    im = im.crop(im.getbbox())
    im = im.resize((im.width * 3, im.height * 3), Image.NEAREST)
    out = os.path.join(REVIEW, "_dens_%s.png" % spr)
    im.save(out)
    return out


def prompt(desc, size):
    return ("Pixel art enemy sprite in EXACTLY the same style as the reference sprite (same game): "
            "16-bit tactics RPG density, bold black outline, flat limited colours, chunky pixels, simple readable shapes. "
            "Subject: %s. Single figure, 3/4-FRONT view facing slightly LEFT toward the viewer, whole body visible, "
            "%s on the canvas. ONLY the figure on a fully transparent background - no ground, no shadow, "
            "no props lying around, no text, no second creature. Dark medieval gothic fantasy." % (desc, SIZE[size][1]))


def submit(keys):
    jobs = json.load(open(JOBS)) if os.path.exists(JOBS) else {}
    for key in keys:
        if key in jobs and jobs[key]:
            print("skip", key, jobs[key]); continue
        name, size, dens, desc = ENEMIES[key]
        px = SIZE[size][0]
        args = {"description": prompt(desc, size), "width": px, "height": px, "no_background": True,
                "style_image_base64": ffgen.b64file(STYLE),
                "reference_images": json.dumps([{"base64": ffgen.b64file(dens_png(DENS[dens])),
                                                 "usage": "pixel density and rendering reference from the same game - NOT the subject, do not copy this design"}])}
        txt, _ = ffgen.call_tool("create_image_pro", args)
        jid = None
        for tok in txt.replace('"', ' ').replace(',', ' ').split():
            if len(tok) == 36 and tok.count('-') == 4: jid = tok; break
        jobs[key] = jid
        print(key, jid or txt[:300])
        json.dump(jobs, open(JOBS, "w"), indent=1)


def sheet(key):
    fs = sorted(glob.glob(os.path.join(REVIEW, "%s_[0-9]*.png" % key)), key=lambda p: int(p.rsplit("_", 1)[1][:-4]))
    imgs = [Image.open(f).convert("RGBA") for f in fs]
    if not imgs: return
    px = SIZE[ENEMIES[key][1]][0]
    S = 3; cols = 8; rows = (len(imgs) + cols - 1) // cols; cell = px * S + 12
    sh = Image.new("RGBA", (cols * cell + 12, rows * (cell + 18) + 12), (28, 30, 40, 255))
    d = ImageDraw.Draw(sh)
    for i, im in enumerate(imgs):
        x = 12 + (i % cols) * cell; y = 12 + (i // cols) * (cell + 18)
        big = im.resize((im.width * S, im.height * S), Image.NEAREST)
        sh.paste(big, (x, y), big)
        d.text((x + 2, y + px * S + 2), "%s #%d" % (key, i), fill=(230, 230, 230, 255))
    sh.save(os.path.join(REVIEW, "SHEET_%s.png" % key))
    print(key, len(imgs), "candidates -> SHEET_%s.png" % key)


def poll():
    jobs = json.load(open(JOBS))
    for key, jid in jobs.items():
        if not jid: continue
        if glob.glob(os.path.join(REVIEW, "%s_[0-9]*.png" % key)):
            print(key, "already downloaded"); continue
        txt, _ = ffgen.call_tool("get_image", {"job_id": jid})
        if "completed" not in txt.lower():
            print(key, "status:", txt[:120].replace("\n", " | ")); continue
        n = 0
        for i in range(32):
            url = "https://api.pixellab.ai/mcp/images/%s/download?index=%d" % (jid, i)
            try:
                data = urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "ironwake"}), timeout=60).read()
            except Exception:
                break
            open(os.path.join(REVIEW, "%s_%d.png" % (key, i)), "wb").write(data); n += 1
        if n: sheet(key)
        else: print(key, "no images")


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "submit": submit(sys.argv[2:] if len(sys.argv) > 2 else list(ENEMIES))
    elif cmd == "poll": poll()
    elif cmd == "sheet": sheet(sys.argv[2])
