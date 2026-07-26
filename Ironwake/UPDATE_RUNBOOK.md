# Ironwake — Update Runbook

**How to ship a patch to Steam and Google Play after launch.** Both builds come from the SAME
`.gml` codebase — one commit → two exports. Created 2026-07-23.

---

## PRE-PUSH CHECKLIST (do this BEFORE building either platform)
- [ ] **F5 clean in GameMaker** — zero compile errors. (Nested-ternary and new-`.yyp`-resource
      errors have bitten before; a clean F5 is the gate.)
- [ ] **Boot-test the running game** — main menu → start a run → hub → combat. Not just "it compiled."
- [ ] **Save compatibility** — if this patch changed how save data is structured, add a migration
      block in `scr_save.gml` (the `if (_save_ver < N)` fix-up pattern) and bump `SAVE_FORMAT_VERSION`.
      A newer build MUST read players' older saves without wiping progress. (See the save-versioning
      section in scr_save; current version tracked there.)
- [ ] **Commit + push** the `.gml` baseline first, so both platform builds come from the same commit.
- [ ] Note what changed for **patch notes** (Steam shows them; players read them).

---

## STEAM UPDATE (easy — NO Valve review post-launch)
Valve: *"Once public, you will be able to release incremental updates without contacting Valve."*

1. In GameMaker: **Create Executable → Windows** (ZIP). Extract `Ironwake.exe` + `data.win` +
   `options.ini` into `tools\steam\content\` (overwrite prior). Confirm the stray `*.url` is gone
   (depot vdf already excludes `*.url`).
2. Run the **steamcmd upload** (the proven pipeline — `perluptis` login, real PowerShell for
   interactive Steam Guard). Produces a new BuildID.
3. Steamworks → **SteamPipe → Builds**: set the new BuildID **live on the `default` branch**.
   → Steam delta-patches it to players automatically.
4. **RECOMMENDED:** push to a **beta branch first**, self-test, THEN move to `default`. One extra
   step; prevents shipping a bad build to everyone.

**Time:** ~10-15 min. **Gotchas:** none major post-launch; just don't set live an untested build.

---

## GOOGLE PLAY UPDATE (moderate — automated review, usually <1 day)
1. In GameMaker Android options: **increment versionCode** (must strictly increase; can't reuse a
   number). Bump the display version string too if it's a notable patch.
2. **Create Executable → Android (App Bundle)** → signed `.aab` (same keystore:
   `C:\Users\miles\Keys\Seahorse\Ironwake.keystore` — the ONLY signing key, never lose it).
3. Play Console → **Production → Create new release** → upload the AAB.
4. **Staged rollout**: release to a percentage first (e.g. 20% → 50% → 100%) so a bad build only
   hits some players. Halt/roll back from the console if vitals spike.
5. Play runs an **automated review** (usually hours to ~a day). Most updates auto-approve.

**Time:** ~20-30 min. **Gotchas:**
- ⏱ **API 36 by Aug 30, 2026** — after that date Play BLOCKS updates unless the build targets
  API 36+. This is the main looming gate to continued patching. Handle the target-SDK bump early
  (test whether GM emits it cleanly or needs a runtime upgrade — see ANDROID_TRACKING).
- The 12-tester × 14-day closed-test gate is a **one-time** cost to REACH production. Once in
  production, updates go straight to the production track (through automated review) — no re-gate.

---

## QUICK REFERENCE
| | Steam | Google Play |
|---|---|---|
| Per-update review | None | Automated, usually <1 day |
| Build artifact | Windows ZIP | signed AAB (versionCode++) |
| Push | steamcmd → set `default` live | upload → staged rollout |
| Propagation | auto delta-patch | Play distributes |
| Hands-on time | ~10-15 min | ~20-30 min |
| Signing | Steam account (`perluptis`) | Ironwake.keystore (single key) |

**The recurring real cost is the GameMaker build + boot-test, done twice — not the storefronts.**
