# Ironwake — LAUNCH FOCUS (one page, the only tracker you need to open)

**Steam launch: Wed Aug 19 2026 (committed).** Android: no fixed date — background track.
This is the spine. Live per-track status: **STEAM_TRACKING.md** · **ANDROID_TRACKING.md**.
Detail kits: STEAM_LAUNCH_CHECKLIST.md · PLAY_STORE_KIT.md · STORE_LISTINGS_LOCALIZED.md.
Updated 2026-07-18.

**Focus decision (07-17):** lock the baseline → finish Steam → keep Android's tester clock
ticking in parallel. Everything else is PARKED (bottom).

Legend: [You] = M dashboard/device/payments · [C] = Claude (code/copy/builds) · 🔴 blocker

---

## 🔴 STEP 0 — UNBLOCK EVERYTHING (do first)
The 07-17 batch is uncommitted + un-F5'd (touch/geometry/tiered ingots + reforge tab +
list-scroll sweeps + per-school spell SFX). It blocks BOTH the Steam build and the Android AAB.
- [ ] **[You] Windows F5 → play-test → commit → push** (first real compile of the whole batch;
      watch for GML syntax). Test: reforge tab + its scroll, the swept lists (buy/picker/stash/
      Sable/Vael/consumables/combat quick-item), new spell SFX per school.
- [ ] [C] After commit: clean the `_for_review/spell_sfx/` candidates (picks are imported).

---

## 🟢 TRACK A — STEAM (the committed launch; ~90% done)
Page was SUBMITTED for review 07-14; all text + art/screenshots/capsules/library green.
1. [ ] **[You] Check email — is the page approved?** If yes → flip **Coming Soon** (starts the
       14-day public clock; Aug 19 already has margin).
2. [ ] [You] **Publish the deferred App Data config** ("Publish to Steam" — releases nothing;
       must precede the first build upload).
3. [ ] [You+C] **Upload a build** from the F5'd baseline (tools/steam kit) → set live on `default`.
4. [ ] [You] **Request Build Review** (3–5 biz days — do EARLY, not launch week).
5. [ ] [You] **Steam Cloud** — config only (WinAppDataLocal / `Ironwake`, cloud-on-by-default).
6. [ ] [C+You] **Steamworks SDK init + Achievements** (C designs the list; needs GMEXT-Steamworks).
7. [ ] [C] **Trailer** (before launch, not for Coming Soon).
8. [ ] [You] **Pricing $9.99 + 10% launch discount** — launch week only.
> Gates (all clear with margin): 21-day hold ~Jul 31 · Coming Soon 14+ days · build review passed.

---

## 🔵 TRACK B — ANDROID (background; only ONE thing is time-sensitive)
The long pole is the **12 testers × 14 continuous days** closed-test gate before production access.
Start that clock ASAP — everything else can follow.
- [ ] [You] ID verification clears (1–5 days from 07-17).
- [ ] [You] Release keystore in GM (**BACK IT UP**) + package `com.seahorsegames.ironwake`, build AAB.
- [ ] [You] **Internal testing** upload — proves the signing/AAB pipeline installs to your S25.
- [ ] [You] **Closed testing** → recruit **12 testers**, opt them in → **⏱ starts the 14-day clock**.
- [ ] [You] Merchant/payments profile (only before a PAID production release).
- [ ] [You] Paste listing from PLAY_STORE_KIT.md + data-safety "none" + PRIVACY_POLICY URL.
- [ ] [C] On-screen gamepad device-tuning (quality, not gating).
- Done already: account + app draft, listing kit, privacy policy, ES/DE/PT-BR listing translations,
  AI disclosure v2.

---

## 🅿️ PARKED — real work, but NOT before Aug 19 (this is what was making you drift)
- In-game localization foundation (loc() string table + pattern screens) — post-launch project.
- Store listings beyond ES/DE/PT-BR (next batch = ID/TR/FR/IT for mobile) — anytime, no build.
- Combat plan v2 numbers (project_combat_plan_0717) · further SFX/art polish · enemy undead
  bone-crunch de-dup · IAP revive-pack idea.
> If it doesn't move STEP 0 or Track A forward, it waits.
