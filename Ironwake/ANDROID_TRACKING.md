# Ironwake — ANDROID / Google Play Tracker

**Living status doc. Updated 2026-07-18.** Spine = LAUNCH_FOCUS.md (Track B). Detail kits:
PLAY_STORE_KIT.md · PRIVACY_POLICY.md · ANDROID_PORT_PLAN.md · STORE_LISTINGS_LOCALIZED.md.

Legend: `[x]` done · `[~]` in progress / partial · `[ ]` not started · 🔴 blocker · ⏱ time-sensitive.

> ## 📍 YOU ARE HERE (2026-07-18)
> Identity verification **CLEARED**. Account + app draft exist. **Release keystore already set up
> (07-07) and signing works** — M built a Release AAB on 07-17 (gradle `compressReleaseAssets`).
> The real gap: **no release has actually been uploaded to a Play testing track yet** (Internal
> testing shows "2 of 3", no release). Baseline is now **committed (c70e8ba, 07-18, F5 CLEAN)**.
> **Next action:** rebuild a fresh Release AAB from that baseline → **upload it to create the
> Internal testing release** → then Closed testing.
> The long pole is ⏱ **12 testers × 14 continuous days** of closed testing before production.

---

## KEY FACTS (do not lose)
- **Package / application id:** `com.seahorsegames.ironwake` (lowercase, PERMANENT — never changes).
- **GM Android config target:** target SDK 35, min SDK 23, arm64, version 1.0.0.0, display name "Ironwake".
- **Account type:** PERSONAL (Seahorse Games = public dev name only, no registered business). $25 paid 07-17.
- **Logins/contacts:** Console login + private contact = miles.colopy@gmail.com · **public store-listing
  email = seahorse.gameco@gmail.com** · public dev name = "Seahorse Games".
- **Closed-test gate:** 12 testers × 14 continuous days (Google cut 20→12 Dec 2024). Clock needs an
  approved release + opted-in testers + visible dev activity.
- **FREE/PAID trap:** app draft may be FREE; free→paid is blocked only AFTER first publish. Flip to
  Paid via merchant profile BEFORE first publish if selling. NEVER publish while Free if it should be paid.
- **Gradle heap fix applied:** `C:\Users\miles\.gradle\gradle.properties` → `org.gradle.jvmargs=-Xmx4096m
  -XX:MaxMetaspaceSize=1024m` (fixed first-AAB OOM; bump to 6-8g if it recurs).
- **PRIVACY POLICY URL (live, public):** https://gist.github.com/Gatsudagger/fb18d8750a7d450fa5d1ac236f49427c
  (paste into Play "Set privacy policy" + Data safety; also for Steam if needed).

---

## PHASE 0 — Account & identity
- [x] Google Play developer account created (personal), $25 paid — 07-17
- [x] Google **identity verification CLEARED** — confirmed 07-18
- [x] App draft "Ironwake" created (Game, English US, package com.seahorsegames.ironwake)
- [x] Device-access check passed (Play Console MOBILE app on S25, signed in as owner)

## PHASE 1 — Signed build pipeline  (keystore DONE; just rebuild from baseline)
- [x] **Release keystore created** — `C:\Users\miles\Keys\Seahorse\Ironwake.keystore` (07-07).
      ⚠️ **Confirm it's backed up off-machine** + passwords/alias recorded (single point of failure).
- [x] Signing wired + working — M built a Release AAB 07-17 (gradle `compressReleaseAssets` succeeded
      after the heap fix). Config lives in GM local prefs, not committed options_android.yy.
- [x] Android config correct: package `com.seahorsegames.ironwake`, version 1.0.0.0, SDK/arm64
- [x] **F5 + commit the baseline** — icon overhaul committed c70e8ba + pushed (07-18, F5 CLEAN)
- [x] **Release AAB built** — `Ironwake.aab` from the c70e8ba baseline (Create Executable → App Bundle) 07-18

## PHASE 2 — "Set up your app" — ✅ COMPLETE 07-18 (unlocks Closed testing)
- [x] App access = all functionality available (no login)
- [x] Content rating — IARC done (violence vs non-humans/fantastical/pixelated, mild blood, alcohol
      REFERENCE (tavern), simulated gambling in-game-currency only, romance/"lover" tier disclosed as
      dating→references-only, fear=mild). Teen-ish rating returned.
- [x] Data safety = "No data collected, No data shared" (saves local-only)
- [x] Target audience = 13-15/16-17/18+; not child-appealing. Ads = No. Advertising ID = No.
- [x] Privacy policy URL = the gist (see KEY FACTS)
- [x] **Main store listing SAVED** — name/short/full desc from PLAY_STORE_KIT; app icon 512
      (lantern) + feature graphic 1024x500 (built from key_art_master, in _for_review/play_assets/) +
      fresh S25 phone screenshots (touch UI + new icons). Category = Role Playing. Video = none yet (optional).
- [~] Localized listings: ES / DE / PT-BR translations done (STORE_LISTINGS_LOCALIZED.md); ID/TR/FR/IT = later
NOTE: DISCLOSURE CONSISTENCY — romance/"lover" relationship tier must also be reflected on STEAM
(PLAY_STORE_KIT §5 + STEAM survey said "platonic" - update so stores match).

