# Ironwake — ANDROID / Google Play Tracker

**Living status doc. Updated 2026-07-20.** Spine = LAUNCH_FOCUS.md (Track B). Detail kits:
PLAY_STORE_KIT.md · PRIVACY_POLICY.md · ANDROID_PORT_PLAN.md · STORE_LISTINGS_LOCALIZED.md.

Legend: `[x]` done · `[~]` in progress / partial · `[ ]` not started · 🔴 blocker · ⏱ time-sensitive.

> ## 📍 (2026-07-26) ⏱ TARGET API 36 REQUIRED — fix BEFORE the closed test
> Play Console issue (verbatim intent): **apps must target Android 16 (API 36) from Aug 30,
> 2026** or updates are blocked; our AAB targets API 35. NOT a past mistake — API 35 was the
> requirement when we built (Google ratchets annually every ~Aug 30). Since production will
> land after Aug 30, the closed test must run on an API-36 build or we rebuild mid-process.
> **FIX (M, in IDE):** Android Studio SDK Manager → install API 36 platform → GM Android
> settings → Target SDK 36 (Min stays 23; runtime update if GM lacks 36) → rebuild Release
> AAB (version bump 1.0.0.1) → upload to Internal track → verify on S25 → Play sends the
> "no longer affected" confirmation. Do this before recruiting testers.
>
> ## 📍 YOU ARE HERE (2026-07-20)
> **07-20: Android developer verification registered** (see KEY FACTS) — identity/distribution
> paperwork only, **no release-track progress, clock not started**. Status below is unchanged.
>
> ⚠️ **ANR DOWNGRADED 07-23 — unconfirmed, needs clean-install repro (was 🔴 launch-blocker).**
> M: no one else reported it, and he had **duplicate Ironwake installs** on his phone (a plausible
> cause). Retesting on a single clean install before treating it as real. Kept on record: "no
> reports" is weak — there are still ZERO external testers to hit it — and main-thread `save_game()`
> is a real risk regardless, so the cheap code check + atomic-save hardening stay on the list. Not
> gating the launch path for now. (Full context: memory `project_anr_and_run_resume_0718`.)
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
- **GM Android config target:** target SDK 35 → ⏱ **MUST become 36** (Play deadline Aug 30 2026,
  see 07-26 YOU-ARE-HERE), min SDK 23, arm64, version 1.0.0.0 → bump per upload, display name "Ironwake".
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
- [x] **D-pad size SLIDER + on/off row in Settings overlay — WIRED 07-24** as ONE combined row
      (panel is height-capped at 1080): row 7 "On-screen D-pad" — A/D sizes (slider), Enter
      toggles off/on (OFF pill), tap-the-track sets size directly. Reset Tutorial moved to row 8.
      All 3 sites done (overlay draw, scr_stats handler 9-row cursor, tap-track block).
- [x] **Tutorial popup on new-character screen — BUILT 07-24.** Self-contained popup in
      obj_char_select (NOT the coach-mark system: tutorial_dismiss → save_game() mid-char-create
      would stub the slot). Touch-only; explains tap vs d-pad + SETTINGS chip resize/disable;
      seen-flag = settings.ini [touch] intro_seen (device-level). GOT IT closes; Step exits while up.
- [x] 🔧 **WHETSTONE SHRINE touch controls — FIXED 07-24** (was the softlock class): tap rows to
      select / tap-again to confirm in both phases + explicit LEAVE/BACK button (simulated Esc),
      all hit-tested in Draw_64 like the shrine.
- [ ] 🔧 **Popup/overlay messages should be LARGER** — folded into the MOBILE READABILITY pass
      (07-24): overlays get a legibility bump alongside the hub redesign.
- [~] 🔧 **D-pad must reach EVERYTHING incl. END TURN** — combat fix DONE 07-24: d-pad DOWN
      focuses END TURN (gold armed border), confirm ends the turn, UP/sideways returns to the
      ability row (end_turn_focus; button lift itself shipped 07-18). FULL SCREEN AUDIT for other
      unreachable verbs still pending.

