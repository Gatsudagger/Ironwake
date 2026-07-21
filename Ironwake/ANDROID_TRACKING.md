# Ironwake — ANDROID / Google Play Tracker

**Living status doc. Updated 2026-07-20.** Spine = LAUNCH_FOCUS.md (Track B). Detail kits:
PLAY_STORE_KIT.md · PRIVACY_POLICY.md · ANDROID_PORT_PLAN.md · STORE_LISTINGS_LOCALIZED.md.

Legend: `[x]` done · `[~]` in progress / partial · `[ ]` not started · 🔴 blocker · ⏱ time-sensitive.

> ## 📍 YOU ARE HERE (2026-07-20)
> **07-20: Android developer verification registered** (see KEY FACTS) — identity/distribution
> paperwork only, **no release-track progress, clock not started**. Status below is unchanged.
>
> 🔴 **ANR on S25 losing runs is still the launch-blocker.** Get the Play vitals trace (suspect:
> main-thread `save_game()`) BEFORE testers are onboarded — 12 people hitting run-loss on day 1
> of a 14-day continuous clock is the worst possible time to find it.
>
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
- **Android developer verification: REGISTERED (07-20).** Google confirmed "all of your apps have
  been successfully registered to meet Android developer verification requirements."
  ⚠️ **This is NOT a release approval and does NOT start the 12×14 closed-test clock.** It is the
  separate identity-verification program covering distribution (incl. sideloading / non-Play
  stores). It changes nothing about the release-track gap below. Don't read it as "Play approved."

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
- [x] ✅ **BLOCKER CLEARED (07-18 late): "Remove Rest of World to make your app paid."**
      CONFIRMED CLICK-PATH (2026 UI): Closed testing → **Manage track** → **Countries/regions** tab →
      remove the **Rest of world** bucket. Paid apps cannot include the auto-add-new-regions bucket
      (no price can exist for an unknown future country) — that's the whole catch-22; the pricing page
      is the WRONG surface (it only prices already-targeted countries). Then a SECOND round of the same
      rule fired: **remove China, Cuba, Iran, Sudan** — these four cannot host a paid app at all
      (sanctions + no Play billing), so they're free-only territories. Unchecked all four → **saved
      clean, no warnings**. KNOWN QUIRK (support thread 404639482).
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

### ⚠️ STANDING RULE (M 07-18, after the whetstone-shrine softlock)
**EVERY new UI/feature must be touch-checked AT BUILD TIME, automatically — no exceptions.**
M hit a NO-TOUCH-CONTROLS softlock on the new whetstone shrine and only escaped via the d-pad.
Hit-testing lives in the **DRAW** events (draw + hit-test together), NOT Step — Step-only reads
give FALSE POSITIVES (07-17 lesson). Any new interactive screen ships with: a tap target for
every verb, or an ACTIONS-chip entry, or confirmed d-pad reachability.

### 07-18 S25 playtest batch (M's phone notes)
- [x] **D-PAD too small / too close together — GEOMETRY FIXED.** Root cause was arithmetic, not
      taste: `_bs` is a HALF-size (button = 2*_bs wide) but centre-to-centre spacing was `1.7*_bs`,
      so the four buttons **overlapped by ~30% by construction**. Also `_bs` was clamped to the
      gutter (`(gutter-18)/5.4`) → a ~210px S25 gutter yielded `_bs=35`, hence "too small".
      NOW: spacing `2.35*_bs` (real gap), size = `46 * global.touch_pad_scale` (gutter cap removed,
      may bleed over the low-left play area), position clamped to screen so it can't run off-edge.
- [x] **D-pad USER-SCALABLE — backend done.** New `[touch]` section in settings.ini +
      `touch_settings_init/save`, `touch_pad_scale_adjust`, `touch_gamepad_toggle` (scr_stats, after
      the video block). Macros TOUCH_PAD_SCALE_DEF **1.25** (= M's "25% bigger") / MIN 0.80 / MAX
      2.00 / STEP 0.15. Self-initializing, so the game runs correctly at 1.25 even before the UI lands.
- [ ] **D-pad size SLIDER + on/off row in Settings overlay** — NOT YET WIRED. Needs 3 sites:
      `ui_draw_settings_overlay` (scr_ui ~6133) row draw, the settings input handler (scr_stats
      ~9684+) cursor/row count, and the touch tap-track block at the END of the overlay.
      NOTE: `global.touch_gamepad_off` was referenced but **never set anywhere** — no row ever existed.
- [ ] **Tutorial popup on new-character screen (before class choice)**: tell the player they can use
      touch OR the d-pad, and resize/disable it in Settings. (M's ask; use the coach-mark system.)
- [ ] 🔧 **WHETSTONE SHRINE has NO touch controls** (softlock class — M escaped only via d-pad).
- [ ] 🔧 **Popup/overlay messages should be LARGER** — they're overlays, so there's free room to
      make them more legible on a phone.
- [ ] 🔧 **D-pad must reach EVERYTHING incl. END TURN** + move the End Turn button UP (nearly
      overlapping the ability row). M chose **combat fix + FULL SCREEN AUDIT** for unreachable verbs.
- [ ] 🔧 **No touch equivalent of Tab to INSPECT a creature from the Bairc pet screen** (Tab-only).
- [ ] 🔧 **Loadout: is there a touch equivalent of Tab for abilities?** — verify, add if missing.
- [~] Touch-wall fixes + keyboard-hint hiding on mobile — built, verify on device after F5

---

## NEXT ACTION
1. F5 + commit current batch. 2. Create + back up the release keystore. 3. Build Release AAB.
4. Upload to Internal testing. Then Phase 2 setup tasks in parallel, then Closed testing to start ⏱.
