#!/usr/bin/env python3
"""Import the luna_moth AWAKENED sprites (08-13, M pick B).

Creates spr_pet_luna_moth_awakened_s and spr_pet_luna_moth_awakened_e as NEW
8-frame animated sprite assets (124x124, style/pipeline = the shipped adult
sets), registers them in Ironwake.yyp, and adds their bare refs to
global.__sprite_includes (obj_game_controller Create) so the compiler never
strips them (pet_sprite resolves them by STRING).

⚠ RUN ONLY WITH GAMEMAKER FULLY CLOSED (CLAUDE_SETTINGS.md: GM rewrites the
.yyp from memory on save/F5 and silently clobbers external entries).

Frames come from the _for_review anim pulls (frames 1-8 of the animate_image
jobs; frame 0 is the input re-render and is skipped):
  south: job 8aed367a-6996-49ce-a0c2-0f08ed9c5eb2 (base still 1769104a)
  east : job 21cc0a78-9f95-4b8e-bc83-1de42516d885 (base still 6c693d6f)
"""
import os, re, shutil, uuid, sys

ROOT     = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPRITES  = os.path.join(ROOT, "sprites")
REVIEW   = os.path.join(ROOT, "_for_review", "awakened_wave1_0813")
YYP      = os.path.join(ROOT, "Ironwake.yyp")
INCLUDES = os.path.join(ROOT, "objects", "obj_game_controller", "Create_0.gml")

SETS = [
    ("spr_pet_luna_moth_awakened_s", "spr_pet_luna_moth_adult_s", os.path.join(REVIEW, "anim_s")),
    ("spr_pet_luna_moth_awakened_e", "spr_pet_luna_moth_adult_e", os.path.join(REVIEW, "anim_e")),
]

KEYFRAME_TPL = """        {{"$Keyframe<SpriteFrameKeyframe>":"","Channels":{{
            "0":{{"$SpriteFrameKeyframe":"","Id":{{"name":"{guid}","path":"sprites/{name}/{name}.yy",}},"resourceType":"SpriteFrameKeyframe","resourceVersion":"2.0",}},
          }},"Disabled":false,"id":"{kf}","IsCreationKey":false,"Key":{key}.0,"Length":1.0,"resourceType":"Keyframe<SpriteFrameKeyframe>","resourceVersion":"2.0","Stretch":false,}},"""

def build_sprite(new_name, template_name, frame_dir):
    tdir = os.path.join(SPRITES, template_name)
    ndir = os.path.join(SPRITES, new_name)
    tyy  = open(os.path.join(tdir, template_name + ".yy"), encoding="utf-8").read()

    frames = [os.path.join(frame_dir, f"frame_{i}.png") for i in range(1, 9)]
    for f in frames:
        if not os.path.isfile(f):
            sys.exit(f"MISSING FRAME: {f}")

    guids = [str(uuid.uuid4()) for _ in frames]
    layer = re.search(r'"layers":\[\s*\{[^}]*"name":"([0-9a-f-]+)"', tyy).group(1)

    os.makedirs(ndir, exist_ok=True)
    for guid, src in zip(guids, frames):
        shutil.copyfile(src, os.path.join(ndir, guid + ".png"))
        ldir = os.path.join(ndir, "layers", guid)
        os.makedirs(ldir, exist_ok=True)
        shutil.copyfile(src, os.path.join(ldir, layer + ".png"))

    yy = tyy.replace(template_name, new_name)
    frames_block = "\n".join(
        f'    {{"$GMSpriteFrame":"v1","%Name":"{g}","name":"{g}","resourceType":"GMSpriteFrame","resourceVersion":"2.0",}},'
        for g in guids)
    yy = re.sub(r'("frames":\[\n).*?(\n  \],)',
                lambda m: m.group(1) + frames_block + m.group(2), yy, flags=re.S)
    kf_block = "\n".join(
        KEYFRAME_TPL.format(guid=g, name=new_name, kf=str(uuid.uuid4()), key=i)
        for i, g in enumerate(guids))
    yy = re.sub(r'("Keyframes":\[\n).*?(\n          \],"resourceType":"KeyframeStore<SpriteFrameKeyframe>")',
                lambda m: m.group(1) + kf_block + m.group(2), yy, flags=re.S)
    yy = re.sub(r'"length":\d+\.0,', '"length":8.0,', yy)
    open(os.path.join(ndir, new_name + ".yy"), "w", encoding="utf-8", newline="\n").write(yy)
    print(f"  {new_name}: 8 frames written")

def register_yyp(names):
    txt = open(YYP, encoding="utf-8").read()
    anchor = '{"id":{"name":"spr_pet_luna_moth_adult_s","path":"sprites/spr_pet_luna_moth_adult_s/spr_pet_luna_moth_adult_s.yy",},},'
    if anchor not in txt:
        sys.exit("YYP ANCHOR NOT FOUND - aborting before damage")
    add = "".join(f'\n    {{"id":{{"name":"{n}","path":"sprites/{n}/{n}.yy",}},}},' for n in names if f'"{n}"' not in txt)
    if add:
        txt = txt.replace(anchor, anchor + add)
        open(YYP, "w", encoding="utf-8", newline="\n").write(txt)
        print("  Ironwake.yyp: resource lines added")
    else:
        print("  Ironwake.yyp: already registered")

def register_includes(names):
    txt = open(INCLUDES, encoding="utf-8").read()
    if names[0] in txt:
        print("  __sprite_includes: already listed"); return
    anchor = "global.__sprite_includes = ["
    block = (anchor + "\n    // Luna Moth AWAKENED set (08-13, M pick B): resolved by STRING via\n"
             "    // pet_sprite (spr_pet_<species>_awakened_<dir>) - listed or stripped.\n"
             "    " + ", ".join(names) + ",")
    txt = txt.replace(anchor, block)
    open(INCLUDES, "w", encoding="utf-8", newline="\n").write(txt)
    print("  __sprite_includes: refs added")

if __name__ == "__main__":
    print("Importing luna_moth awakened sprites (GM must be CLOSED):")
    for new_name, template, fdir in SETS:
        build_sprite(new_name, template, fdir)
    register_yyp([s[0] for s in SETS])
    register_includes([s[0] for s in SETS])
    print("DONE. Verify in IDE, then F5.")
