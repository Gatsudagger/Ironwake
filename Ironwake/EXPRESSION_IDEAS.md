# Player Expression Proposals — 2026-07-03

**Ask (M):** ideas that synergize with EXISTING systems and add player expression — combat, side minigames, customization. Ranked by synergy-per-effort; each names the systems it rides on. Nothing here is committed scope.

---

## 1. Knucklebones at the tavern (side minigame) — RIDES: Tavern board, affinity, gold economy
The tavern now exists as a place. Add a **dice-and-daggers gambling game** playable there against a rotating NPC opponent (the 6 hub NPCs off-shift — each with a visible play personality: Dorn plays safe, Sable cheats charmingly, Vex never bluffs).
- Small gold stakes; winning against an NPC gives their affinity drip (+2, capped like function-use); a weekly "high table" with a trinket/rune prize.
- Cult-classic precedent: The Witcher's Gwent, Lance's Knucklebones (Cult of the Lamb) — side games are disproportionately loved.
- **Effort:** medium (one screen, simple rules, AI personalities are just risk thresholds). **Expression:** play style + who you choose to sit with.

## 2. Ability Mastery notches — RIDES: per-slot save, loadout screen, Compendium
Track per-ability lifetime casts. At 25 / 75 casts an ability earns a **mastery notch** and the player picks ONE of two micro-mods (permanent, per slot):
- e.g. Snipe: "+5 accuracy" OR "+4 crit"; Iron Skin: "+1 turn" OR "+1 reduction"; Bear Trap: "root +1 turn" OR "+4 damage".
- This is the classic "your Snipe isn't my Snipe" expression lever, and it makes *using* an off-meta ability its own investment (helps dead-pick viability from the audit).
- **Effort:** medium (data + one pick modal + loadout badge). **Expression:** very high — every player's kit drifts unique.

## 3. Combat stances for the active pet — RIDES: the whole pet system
A Warrior/Guardian pet gets a **stance** set at the Gate (or once per combat, 0 AP): Aggressive / Guarded / Assist.
- Warrior: Aggressive = current behavior; Guarded = -50% pet damage, +guard chance on you; Assist = pet strikes YOUR target with a small Exposed rider.
- Guardian: prioritize heal / prioritize shield / cleanse-first.
- Makes the companion an expression of your build, not just a stat block; reuses the existing pet-turn hooks.
- **Effort:** low-medium. **Expression:** high for pet-invested players.

## 4. School-tinted ability VFX — RIDES: element schools, Vael, the VFX pass
Vael sells **spell tints**: your ability VFX and combat-log school words recolor to a purchased palette (ember-orange fire, ghost-green fire, void-black shock...). Pure cosmetics, `school_color()` is already a single function — a purchased palette just overrides its returns.
- **Effort:** low. **Expression:** cosmetic identity; gives Vael's shop late-game gold sinks.

## 5. Epithets (earned titles) — RIDES: run history, milestones, char screen
One equippable **title** shown on the character screen, run-history rows, and (later) the death/victory screen: "the Soul-bound" (Bond 18 pet), "Flamewalker" (A5 Scorched clear), "Petra's Favorite" (Lover), "Deathless" (10 clears without dying).
- **Effort:** low (a milestone table + one picker row). **Expression:** bragging rights; retroactively rewards everything the game already tracks.

## 6. Borrowed Memories (run-scoped ability slot) — RIDES: events/shrines, loadout, past-lives lore
From the audit: shrine/event outcomes can grant a **temporary 6th ability for this run only**, drawn from OTHER classes' pools ("a memory that isn't yours"). Cross-class dabbling without breaking class identity; run-to-run variance the loadout system currently lacks.
- **Effort:** low-medium (loadout already resolves by name; add a run-scoped extra slot). **Expression + variance:** high.

## Recommended order
4 (tints) and 5 (epithets) are cheap charm wins alongside the flavor pass · 6 (borrowed memories) lands with the §6 rework batch · 3 (pet stances) when pets get their next content pass · 2 (mastery) as its own mini-phase · 1 (Knucklebones) as the tavern's second act once 4c ships.
