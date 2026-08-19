#!/usr/bin/env python
"""Builds the "social media posts" folder: a 14-day X/Twitter plan (2-3 posts a day), each day
in its own folder with the post text (.md) and ready-to-attach PNG images composed from the
game's own sprites (pets at every stage, scions, eggs, classes, NPCs, dungeons, bosses).
Re-run any time; it overwrites. Posts are written in plain language on purpose.
  python tools/make_social_posts.py
"""
import os, glob, re, shutil
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "social media posts")
SPR = os.path.join(ROOT, "sprites")
BG = (14, 12, 20, 255)
FG = (232, 222, 200, 255)
DIM = (150, 145, 160, 255)
GOLD = (235, 195, 90, 255)
STORE = "https://store.steampowered.com/app/4954740/Ironwake/"
PLAY = "https://play.google.com/store/apps/details?id=com.seahorsegames.ironwake"
TAGS = "#indiegame #roguelite #pixelart #gamedev #IndieGameDev"

def font(sz):
    for f in ["C:/Windows/Fonts/georgia.ttf", "C:/Windows/Fonts/times.ttf", "C:/Windows/Fonts/arial.ttf"]:
        if os.path.exists(f): return ImageFont.truetype(f, sz)
    return ImageFont.load_default()

def spr_png(name, frame=0):
    d = os.path.join(SPR, name)
    if not os.path.isdir(d): return None
    # first frame per the .yy order when possible, else first png
    yy = os.path.join(d, name + ".yy")
    fs = sorted(glob.glob(os.path.join(d, "*.png")))
    if not fs: return None
    try:
        t = open(yy, encoding="utf-8").read()
        order = re.findall(r'"path":"sprites/%s/%s.yy",\},"resourceType":"SpriteFrameKeyframe"' % (name, name), t)
        ids = re.findall(r'"Id":\{"name":"([0-9a-f-]+)","path":"sprites/%s/%s.yy"' % (name, name), t)
        if ids:
            p = os.path.join(d, ids[min(frame, len(ids) - 1)] + ".png")
            if os.path.exists(p): return Image.open(p).convert("RGBA")
    except Exception:
        pass
    return Image.open(fs[0]).convert("RGBA")

def crisp(im, target_h):
    im = im.crop(im.getbbox()) if im.getbbox() else im
    sc = max(1, round(target_h / max(1, im.height)))
    return im.resize((im.width * sc, im.height * sc), Image.NEAREST)

def fit(im, target_h):
    im = im.crop(im.getbbox()) if im.getbbox() else im
    sc = target_h / max(1, im.height)
    return im.resize((max(1, round(im.width * sc)), target_h), Image.NEAREST if sc >= 1 else Image.LANCZOS)

def card(w, h, title, subtitle=""):
    im = Image.new("RGBA", (w, h), BG)
    d = ImageDraw.Draw(im)
    # thin gold frame
    d.rectangle([8, 8, w - 9, h - 9], outline=(120, 100, 60, 255), width=2)
    d.text((28, 22), title, font=font(44), fill=FG)
    if subtitle: d.text((30, 78), subtitle, font=font(24), fill=DIM)
    return im, d

