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

**STATUS 2026-07-14 (key-art session): ALL GRAPHICAL ASSETS UPLOADED + SAVED CLEAN.**
Master = MidJourney gen (M's account, commercial rights): hooded hero + rabbit-like
companion on a forest path, blood-red moon, distant lantern-lit town; companion was
PIL-transplanted from a second gen (swap was one-off session work; the finished
composite is committed as `tools/steam/art/key_art_master.png`, sources alongside).
All 8 sizes built by `tools/steam/build_capsules.py` from tools/steam/art/ masters
(rerunnable end to end, outputs to _for_review/steam_capsules/). Logotype = Cinzel Decorative
Bold, parchment + dark stroke; NO tagline (M cut it). App/shortcut icon = M's lantern
gen #2, glow-punched. GOTCHAS LEARNED (they will bite again):
- Store Graphical Assets page: drag ONLY files that map to slots; any unmatched image
  in the batch blocks the whole Upload ("image type selected for every image").
- LIBRARY HERO must contain no text/logo AND Steam's detector false-positives on
  clusters of bright town windows (rejected twice); shipped hero = moon/hills crop
  with zero warm light clusters.
- The red "Requirements:" line under Small Capsule is permanent boilerplate, not an
  error; real failures are popups at Save.
- Client Images page (App Admin): Shortcut Icon needs PNG 256/512 (or ICO >=256) -
  184px gets rejected; "Convert shortcut icon to app icon" checkbox regenerates the
  184 App Icon from it. Never upload the 32px file to App Icon (blurry stretch).
- Page Background 1438x810 exists too (not on the checklist): ambient, no logo -
  built as page_background_1438x810.png.
Icon candidates M rejected on the way: red-moon-only, key-art pet on moon, hero
silhouette on moon (liked, runner-up), in-game Rimefox on moon. REMAINING FOR PAGE
SUBMIT: 5+ screenshots (KIT section 8) -> submit for review.

**STATUS 2026-07-14 evening (screenshot session): 13 SCREENSHOTS UPLOADED + SAVED
CLEAN - store-page checklist fully green.** M shot 19 candidates windowed on 07-13
into `Steam Page Images/` (repo root, untracked); windowed grabs came out 1902-1916 x
1062-1072 and Steamworks REJECTS anything under exactly-1920x1080 ("Dimensions
provided do not match any known assets"). Fix = `tools/steam/fit_screenshots.py`:
center-crop to 16:9 + Lanczos upscale to 1920x1080 (~1%, invisible), outputs to
`_for_review/steam_screenshots_1920/`. M chose ALL 13 over the curated 8; skipped
only `tavern requests.png` (1547x1037 source - the crop cut its title band + footer;
parked in `_skip/`). The 5 "title thumbnail" PNGs are MidJourney gens (1456x816),
NOT gameplay - never upload as screenshots; M says ignore. Suggested top-row order:
combat 1, Petra hub screen, Dungeon choice screen, Dungeon loadout, Title screen.
Mature-content checkbox unchecked on all. STILL UNSHOT (KIT section 8 hook shots,
optional - can be added post-approval): Awakened-pet aura (Bairc shot exists but has
the wrong pet selected), Shrine of Tribute overlay, High Table/Knucklebones.
LIBRARY ASSETS ADDENDUM (same evening): the checklist item is actually FIVE
sub-assets - capsule 600x900, hero 3840x1240, logo PNG, **Library Header 920x430**
(D1 missed it; same art as the header capsule = canonical, Steam falls back to the
header capsule when unset; now built by build_capsules.py as
library_header_920x430.png), and the **Placement Tool** (not an upload - the
interactive widget at librarylogoeditorpopup/<appid> that pins the logo over the
hero; bottom-left anchor default was correct for our wordmark, M saved as-is).
All five green 07-14.
BROADCAST ASSETS (suggested, not required - done 07-14 anyway): two panels
199x433 flanking the live-broadcast video on the store page; built by
build_capsules.py from the master's tree-line edges (ambient, no text) as
broadcast_left_199x433.png / broadcast_right_199x433.png; upload = drag to the
top drop zone on the Broadcast Assets tab, pick type 'Broadcast Panel' +
left/right direction in the dropdown, Upload, Save. Both up + saved clean.
RECOMMENDED ITEMS (07-14 ruling): tick NO Supported-Features box for anything not
in the build. Cloud Saves + Steam Achievements boxes stay UNTICKED until D7/D4
actually ship them during the Coming Soon window (both planned pre-launch).
ACCESSIBILITY WIZARD done + saved 07-14: YES only to custom volume controls
(music/SFX sliders), adjustable difficulty (opt-in Awakening tiers, A0 baseline),
keyboard-only play, and own-pace/turn-based-style option if worded; NO to all else
(readability, directional audio, color alternatives, text size, subtitles,
contrast, camera comfort, TTS, save-anytime - saves are hub-gated).
**STORE PAGE SUBMITTED FOR REVIEW 2026-07-14 (M, same evening).** Review = 2-3
business days -> expect verdict ~Jul 16-17; email on approval; page locked for
edits while in review. ON APPROVAL: M flips **Coming Soon** (starts the >=14-day
public clock - Aug 19 launch date already set, margin is huge). If Valve bounces
anything, fix + resubmit (rejections cite the exact item). DURING THE WAIT, docket
order: D4 achievements (Claude drives design first - no dashboard dependency),
the 3 bug-report screenshots in Screenshots\ (07-13: portrait text overlay
collision, egg hatch text issues, petra borderline cropped), optional reshoot of
the 3 KIT hook shots (Awakened aura / Shrine / High Table - screenshots stay
editable after approval).

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

1. [x] **DONE 07-20.** Steamworks SDK downloaded (`steamworks_sdk_164.zip`) and extracted to
   **`C:\Users\miles\steamworks_sdk\`** (NOT `C:\steamworks_sdk` — user folder, no admin needed).
   steamcmd verified at:
   `C:\Users\miles\steamworks_sdk\sdk\tools\ContentBuilder\builder\steamcmd.exe`
2. In GameMaker: **Create Executable** for Windows (same flow as the itch builds), take
   the **Zip**, and extract its contents into `tools\steam\content\` (so
   `tools\steam\content\Ironwake.exe` exists at the top level).
3. Run the upload (PowerShell) — **login is `perluptis`** (the Steamworks account):
   ```
   C:\Users\miles\steamworks_sdk\sdk\tools\ContentBuilder\builder\steamcmd.exe +login perluptis +run_app_build "C:\Users\miles\GameMakerProjects\Ironwake\tools\steam\scripts\app_build_4954740.vdf" +quit
   ```
   First run asks for password + Steam Guard code, then caches the session. Must be run by M
   in a normal terminal — it's interactive (Steam Guard), so it can't be automated.
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
