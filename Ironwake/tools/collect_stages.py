import os, urllib.request
JOBS = {"S1": ("3cb1997e-5ec2-4016-8525-cacb53ddc524", 16),
        "S2": ("6f2da437-2a07-4eb2-905e-cbe6f5256890", 16),
        "S3": ("5f564fa7-62d4-4526-b8a3-332740aa32e9", 16)}
B = ("https://backblaze.pixellab.ai/file/pixellab-characters/objects/"
     "c50e1365-1a8c-44be-a773-5ee635581147/%s/rotations/frame_%d.png")
UA = {"User-Agent": "Mozilla/5.0"}
root = "_for_review/creatures_0806"
done = 0
for lab, (oid, n) in JOBS.items():
    d = os.path.join(root, "_STAGE_" + lab)
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
    print(lab, got, "/", n)
    if got == n: done += 1
print("complete:", done, "/ 3")
