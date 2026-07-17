#!/usr/bin/env python
"""ElevenLabs Music REST client for Ironwake - composition-plan generations.

The MCP compose_music tool 500s on ANY composition_plan payload (bridge bug,
07-17); plain-prompt gens work. This goes to the REST API directly, same
pattern as elevenlabs_gen.py (SFX). Reads the API key from the user MCP
config or ELEVENLABS_API_KEY. Appends to the shared spend log.

Usage:
  python tools/elevenlabs_music.py plan <plan.json> <out.mp3> [note]
"""
import json, os, sys, time, urllib.request, urllib.error

API = "https://api.elevenlabs.io/v1"
LOG = os.path.join(os.path.dirname(os.path.abspath(__file__)), "elevenlabs_spend_log.txt")


def api_key():
    k = os.environ.get("ELEVENLABS_API_KEY")
    if k:
        return k
    cfg = os.path.join(os.path.expanduser("~"), ".claude.json")
    with open(cfg, "r", encoding="utf-8") as f:
        data = json.load(f)
    return data["mcpServers"]["elevenlabs"]["env"]["ELEVENLABS_API_KEY"]


def balance():
    r = urllib.request.Request(API + "/user/subscription", headers={"xi-api-key": api_key()})
    with urllib.request.urlopen(r, timeout=60) as resp:
        s = json.loads(resp.read())
    print("credits used %d / %d" % (s["character_count"], s["character_limit"]))
    return s["character_count"]


def compose_plan(plan_path, out, note=""):
    used0 = balance()
    with open(plan_path, "r", encoding="utf-8-sig") as f:   # -sig: PS 5.1 writes BOMs
        plan = json.load(f)
    body = {"composition_plan": plan, "model_id": "music_v2"}
    r = urllib.request.Request(API + "/music", headers={"xi-api-key": api_key(),
                                                        "Content-Type": "application/json"})
    r.data = json.dumps(body).encode()
    r.method = "POST"
    try:
        with urllib.request.urlopen(r, timeout=600) as resp:
            audio = resp.read()
    except urllib.error.HTTPError as e:
        print("HTTP", e.code, e.read().decode(errors="replace")[:2000])
        sys.exit(1)
    with open(out, "wb") as f:
        f.write(audio)
    used1 = balance()
    with open(LOG, "a", encoding="utf-8") as f:
        f.write("%s  cost=%d  dur=plan  out=%s  prompt=REST music plan: %s\n"
                % (time.strftime("%Y-%m-%d %H:%M"), used1 - used0,
                   os.path.basename(out), note[:100]))
    print("WROTE %s (%d bytes)  COST %d credits" % (out, len(audio), used1 - used0))


if __name__ == "__main__":
    if len(sys.argv) >= 4 and sys.argv[1] == "plan":
        compose_plan(sys.argv[2], sys.argv[3], sys.argv[4] if len(sys.argv) > 4 else "")
    else:
        print(__doc__)
