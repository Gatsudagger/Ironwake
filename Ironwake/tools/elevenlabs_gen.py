#!/usr/bin/env python
"""
ElevenLabs SFX generation for Ironwake - budget-disciplined CLI.
Rules of record: CLAUDE_SETTINGS.md "AI Generation Credit Budgets".

- API key is read from the user MCP config (~/.claude.json, elevenlabs server
  env) or the ELEVENLABS_API_KEY env var - NEVER hardcoded here (repo is git).
- `balance` prints the credit meter (used/limit) - run at session start + end.
- `gen` makes ONE deliberate generation per invocation (no loops by design),
  prints the credit cost measured against the meter, and appends to
  tools/elevenlabs_spend_log.txt so every credit is accounted for.

Usage:
  python tools/elevenlabs_gen.py balance
  python tools/elevenlabs_gen.py gen "<prompt>" <duration_s> <out.mp3> [prompt_influence]
"""
import json, os, sys, time, urllib.request

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


def req(path, body=None):
    r = urllib.request.Request(API + path, headers={"xi-api-key": api_key(),
                                                    "Content-Type": "application/json"})
    if body is not None:
        r.data = json.dumps(body).encode()
        r.method = "POST"
    with urllib.request.urlopen(r, timeout=120) as resp:
        return resp.read()


def balance():
    s = json.loads(req("/user/subscription"))
    used, limit = s["character_count"], s["character_limit"]
    print("credits used %d / %d  (remaining %d)  tier=%s  resets=%s"
          % (used, limit, limit - used, s.get("tier"),
             time.strftime("%Y-%m-%d", time.localtime(s.get("next_character_count_reset_unix", 0)))))
    return used, limit


def gen(prompt, dur, out, influence=0.35):
    used0, limit = balance()
    audio = req("/sound-generation", {
        "text": prompt,
        "duration_seconds": float(dur),
        "prompt_influence": float(influence),
    })
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    with open(out, "wb") as f:
        f.write(audio)
    used1, _ = balance()
    cost = used1 - used0
    line = "%s  cost=%d  dur=%ss  out=%s  prompt=%s" % (
        time.strftime("%Y-%m-%d %H:%M"), cost, dur, os.path.basename(out), prompt[:100])
    with open(LOG, "a", encoding="utf-8") as f:
        f.write(line + "\n")
    print("WROTE %s (%d bytes)  COST %d credits" % (out, len(audio), cost))


if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "balance":
        balance()
    elif len(sys.argv) >= 5 and sys.argv[1] == "gen":
        gen(sys.argv[2], sys.argv[3], sys.argv[4],
            sys.argv[5] if len(sys.argv) > 5 else 0.35)
    else:
        print(__doc__)
