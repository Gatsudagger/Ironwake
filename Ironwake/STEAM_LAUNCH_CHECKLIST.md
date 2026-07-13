# Ironwake - Steam Launch Runbook

From "app created" to Early Access launch, click by click. Started 2026-07-10, the day
the app was created. Companion docs: **STEAM_PAGE_KIT.md** (all paste-ready store copy),
**CREDITS.md** (license audit of record), `tools/steam/` (build upload kit).

**You do the dashboard clicks and payments; Claude preps files, copy, code, and builds.**
Everything happens at https://partner.steamgames.com - you do NOT need a website,
mailing list, or anything outside Steam to launch.

---

## 0. Our numbers (CORRECTED 2026-07-13 from the App Admin page)

| Thing | Value |
|---|---|
| **App ID** | **4954740** <- this goes everywhere (the receipt's "store item 1246716" is a different, internal ID) |
| Default depot | **4954741** (App ID + 1 - CONFIRM under SteamPipe -> Depots before first upload) |
| Store packages | 1719511 "Ironwake" (the one customers buy) / 1719509 dev comp / 1719510 beta |
| App admin URL | https://partner.steamgames.com/apps/landing/4954740 |
| Developer / Publisher (public) | **Seahorse Games** (set 07-13; matches the Android company name "Seahorse") |

---

## 1. The three clocks (per the App Admin Release Progress panel, read 2026-07-13)

1. **21-day hold:** minimum **21 days since the first purchase of an app credit**.
   Fee paid ~2026-07-10 -> **earliest possible release ~ Fri Jul 31**.
2. **Coming Soon minimum:** the store page must be publicly "Coming Soon" for **14+ days**
   before release. Page review takes **2-3 business days** per round.
3. **Build review:** separate, **3-5 business days** per round. Do it well before launch
   week, not at the end.

Also: once the page is live and your release date is **within 14 days**, the date is
LOCKED without contacting Steam support - don't set an exact date until we're sure.

**LAUNCH DATE SET (M, 07-13): Wednesday August 19, 2026** - entered in Steamworks;
customers see "August 2026" until close to the day. Clears every gate with room.

```
Jul 10     app created                  Jul 20-ish  page LIVE, wishlists start
Jul 13     ALL page text DONE           Jul 28-ish  build uploaded + review passed
Jul 14-17  screenshots + capsule art    Jul 31      21-day gate opens
Jul 17-18  submit page for review       Aug 19      EA LAUNCH (locked in dashboard)
```

**STATUS 2026-07-13 (dashboard walkthrough with M):** Store Presence checklist - ALL
text items green: Basic Info (Seahorse Games dev+pub, Windows-only 64-bit, English
interface, RPG/Strategy/Indie), Descriptions (KIT text pasted), Content Survey
(fantasy violence + simulated-gambling option 3 + AI pre-generated disclosure),
Planned Release Date (Aug 19), System Requirements, Controller Support Description,
Support Info, Dev/Publisher Names, Tags (all 15 in order). M wrote his own EA
questionnaire answers. REMAINING (all art): 5+ screenshots, capsule images, library
assets, app icon + shortcut icon. Game Build checklist remaining: pricing, build
upload, launch options, trailer, Steam Input (post-EA). NOTE: App Data Admin has
un-published config changes (OS checkboxes) - "Prepare for Publishing" already run,
M deferred "Publish to Steam"; MUST be published before/with the first build upload
(it releases nothing - config only).

---

## 2. THIS WEEK - the store page (M in dashboard, Claude for assets/copy)

Work the **"Your Store Presence" checklist** on the right side of the App Admin landing
page (https://partner.steamgames.com/apps/landing/4954740) top to bottom - every line
links straight to its form, and its checkbox fills when Steam considers it complete.

The items, with where their content comes from:

1. **Basic Info** - developer/publisher = `Seahorse Games` (both), franchise blank,
   genres RPG (+ Strategy, Indie), languages English (interface/subtitles only, no
   full-audio), support email. Platforms: **Windows ONLY** (Android/mobile is a separate
   store entirely - never list it here).
2. **Descriptions** - paste short description (KIT section 2) + About This Game (KIT
   section 3) verbatim.
3. **Content Survey** - KIT section 5: stylized fantasy violence, in-game-gold gambling
   note, and the **AI disclosure pasted verbatim**. Required before release.
4. **Planned Release Date** - the month-style option: **August 2026**. No exact date yet.
5. **System Requirements** - min: Windows 10 64-bit / 2.0 GHz dual core / 4 GB RAM /
   DirectX 11 compatible incl. integrated (Intel HD 4000+) / DirectX 11 / 1 GB storage.
   Recommended column optional - leave blank or copy minimums.
6. **Controller Support Description** - keyboard + mouse at EA launch; full controller
   support planned during Early Access (matches the EA questionnaire answer).
7. **5 Or More Screenshots** - 1920x1080, shot list = KIT section 8. Shoot in an F5
   session (fonts are already the OFL swaps, everything is shippable).
8. **Capsule Images** - header 920x430 / small 462x174 / main 1232x706 / vertical
   748x896. Art = gothic title treatment over the night-vista backdrop.
9. **Library Assets** - library capsule 600x900, hero 3840x1240, logo (transparent PNG).
10. **Support Info** - support email (and itch page URL if it asks for a site).
11. **Developer and Publisher Names** - `Seahorse Games` / `Seahorse Games`.
12. **Store Page Descriptive Tags** - in this order (first five weigh most): Roguelite,
    Turn-Based Combat, Dungeon Crawler, Dark Fantasy, Pixel Graphics, then RPG, Loot,
    Procedural Generation, Turn-Based Tactics, Singleplayer, Creature Collector, Gothic,
    Character Customization, Indie, Replay Value.
13. **App Icon** (community section) - 32x32 + 184x184 (client/library icons).

Plus, findable from the store page editor (not always in the sidebar list):

- **Early Access setup** - tick "Early Access", paste the five questionnaire answers
  (KIT section 4); EA duration blank = "Roughly 6 months, extending only if community
  feedback warrants it."
- **Credits** - Alex Coldfire + Sara Garrard lines (KIT section 6) - these are LICENSE
  TERMS, not courtesy. Alex Coldfire (CC BY-ND) must appear in the author/credit section.

Then: **Save + "Submit for Review"**. 2-3 business days; fix-and-resubmit rounds are
normal for a first page - read reviewer notes carefully. The moment it's approved, YOU
flip it visible ("Release Coming Soon page") - approval does not auto-publish, and that
click starts the 14-day clock. Share the link everywhere; wishlists are the launch
currency (every wishlist emails the player at launch). Put it on the itch page too.

---

## 3. IN PARALLEL - get a build onto Steam (`tools/steam/` kit)

One-time setup (M, ~20 min):

1. Download the **Steamworks SDK**: https://partner.steamgames.com/downloads/list ->
   unzip anywhere, e.g. `C:\steamworks_sdk\`. steamcmd is inside at
   `sdk\tools\ContentBuilder\builder\steamcmd.exe`.
2. In GameMaker: **Create Executable** for Windows (same flow as the itch builds), take
   the **Zip**, and extract its contents into `tools\steam\content\` (so
   `tools\steam\content\Ironwake.exe` exists at the top level).
3. Run the upload (PowerShell):
   ```
   C:\steamworks_sdk\sdk\tools\ContentBuilder\builder\steamcmd.exe +login <your_steam_login> +run_app_build "C:\Users\miles\GameMakerProjects\Ironwake\tools\steam\scripts\app_build_4954740.vdf" +quit
   ```
   First run asks for password + Steam Guard code, then caches the session.
4. Dashboard -> App Admin -> **SteamPipe -> Builds**: your upload appears; set it **live
   on the `default` branch** ("Set build live on branch"). Make a private `beta` branch
   too - free stranger-playtest channel using the 1719510 beta package keys.
5. Dashboard -> **Installation -> General Installation**: add Launch Option 1 -
   Executable: `Ironwake.exe`, OS: Windows, type: Launch (default).
6. Install it yourself through the Steam client (you auto-own it via the dev comp
   package) and confirm it boots.
7. When the store page is approved and a build is live on default: App Admin ->
   **request Build Review**. Pass = release button unlocks (after the clocks in section 1).

Repeat uploads for every new build = steps 2-3 only (bump the `Desc` line in the vdf).
`content\` and `output\` are gitignored - never commit a packaged build.

**Gotchas:**
- Never ship `steam_appid.txt` in the depot (the vdf already excludes it - it's a
  local-dev file only).
- The GM zip contains everything the game needs (exe + data.win + options); no
  installer, no redistributables needed for a GM game.
- Price is set separately: App Admin -> **Pricing** -> $9.99 (per KIT section 7),
  request the 10% launch discount there too. Do this during launch week, not before.

---

## 4. DURING THE WINDOW (Jul 14 -> Aug 4) - feature + polish work

In rough priority order (M ruled 07-10: cloud saves + achievements + SDK init all in):

1. **Auto-Cloud saves** - config only, no code. App Admin -> **Steam Cloud**:
   - Byte quota: 100 MB / 1000 files (saves are tiny; roomy is free).
   - Root: `WinAppDataLocal`, path: `Ironwake` (that's `%LocalAppData%\Ironwake`,
     where every slot + settings.ini already lives).
   - Enable "Cloud on by default". Test: play on the Steam build, check the file shows
     in Steam -> Settings -> Cloud -> storage page.
2. **Steamworks SDK init** (code, Claude session): install YoYo's official
   **GMEXT-Steamworks** extension, App ID 4954740, `steam_initialised()` smoke test,
   overlay (Shift+Tab) working. Prerequisite for achievements.
3. **Achievements** (code + dashboard, Claude designs the list for M sign-off):
   natural map = codex completion tiers, first pet Awakening, each capstone, betrayal,
   win state ("IRONWAKE STANDS"), High Table win, Awakening ladder milestones.
   Define in App Admin -> Stats & Achievements; fire via `steam_set_achievement()` at
   the existing counters (total_kills, dungeon_clears_total, bond gates, run_history).
4. **Stranger playtest** via the beta branch (or keep using itch) - first-hour watch,
   ~5 players, per the roadmap.
5. **Trailer** (needed before launch, not for Coming Soon) - beat sketch in KIT section 8.

---

## 5. LAUNCH WEEK checklist

- [ ] Build review PASSED and final build live on `default`
- [ ] 21-day gate passed (~ Jul 31) and page has been Coming Soon 14+ days
- [ ] Pricing set ($9.99) + 10% launch discount configured
- [ ] Trailer uploaded to the store page
- [ ] EA questionnaire final, AI disclosure + Coldfire/Garrard credits verified on page
- [ ] Steam Cloud tested with a real save round-trip
- [ ] In-game version stamp bumped + patch notes drafted for day-1
- [ ] Press the green **Release App** button (App Admin - appears when all gates pass)
- [ ] Post launch announcement (Steam Community hub post) + itch page banner link

Post-launch: patch cadence + public roadmap per the EA questionnaire promise; 1.0 price
move to $12.99 announced ~2 weeks ahead.