def lineup(path, title, subtitle, items, cell_h=260, cols=None, labels=True, crisp_px=True, raw=False):
    """items: list of (label, PIL image). raw=True: images are pasted as given (pre-scaled)."""
    n = len(items); cols = cols or min(n, 6); rows = (n + cols - 1) // cols
    cw = 290; ch = cell_h + (44 if labels else 10)
    w = max(1200, cols * cw + 60); h = 120 + rows * ch + 30
    im, d = card(w, h, title, subtitle)
    for i, (lbl, sp) in enumerate(items):
        if sp is None: continue
        if raw: g = sp
        else:
            g = crisp(sp, cell_h - 20) if crisp_px else fit(sp, cell_h - 20)
            if g.height > cell_h - 10 or g.width > cw - 20: g = fit(g, min(cell_h - 20, int((cw - 20) * g.height / max(1, g.width))))
        x = 30 + (i % cols) * cw; y = 120 + (i // cols) * ch
        im.paste(g, (x + (cw - g.width) // 2, y + (cell_h - g.height) - 4), g)
        if labels:
            f = font(22); tw = d.textlength(lbl, font=f)
            d.text((x + (cw - tw) / 2, y + cell_h + 6), lbl, font=f, fill=GOLD)
    d.text((w - 230, h - 40), "IRONWAKE", font=font(22), fill=DIM)
    im.save(path)
    return path

def stage_strip(path, species, nice):
    # Growth reads as growth: baby 60% / young adult 80% / adult 100% of the cell.
    items = []
    for st, lbl, frac in [("baby", "Baby", 0.60), ("youngadult", "Young adult", 0.80), ("adult", "Adult", 1.0)]:
        sp = spr_png("spr_pet_%s_%s_s" % (species, st))
        g = crisp(sp, int(280 * frac))
        if g.width > 270: g = fit(g, int(g.height * 270 / g.width))
        items.append((lbl, g))
    return lineup(path, nice + " grows up with you", "Every creature has three life stages - and a fourth, Awakened, for the ones you raise to the end", items, cell_h=300, cols=3, raw=True)

def spotlight(path, species, nice, move, line, stage="adult"):
    """One big creature + its signature move, for the spotlight posts."""
    w, h = 1200, 560
    im, d = card(w, h, nice, "Signature move: " + move)
    sp = spr_png("spr_pet_%s_%s_s" % (species, stage))
    g = crisp(sp, 400)
    if g.width > 520: g = fit(g, int(g.height * 520 / g.width))
    im.paste(g, (60 + (520 - g.width) // 2, 120 + (400 - g.height) // 2), g)
    # wrapped line on the right
    f = font(30); words = line.split(); rows = []; cur = ""
    for wd in words:
        t = (cur + " " + wd).strip()
        if d.textlength(t, font=f) > 560: rows.append(cur); cur = wd
        else: cur = t
    if cur: rows.append(cur)
    y = 170
    for r in rows: d.text((620, y), r, font=f, fill=FG); y += 42
    d.text((w - 230, h - 40), "IRONWAKE", font=font(22), fill=DIM)
    im.save(path); return path

POSTS = []   # (day, idx, title, body, image, note) - written out as plain text + CSV at the end
def write(day_dir, idx, title, body, image=None, note=None):
    day = int(os.path.basename(day_dir).split("_")[1])
    POSTS.append((day, idx, title, body.strip(), image or "", note or ""))

# ---------------------------------------------------------------------------
if os.path.isdir(OUT): shutil.rmtree(OUT)
os.makedirs(OUT)
IMG = os.path.join(OUT, "images"); os.makedirs(IMG)

# ---- images ----------------------------------------------------------------
# ONE art generation only (M 08-19: mixing the 64px stills / old pair with the 124px batch
# showed how mismatched they are) - these are all from the same 124px 9-frame batch.
pets_a = [("Pyre Bison", "pyre_bison"), ("Lockjaw Turtle", "lockjaw_turtle"), ("Stormkirin", "stormkirin"), ("Glimmer Slime", "glimmer_slime"),
          ("Canopy Shrew", "canopy_shrew"), ("Duskraven", "duskraven"), ("Pale Widow", "pale_widow"), ("Thorn Boar", "thorn_boar"),
          ("Shellback", "shellback"), ("Bone Stag", "bone_stag"), ("Sporeling", "sporeling"), ("Voidkit", "voidkit")]
lineup(os.path.join(IMG, "pets_lineup_adults.png"), "Some of the creatures you can raise", "47 species live in Ironwake's dungeons. Every one can be found, hatched and raised.",
       [(n, spr_png("spr_pet_%s_adult_s" % s)) for n, s in pets_a], cell_h=250, cols=6)
lineup(os.path.join(IMG, "pets_lineup_babies.png"), "...and this is how they start", "Babies. Most arrive as eggs; a few are found alive in the dungeon.",
       [(n, spr_png("spr_pet_%s_baby_s" % s)) for n, s in pets_a], cell_h=220, cols=6)
stage_strip(os.path.join(IMG, "stages_saber_hound.png"), "bone_stag", "The Bone Stag")
stage_strip(os.path.join(IMG, "stages_luna_moth.png"), "luna_moth", "The Luna Moth")
stage_strip(os.path.join(IMG, "stages_pyre_bison.png"), "pyre_bison", "The Pyre Bison")
stage_strip(os.path.join(IMG, "stages_frostmarten.png"), "stormkirin", "The Stormkirin")
scions = [("Vaultling", "vaultling"), ("Marrow Adder", "marrow_adder"), ("Gaolwyrm", "gaolwyrm"), ("Cinder Newt", "cinder_newt"), ("Magma Leech", "magma_leech"),
          ("Golemite", "golemite"), ("Rimefox", "rimefox"), ("Crypt Bat", "crypt_bat"), ("Hoarfrost Drake", "hoarfrost_drake")]
lineup(os.path.join(IMG, "scions_lineup.png"), "Scions - the bosses' own kin", "Nine creatures only a boss can drop. Each one has a signature move nobody else has.",
       [(n, spr_png("spr_pet_%s_adult_s" % s)) for n, s in scions], cell_h=250, cols=5)
eggs = [("Savage", "savage"), ("Tender", "tender"), ("Fortune", "fortune"), ("Gilded", "gilded"), ("Scholar", "scholar"), ("Dust", "dust"), ("Ley", "ley"), ("Keen", "keen"), ("Vital", "vital"), ("Warding", "warding")]
lineup(os.path.join(IMG, "eggs_lineup.png"), "Ten kinds of egg", "The shell tells you what the creature leans toward - if you can read it. Bairc can.",
       [(n, spr_png("spr_pet_egg_%s" % s)) for n, s in eggs], cell_h=200, cols=5)
lineup(os.path.join(IMG, "npcs_camp.png"), "The camp at Ironwake", "Seven people who remember what you did for them.",
       [("Petra - merchant", spr_png("spr_npc_petra_idle")), ("Dorn - smith", spr_png("spr_npc_dorn_idle")), ("Vex - trainer", spr_png("spr_npc_vex_idle")),
        ("Maren - runesmith", spr_png("spr_npc_maren_idle")), ("Sable - alchemist", spr_png("spr_npc_sable_idle")), ("Vael - aesthete", spr_png("spr_npc_vael_idle")),
        ("Bairc - creature keeper", spr_png("spr_npc_bairc_idle"))], cell_h=260, cols=4)
lineup(os.path.join(IMG, "bosses.png"), "Three dungeons, three final bosses", "The Ashen Vault, the Scorched Depths, the Tundra Tomb - and what waits at the bottom of each.",
       [("Malgrath the Warden", spr_png("spr_malgrath_warden_ff")), ("Forge Tyrant", spr_png("spr_forge_tyrant")), ("The Eternal Frost", spr_png("spr_eternal_frost")),
        ("Bone Sovereign", spr_png("spr_bone_sovereign_hd")), ("Molten Revenant", spr_png("spr_molten_revenant")), ("Glacial Warden", spr_png("spr_glacial_warden"))], cell_h=300, cols=3)
# Launch post = the Steam key art, untouched (no caption bar on a hero image).
shutil.copyfile(os.path.join(ROOT, "tools", "steam", "art", "key_art_master.png"), os.path.join(IMG, "key_art.png"))
lineup(os.path.join(IMG, "dungeons.png"), "Three dungeons", "Ashen Vault - Scorched Depths - Tundra Tomb. Five Awakening tiers each, then the endless Descent.",
       [("Ashen Vault", spr_png("spr_dungeon_ashen_vault")), ("Scorched Depths", spr_png("spr_dungeon_scorched_depths")), ("Tundra Tomb", spr_png("spr_dungeon_tundra_tomb"))],
       cell_h=300, cols=3, crisp_px=False)
lineup(os.path.join(IMG, "classes.png"), "Three classes", "Arcanist - Bloodwarden - Shadowstrider. Pick one, build it your way.",
       [("Arcanist", spr_png("spr_portrait_arc_m1")), ("Bloodwarden", spr_png("spr_portrait_blood_m2")), ("Shadowstrider", spr_png("spr_portrait_shadow_m1"))],
       cell_h=420, cols=3, crisp_px=False)
lineup(os.path.join(IMG, "abilities_sample.png"), "A few of the 78 abilities", "Every one has its own talent web.",
       [("Soulfire", spr_png("spr_ability_soulfire")), ("Arcane Burst", spr_png("spr_ability_arcane_burst")), ("Blink", spr_png("spr_ability_blink")),
        ("Gore Strike", spr_png("spr_ability_gore_strike")), ("Blood Leech", spr_png("spr_ability_blood_leech")), ("Shadow Step", spr_png("spr_ability_shadow_step")),
        ("Snipe", spr_png("spr_ability_snipe")), ("Bear Trap", spr_png("spr_ability_bear_trap"))], cell_h=200, cols=4)
lineup(os.path.join(IMG, "duelist_and_ghost.png"), "Not everything down there wants to kill you", "The Ashen Duelist wants a fair fight. The Merchant's Ghost wants your gold.",
       [("The Ashen Duelist", spr_png("spr_ashen_duelist")), ("Banshee in a Bottle", spr_png("spr_icon_banshee_bottle"))], cell_h=320, cols=2)
lineup(os.path.join(IMG, "enemies_sample.png"), "Some of what's waiting", "Each dungeon family has its own foes - and several looks for each one.",
       [("Skeleton Soldier", spr_png("spr_skeleton_soldier_ff")), ("Vault Crawler", spr_png("spr_vault_crawler_ff")), ("Cinder Imp", spr_png("spr_cinder_imp_ff")),
        ("Magma Slug", spr_png("spr_magma_slug_ff2")), ("Glacial Lurker", spr_png("spr_glacial_lurker_ff")), ("Snowbound Wraith", spr_png("spr_snowbound_wraith_ff"))], cell_h=240, cols=6)

spotlight(os.path.join(IMG, "spot_vaultling.png"), "vaultling", "The Vaultling", "Warden's Seal",
          "Once per fight, the first enemy ability that would hit you breaks against the seal. Negated. Its parent is the Vault Sentinel.")
spotlight(os.path.join(IMG, "spot_crypt_bat.png"), "crypt_bat", "The Crypt Bat", "Echo Shriek",
          "The first time you drop below 40% health in a fight, it shrieks - and every enemy on the field is left Exposed.")
spotlight(os.path.join(IMG, "spot_lantern_wyrm.png"), "lantern_wyrm", "The Lantern Wyrm", "Borrowed Light",
          "The first time you fall below half health, its lantern gives back 15% of your max HP.")
spotlight(os.path.join(IMG, "spot_golemite.png"), "golemite", "The Golemite", "Stoneshadow",
          "The first blow that would drop you below half health is halved by its stone shadow.")
spotlight(os.path.join(IMG, "spot_hoarfrost_drake.png"), "hoarfrost_drake", "The Hoarfrost Drake", "Long Winter",
          "An elite or boss's first action freezes in its throat - delayed a whole turn.")

# ---- posts -------------------------------------------------------------------
D = lambda n: os.path.join(OUT, "day_%02d" % n)
I = lambda f: "images/" + f

# DAY 1 - launch
write(D(1), 1, "Launch announcement",
f"""Ironwake is out now on Steam and Android.

A dark-fantasy roguelite where you dive into three dungeons, fight turn-based battles, and raise the creatures you find down there.

25% off this week.

{STORE}

{TAGS}""", I("key_art.png"), "Pin this one. Add the Play Store link in a reply once the listing is live.")
write(D(1), 2, "What the game is, in one breath",
f"""What is Ironwake?

- Turn-based combat with action points
- Three dungeons, five difficulty tiers each
- A camp full of people who remember you
- 47 creatures you can hatch, raise and fight beside

Out now: {STORE}""", I("pets_lineup_adults.png"))
write(D(1), 3, "First-day thank you + ask",
"""Day one. Thank you to everyone who picked it up.

If you run into anything weird, tell us here or on the Steam forum - we're reading everything and patching fast.

If you're enjoying it, a Steam review helps a small team more than you'd think.""", I("pets_lineup_babies.png"))

# DAY 2 - pets intro
write(D(2), 1, "Pets: the idea",
"""Let's talk about the creatures.

Deep in the dungeon you find eggs. Bring one back to camp and Bairc, the creature keeper, raises it for you.

It grows, it learns to fight beside you, and eventually it becomes something the dungeon has never seen.""", I("eggs_lineup.png"))
write(D(2), 2, "Three stages",
"""Every creature grows through three stages: baby, young adult, adult.

Raise one far enough and it can cross into a fourth - Awakened - with a permanent gift of your choosing.

This is the Bone Stag.""", I("stages_saber_hound.png"))
write(D(2), 3, "Found alive",
"""Not every creature comes from an egg.

Some are found alive in the dungeon - already grown - and just... follow you home.

A few of those arrive corrupted. You can cure that. Or not.""", I("pets_lineup_babies.png"))

# DAY 3 - scions & signature moves
write(D(3), 1, "Scions",
"""Every boss in Ironwake has kin.

Beat the boss and there's a chance a Scion drops - a creature only that boss can give you. Nine of them exist.

Each Scion has a signature move no other creature has.""", I("scions_lineup.png"))
write(D(3), 2, "Signature move spotlight: Vaultling",
"""Signature move spotlight: the Vaultling.

Warden's Seal - once per fight, the first enemy ability that would hit you breaks against the seal. Negated. Gone.

Its parent is the Vault Sentinel.""", I("spot_vaultling.png"), "A short clip of the seal going off beats the card if you have one.")
write(D(3), 3, "Signature move spotlight: Crypt Bat",
"""Signature move spotlight: the Crypt Bat.

Echo Shriek - the first time you drop below 40% health in a fight, it shrieks and EVERY enemy on the field is left Exposed.

That's the moment you hit them with everything.""", I("spot_crypt_bat.png"))

# DAY 4 - garden, feeding, bond
write(D(4), 1, "Bairc's garden",
"""Your creatures don't live in a menu. They live in Bairc's garden.

Walk the grounds, feed them, toss a crumb in the pond, stack a stone on the cairn. Creatures you donate stay there for good.

(It's getting a big customization update after launch.)""", I("pets_lineup_adults.png"), "A garden screenshot/clip beats the lineup if you have one.")
write(D(4), 2, "Feeding + favored treats",
"""Feeding is simple: basic feed grows them, good food grows them faster, treats build the bond.

Every species has a favored treat. Get it right and the bond jumps. A Stormkirin will wait out a storm for the right one.""", I("stages_frostmarten.png"))
write(D(4), 3, "Bond",
"""Bond matters.

A creature that trusts you fights harder for you. Bond unlocks its deeper abilities and, at the top, its Awakened form.

It's not a grind. It's feeding the thing that saved your life on floor 3.""", I("stages_luna_moth.png"))

# DAY 5 - classes
write(D(5), 1, "Three classes",
"""Three classes.

Arcanist - spells, souls, big bursts.
Bloodwarden - heavy hits, blood magic, heals by hurting.
Shadowstrider - dodges, traps, crits.

Every ability has its own talent web, so two Arcanists rarely play the same.""", I("classes.png"))
write(D(5), 2, "Arcanist",
"""The Arcanist runs on Souls.

Cheap spells feed the reserve, big spells spend it. Soulfire, Void Drain, Arcane Burst - chain them right and the last one hits like a truck.

Spam it and it fades. Play the rhythm.""", I("abilities_sample.png"))
write(D(5), 3, "Shadowstrider",
"""The Shadowstrider sets the table before the fight starts.

Bear traps, snares, triplines. Blink out of a hit. Then Snipe whatever's left standing in the wreckage.

Rooted enemies can't reach you. Ranged ones can. Plan for both.""", I("abilities_sample.png"))

# DAY 6 - combat
write(D(6), 1, "Action points",
"""Combat: you get action points each turn. Abilities cost points. A basic attack is free.

Spend, then end your turn. Enemies act. Repeat.

Simple rules, a lot of room inside them.""", I("enemies_sample.png"), "A combat clip beats the lineup if you have one.")
write(D(6), 2, "Intents",
"""Enemies tell you what they're about to do.

The chip above each health bar shows it: red for an attack (with rough damage), purple for a spell, green for a heal, amber for a status.

Stun, root or silence them and the chip greys out. That move is cancelled.""", I("enemies_sample.png"))
write(D(6), 3, "Detonations",
"""Set up, then detonate.

Put a burn, a bleed, a chill on something - then hit it with a detonator like Snipe or Arcane Burst and the status goes off.

Rift detonates every enemy it touches. That's the cascade turn.""", I("abilities_sample.png"))

# DAY 7 - dungeons
write(D(7), 1, "Three dungeons",
"""Three dungeons.

The Ashen Vault - the dead who were left behind.
The Scorched Depths - a forge that never cooled.
The Tundra Tomb - pilgrims who were never let in.

Each has its own monsters, bosses, music and secrets.""", I("dungeons.png"))
write(D(7), 2, "Bosses",
"""At the bottom of each dungeon: something that should have stayed asleep.

Beat it and its kin might follow you home.""", I("bosses.png"))
write(D(7), 3, "Awakening tiers",
"""Every dungeon has five Awakening tiers.

Higher tiers: tougher enemies, bigger packs, bosses that enrage - and better, rarer loot.

Start at A0. Work up. Post-game there's an endless Descent for the people who clear all of it.""", I("bosses.png"))

# DAY 8 - camp
write(D(8), 1, "The camp",
"""Between runs you're at camp.

Petra sells supplies. Dorn forges. Vex trains you. Maren works runes. Sable brews. Vael changes how you look. Bairc keeps your creatures.

Every one of them remembers what you've done for them.""", I("npcs_camp.png"))
write(D(8), 2, "Bonds with the camp",
"""Help the camp and the camp helps back.

Gifts and favors deepen your bond with each person. Rank up their stations and they open new services - better stock, cheaper training, new crafts.""", I("npcs_camp.png"))
write(D(8), 3, "The tavern board",
"""The tavern board is where the townsfolk ask for things.

Hunts, errands, favors. Pick up a posting before a run and there's a little extra waiting when you get back.""", I("npcs_camp.png"), "A board screenshot beats the NPC card if you have one.")

# DAY 9 - crafting
write(D(9), 1, "Pattern Book",
"""Crafting in Ironwake starts with breaking things.

Smelt gear at Dorn's and you learn its pattern. Study enough patterns and you can craft that affix yourself - uncommon, then rare, then epic.

The Pattern Book keeps track.""", I("abilities_sample.png"), "A Pattern Book screenshot beats this if you have one.")
write(D(9), 2, "Runes",
"""Maren sockets runes.

Gear runes add stats. Aspect runes change how you fight - more crit, more dodge, fire on every spell. Three tiers, and the top tier can only be crafted.""", I("npcs_camp.png"))
write(D(9), 3, "Temper + reforge",
"""Don't like a roll? Dorn rerolls it.

Reforge reworks an item's affixes for an ingot. Tempering raises its quality step by step. Your favorite sword can stay your favorite sword.""", I("classes.png"))

# DAY 10 - odd encounters
write(D(10), 1, "The Ashen Duelist",
"""Not everything down there wants to kill you.

The Ashen Duelist wants a fair fight. Beat him and he comes back stronger next time, with new tricks and scars to match. Keep winning and he starts parting with relics.""", I("duelist_and_ghost.png"))
write(D(10), 2, "Merchant's Ghost",
"""Sometimes a ghost sets up shop between rooms.

He sells things nobody else has. He does not haggle. He has been dead a while and is in no hurry.""", I("duelist_and_ghost.png"))
write(D(10), 3, "Banshee in a Bottle",
"""Every dungeon's final boss guards a Banshee in a Bottle.

Carry it home, let Maren release it, and the spirit leaves a song behind - a new track for your camp or dungeon music.

There are more songs than you think.""", I("duelist_and_ghost.png"))

# DAY 11 - corruption, capstones, awakened
write(D(11), 1, "Corruption",
"""Some creatures come back corrupted.

It pushes at them - and at you, while it's carried. Each run it gets worse. Cure it at Bairc's, or let it run its course and see what it becomes.

Your call. It's always your call.""", I("spot_golemite.png"))
write(D(11), 2, "Capstones",
"""Raise a creature to adulthood and it chooses a capstone - a permanent gift.

Cheaper boons. Harder hits. A shield when you need it most. Found creatures roll theirs on the spot; raised ones let you pick.""", I("stages_pyre_bison.png"))
write(D(11), 3, "Awakened",
"""The fourth stage: Awakened.

It takes a deep bond and a long road. The creature crosses over, keeps everything it was, and gains an aura that changes the fight around it.

Worth the road.""", I("stages_luna_moth.png"))

# DAY 12 - mobile
write(D(12), 1, "Also on Android",
f"""Ironwake is on Android too - the full game, not a cut-down one.

Built for touch from the start: tap to target, an on-screen d-pad, pinch to zoom the UI.

{PLAY}""", I("pets_lineup_adults.png"), "A phone screenshot beats this if you have one.")
write(D(12), 2, "Same save, any way you play",
"""Keyboard, mouse, controller or touch - every screen works with all of them.

Play how you like. We tested it on a phone with fat thumbs.""", I("dungeons.png"))

# DAY 13 - challenge + achievements
write(D(13), 1, "Iron Vow",
"""For the people who want it to hurt:

Iron Vow - one life. Ironman saves - quitting is a checkpoint, not an escape. And the Descent: an endless fall past the last Awakening tier.""", I("bosses.png"))
write(D(13), 2, "Achievements",
"""67 Steam achievements, and none of them are "press start".

Hatch every scion. Win a duel at every tier. Free every banshee. See what the dungeon does when you stop being afraid of it.""", I("scions_lineup.png"))

# DAY 14 - community
write(D(14), 1, "Show us your creatures",
"""Show us your creatures.

Screenshot your favorite - name, stage, what it does for you - and reply here. We'll share the best ones.

(We have opinions about the Pyre Bison.)""", I("pets_lineup_adults.png"))
write(D(14), 2, "Patch cadence",
"""Week one is done. Here's how updates work:

Small fixes ship as we find them. Bigger things - the garden overhaul, more creatures, new songs - come in named updates with notes.

Tell us what you want first.""", I("spot_hoarfrost_drake.png"))
write(D(14), 3, "Thanks",
f"""One week since launch.

Thank you. Every review, every bug report, every screenshot of a Bonehound wearing a name it didn't ask for - it all helps.

{STORE}""", I("spot_lantern_wyrm.png"))

# ---- OUTPUT: one folder per day: posts.txt + the images right next to it (post_N.png) ----
import csv
days = sorted(set(p[0] for p in POSTS))
master = []
for d in days:
    dd = os.path.join(OUT, "day_%02d" % d); os.makedirs(dd, exist_ok=True)
    lines = ["DAY %d" % d, "=" * 40, ""]
    for (day, idx, title, body, image, note) in [p for p in POSTS if p[0] == d]:
        lines.append("--- Post %d: %s ---" % (idx, title))
        lines.append(body)
        if image:
            src = os.path.join(OUT, image.replace("/", os.sep))
            dst = os.path.join(dd, "post_%d.png" % idx)
            shutil.copyfile(src, dst)
            lines.append("[image: post_%d.png  (in this folder)]" % idx)
        if note: lines.append("[note: %s]" % note)
        lines.append("")
    txt = "\n".join(lines)
    open(os.path.join(dd, "posts.txt"), "w", encoding="utf-8").write(txt + "\n")
    master.append(txt)
open(os.path.join(OUT, "ALL_POSTS.txt"), "w", encoding="utf-8").write("\n\n".join(master) + "\n")
with open(os.path.join(OUT, "schedule.csv"), "w", encoding="utf-8", newline="") as f:
    w = csv.writer(f)
    w.writerow(["day", "post", "title", "text", "image_file", "note"])
    for (day, idx, title, body, image, note) in POSTS:
        w.writerow([day, idx, title, body, os.path.join(OUT, "day_%02d" % day, "post_%d.png" % idx) if image else "", note])

readme = f"""IRONWAKE - SOCIAL MEDIA POSTS (X / Twitter), 2 weeks, 2-3 posts a day
=====================================================================

FILES
  day_01/ ... day_14/   one folder per day: posts.txt (the text, in order) + post_1.png,
                        post_2.png ... = the image for that post, right there. Open the
                        folder, copy the text, drag the picture. Done.
  ALL_POSTS.txt         every day in one file
  schedule.csv          same posts as a spreadsheet (day, post, title, text, image path, note)
                        - import into Buffer / Hootsuite / X scheduler
  images/               the source PNGs (built from the game's own sprites)

RULES OF THUMB
  - Plain language. Short sentences. One idea per post.
  - Lead with the picture; the text should still make sense without it.
  - Store link on launch-type posts only: {STORE}
  - Tags on the first post of the day only: {TAGS}
  - Reply to your own post with extra detail instead of writing a wall.
  - When someone answers, answer back.

SCHEDULE
  Day 1   Launch: announcement, what it is, thank-you + ask for reviews
  Day 2   Creatures: eggs, three stages, found-alive
  Day 3   Scions + signature moves: lineup, Vaultling, Crypt Bat
  Day 4   Bairc's garden: the garden, feeding/treats, bond
  Day 5   Classes: three classes, Arcanist, Shadowstrider
  Day 6   Combat: action points, intents, detonations
  Day 7   Dungeons: three dungeons, bosses, Awakening tiers
  Day 8   The camp: NPCs, camp bonds, tavern board
  Day 9   Crafting: Pattern Book, runes, temper/reforge
  Day 10  Odd encounters: Ashen Duelist, Merchant's Ghost, Banshee in a Bottle
  Day 11  Corruption / capstones / Awakened
  Day 12  Android: touch, input parity
  Day 13  Challenge: Iron Vow / Descent, achievements
  Day 14  Community: show us your creatures, patch cadence, thanks

IMAGES
{chr(10).join('  ' + f for f in sorted(os.listdir(IMG)))}

Posts marked [note: attach a clip/screenshot] want real footage - combat, garden, Pattern Book,
phone - where a sprite sheet can't do the job.

Regenerate with:  python tools/make_social_posts.py   (overwrites this folder)
"""
open(os.path.join(OUT, "README.txt"), "w", encoding="utf-8").write(readme)
print("done:", OUT)
for f in sorted(os.listdir(OUT)): print(" ", f)
