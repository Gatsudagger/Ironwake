# Ironwake — Store Trailer Plan (~70s wishlist trailer)

**Created 2026-07-23.** Purpose: the Steam store trailer — autoplays (often muted) at the top of
the page, single biggest lever on wishlist conversion. Blocks the build-review checklist item
"Trailer Uploaded" (see STEAM_TRACKING). Supersedes the 30-45s sketch in STEAM_PAGE_KIT §8.

## Pipeline
- **Capture:** NVIDIA (ShadowPlay / NVIDIA App). Play **fullscreen (F11)** → native 1920×1080,
  pixel-clean, exactly Steam's target. Record generously; we trim in the edit.
- **Edit:** CapCut (free). Use its **beat-sync** to auto-place cuts on the music, then follow the
  cut sheet's trim/text/timing notes. Editorial choices stay manual — AI auto-cutters are built for
  dialogue, not music montages.
- **Music:** from the owned catalog (ElevenLabs tracks / TomMusic pack). Pick ONE driving track;
  see "Music" below.
- **Upload:** Steamworks store page → video. 1080p, H.264 mp4. No third-party logos in-frame.

## The three hooks this trailer MUST land
1. **Tactical AP combat** — intent chips, spell VFX, status detonation (table stakes, show fast).
2. **The town remembers** — NPC bonds + **betrayal** when neglected. THE differentiator; the
   emotional center. No competitor screenshot shows relationship stakes.
3. **Pets** — hatch → bond → Awakening with aura. The growth/dopamine hook.

## Structure (target ~70s)
| # | Beat | ~Time | On-screen text |
|---|------|-------|----------------|
| 1 | Cold open — living title backdrop, portcullis SFX | 0-5s | "A roguelite where the town remembers" |
| 2 | Combat I — 2-3 fast AP-combat cuts | 5-20s | (none, or a verb: "Spend. Detonate. Survive.") |
| 3 | The town — bond meter rising, dialogue, then BETRAYAL beat | 20-35s | "Earn their trust." → "Or lose it." |
| 4 | Pets — egg hatch → bond → Awakening cross-dissolve w/ aura | 35-50s | "Raise something of your own" |
| 5 | Depth montage — loot+sockets, event choice, shrine, Knucklebones | 50-62s | (rapid, no text) |
| 6 | Title card — logo / "IRONWAKE STANDS" | 62-70s | title → "Wishlist Now · Coming Soon" |

## SHOT LIST — what to capture with NVIDIA
Record each as its own clip (5-15s of usable action; longer is fine, we trim). Aim for clean,
readable moments — no menus half-open, no cursor jitter, no debug levers.

**Beat 1 — Cold open**
- [ ] Title screen idle: the living backdrop (panned vista, shooting star, moon glow, fog). 8s.

**Beat 2 — Combat (capture 3-4, we pick the best 3)**
- [ ] A turn where an **intent chip** is visible on an enemy, then you act. 6s.
- [ ] A **spell VFX** hit — biggest, flashiest ability you have (school affix glow if possible). 5s.
- [ ] A **status detonation** / Exposed combo popping (the payoff visual). 5s.
- [ ] A kill that collapses an enemy HP bar. 4s.

**Beat 3 — The town (the differentiator — capture carefully)**
- [ ] Hub NPC screen: portrait + **bond/affinity meter**, ideally mid-rise after a gift/dialogue. 6s.
- [ ] A warm dialogue line on-screen (pick one with heart). 4s.
- [ ] A **betrayal / neglect** moment: slot demotion, the betrayal severity line, or a soured NPC.
      This is the money shot for "the town remembers." 6s.

**Beat 4 — Pets**
- [ ] An **egg hatching**. 5s.
- [ ] Pet + owner bonding beat (feed/garden, a bond stance). 5s.
- [ ] **Awakening (Stage 4)** with the aura active — the wing-crossing/aura moment. THE dopamine
      shot; capture it clean and lingering. 8s.

**Beat 5 — Depth montage (fast cuts, capture plenty)**
- [ ] Loadout/loot: rarity-colored affix gear + **rune sockets**, an item lore splash. 6s.
- [ ] An **event room / Shrine of Tribute** framed choice overlay. 5s.
- [ ] **Knucklebones / High Table** tournament mid-game. 5s.

**Beat 6 — Title**
- [ ] Win-state screen "IRONWAKE STANDS" if reachable, OR clean title logo. 5s.

## Music
Pick ONE driving track from the owned catalog — something with a clear build so beat 3 (betrayal)
can hit on a swell and beat 6 lands on a resolve. Candidates to audition: the dual-pool combat
tracks, or a Banshee-bottle track if tonally right. Decide before the edit; the whole cut syncs
to it.

## CapCut Cut Sheet (workflow — decided 07-23)
Editor: **CapCut desktop** (free). Build from SCRATCH, not a template — templates bake in a
"CapCut" watermark/outro; a plain export of your own clips has NO watermark. If a default end
sticker appears, delete it.

**Order of operations (music drives everything):**
1. **New project → set canvas 1920×1080, 30fps** (match your footage fps if it's 60 → 60 is fine too).
2. **Import all ~11 min of footage + the chosen music track.**
3. **Drop the MUSIC on the timeline FIRST.** Select it → **Beats** panel → **Auto-generate beats**.
   Those beat markers are your cut points — every hard cut should land on one.
4. **Block out the 6 beats** (see structure table above) along the music. Don't fine-trim yet —
   just get the right clip in the right zone: cold open → combat → town/betrayal → pets → depth
   montage → title.
5. **Trim each clip to its best 2-4s**, snapping cut ends to beat markers. Montage (beat 5) cuts
   fastest — 0.5-1s per clip, one per beat.
6. **Transitions:** hard cuts everywhere EXCEPT one **cross-dissolve** at the pet→Awakening moment
   (beat 4). Overusing transitions reads amateur; restraint reads pro.
7. **Text overlays** (muted-autoplay hook — keep them SHORT, high-contrast, 1-1.5s each):
   - 0-5s: "A roguelite where the town remembers"
   - ~20s: "Earn their trust." → "Or lose it." (two quick beats around the betrayal)
   - ~35s: "Raise something of your own"
   - End card: title logo → "Wishlist Now · Coming Soon"
8. **Audio mix:** music is the bed. **Mute/duck the gameplay SFX** under it, but keep 2-3 diegetic
   HITS punched through for impact: the portcullis at the open, a big spell impact, and — if a
   cursed-shrine beat is in frame — the new curse laugh. Sync those hits to the picture.
9. **Export:** Resolution **1080p**, format **mp4 (H.264)**, frame rate to match, **highest bitrate
   option** (Steam wants a high-quality source; 10+ Mbps). No watermark.

**Steam upload:** Store Page Admin → Trailers tab (see reference_steamworks_nav). Steam accepts
H.264 mp4; it transcodes its own variants from your high-quality source.

## Open decisions before edit
- On-screen text: minimal verbs (above) vs none. Muted autoplay argues FOR a few text beats.
- Title logo asset: do we have a clean transparent wordmark for the end card, or pull from capsule art?
- Launch date on end card: "Coming Soon" vs "Aug 19" (only if the date is locked publicly by then).
