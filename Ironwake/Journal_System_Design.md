# Journal System

**Status:** Final framework draft — layout/pixel specifics and art (portraits) downstream
**Build phase:** **Phase 4 (later).** The thin-affinity track (Phase 0.5) runs without the Journal; gifts, real gate quests, and the Journal UI all land together in Phase 4. See `BUILD_ORDER.md`.
**System owner:** UI / meta-progression surface
**Hosts / surfaces:** NPC Affinity system (Relationships tab), all quest content incl. affinity gate quests + Petra's cursed-recipe hunts (Quests tab)
**Depends on:** existing inventory/escape overlay *patterns* (not the menu itself), Affinity system (data), quest data layer

---

## 0. Scope & framing

The Journal is fundamentally a **display/UI system** — it *surfaces* data that other systems own (affinity, quests, Petra's recipes). It does not define mechanics; it renders and navigates them. Keep design focused on **what it shows, how it's organized, how you navigate it** — not re-litigating the systems behind it.

**In-fiction framing:** the Journal is the player character's *personal journal* — their own notes and record. This is deliberate: intimate content (relationships, romance) belongs in a personal journal, not a clinical "codex." The framing is why this is "Journal," not "Codex."

> **Live-build reconciliation (2026-06-29):** the Journal, NPC Affinity, and the Petra/Bairc content it surfaces are **all net-new** (nothing exists yet). Two **existing** reference surfaces already cover some of what the future expandable tabs (§5) imagine — coordinate, don't duplicate:
> - **Item Codex** — base-item discovery tracker with splash art + detail pane (the hub item gallery). Owns "items I've found."
> - **Compendium** — the char-menu tab #4 (Stats / Equipment / Abilities / Consumables / **Compendium**); a help/mechanics reference with sections.
> A future Journal **Bestiary / Lore / World** tab should fold into or link these rather than re-implement them. Also: Petra's "cursed-recipe" content rides on **cursed items, which are net-new and undesigned** — the only built "curse" system is the run-scoped devil's-bargain (`SYSTEMS_CURSES.md`), unrelated.

---

## 1. Structure & access

- **Independent overlay, toggled on `J`.** NOT a tab on the inventory/escape menu — its own object, own toggle, own state. This avoids tab-row crowding on either menu and keeps each focused.
- **Reuses existing overlay patterns**, not the inventory menu's tab array: full-screen translucent panel, depth handling, and the locked control scheme (W/S navigate, Q/E switch tabs, Enter select, Esc back). Consistent feel, no shared tab list.
- **Accessible everywhere** — hub and mid-dungeon.
- **Two tabs at launch:** Relationships, Quests. Q/E switches between them. Built as an **expandable slot array** so future tabs (Bestiary, Lore/World) drop in without rework.

### Action-gating (uniform rule across tabs)
The Journal is **always viewable & navigable** anywhere, but **committing actions is hub-only**:
- **Hub:** fully interactive — gift NPCs, start gate quests, all NPC interaction live.
- **Mid-dungeon:** **view/track only.** Profiles readable, tiers/progress visible, quest progress ticks live (floor-clears advance affinity/quests in real time), ledger reviewable — but action buttons (gift, start quest) are **disabled with a "hub only" affordance** (shown-but-greyed, not hidden, so the player knows the action exists).

---

## 2. Relationships tab

**Layout: master-detail** — NPC list on the left, full profile pane on the right. (Matches the established escape-menu layout language.)

### NPC list (left)
- **Only NPCs the player has met appear.** The list grows over time as a record of the player's journey — no locked "???" stranger entries.
- Each row: portrait thumbnail, name, current tier (and an update badge — see §4).

### Profile pane (right) — dense single view, no scrolling
Everything visible at once:
- **Portrait** (full display), **name**, **current tier**.
- **Progress bar toward the next gate.** Shows the *tier* and *progress*, **never the raw numeric score** (diegetic — "getting closer to Maren," not "47/120").
- **Lore blurb** — character flavor/background.
- **Gift-taste grid** — **only revealed tastes shown**; undiscovered tastes are **"???" slots**. This shows *how many* tastes exist to find (e.g. "2 of 5 loved discovered") without spoiling them, turning gifting into visible collection progress. (5-band: Loved / Liked / Neutral / Disliked / Hated — see Affinity doc §4.)
- **Interaction ledger** — **grouped** into: Gifts given / Quests done / Milestones. Reads like journal sections, not a flat log.
- **Pinned active quest** with this NPC, if any.

---

## 3. Quests tab

The game's **general quest log** — not just relationship gates. Hosts: affinity **gate quests**, Petra's **cursed-recipe hunts**, and any other current/future Ironwake quest content.

**Layout: categorized list (left) + detail pane (right)** — master-detail, consistent with Relationships.

### List (left) — grouped by STATUS
- **Active / Available / Completed.** Status-first answers "what can I do now?" before anything else.

### Detail pane (right)
- **Objective** + **progress**.
- **Reward** + **which NPC/tier it unlocks** (for gate quests).
- **Lore/flavor description.**
- **Turn-in hint** (e.g. "return to Petra at the hub").

### Action-gating in Quests
Consistent with §1: gate quests can only be **started at the hub**. Mid-dungeon, **Available** quests show visible-but-not-startable (same "hub only" affordance). **Active** quests still **track progress live** mid-run (floor-clears tick). Keeps the gating rule uniform with gifting.

---

## 4. Notifications

Subtle, non-intrusive update signals (no blocking popups):
- A **badge/notification** when affinity changes, a gift taste is newly learned, or quest progress updates.
- Surfaced as a badge on the relevant NPC row / quest entry (and optionally the `J` icon), so a player who isn't currently in the Journal knows something changed when a floor-clear ticks progress.
- Keep it clean — a badge, not a barrage.

---

## 5. Open / downstream

1. **Pixel layout & sizing** — concrete panel dimensions, list/detail split ratios, against the existing overlay's GUI dimensions.
2. **Portrait art** — every met NPC needs a portrait (PixelLab pass). Profile pane assumes a full portrait display.
3. **Data hooks** — the Journal reads affinity state (tier, progress, revealed tastes, ledger) and quest state from those systems; those systems own the data. Define the read interfaces when implementing.
4. **Expandable tabs** — Bestiary / Lore / World are future slots in the same tab array; not designed yet.
5. **Badge/notification persistence** — when a badge clears (on view? on hub return?) — minor UX ruling for implementation.

---

## 6. Dependencies & cross-refs

- **Affinity system** — Relationships tab is its primary UI surface (profiles, tiers, taste hints, ledger). The Affinity doc references the Journal as a hard dependency; this is the other side of that link.
- **Petra (Treasure Trader)** — her cursed-recipe hunts surface in the Quests tab; her recipe-ledger hints render here too.
- **Existing menus** — inherits overlay/control patterns from the established inventory/escape overlay and Dungeon Gate tabbed screens, but is a *separate* object toggled on `J`.
