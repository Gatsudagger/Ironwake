# Ironwake — STEAM Tracker

**Living status doc. Updated 2026-07-20.** Spine = LAUNCH_FOCUS.md (Track A). Detail kits:
STEAM_LAUNCH_CHECKLIST.md · STEAM_PAGE_KIT.md · CREDITS.md · tools/steam/.

Legend: `[x]` done · `[~]` in progress / partial · `[ ]` not started · 🔴 blocker · ⏱ time-sensitive.

> ## 📍 YOU ARE HERE (2026-07-26 evening) — BUILD SUBMITTED FOR REVIEW 🏁
> **EVERYTHING done in one day (approval → submission):**
> - ✅ Page approved · ✅ Coming Soon LIVE (clock done Aug 9) · ✅ AI disclosure v2 pasted
> - ✅ **TRAILER v3 UPLOADED + PUBLISHED** ("Ironwake — Early Access Trailer", first position).
>   Built from beta footage + a purpose-generated ElevenLabs track (990 credits, one candidate,
>   approved first listen) cut to the song's MEASURED structure; devil-laugh exit into black.
>   Assembly is scripted: `Ironwake Trailer\build_trailer.py` (v3 = current). Betrayal + boss
>   slots are PLACEHOLDERS — replace when M captures footage (TRAILER_CUT_SHEET.md §4), then
>   re-render + swap the upload (allowed anytime).
> - ✅ **Controller wizard FIXED**: it falsely claimed "full use of Steam Input API" — that claim
>   is what made the FEATURES checklist item gate the box (07-22 note "not a gate" was WRONG).
>   Re-answered truthfully: Full Controller Support, Xbox (native XInput), NO Steam Input API.
>   Checklist completed immediately after publish.
> - ✅ **"Mark build ready for review" SUBMITTED 07-26** with reviewer notes (offline/no MTX/no
>   servers, XInput support, quick content path, local saves). Verdict via email in 3-5 biz
>   days (~Jul 29–Aug 4, allow 7). Build under review: 24307135. Updating the build during/
>   after review is explicitly allowed.
> - ⚠️ NOTE (M, 07-26): don't oversell "the town remembers" in copy — only basic relationships
>   ship today; M will deepen the theme later. Reword the trailer's betrayal card at recut.
> **Remaining to launch:** Valve verdict → (optional) final trailer recut + build re-upload →
> release button Aug 19. Clocks: credit hold ~Jul 31 ✓ by launch; Coming Soon Aug 9 ✓.
> - ✅ **LAUNCH DISCOUNT SET 07-26: 20%** (M's call, up from planned 10% — right for a
>   zero-review launch: bigger badge, $7.99 impulse zone, maximizes early review volume;
>   consistent with the EA price-ladder story). **DATE DECISION 07-26: Aug 19 KEPT** —
>   earliest-possible Aug 9 rejected (Sunday launch, wishlist runway too short, build-review
>   collision risk, draft trailer still live).
> - ✅ **CLOUD SAVES CONFIGURED + LIVE (07-26 evening):** quota 10 MB / 10 files; Auto-Cloud
>   root WinAppDataLocal / Ironwake / `ironwake_save*.json` / Windows; settings.ini deliberately
>   NOT synced (device-local prefs); dev-only + Dynamic Cloud Sync OFF (no Cloud API integration).
>   Steam Cloud ticked under Supported Features. Config page URL: partner.steamgames.com/apps/cloud/4954740.
>   Verify: launch via Steam → quit → library shows sync. Gotcha hit: Supported-Features tick
>   saved but sat UNPUBLISHED — always check Publish tab for pending changes.
> - **ACHIEVEMENTS: design already exists** — ACHIEVEMENTS_SPEC.md (32 achievements, 07-17,
>   epithet-backed triggers, feasibility-keyed). Awaiting M sign-off; wire with GMEXT-Steamworks
>   AFTER build review passes (or as an EA-patch marketing beat).
>
> ## 📍 (2026-07-26 morning)
> ✅ **STORE PAGE APPROVED 07-26** (Valve email; EA-answer resubmit v2 passed round 2).
> Same-day follow-through, ALL DONE 07-26:
> - ✅ **COMING SOON IS LIVE** — flipped from the app landing page. 14-day public clock runs
>   Jul 26 → **Aug 9**, 10 days ahead of the Aug 19 launch. Page is PUBLIC; wishlisting open.
> - ✅ **Public page sanity-checked** (store.steampowered.com/app/4954740): capsule, all 13
>   screenshots, description, EA v2 answers, wishlist button — all render correctly.
> - ✅ **AI-content disclosure v2 pasted** (replaced the stale v1 wholesale; adds the ElevenLabs
>   audio clause; no runtime AI). NAV NOTE: the Content Survey / AI disclosure is edited via a
>   link on the **APP LANDING PAGE** — it is NOT under Store Page Admin's Basic Info or Ratings
>   tabs, and NOT the "Legal Lines" field (that's copyright/EULA only).
> 🔴 **TRAILER is now the ONLY gate to Build Review submission** (Game Build checklist:
> everything ✅ except Trailer Uploaded; submit button hidden until complete). Plan + shot
> list in TRAILER_PLAN.md — M captures footage (NVIDIA F11 1080p), CapCut edit, ~70s.
> Build review = 3-5 biz days/round; to hold Aug 19, trailer up by ~**Aug 8-10** at the
> latest — sooner for a round-2 cushion. Wishlist marketing can start NOW.
>
> ## 📍 (2026-07-22)
> **07-22 status read off the app landing page (`partner.steamgames.com/apps/landing/4954740`):**
> - **Store Presence: Checklist complete — "Your app is in the review queue… Submitted for review
>   on Jul 20."** Resubmit DID register. 3-5 business days from Mon Jul 20 → verdict ~Jul 23-27.
>   Valve emails the result; feedback also viewable/answerable on the Steamworks Support site.
>   No action available until it lands. **Re-checked 07-23: still "in the review queue," no verdict
>   yet — normal 2 days into the 3-5 day window.**
> - **Game Build: Checklist INCOMPLETE.** Not gated on page approval (see correction below).
>   This is the actionable Steam work today. Exact state read 07-22:
>   - STORE: [x] Platform Support Matches · [x] App Configuration ·
>     **[ ] Pricing For At Least One Package** · **[ ] Published Pricing For At Least One Package** ·
>     [ ] Trailer Uploaded
>   - DEPOTS: **[x] ALL EIGHT GREEN** (depot configured, build configured, launch options defined,
>     install directory set, depot languages configured, store+devcomp packages match, package
>     includes Windows depot, all depots attached). The 07-20 SteamPipe work is fully validated.
>   - FEATURES: [ ] Steam Input API Configuration (not a gate; drives the Full Controller Support
>     badge — we DO ship gamepad support, so worth doing)
>   - Store Presence RECOMMENDED (explicitly "not required"): [ ] Cloud Saves · [ ] Steam Achievements
> - ✅ **PRICING SET + PUBLISHED 07-22** — package 1719511 @ **USD 9.99** (CNY ¥42.00 / EUR €10,25 /
>   GBP £9.09, Valve multi-variable conversion, left unrounded as generated). Price status reads
>   **Published**, so both blocked items cleared in one action. Key packages 1719509/1719510 confirmed
>   still unpriced. Sanity check: 4-8 hrs to see most content + replay ≈ $1/hr first pass — $9.99 holds.
> - 🔴 **AFTER PRICING: the remaining gate to build-review submission is the TRAILER.** Post-pricing
>   Game Build state: STORE = Platform Support ✅ / Pricing ✅ / Published Pricing ✅ /
>   **Trailer Uploaded ☐** / App Configuration ✅ · DEPOTS all ✅ · FEATURES Steam Input API ☐.
>   The submit button ("Mark as ready for review") does NOT appear — it shows only when the checklist
>   is complete. Steam Input = optional (recommended tier). **Trailer is the blocker** (long-standing
>   Steam release-review requirement; not spelled out in docs but strongly evidenced by missing submit
>   button). Trailer was already Phase C ("before launch") — now promoted to a build-review GATE.
>   NEEDS: gameplay capture (M) + edit. Pricing note: was previously (wrongly) filed under Phase D
>   launch-week; it actually gated review and is now DONE. Price freely changeable until release;
>   10% launch discount configured separately in release settings.
> - **Release gates restated by Valve:** page + build both reviewed & approved · Coming Soon visible
>   ≥2 weeks (→ must be live by **Aug 5** for Aug 19) · ≥21 days since first app-credit purchase (~Jul 31).
> - Review-status location: NEITHER Publish tab shows it. It's on the app landing page.
>   Full verified nav map lives in Claude's memory (`reference_steamworks_nav`).
>
> ## 📍 (2026-07-20)
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
> - [ ] Request Build Review. ⚠️ **CORRECTION (07-22): this is NOT gated on page approval.** The app
>       landing page states verbatim: *"Your store page and game build may be worked on in any order."*
>       Game Build has its OWN checklist, currently **incomplete** — workable NOW, in parallel.
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
- **Depot:** 4954741 · **Packages** (read 07-22): **1719511 "Ironwake" = THE STORE PACKAGE — this is
  the one that gets priced.** 1719509 "Ironwake Developer Comp" + 1719510 "Ironwake for Beta Testing"
  are auto-created CD-key packages (Release State Override: released) — they stay FREE, never price them.
- ⚠️ **Price Management Tool defaults to "Show only released packages"** and therefore shows an EMPTY
  table for us — Ironwake is `unavailable`, so it's filtered out. Change that dropdown to include
  unreleased packages before concluding anything is missing. (Cost a confused round on 07-22.)
- **Price:** $9.99 + 10% launch-week discount (launch week only). **Play = $4.99 — DELIBERATELY
  DIFFERENT, reaffirmed 07-22.** Steam's price-parity rule covers other *PC* storefronts (Epic, GOG,
  itch, Humble) only; mobile is NOT a PC storefront and Valve does not police it. Mobile buyers
  anchor $2-7, PC roguelite buyers $10-20. Matching Steam down to $4.99 would halve PC revenue per
  unit for no compliance benefit and signal "smaller than it is" below the $9.99 category floor.
  Valve also permits raising price when leaving EA, so price-low-then-climb is the wrong play.
  Do not "fix" this apparent mismatch — it is intentional.
