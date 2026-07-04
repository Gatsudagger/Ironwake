# Phase 4b — Gifts (implementation mini-spec)

**Parent design:** `NPC_Affinity_System_Design.md` §4 (gifts), `Journal_System_Design.md` §2 (taste grid, ledger).
**Status:** BUILT 2026-07-03 + UX REWORK same day (M's playtest feedback) — needs M's F5. Two v1 deviations: trinket drops are **boss-only** (event-room source deferred), trinkets have **no icons yet** (picker shows a flavor pane; CraftPix import is polish).

**UX rework (M, post-F5 of v1):**
1. **[F] Give a gift moved INSIDE each NPC's engagement window** (all 7 screens, one shared gc handler guarded against every sub-modal; footer hints added). The hub-list [F] is gone.
2. **Gift result POPUP** (`ui_draw_gift_popup`, `global.gift_popup`): reaction line + "Bond +N/−N" + live tier + progress bar; any confirm key dismisses.
3. **Tavern Requests board** — 8th hub-list row; the portrait panel becomes a posting-board image (`spr_tavern_board` when imported, drawn placeholder until then); Space opens the board screen (`tavern_board_open`, `ui_draw_tavern_board`) where requests are read/accepted/turned in (pinned-note rows, reward on the right). **The Journal is now VIEW/TRACK ONLY.** The hub-row [Q] shortcut is gone. Gate/love quests (4c) will be offered by the NPC directly in their window at tier-ready — not the board.
**Design-lock:** numbers TUNABLE.

**4b scope:** gift action + per-NPC category taste tables + 7 signature gift trinkets (rare drops) + taste discovery (Journal grid goes live) + reaction ledger entries.
**NOT in 4b:** real gate quests / demotion / decay (4c), cursed items (4d).

---

## 1. The gift action

- **[F] Give a gift** on the hub NPC row (beside [B] deepen bond / [Q] quest). Hub-only by nature.
- Opens the **existing item-sacrifice picker** (`item_picker_open`, purpose `"gift"`) filtered to giftables: unequipped gear (stash + pack), consumables, unsocketed runes, pet feed (pouch), and gift trinkets. Select → confirm ("Give X to Petra?") → resolve.
- **Flat 1 gift per run** (`global.gift_given`, reset in `end_run`). The row shows "[F] Give a gift" or "(gift given — after your next run)".
- The item is consumed. Reaction line + heart/sour flourish + affinity delta + ledger entry + taste reveal.

## 2. Reaction bands & scoring (TUNABLE)

| Band | Affinity | Reaction tone |
|---|---|---|
| Loved | **+10** | delighted, personal line |
| Liked | **+5** | warm |
| Neutral | **+1** | polite |
| Disliked | **−5** | cool |
| Hated | **−10** | offended |

- **Rarity sweetener:** gear/rune gifts add +1 per rarity tier above Common (a Loved Epic = +13). Trinkets ignore this (they carry their own value).
- Gift gains **count against the per-run soft cap** (design §3) — EXCEPT signature trinkets, which **bypass** it like quest chunks (rare, non-farmable, drop-gated).
- Negative hits have no cap (bad gifts always hurt).

## 3. Category taste tables (DRAFT — M approves)

Categories: **Weapons · Armor · Jewelry · Potions (consumables) · Runes · Pet Feed**. One Loved, one Hated, the rest Liked/Disliked/Neutral per NPC — every table asymmetric so learning matters.

| NPC | Loved | Liked | Neutral | Disliked | Hated |
|---|---|---|---|---|---|
| **Dorn** | Weapons | Armor | Runes | Potions | Pet Feed |
| **Sable** | Potions | Runes | Pet Feed | Armor | Weapons |
| **Maren** | Runes | Jewelry | Armor | Potions | Pet Feed |
| **Vex** | Armor | Weapons | Potions | Jewelry | Pet Feed |
| **Petra** | Jewelry | Weapons | Armor · Potions | Pet Feed | Runes* |
| **Vael** | Jewelry | Armor | Weapons | Runes | Pet Feed |
| **Bairc** | Pet Feed | Potions | Armor | Jewelry | Weapons |

\* Petra hates runes ("dust-clotted rocks I can't move"). Note the deliberate spread: Pet Feed is Hated by four NPCs but Bairc's Loved — the cheap gift is a trap unless it's for him.

## 4. Signature gift trinkets (DRAFT — M approves)

Seven hand-authored items, one per NPC — **rare, strong, obvious once found** ("a gift begging for its owner"). Universally Neutral (+1) if given to the wrong NPC; to their person: **+25 affinity, bypasses the soft cap.**

| Trinket | For | Flavor hook |
|---|---|---|
| Meteoric Ingot | Dorn | star-metal he's only read about |
| Sealed Grimoire Page | Sable | a recipe in a dead alchemist's hand |
| Singing Runestone | Maren | a rune that hums off-key |
| Champion's Hand-Wraps | Vex | worn by someone who never lost |
| Flawless Appraisal Lens | Petra | sees the true price of anything |
| Bolt of Duskweave | Vael | cloth that drinks the light |
| Orphaned Egg Shard | Bairc | still warm, long after it should be |

- **Drop source:** boss kills + event rooms, ~3% per boss (roughly boss-egg rarity), random trinket, duplicates allowed (a dupe is still +25 or vendor gold).
- **Icons:** from the staged CraftPix mineral/potion packs (`C:\Asset_Library`) — no PixelLab spend.
- **Extraction-gated (M ruled 2026-07-03):** trinkets found in-run ride `global.run_trinkets`; extraction/clear banks them into the owned pool (`global.gift_trinkets`), **death loses them** — same stakes as carried loot.

## 5. Discovery & the Journal taste grid

- **Learn-by-doing:** each gift permanently reveals that NPC×category band cell (`global.npc_tastes_known`), rendered in the Journal grid ("Loves: Weapons · Likes: ??? · ...").
- **Soft hints:** on reaching **Acquaintance**, the NPC's Loved category is hinted in their profile ("I suspect Dorn would appreciate a fine weapon"). On **Friend**, the Hated category is hinted. No blind trial-and-error path to disaster.
- Ledger logs every gift + reaction; badge on new reveal.

## 6. Code seams

| Concern | Seam |
|---|---|
| Taste tables + trinket catalog | `scr_stats` new block (`gift_taste(npc, category)`, `gift_trinket_catalog()`) |
| Gift action | hub Step [F] handler → `item_picker_open("gift", …)` → resolve in the picker's commit switch (model on `vex_trait`) |
| Giftable enumeration | new picker candidate builder (stash+pack gear, consumables, runes, feed pouch, trinkets) |
| 1/run flag | `global.gift_given` — reset in `end_run`, saved |
| Trinket drops | boss-drop roll beside the boss-egg roll (`pet_try_boss_egg` call site) + event-room reward table |
| Discovery + ledger + badges | `global.npc_tastes_known` (saved); reuse `ledger_add` / `journal_badge_npc` |
| Journal grid | replace the 4a "???" placeholder line in `ui_draw_journal` |
| Reaction lines | per-NPC × band one-liners, hand-authored (M can punch up) |

## 7. Open

1. M approves/edits §3 taste tables + §4 trinket set (names/flavor).
2. Trinket death rule: keep-on-death (current draft) vs extraction-gated.
3. Reaction one-liners — I draft all 35 (7 NPCs × 5 bands), M edits taste.
