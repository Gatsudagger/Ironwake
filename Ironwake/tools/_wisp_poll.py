import ffgen, os, json, sys, time
ffgen.REVIEW = os.path.join(ffgen.ROOT, '_for_review', 'wispfox_anim_0818')
ffgen.ANIMS = os.path.join(ffgen.REVIEW, 'ANIMS.json')
for _ in range(40):
    ffgen.anim_poll()
    rows = json.load(open(ffgen.ANIMS))
    if all(r['done'] for r in rows):
        print('ALL DONE'); sys.exit(0)
    time.sleep(20)
print('TIMEOUT')
