# Ironwake Trailer — Cut Review & Build Sheet
**Written 2026-07-26 against `Ironwake trailer beta.mp4` (1:55.93, 1080p30, Clipchamp).**

---

## 1. What the beta cut is (frame-sampled timeline)

| Time | Content |
|---|---|
| 0:00–0:06 | Title screen (moon/town vista) |
| 0:06–0:12 | Character creation — class select, portrait picker |
| 0:12–0:20 | Camp menu → Dorn's shop → Bairc dialog |
| 0:20–0:35 | Egg garden → "THE SHELL TREMBLES…" → hatch → naming **Bloopie** |
| 0:35–0:45 | Loadout ("PREPARE TO DESCEND") + companion tab |
| 0:45–0:50 | **Combat** (Vault Crawler, catacombs) — the only combat sampled |
| 0:50–1:10 | Stats page, equipment, Shrine of Tribute, floor map |
| 1:10–1:30 | Gear, Stranger's Memory event, Cursed Altar, LOOT FOUND (epics) |
| 1:30–1:50 | Camp victory, Fortune Egg, **WYRMLING reveal**, Bloopie ready-to-grow |
| 1:50–1:56 | Knucklebones (empty board) — no end card |

## 2. Honest verdict

**As a social/"my first run" story video: this is genuinely good.** The Bloopie arc
(egg stirs → shell trembles → hatch → name it → it descends with you → Wyrmling #2
arrives) is a charming narrative spine no big-studio trailer has. Keep it intact for
the solo-dev VO cut (§5).

**As the Steam store trailer: it will not convert, for three fixable reasons.**
1. **No combat until ~0:45.** Steam shoppers decide muted in 5–15 seconds; the genre
   pitch (tactical AP roguelite) is invisible for the first three-quarters of a minute.
2. **~85% of runtime is menu/UI screens.** In the small store-page player, list text is
   illegible; UI reads as "spreadsheet game." Valve's own trailer guidance: majority
   actual gameplay.
3. **The three locked hooks aren't landed:** no betrayal beat (the money shot), no
   Awakening/late-game power, no boss. Ends with no CTA/end card.

## 3. Store-cut restructure (target 60–75s)

Reuse existing footage where marked ♻; NEW = needs capture (shot list §4).

| # | Time | Clip | Text card (Cinzel, 2-line max, bottom third) |
|---|---|---|---|
| 1 | 0:00–0:04 | NEW: hardest-hitting combat moment (detonation combo or boss opener) | — (cold open, impact SFX) |
| 2 | 0:04–0:08 | ♻ Title vista (trim to 4s) | — (logo is the card) |
| 3 | 0:08–0:20 | NEW: 3× combat clips, different dungeons/abilities, 3–4s each | **"OUTTHINK. UNMAKE."** on first clip → **"Tactical combat. Every point of AP matters."** |
| 4 | 0:20–0:32 | ♻ Egg stirs → SHELL TREMBLES → hatch → name Bloopie (compress to 12s) | **"What you raise… fights beside you."** |
| 5 | 0:32–0:40 | NEW: pet acting in combat + (if capturable) Awakened aura | **"…and grows into something else."** |
| 6 | 0:40–0:50 | ♻ Quick UI flash-cuts ≤1.5s each: Cursed Altar → Stranger's Memory → LOOT FOUND epics → floor map | **"Every descent is a gamble."** |
| 7 | 0:50–0:58 | NEW: betrayal scene / NPC bond moment | **"The town remembers what you do."** |
| 8 | 0:58–1:05 | NEW: boss or chaos-peak combat, cut on beats | — |
| 9 | 1:05–1:12 | End card: logo on black → **"AUGUST 2026 — WISHLIST NOW ON STEAM"** + Seahorse Games | — |

Editing rules: cut ON music beats (Clipchamp/CapCut beat markers); no clip over 4s
except the hatch arc; UI screens only as ≤1.5s flash-cuts; layer real game SFX
(hits, detonations, loot stinger) under the music at ~-12dB.

## 4. NEW capture needed (NVIDIA F11, fullscreen 1080p)

1. 4–6 combat clips: different dungeons/backdrops, showy abilities (detonations,
   frost/shock, Soul Engine), include a kill + loot pop.
2. One boss fight burst (any of the 6 bosses — pick the most readable arena).
3. Pet acting in combat + Awakened pet aura if a save has one.
4. Betrayal beat (or bond-decay/severity moment) — Beat 3 money shot.
5. OPTIONAL: win-state "IRONWAKE STANDS" flash for the end of clip 8.

## 5. Solo-dev VO social cut (~45s, made FROM the beta cut)

The beta cut's chronological structure is the skeleton — add VO + captions
(always captioned), export 9:16 crop for TikTok/Shorts, 16:9 for YouTube.

> (title screen) "I spent a year making a gothic roguelite, alone, and I need you
> to meet someone."
> (egg stirs) "This is an egg I found in a dungeon. The manual I also wrote says
> it's fine."
> (SHELL TREMBLES → hatch) "…It was not fine. This is Bloopie."
> (naming) "Yes, you name them. Yes, this town will remember the name Bloopie."
> (combat with pet) "Bloopie shields me in a turn-based deathmatch while I commit
> tactical war crimes with three action points."
> (cursed altar / loot) "You can curse yourself for better loot, because I believe
> in you specifically."
> (betrayal or camp) "Also the NPCs remember everything you do to them. Everything."
> (Wyrmling reveal) "Anyway there's a second egg now. Wishlist Ironwake on Steam.
> Bloopie is counting on you. August 2026."

Tone: dry, deadpan, sincere underneath. One take, slightly imperfect audio is FINE
for this format — it's the authenticity signal.

## 6. Music (store cut)

Owned candidates to audition, in recommended order:
1. **snd_music_dungeon_1–4** (the run/dungeon pool) — pick the most driving/percussive
   of the four; trailers want momentum, not ambience.
2. The 3 Banshee music-unlock tracks — moodier; fallback if no dungeon track has
   enough drive.
3. TomMusic pack (Asset_Library\Sounds) — last resort; check license credit note in
   CREDITS.md before shipping it in marketing material (it's commercial-OK).

Pick BEFORE re-editing; the beat grid determines the cuts.

## 7. Steam upload settings (when done)

Store Page Admin → **Trailers** tab. Highest-quality H.264 ≥5000kbps, 1920×1080,
30 or 60fps; Steam re-encodes. Name it ("Ironwake — Early Access Trailer"), set as
first/autoplay trailer. Upload completes the Game Build checklist → "Mark as ready
for review" appears.
