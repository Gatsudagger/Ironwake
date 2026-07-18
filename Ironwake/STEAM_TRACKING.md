# Ironwake — STEAM Tracker

**Living status doc. Updated 2026-07-18.** Spine = LAUNCH_FOCUS.md (Track A). Detail kits:
STEAM_LAUNCH_CHECKLIST.md · STEAM_PAGE_KIT.md · CREDITS.md · tools/steam/.

Legend: `[x]` done · `[~]` in progress / partial · `[ ]` not started · 🔴 blocker · ⏱ time-sensitive.

> ## 📍 YOU ARE HERE (2026-07-18)
> Store page **SUBMITTED for review 07-14** — all text/art/screenshots/capsules/library green.
> **Waiting on Valve page approval.** Once approved → flip **Coming Soon** (starts the 14-day public
> clock; Aug 19 has margin). Build upload + Build Review still ahead — do them EARLY, not launch week.
> ~90% done. **Committed launch: Wed Aug 19 2026.**

---

## KEY FACTS
- **AppID:** 4954740 · **Publisher:** Seahorse Games · **Launch:** Wed **Aug 19 2026** (committed).
- **Price:** $9.99 + 10% launch-week discount (launch week only).
- **AI disclosure:** v2 LIVE in CREDITS.md + STEAM_PAGE_KIT §5 — still must be pasted into the live
  Steam AI-content survey when reachable.
- **Gates (all clear with margin):** 21-day trust hold ~Jul 31 · Coming Soon must be live 14+ days ·
  build review must pass.

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
