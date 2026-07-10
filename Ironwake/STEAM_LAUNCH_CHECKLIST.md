# Ironwake — Steam Launch Runbook

From "app created" to Early Access launch, click by click. Started 2026-07-10, the day
the app was created. Companion docs: **STEAM_PAGE_KIT.md** (all paste-ready store copy),
**CREDITS.md** (license audit of record), `tools/steam/` (build upload kit).

**You do the dashboard clicks and payments; Claude preps files, copy, code, and builds.**
Everything happens at https://partner.steamgames.com — you do NOT need a website,
mailing list, or anything outside Steam to launch.

---

## 0. Our numbers (from the app-creation receipt, 2026-07-10)

| Thing | Value |
|---|---|
| **App ID** | **1246716** ← this goes everywhere |
| Default depot | **1246717** (App ID + 1, auto-created) |
| Store packages | 1719511 "Ironwake" (the one customers buy) · 1719509 dev comp · 1719510 beta |
| App admin URL | https://partner.steamgames.com/apps/landing/1246716 |

---

## 1. The three clocks (verified against Steamworks docs 2026-07-10)

1. **30-day hold:** a new partner cannot release until **30 days after the $100 app fee
   cleared**. Fee paid ~2026-07-10 → **earliest possible release ≈ Sun Aug 9**.
2. **Coming Soon minimum:** the store page must be publicly "Coming Soon" for **≥14 days**
   before release. Page review takes **3–5 business days** after you submit it.
3. **Build review:** the actual game build gets a separate review (usually a few days,
   first build can take longer). Do it well before launch week, not at the end.

Also: once the page is live and your release date is **within 14 days**, the date is
LOCKED without contacting Steam support — don't set an exact date until we're sure.

**The 30-day hold dominates. Working target: EA launch Tue Aug 11 – Tue Aug 18, 2026.**
(Tue–Thu launches perform best; never launch into a Steam seasonal sale week.)

```
Jul 10  app created (today)          Jul 20-ish  page LIVE, wishlists start
Jul 11-14  page content + screenshots     Aug 3-ish   build uploaded + review passed
Jul 14-15  submit page for review         Aug 9       30-day gate opens
                                          Aug 11-18   EA LAUNCH
```

---

## 2. THIS WEEK — the store page (M in dashboard, Claude for assets/copy)

Dashboard → App Admin (1246716) → **Edit Store Page**.

1. **Basic Info tab:** name, developer/publisher, genres, tags — all in STEAM_PAGE_KIT §1.
   Set release date to a **window, not a date**: pick "August 2026" / "Coming Soon".
2. **Description tab:** paste short description (§2) + About This Game (§3) verbatim.
3. **Early Access tab:** tick Early Access, paste the five questionnaire answers (§4).
   Fill the one `[M: ...]` blank (EA duration — suggested "roughly 6 months").
4. **Content Survey / ratings:** answers in §5 — including the **AI disclosure, paste
   verbatim**, and the gambling clarification (in-game gold dice only).
5. **Credits:** Alex Coldfire + Sara Garrard lines (§6) — these are LICENSE TERMS, not
   courtesy. Alex Coldfire (CC BY-ND) must appear in the page's author/credit section.
6. **Graphical assets** — the actual work item. Required before you can submit:
   - Capsules: header 920×430 · small 462×174 · main 1232×706 · vertical 748×896 ·
     library 600×900 + library hero 3840×1240 + logo (transparent PNG).
   - **≥5 screenshots at 1920×1080** — shot list in §8 of the page kit. Shoot them in a
     fresh F5 session (Claude can drive a checklist of which screens to open; the new
     EB Garamond/Cinzel fonts are already live so anything we shoot now is shippable).
   - Capsule art: the gothic title treatment over the night-vista title backdrop.
     PixelLab/upscale session if needed — budget rules apply (100 gens cap).
7. **Save + "Submit for Review"** (button top of page). 3–5 business days. Fix-and-resubmit
   rounds are normal for a first page — read the reviewer notes carefully.
8. The moment it's approved, YOU flip it visible ("Release Coming Soon page") — approval
   does not auto-publish. **That click starts the 14-day clock. Do it immediately.**
9. Share the store link. Wishlists are the launch currency — every wishlist emails the
   player at launch. Put the link on the itch page too.

---

## 3. IN PARALLEL — get a build onto Steam (`tools/steam/` kit)

One-time setup (M, ~20 min):

