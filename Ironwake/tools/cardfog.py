"""09-02 Drowned Reach fog pass: pixflux img2img over v6 (pier+ghost ship) placed on a dark fill,
so the model paints a real foggy sky + water instead of a cut-out. 1 gen per strength."""
import os, sys, json, time, base64, io, urllib.request
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ffgen import call_tool
from PIL import Image
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__))); R=os.path.join(ROOT,"_for_review","cards_0902")
src=Image.open(os.path.join(R,"drowned_reach_v6","cand_0.png")).convert("RGBA")
base=Image.new("RGBA",src.size,(22,34,30,255)); base.alpha_composite(src)
buf=io.BytesIO(); base.save(buf,"PNG"); b64=base64.b64encode(buf.getvalue()).decode()
DESC=("gothic dark fantasy pixel art night scene: a rotting abandoned wooden pier leading away over still black-green "
      "water, thick dense grey-green fog banks fill the entire sky and roll low over the water, a ghostly tattered "
      "sailing ship faintly visible through the fog, one faint gold lantern far down the dock, broken crates on the "
      "near planks, moody, grim, 3-4 tone shading, no text, no characters")
jobs=[]
for st in [int(a) for a in sys.argv[1:]] or [200,120]:
    txt,_=call_tool("create_image_pixflux",{"description":DESC,"init_image_base64":b64,"init_image_strength":st,
                    "no_background":False,"view":"side","shading":"medium shading","outline":"selective outline","detail":"medium detail"})
    jid=None
    for tok in txt.replace('"',' ').replace(':',' ').split():
        if len(tok)==36 and tok.count("-")==4: jid=tok; break
    print("strength",st,"job",jid); jobs.append((st,jid))
for st,jid in jobs:
    for _ in range(40):
        txt,_=call_tool("get_image",{"job_id":jid})
        urls=[w.strip("(),") for w in txt.split() if w.startswith("http") and ".png" in w]
        if urls:
            p=os.path.join(R,f"drowned_reach_v6_fog{st}.png")
            open(p,"wb").write(urllib.request.urlopen(urllib.request.Request(urls[0],headers={"User-Agent":"ironwake"}),timeout=60).read())
            print("saved",p); break
        time.sleep(8)
    else: print("timeout",st,txt[:300])
