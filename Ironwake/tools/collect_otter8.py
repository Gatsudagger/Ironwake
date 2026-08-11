import os, urllib.request
JOBS = {"baby": "3a50fe79-d8fa-465f-9e39-46c25bfad13b",
        "youngadult": "6e09d4ee-96c4-40cd-8af9-9b93455bafb1",
        "adult": "1db7c2fd-1e8c-4ddc-9ecd-6354a0b8c24d"}
DIRS = ["south", "east"]
B = ("https://backblaze.pixellab.ai/file/pixellab-characters/objects/"
     "c50e1365-1a8c-44be-a773-5ee635581147/%s/rotations/%s.png")
UA = {"User-Agent": "Mozilla/5.0"}
out = "_for_review/creatures_0806/_OTTER8"
os.makedirs(out, exist_ok=True)
done = 0
for stage, oid in JOBS.items():
    got = 0
    for d in DIRS:
        p = os.path.join(out, "sluice_otter_%s_%s.png" % (stage, d[0]))
        if os.path.exists(p):
            got += 1; continue
        try:
            r = urllib.request.Request(B % (oid, d), headers=UA)
            open(p, "wb").write(urllib.request.urlopen(r, timeout=60).read())
            got += 1
        except Exception:
            if os.path.exists(p): os.remove(p)
            break
    if got == len(DIRS): done += 1
print("stages complete:", done, "/ 3")