1. Download the **Steamworks SDK**: https://partner.steamgames.com/downloads/list →
   unzip anywhere, e.g. `C:\steamworks_sdk\`. steamcmd is inside at
   `sdk\tools\ContentBuilder\builder\steamcmd.exe`.
2. In GameMaker: **Create Executable** for Windows (same flow as the itch builds), take
   the **Zip**, and extract its contents into `tools\steam\content\` (so
   `tools\steam\content\Ironwake.exe` exists at the top level).
3. Run the upload (PowerShell):
   ```
   C:\steamworks_sdk\sdk\tools\ContentBuilder\builder\steamcmd.exe +login <your_steam_login> +run_app_build "C:\Users\miles\GameMakerProjects\Ironwake\tools\steam\scripts\app_build_1246716.vdf" +quit
   ```
   First run asks for password + Steam Guard code, then caches the session.
4. Dashboard → App Admin → **SteamPipe → Builds**: your upload appears; set it **live on
   the `default` branch** ("Set build live on branch"). Make a private `beta` branch too —
   free stranger-playtest channel using the 1719510 beta package keys.
5. Dashboard → **Installation → General Installation**: add Launch Option 1 —
   Executable: `Ironwake.exe`, OS: Windows, type: Launch (default).
6. Install it yourself through the Steam client (you auto-own it via the dev comp
   package) and confirm it boots from a clean machine-state perspective.
7. When the store page is approved and a build is live on default: App Admin →
   **request Build Review**. Pass = release button unlocks (after the clocks in §1).

Repeat uploads for every new build = steps 2–3 only (bump the `Desc` line in the vdf).
`content\` and `output\` are gitignored — never commit a packaged build.

**Gotchas:**
- Never ship `steam_appid.txt` in the depot (the vdf already excludes it — it's a
  local-dev file only).
- The GM zip contains everything the game needs (exe + data.win + options); no
  installer, no redistributables needed for a GM game.
- Price is set separately: App Admin → **Pricing** → $9.99 (per §7 of the page kit),
  request the 10% launch discount there too. Do this during launch week, not before.

---

## 4. DURING THE WINDOW (Jul 14 → Aug 9) — feature + polish work

In rough priority order (M ruled 07-10: cloud saves + achievements + SDK init all in):

1. **Auto-Cloud saves** — config only, no code. App Admin → **Steam Cloud**:
   - Byte quota: 100 MB / 1000 files (saves are tiny; roomy is free).
   - Root: `WinAppDataLocal`, path: `Ironwake` (that's `%LocalAppData%\Ironwake`,
     where every slot + settings.ini already lives).
   - Enable "Cloud on by default". Test: play on the Steam build, check the file shows
     in Steam → Settings → Cloud → storage page.
2. **Steamworks SDK init** (code, Claude session): install YoYo's official
   **GMEXT-Steamworks** extension, App ID 1246716, `steam_initialised()` smoke test,
   overlay (Shift+Tab) working. Prerequisite for achievements.
3. **Achievements** (code + dashboard, Claude designs the list for M sign-off):
   natural map = codex completion tiers, first pet Awakening, each capstone, betrayal,
   win state ("IRONWAKE STANDS"), High Table win, Awakening ladder milestones.
   Define in App Admin → Stats & Achievements; fire via `steam_set_achievement()` at
   the existing counters (total_kills, dungeon_clears_total, bond gates, run_history).
4. **Stranger playtest** via the beta branch (or keep using itch) — first-hour watch,
   ~5 players, per the roadmap.
5. **Trailer** (needed before launch, not for Coming Soon) — beat sketch in page kit §8.

---

## 5. LAUNCH WEEK checklist

- [ ] Build review PASSED and final build live on `default`
- [ ] 30-day gate passed (≈ Aug 9) and page has been Coming Soon ≥14 days
- [ ] Pricing set ($9.99) + 10% launch discount configured
- [ ] Trailer uploaded to the store page
- [ ] EA questionnaire final, AI disclosure + Coldfire/Garrard credits verified on page
- [ ] Steam Cloud tested with a real save round-trip
- [ ] In-game version stamp bumped + patch notes drafted for day-1
- [ ] Press the green **Release App** button (App Admin → it appears when all gates pass)
- [ ] Post launch announcement (Steam Community hub post) + itch page banner link

Post-launch: patch cadence + public roadmap per the EA questionnaire promise; 1.0 price
move to $12.99 announced ~2 weeks ahead.
