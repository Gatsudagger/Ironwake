# Ironwake — Google Play Store Listing Kit

Paste-ready copy + specs for the Play Console listing. Adapted 2026-07-17 from
STEAM_PAGE_KIT.md so messaging stays consistent across stores. Companion docs:
PRIVACY_POLICY.md (host it, link it), CREDITS.md (license audit of record).

Developer (public): **Seahorse Games**  ·  Package: **com.seahorsegames.ironwake**

---

## 1. Store listing — text fields

| Play field | Limit | Value |
|---|---|---|
| App name | 30 chars | **Ironwake** |
| Short description | 80 chars | see §2 |
| Full description | 4000 chars | see §3 |
| Category | — | **Role Playing** (Play's closest to the Steam RPG/Strategy pairing) |
| Tags | pick from Play's list | Roguelike, Turn-Based, Dungeon Crawler, RPG, Singleplayer |
| Contains ads | — | **No** |
| In-app purchases | — | **No** (currently — the dice games wager in-game gold only, not real money; revisit only if the 99c revive-pack IAP is ever built) |

---

## 2. Short description (80-char limit)

**Recommended (66 chars):**
> A gothic turn-based roguelite where the town remembers what you do.

Alternates:
> Gothic turn-based roguelite. Bond with the town. Raise a companion.  (66)
> Gothic roguelite: raise a companion, bond or betray a town that remembers.  (74)

---

## 3. Full description (4000-char limit — this is ~1,850)

> The lanterns of Ironwake never go out — someone has to keep watch over the gate.
>
> A turn-based roguelite dungeon crawler about the runs you take and the town you come
> home to. Every descent makes you stronger. Every return deepens — or damages — the
> bonds with the people who wait at the gate.
>
> THE TOWN REMEMBERS
> Ironwake's keepers are not vending machines. Train with them, drink with them, bring
> them gifts, take on their personal quests — and they open up: new services, secret
> stock, their own stories. Neglect them and they cool. Betray one and they remember it,
> and the town hears about it too.
>
> A COMPANION AT YOUR SIDE
> Hatch a creature from one of many strange eggs. Feed it, tend it, fight beside it. Your
> companion grows through real stages — and if you raise it well, it crosses into its
> Awakened form, wings and all. Raise it badly and corruption takes root instead.
>
> COMBAT WITH TEETH
> A tight 3-action-point economy where sequencing is everything: set enemies up Exposed,
> detonate stacked statuses, and read every enemy's telegraphed intent before you commit.
> Three classes, eight schools of elemental magic, and weapon roles that genuinely change
> how a turn plays.
>
> A DUNGEON THAT NEVER REPEATS
> Procedurally-built floors with branching paths: shrines that sell run-warping boons,
> curse altars that pay you to suffer, stat-gated event rooms, treasure vaults, and a
> tavern board of ever-changing requests from the townsfolk.
>
> LOOT WORTH READING
> Affix-rolled gear, socketable runes, hand-authored legendaries with painted lore art,
> and an item codex that fills in the history of everything you've found. Between runs:
> reforge, fuse potions at the cauldron, and gamble it all at the High Table dice
> tournament.
>
> THE LONG GAME
> Permanent character progression, an endless Awakening difficulty ladder that rescales
> the loot with you, unlockable skins and portraits, and a bond web that takes many runs —
> and a few hard choices — to fully open.
>
> Designed for touch: turn-based combat means no twitch reflexes — every action is a
> considered tap.

---

## 4. Graphics assets (Play required sizes)

| Asset | Size | Source |
|---|---|---|
| App icon | 512×512 PNG (32-bit) | reuse the lantern icon in tools/steam/art (already 512) |
| Feature graphic | 1024×500 PNG/JPG | crop from the MidJourney key-art vista (no text overlap; logo optional) |
| Phone screenshots | 2–8, 16:9 or 9:16, min 1080px on a side | the Steam 1920×1080 set works as landscape phone shots (reuse tools/steam _archive crops) |
| (optional) 7-inch / 10-inch tablet shots | — | skip for launch; phone shots suffice |

Shot list = same beats as Steam KIT §8 (combat, hub bond screen, Awakened companion,
loot/loadout, shrine/event, knucklebones, title). Capture in the touch build so the
chip bar / no-keyboard-legend UI shows.

---

## 5. Content rating (IARC questionnaire)

- **Violence:** stylized fantasy violence vs monsters (pixel art, brief effects; no gore,
  no violence against realistic humans).
- **Gambling / simulated gambling:** in-game dice mini-games (Knucklebones, High Table)
  wager **in-game gold only** — no real money, no loot boxes, no purchasable currency.
  Answer the "simulated gambling" question consistently with the Steam survey (opt-in
  simulated gambling with no real-world value). Expected rating: Teen-ish.
- Expected outcome: a mid rating; no blocking content.

---

## 6. Data safety form + AI disclosure

**Data safety (Play requires this even collecting nothing):**
- Data collected: **None.** The game stores saves in the app's local sandbox only.
- Data shared: **None.**
- No account, no analytics, no ads SDK, no network calls.
- Privacy policy URL: **required** — host PRIVACY_POLICY.md somewhere (itch page works)
  and paste the URL.

**AI-generated content:** Play's listing flow asks about AI content. Answer consistently
with the LIVE disclosure v2 (single source: CREDITS.md "AI Content Disclosure (v2)"):
> Ironwake contains pre-generated AI content. Some 2D art assets (character sprites,
> portraits, item illustrations, backgrounds, and icon sets) were created using AI
> image-generation tools (PixelLab and MidJourney, plus licensed third-party icon packs
> produced with Stable Diffusion). Some sound effects, ambient audio, and music tracks were
> created using AI audio-generation tools (ElevenLabs). All AI-generated assets were
> reviewed, curated, and edited by the developer. The game does not generate any content
> with AI at runtime, and no live AI models are accessed by the game.

(ElevenLabs covers audio AND the 3 Banshee music tracks. Suno is NOT named — no Suno
track has shipped; add "and Suno" only once one imports.)

---

## 7. Credits / license (do NOT skip — same terms as Steam)

- Music by **Alex Coldfire** — CC BY-ND 4.0 requires his credit in-game AND in the
  listing/author section.
- Music by **Sara Garrard**.
- The in-game CREDITS screen (title menu) already carries the full list.

---

## 8. Pricing

- Premium (paid), no ads, no IAP. Mobile prices independently of Steam — likely
  **$6.99–7.99** (decided at port time; STEAM_PAGE_KIT §7). Paid pricing requires the
  **merchant/payments profile** set up before a PRODUCTION release (not needed for
  internal/closed testing, which distribute free to testers).

---

## 9. Order of operations (test → production)

1. ID verification cleared + a clean S25 playthrough.
2. GameMaker: package = com.seahorsegames.ironwake, release keystore (BACK UP), build AAB.
3. **Internal testing** upload — proves the signing/AAB pipeline; installs to your device
   from the store. (No production-gate credit.)
4. **Closed testing** — recruit 12+ testers, get them opted in → starts the **14-day
   clock** required for production access. Can run alongside the Steam launch.
5. Fill this listing (§1-§7) + graphics (§4) + data safety + privacy URL.
6. Merchant profile + set price (before production only).
7. Apply for production access after 14 continuous days with 12+ testers.
