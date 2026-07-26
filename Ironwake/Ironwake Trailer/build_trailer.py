"""Ironwake store-trailer assembler (v1).

Cut grid is timed to the MEASURED structure of trailer_song_v1.mp3:
  0.0 hit / 4.5-11.5 hushed intro / 11.5-16 build / 16-41.5 driving wall /
  41.5-48.5 tender celesta / 48.5-61 dark drive / 61-72 outro.
Re-renderable: edit SEGMENTS / cards and re-run.
"""
import os, subprocess, sys
import imageio_ffmpeg
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
FF = imageio_ffmpeg.get_ffmpeg_exe()
BETA = os.path.join(HERE, "Ironwake trailer beta.mp4")
SONG = os.path.join(HERE, "music_candidates", "trailer_song_v1.mp3")
WORK = os.path.join(HERE, "_build")
OUT = os.path.join(HERE, "ironwake_trailer_store_v3.mp4")
LAUGH = os.path.join(HERE, "..", "sounds", "snd_curse_laugh", "snd_curse_laugh.ogg")
FONT_CINZEL_B = r"C:\Users\miles\AppData\Local\Microsoft\Windows\Fonts\CinzelDecorative-Bold.ttf"
FONT_CINZEL_R = r"C:\Users\miles\AppData\Local\Microsoft\Windows\Fonts\CinzelDecorative-Regular.ttf"
FONT_GARAMOND = r"C:\Users\miles\AppData\Local\Microsoft\Windows\Fonts\EBGaramond-VariableFont.ttf"
os.makedirs(WORK, exist_ok=True)

def ff_font(p):
    return p.replace("\\", "/").replace(":", "\\:")

def game_card(text, dur, size=42, y="h-190"):
    """In-game-style overlay: EB Garamond caps, white, soft shadow, 0.5s fade in/out.
    Mimics the game's own 'THE SHELL TREMBLES...' treatment."""
    t = text.replace("'", r"\\\'").replace(":", r"\:")
    f = ff_font(FONT_GARAMOND)
    alpha = f"if(lt(t,0.5),t/0.5,if(gt(t,{dur}-0.6),({dur}-t)/0.6,1))"
    common = (f"fontfile='{f}':text='{t}':fontsize={size}:x=(w-text_w)/2"
              f":alpha='{alpha}'")
    return (f"drawtext={common}:y={y}+2:fontcolor=black@0.8,"
            f"drawtext={common}:y={y}:fontcolor=0xF2EDE3")

ZOOM = "zoompan=z='1+0.00030*in':d=1:s=1920x1080:fps=30"   # slow push-in

# Cut grid — each dict: t=source sec in beta (or src=ENDCARD/BLACK), d=duration, vf=filter
SEGMENTS = [
    # TITLE REVEAL (0.0-11.5): black; the opening hit lands and the blood moon
    # fades in on its decay; vista at half speed owns the whole hushed intro
    # NOTE: setpts must come AFTER zoompan (zoompan re-times by frame count and
    # would silently undo an upstream slow-down)
    dict(t=0.1, d=11.5, input_t=5.75,
         vf=ZOOM + ",setpts=2.0*PTS,fade=t=in:st=0.3:d=1.4"),
    # BUILD (11.5-16.0): the descent begins
    dict(t=36.6, d=2.2, vf=None),                              # PREPARE TO DESCEND
    dict(t=66.0, d=2.3, vf=None),                              # floor map
    # DRIVING WALL (16.0-41.5): combat + the run
    dict(t=43.5, d=3.1, vf=None),                              # combat
    dict(t=39.6, d=1.5, vf=None),                              # traits
    dict(t=49.6, d=1.9, vf=None),                              # combat kill
    dict(t=41.3, d=1.8, vf=None),                              # companion tab
    dict(t=44.0, d=2.5, vf="scale=2150:1210,crop=1920:1080"),  # combat punch-in
    dict(t=61.0, d=2.5, vf=None),                              # shrine
    dict(t=76.0, d=2.6, vf=None),                              # stranger's memory
    dict(t=81.0, d=2.6, vf=None),                              # cursed altar
    dict(t=86.0, d=2.6, vf=None),                              # loot found epics
    dict(t=71.2, d=2.2, vf=None),                              # rare vestment equip
    dict(t=90.3, d=2.2, vf=None),                              # victory camp
    # TENDER (41.5-48.5): the hatch arc rides the celesta
    dict(t=20.6, d=1.6, vf=None),                              # shell trembles
    dict(t=22.9, d=1.4, vf=None),                              # it's hatching
    dict(t=24.6, d=2.0, vf=None),                              # gloomtoad reveal
    dict(t=30.6, d=2.0, vf=game_card("WHAT YOU RAISE FIGHTS BESIDE YOU.", 2.0)),  # naming
    # DARK DRIVE (48.5-61.0): second egg, betrayal, climax
    dict(t=98.6, d=1.7, vf=None),                              # wyrm egg trembles
    dict(t=101.7, d=1.4, vf=None),                             # wyrmling reveal
    dict(t=77.5, d=3.7, vf="eq=brightness=-0.18:saturation=0.55,"
         + game_card("THE TOWN REMEMBERS WHAT YOU DO.", 3.7, 46, "(h-text_h)/2")),  # PLACEHOLDER: betrayal capture
    dict(t=46.9, d=2.9, vf="scale=2210:1244,crop=1920:1080"),  # climax burst (PLACEHOLDER: boss)
    dict(t=86.2, d=1.4, vf="scale=2150:1210,crop=1920:1080"),  # loot punch
    dict(t=90.4, d=1.4, vf=None),                              # victory
    # OUTRO (61.0-72.0)
    dict(t=106.9, d=2.4, vf="fade=t=out:st=1.7:d=0.7"),        # bloopie ready to grow
    dict(src="ENDCARD", d=8.6, vf="fade=t=in:st=0:d=1.5,fade=t=out:st=7.1:d=1.5"),
    # EXIT THROUGH DARKNESS (72.0-76.0): devil laugh alone in the black
    dict(src="BLACK", d=4.0, vf=None),
]

