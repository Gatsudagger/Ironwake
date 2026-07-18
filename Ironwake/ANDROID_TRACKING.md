# Ironwake — ANDROID / Google Play Tracker

**Living status doc. Updated 2026-07-18.** Spine = LAUNCH_FOCUS.md (Track B). Detail kits:
PLAY_STORE_KIT.md · PRIVACY_POLICY.md · ANDROID_PORT_PLAN.md · STORE_LISTINGS_LOCALIZED.md.

Legend: `[x]` done · `[~]` in progress / partial · `[ ]` not started · 🔴 blocker · ⏱ time-sensitive.

> ## 📍 YOU ARE HERE (2026-07-18)
> Identity verification **CLEARED**. Account + app draft exist. **Release keystore already set up
> (07-07) and signing works** — M built a Release AAB on 07-17 (gradle `compressReleaseAssets`).
> The real gap: **no release has actually been uploaded to a Play testing track yet** (Internal
> testing shows "2 of 3", no release). **Next action:** F5+commit the current batch → rebuild a
> fresh Release AAB from that baseline → **upload it to create the Internal testing release** →
> then Closed testing.
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
- [ ] **F5 + commit the current batch** (icons + combat + Android geometry/touch) → verified baseline
- [ ] **Rebuild a fresh Release AAB** (`.aab`) from that committed baseline (build config = Release)

## PHASE 2 — "Set up your app" (Console dashboard, no build needed) — can do NOW
- [ ] App access (all functionality available, or provide test login) — Ironwake: no login = "all available"
- [ ] Content rating — complete **IARC questionnaire**
- [ ] Data safety — **"collects no data"** (per PLAY_STORE_KIT.md + PRIVACY_POLICY.md)
- [ ] Target audience & content (age groups) + **News app = No** + Ads declaration (**No ads**)
- [ ] **Main store listing** — paste 80-char short + 4000-char full desc from PLAY_STORE_KIT.md;
      graphics (512 icon from tools/steam; 1024×500 feature graphic; phone screenshots 16:9 OK)
- [ ] Privacy policy URL (host PRIVACY_POLICY.md on itch, paste URL)
- [ ] AI-generated content declaration — consistent with Steam AI-disclosure v2 (CREDITS.md)
- [~] Localized listings: ES / DE / PT-BR translations done (STORE_LISTINGS_LOCALIZED.md); ID/TR/FR/IT = later

## PHASE 3 — Internal testing (fast path, NO gate) — proves signing/install
- [~] Internal testing track exists ("2 of 3" shown) — but **no real release uploaded yet**
- [ ] Create internal-testing **release** → upload the signed AAB
- [ ] Add internal testers (email list) → install on S25 → confirm it runs

## PHASE 4 — Closed testing  ⏱ STARTS THE 14-DAY CLOCK
- [ ] Create Closed testing track + release (promote the AAB)
- [ ] Recruit **12 testers**, get them opted-in & installed → ⏱ 14 continuous days begins
- [ ] Keep visible dev activity during the window

## PHASE 5 — Monetization & production
- [ ] Merchant / payments profile (gates the price field; public address requirement — PO box option)
- [ ] Set pricing (decision pending; premium like Steam $9.99-equiv, or free?) — monetize questionnaire
      currently ticks Paid + IAP
- [ ] (Optional/uncommitted) 99c revive-pack IAP — flagged risk: pay-to-win backlash + IARC re-answer
      + Play Billing GMEXT needed
- [ ] Apply for production access (after the 14-day closed test completes)

## QUALITY (not gating, do around the above)
- [~] On-screen gamepad overlay v2 built — needs S25 device tuning
- [~] Touch-wall fixes + keyboard-hint hiding on mobile — built, verify on device after F5

---

## NEXT ACTION
1. F5 + commit current batch. 2. Create + back up the release keystore. 3. Build Release AAB.
4. Upload to Internal testing. Then Phase 2 setup tasks in parallel, then Closed testing to start ⏱.
