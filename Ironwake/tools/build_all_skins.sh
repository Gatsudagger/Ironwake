#!/usr/bin/env bash
# Build every skin sprite listed in skin_manifest.txt. Tolerant: a failed/incomplete
# generation is reported and skipped (re-run later). Skips already-built resources.
cd "$(dirname "$0")/.." || exit 1
ok=0; fail=0; skip=0
while read -r cid name; do
    [ -z "$cid" ] && continue
    if [ -f "sprites/$name/$name.yy" ]; then
        echo "SKIP  $name (already built)"; skip=$((skip+1)); continue
    fi
    if python tools/build_char_sprite.py "$cid" "$name" 2>/tmp/skinerr; then
        ok=$((ok+1))
    else
        echo "FAIL  $name ($cid): $(tail -1 /tmp/skinerr)"; fail=$((fail+1))
        rm -rf "sprites/$name"   # clean partial
    fi
done < tools/skin_manifest.txt
echo "---- built=$ok skipped=$skip failed=$fail ----"