def make_endcard():
    img = Image.new("RGB", (1920, 1080), (8, 6, 12))
    dr = ImageDraw.Draw(img)
    def center(text, font, y, fill):
        w = dr.textlength(text, font=font)
        dr.text(((1920 - w) / 2, y), text, font=font, fill=fill)
    center("IRONWAKE", ImageFont.truetype(FONT_CINZEL_B, 150), 340, (122, 156, 214))
    center("AUGUST 2026", ImageFont.truetype(FONT_CINZEL_R, 60), 570, (232, 220, 192))
    center("WISHLIST NOW ON STEAM", ImageFont.truetype(FONT_CINZEL_R, 44), 670, (232, 220, 192))
    center("SEAHORSE GAMES", ImageFont.truetype(FONT_CINZEL_R, 28), 950, (110, 104, 96))
    p = os.path.join(WORK, "endcard.png")
    img.save(p)
    return p

ENC = ["-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p",
       "-r", "30", "-an"]

def run(args):
    r = subprocess.run([FF, "-y", "-hide_banner", "-loglevel", "error"] + args)
    if r.returncode != 0:
        sys.exit(f"ffmpeg failed: {' '.join(args[:8])}...")

endcard = make_endcard()
paths, total = [], 0.0
for i, s in enumerate(SEGMENTS):
    p = os.path.join(WORK, f"seg{i:02d}.mp4")
    vf = (s.get("vf") or "null") + ",setsar=1"
    if s.get("src") == "ENDCARD":
        run(["-loop", "1", "-t", str(s["d"]), "-i", endcard, "-vf", vf] + ENC + [p])
    elif s.get("src") == "BLACK":
        run(["-f", "lavfi", "-i", f"color=c=0x08060c:s=1920x1080:r=30:d={s['d']}",
             "-vf", vf] + ENC + [p])
    elif s.get("input_t"):
        # read input_t seconds of source; filters (setpts) stretch it to d
        run(["-ss", str(s["t"]), "-t", str(s["input_t"]), "-i", BETA,
             "-vf", vf, "-t", str(s["d"])] + ENC + [p])
    else:
        run(["-ss", str(s["t"]), "-i", BETA, "-t", str(s["d"]), "-vf", vf] + ENC + [p])
    paths.append(p); total += s["d"]
print(f"{len(paths)} segments, {total:.1f}s")

lst = os.path.join(WORK, "concat.txt")
with open(lst, "w") as f:
    for p in paths:
        f.write(f"file '{p}'\n")
run(["-f", "concat", "-safe", "0", "-i", lst, "-c", "copy", os.path.join(WORK, "video.mp4")])

# song fades out 70-72; curse laugh enters at 71.2 and echoes into the black
run(["-i", os.path.join(WORK, "video.mp4"), "-i", SONG, "-i", LAUGH,
     "-filter_complex",
     "[1:a]afade=t=out:st=70:d=2[song];"
     "[2:a]adelay=71200|71200,volume=1.4[laugh];"
     "[song][laugh]amix=inputs=2:duration=longest:normalize=0,apad=whole_dur=76[mix]",
     "-map", "0:v", "-map", "[mix]",
     "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", OUT])
print("OUT:", OUT)