### 07-24 FULL SCREEN AUDIT — keyboard verbs missing a touch and/or gamepad path
Method: every `input_hotkey`/raw `keyboard_check_pressed` site diffed against the pad hotkey
map (`__input_pad_hotkey_map`), touch chip bar, action menus, and Draw-side tap handlers
(Draw checked directly — Step-only greps false-positive). Nav/confirm/cancel verbs count as
covered via the on-screen d-pad. Verified COVERED and skipped here: board K/T/R, shrine 1/2/3,
floor G/E/J/I, hub chips, Maren/Sable/charmenu tab taps, loadout Tab/M chips, victory/extract
overlays (click fallbacks), knucklebones play (pure nav), title menu + slot picker taps,
char-select gender (tap cells), gift popup (click).
**NEW DEV LEVER (07-24): F9 = forced touch mode on Windows** (IDE-run only, compiled out of
release like F7/F8). input_device() reads 2, so chips/d-pad/taps/long-press/swipes all run and
are driven by the mouse — test the whole touch UI without the phone. Pair with F7 (phone
aspect) for a desktop S25 approximation. Real-device passes still needed for thumb ergonomics,
multi-touch, and Android-only quirks before shipping.

ALL 9 FIXED 07-24 (same session, M's call):
- [x] 🔴 **Combat `G` — companion guard**: pad `G`→L3 in the combat map + touch "GUARD: ON/OFF"
      button left of END TURN (490-730 × 856-916), drawn only under the Step handler's own gate
      (guarded-stance Warrior companion active).
- [x] 🟠 **Char menu `U` — unequip slot**: touch "UNEQUIP SLOT" footer button on the Equipment
      tab (only while the selected slot holds an item; sits where the hidden key legend was).
- [x] 🟠 **Loadout companion `B` — pet stance**: STANCE chip on the companion tab, gated to a
      pet row with a non-empty `pet_stance_list` (Fortune pets excluded — no dead chip).
- [x] 🟡 **Title `O` — Settings**: touch SETTINGS button bottom-right of the title menu phase.
- [x] 🟡 **Char menu `T` — epithet**: title line is now tappable; hint reads "tap:" on touch.
- [x] 🟡 **Char select `G` — gender on pad**: `G`→RT added to the charsel map (legend
      auto-translates to the pad glyph).
- [x] 🟡 **Mid-run `P` overlay**: pad `P`→L3 (floor) / Select (combat) + flashing UPGRADE chip
      on the floor map when points are pending (mirrors the hub chip). Touch-in-combat left
      uncovered deliberately — a combat chip bar would collide with the widened ability row,
      and the floor chip covers the same spend between fights.
- [x] ⚪ **Bairc feeds beyond 6**: pad/touch feed submenu now lists ALL owned feeds via new
      absolute `bairc:feedabs<i>` tags (menu height auto-scales; keyboard 1-6+D/A paging
      unchanged).
- [x] ⚪ **Knucklebones `H` — rules**: RULES chip in the new "kb" chip-bar context (same chip
      toggles the overlay closed).
- [x] 🔧 **Bairc pet INSPECT on touch — FIXED 07-24**: "Details" entry added to the creature
      action submenu (tag bairc:detail → same Tab detail popup).
- [x] 🔧 **Loadout Tab equivalent — VERIFIED PRESENT 07-24**: long-press examine already wired
      (obj_hub_controller Step ~485 + "Hold an ability to examine" hint).
- [~] Touch-wall fixes + keyboard-hint hiding on mobile — built, verify on device after F5

---

## NEXT ACTION (updated 07-26)
1. ⏱ Target SDK 35→36 in GM (+API 36 platform via SDK Manager) → rebuild AAB (1.0.0.1) →
   upload to Internal track → verify on S25 (clears the Play API-level issue).
2. Finish merchant/payments verification (Phase 5) + add License testers.
3. Recruit to 12 valid Google-account testers (~8 usable now; swap the Yahoo addr).
4. Promote the API-36 AAB to Closed testing → ⏱ 14-day clock starts.
5. 🔴 Before production: swap public merchant address off M's home address.