- **PRICE ROADMAP (planned 07-23):** $9.99 is the **EA launch** price, deliberately set low for an
  UNKNOWN dev with ZERO launch reviews — price is the only trust signal a shopper has at launch, so
  $9.99 converts wishlists where a premium would make people "wait for reviews" (where momentum dies).
  Ironwake's FEATURE depth (49 abilities/8 schools/detonation combos, full pet+Awakening system, NPC
  bonds+betrayal, procedural floors/events/shrines/boons/curses, codex, Knucklebones, win state) is a
  $14.99-19.99 footprint; the cap is CONTENT HOURS (~4-8 hrs first pass, M's estimate) + no track
  record. **Plan: raise toward $12.99-14.99 as EA content is added**, each bump justified by a visible
  changelog + accumulated reviews. Valve explicitly permits raising price when leaving EA. Steam-only
  ladder — Play stays $4.99. Revisit the number at each major content drop and at the EA→1.0 exit.
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

## PHASE A — Store page  (approved; Coming Soon pending)
- [x] Store page copy, tags, capsules, screenshots (13, cropped to 1920×1080), library assets 5/5,
      broadcast panels, page background — all uploaded & saved
- [x] Page **SUBMITTED for review** — 07-14 · rejected 07-20 · resubmitted 07-20
- [x] ✅ **Page APPROVED 2026-07-26** (round 2)
- [x] ✅ **COMING SOON LIVE 2026-07-26** — public clock done Aug 9; public page verified
- [x] ✅ **AI-content disclosure v2 pasted 2026-07-26** (via app-landing-page Content Survey link)

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

## NEXT ACTION (updated 07-26 — page approved, Coming Soon LIVE, AI survey done)
1. [You] TRAILER footage capture (TRAILER_PLAN.md shot list, NVIDIA F11 1080p) — the ONLY
   remaining gate to Build Review. Then [C] frame-timed CapCut cut sheet → edit → upload.
2. Trailer uploaded → "Mark as ready for review" appears → submit Build Review (3-5 biz days).
3. Optional while waiting: Steam Input API config (Full Controller badge), Cloud Saves config.