## PHASE 3 — Internal testing (fast path, NO gate) — proves signing/install
- [x] Created internal release + uploaded `Ironwake.aab` (v1000000/1.0.0, Target SDK 35, arm64) — 07-18
- [x] Review: 2 non-blocking warnings only (no deobfuscation file; no native debug symbols — both safe to ignore)
- [x] **Save and publish** → live on internal track (no Google review); 358 MB install
- [~] Tester email list (8 emails, incl. miles.colopy@gmail.com) — CHECK it's SELECTED/applied to the
      track, not just created in the address book
- [x] Opt-in WORKED — S25 (miles.colopy@gmail.com) reached the app page with an Install button
- [~] **Install tap errors "something went wrong on our end. Please try again."** — Google-side
      build-provisioning lag (page shows Install before download artifacts are ready). FIX = retry
      Install / wait 30-60 min from publish / clear Play Store cache / reboot. NOT a config problem.
- [x] **Ironwake installs + LAUNCHES on S25, new icons confirmed good** (07-18) — full pipeline
      (signing → AAB → Play → install → run) validated end-to-end.
NOTE: list has a Yahoo addr (dvr1989@yahoo.com) that can't be a Play tester; swap for a Google acct.
NOTE: closed testing needs 12 valid Google-account testers (have ~8 usable) - line up ~4 more.

## PHASE 4 — Closed testing  ⏱ STARTS THE 14-DAY CLOCK
- [ ] Create Closed testing track + release (promote the AAB)
- [ ] Recruit **12 testers**, get them opted-in & installed → ⏱ 14 continuous days begins
- [ ] Keep visible dev activity during the window

## PHASE 5 — Monetization & production  🔴 GATES the closed-test rollout (do FIRST)
**DECISION 07-18: Ironwake = PAID/premium on Android** (M chose). RATIONALE: free→paid is PERMANENTLY
blocked once published; paid→free is always allowed — so set Paid now to preserve the option. Must be
"born paid" BEFORE rolling out any published release (incl. closed test), or it locks into Free forever.
- [~] **Create merchant account / Google payments profile** (this is the current prompt) — set up as
      **INDIVIDUAL** (Seahorse Games isn't a registered business). Needs legal name + address + bank
      (payout) + US tax interview (W-9). May take time to verify → closed test waits on it.
- [x] App set to **Paid**, price **$4.99** entered for all listed countries (07-18).
- [ ] 🔴 **BLOCKER (07-18): "Remove Rest of World to make your app paid."** Paid apps can't include the
      "New countries/regions" / Rest-of-World auto-add bucket (App pricing shows 2 unpriceable rows:
      New countries/regions USD + EUR — pricing them → "remove rest of world"; leaving blank → "set a
      price"; catch-22). FIX IS NOT ON THE PRICING PAGE (it only prices targeted countries, no add/
      remove buttons there). Root = the app's COUNTRY TARGETING includes auto-add-new-regions. Resume:
      go to the CLOSED TEST track → Countries/regions → target SPECIFIC countries + turn OFF "auto-add
      new countries/regions" so the New-regions bucket disappears from pricing. OR Google Play support
      clears the flag. KNOWN QUIRK (support thread 404639482). NEEDS exact 2026 click-path confirmed.
- [ ] **License testers** (Play Console → Setup → License testing) — add the 12 tester Gmail accounts so
      they download the PAID app FREE (paid-app closed testers otherwise must buy it; internal testers
      already free). This is how the 12-tester closed test works on a paid app.
- [ ] THEN roll out the closed test (as a paid app) → 14-day clock.
- [ ] (Optional/uncommitted) 99c revive-pack IAP — flagged risk: pay-to-win backlash + IARC re-answer
      + Play Billing GMEXT needed.
- [ ] 🔴🔴 **BEFORE PRODUCTION / PUBLIC LAUNCH: SWAP the public merchant address off M's HOME
      address** (122 Gibson St) to a **virtual business mailbox** (real street address — iPostal1 /
      Anytime Mailbox / Stable / UPS Store; Google rejects plain PO boxes). M used home address 07-18
      only to unblock the closed test (no public buyers during closed testing = low exposure). It
      becomes consumer-visible at production (EU seller-info rules). **DO NOT ship to production with
      the home address public.** (M explicitly asked to be reminded.)
- [ ] Apply for production access (after the 14-day closed test completes).

## QUALITY (not gating, do around the above)
- [~] On-screen gamepad overlay v2 built — needs S25 device tuning
- [ ] 🔧 **FIX (M flagged 07-18, S25): on-screen D-PAD is too CRAMPED and OVERLAPPING** in the
      current committed version (c70e8ba). ui_draw_touch_gamepad (scr_ui) — buttons overlap; re-space
      / resize the d-pad cross + OK so they don't collide. Fix next session.
- [ ] 🔧 **FIX (M flagged 07-18, S25): no touch target to INSPECT a creature from the Bairc pet
      screen** — creature-inspection is Tab-only; touch users can't open it. Add a touch tap/hold
      target (or ACTIONS-chip entry) on the Bairc pet list. Same class as the touch-verb gaps in
      the 07-17 touch-wall audit. Fix next session.
- [~] Touch-wall fixes + keyboard-hint hiding on mobile — built, verify on device after F5

---

## NEXT ACTION
1. F5 + commit current batch. 2. Create + back up the release keystore. 3. Build Release AAB.
4. Upload to Internal testing. Then Phase 2 setup tasks in parallel, then Closed testing to start ⏱.
