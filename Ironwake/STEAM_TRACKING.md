# Ironwake — STEAM Tracker

**Living status doc. Updated 2026-07-20.** Spine = LAUNCH_FOCUS.md (Track A). Detail kits:
STEAM_LAUNCH_CHECKLIST.md · STEAM_PAGE_KIT.md · CREDITS.md · tools/steam/.

Legend: `[x]` done · `[~]` in progress / partial · `[ ]` not started · 🔴 blocker · ⏱ time-sensitive.

> ## 📍 YOU ARE HERE (2026-07-20)
> 🔴 **Store page REJECTED 07-20** — Early Access answers "do not fully explain what a customer can
> expect." All five narrative EA questions flagged. **FIXED same day:** STEAM_PAGE_KIT §4 rewritten
> (v2, +§4b rejection log); plain-text paste file at `_for_review/steam_ea_paste.txt`; M pasted all
> six fields into Steamworks and **RESUBMITTED FOR REVIEW 07-20**. ⏳ Awaiting Valve round 2.
> Then → Valve approval → flip **Coming Soon** (14-day public clock) → build upload → Build Review.
>
> ### 🔨 BUILD UPLOAD — IN PROGRESS (started 07-20, runs in parallel with page review)
> - [x] App Data Admin **config PUBLISHED** (the deferred Jul-13 publish). Diff was config-only
>       (`oslist windows` / `osarch 64` / icon + clienticon hashes); `ReleaseState` stayed
>       `unavailable` so nothing released. Steam's own note: publishing config does NOT release
>       an unreleased game.
> - [x] **Steamworks SDK** extracted → `C:\Users\miles\steamworks_sdk\` (user folder, NOT `C:\` —
>       no admin needed). steamcmd verified at `sdk\tools\ContentBuilder\builder\steamcmd.exe`.
> - [x] `tools\steam\content\` created (empty, staged). Both .vdf verified correct; `Desc` bumped
>       to 07-20.
> - [x] GameMaker Windows ZIP built (07-20) → extracted to `tools\steam\content\`
>       (`Ironwake.exe` + `data.win` + `options.ini`). **Stray `The Bloodline.url`** (Steam shortcut
>       to unrelated appid 1159290, from the project's Included Files) removed + `*.url` added to depot
>       vdf FileExclusion. M should also delete it from GM Included Files so it stops riding along.
> - [x] **steamcmd upload SUCCEEDED 07-20** — `BuildID 24307135`, AppID 4954740, depot 4954741.
>       Login `perluptis`, run in real PowerShell (interactive Steam Guard). vdf `SetLive` empty =
>       uploaded but NOT live yet.
> - [x] **BuildID 24307135 set LIVE on `default` branch (07-20).** Depot 4954741, 397 MB.
> - [x] **Launch Option 0 added + PUBLISHED (07-20):** `Ironwake.exe`, Launch (Default), Windows.
>       Config-only publish, ReleaseState stayed unavailable.
> - [x] **Installed via Steam client + BOOTS & RUNS (07-20).** Full SteamPipe pipeline proven
>       end-to-end. (Library page shows blank pre-publish — EXPECTED; art/info populate once the
>       store page clears review. Not a build issue.)
> - [ ] THEN request Build Review (needs the store page approved first — page is in review round 2).
>
> ### ✅ BUILD PIPELINE COMPLETE (07-20). Remaining gates to launch:
> 1. Store page approval (Valve, EA resubmit round 2 pending) → then flip Coming Soon (14-day clock)
> 2. Request Build Review (3-5 biz days) — do the MOMENT the page is approved
> 3. Deferred code: combat HP-bar overlap reorder + a re-upload (cheap now the pipeline works)
> 4. Housekeeping: [x] 07-20 polish batch COMMITTED b894c87 + pushed ironwake/pets-phase2-ui-polish.
>    [ ] STILL TODO: delete `The Bloodline.url` from GM Included Files (rides along in every build,
>    incl. Android AAB; depot vdf excludes it from Steam but source is unchanged).
> ⏱ **Build review is 3-5 business days PER ROUND** and the build isn't uploaded yet. Checklist
> targeted "Jul 28-ish". With Aug 19 committed and a page round now burned, start the upload as soon
> as the page is resubmitted — don't wait for approval (only the *review request* needs approval).
> **Committed launch: Wed Aug 19 2026.**

---

## KEY FACTS
- **AppID:** 4954740 · **Publisher:** Seahorse Games · **Launch:** Wed **Aug 19 2026** (committed).
- **Price:** $9.99 + 10% launch-week discount (launch week only).
- **AI disclosure:** v2 LIVE in CREDITS.md + STEAM_PAGE_KIT §5 — still must be pasted into the live
  Steam AI-content survey when reachable.
- **Gates (all clear with margin):** 21-day trust hold ~Jul 31 · Coming Soon must be live 14+ days ·
  build review must pass.
- **⚠️ NAME COLLISION (found 07-20, DECISION: keep "Ironwake", no action).** A second Steam game
  titled **IRONWAKE** exists: **AppID 4858340**, dev/pub **Enunion Team**, first-person psychological
  horror (Soviet robot / sealed bunker), **planned release Oct 25 2026**, no reviews yet.
  Their AppID is LOWER = registered before ours. **We ship ~2 months earlier (Aug 19).**
  Not a blocker: Valve does not enforce title uniqueness (only acts on trademark disputes), and the
  rejection was unrelated. Real cost is **search collision / wishlist attribution**, not legality.
  Rejected renaming — the Play package `com.seahorsegames.ironwake` is PERMANENT, capsule art carries
  the wordmark, and Ironwake is the in-fiction town name ("The town remembers").
  Fallback if they gain traction: subtitle **"Ironwake: The Town Remembers"** (keeps name + package
  id; would want a capsule-art revision pass).

---

## PHASE A — Store page  (≈done)
- [x] Store page copy, tags, capsules, screenshots (13, cropped to 1920×1080), library assets 5/5,
      broadcast panels, page background — all uploaded & saved
- [x] Page **SUBMITTED for review** — 07-14
- [ ] 🔴 **[You] Page APPROVED?** check email / Steamworks. If yes →
- [ ] **[You] Flip to Coming Soon** (⏱ starts the 14-day public clock)
- [ ] **[You] Paste AI-content disclosure** into the live Steam survey (text ready in CREDITS.md)

## PHASE B — App config & build
- [ ] **[You] Publish the deferred App Data config** ("Publish to Steam" — releases nothing; MUST
      precede the first build upload)
- [ ] **[You+C] Upload a build** from the F5'd baseline (tools/steam kit) → set live on `default` branch
- [ ] **[You] Request Build Review** (3-5 business days — do EARLY, not launch week)
- [ ] **[You] Steam Cloud** — config only (WinAppDataLocal / `Ironwake`, cloud-on-by-default)

## PHASE C — Features
- [ ] **[C+You] Steamworks SDK init + Achievements** (C designs the list; needs GMEXT-Steamworks)
- [ ] **[C] Trailer** (before launch; not required for Coming Soon)

## PHASE D — Launch week
- [ ] **[You] Set pricing** $9.99 + 10% launch discount
- [ ] Final release/build set live; launch Aug 19

---

## DEPENDENCY NOTE
Build upload (Phase B) needs the **F5'd + committed baseline** — same baseline the Android AAB
needs. The current uncommitted batch (icons 07-18 + combat + Android geometry/touch) must be
F5'd/committed first. See [[ANDROID_TRACKING]] Phase 1.

## NEXT ACTION
1. [You] Check if the page is approved → flip Coming Soon (starts the 14-day clock).
2. [You] Publish deferred App Data config. 3. Upload a build → Request Build Review EARLY.
