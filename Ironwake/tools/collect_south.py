import os, urllib.request
JOBS = {"A": ("1575cabd-ebf1-4ac9-8d55-872c49f0fdc4", 16),
        "B": ("ab50e95b-788c-4724-b2c5-4991b4e3786b", 16),
        "C": ("7ce584ef-5996-4d5a-8e07-0f763dc1b01c", 13)}
B = ("https://backblaze.pixellab.ai/file/pixellab-characters/objects/"
     "c50e1365-1a8c-44be-a773-5ee635581147/%s/rotations/frame_%d.png")
UA = {"User-Agent": "Mozilla/5.0"}
root = "_for_review/creatures_0806"
done = 0
for lab, (oid, n) in JOBS.items():
    d = os.path.join(root, "_SOUTH_" + lab)
    os.makedirs(d, exist_ok=True)
    got = 0
    for i in range(n):
        p = os.path.join(d, "frame_%d.png" % i)
        if os.path.exists(p):
            got += 1; continue
        try:
            r = urllib.request.Request(B % (oid, i), headers=UA)
            open(p, "wb").write(urllib.request.urlopen(r, timeout=60).read())
            got += 1
        except Exception:
            if os.path.exists(p): os.remove(p)
            break
    if got == n: done += 1
print("complete:", done, "/ 3")
