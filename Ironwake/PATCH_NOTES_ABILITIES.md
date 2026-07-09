# Ability & Trait Changes — Patch Notes (2026-07-03)

Plain-language summary of everything from the ability audit, approved by M. Full analysis lives in `ABILITY_AUDIT.md`; specs in `INTENT_SPEC.md` / `EXPRESSION_IDEAS.md`.

---

## FIXED — things that were broken

| What | Was | Now |
|---|---|---|
| **Arcane Surge** (trait) | Buffed abilities costing 4+ AP — nothing costs that. It literally never worked. | 3-AP abilities deal +25% damage. |
| **Crimson Reserve** (trait) | "+20 Blood" vs a 10-point bar (a mislabeled full bar). | Start each combat with 4 Blood. |
| **Soulbind** (Arcanist) | **Did nothing.** No combat code existed. | See "reworked" below — fully built. |
| **Undying** (Bloodwarden) | **Did nothing.** No combat code existed. | See "reworked" below — fully built. |
| **Evasive Roll** (Shadowstrider) | **Did nothing.** No combat code existed. | See "reworked" below — fully built. |
| ~9 stale tooltips | Numbers from before the §3 buffs (Arcane Burst "28", etc.). | All match live data. Bonebreaker's DATA was the wrong one — raised 14 → 18. |
| Petra's shop | "v more wares below" on every visit + clicking feed rows misselected (hit-test bug). | Compact rows fit her whole standard stock on one page; clicks land correctly. |

## REWORKED — dead picks given real identities

| Ability | New identity |
|---|---|
| **Soulbind** (2 AP + 1 Soul) | **Lifelink.** The bound enemy takes 40% of every hit you receive, and that stolen vitality heals YOU for the same. Combat-long. |
| **Undying** (3 AP + 3 Blood) | Survive the next lethal blow → **surge back to 25% max HP and gain 3 Blood.** Fires before the Last Stand trait. |
| **Evasive Roll** (0 AP + 2 Prep) | Halve the next hit above 10 damage; **a clean absorb refunds 1 Preparation.** |
| **Strike** (general, 1 AP) | **Momentum:** if Strike kills the target, its AP is refunded. |
| **Second Wind** (general, 2 AP) | Now ALSO cleanses your newest debuff — the game's only self-cleanse. |
| **Spike Trap** (Shadowstrider) | Cost cut 3 AP + 2 Prep → **2 AP + 1 Prep.** The bleed trap; Death Snare stays the stun trap. |
| **Arcane Echo** (Arcanist) | No mechanics change — it secretly ALWAYS splashed 50% of its damage to every other enemy and the tooltip never said so. Tooltip now discloses its mini-AoE identity. |

## ROUND 3 (2026-07-04) — Hexed + trait fixes

| What | Was | Now |
|---|---|---|
| **Curse** (Arcanist, 2 AP) | +4 damage taken — a worse Scorch. | **Hexed** (3 turns): still +4 damage taken per hit, but detonation reactions on the target are **DOUBLED** (Exposed +24, burn +80% crit, root/frost +60% dmg, weaken +30%, bleed +10/tick, void 60% lifesteal, shock arc 66%, Mortality −80% healing) and **each detonation spreads +2 damage-taken (2 turns) to every other enemy** (refreshes, never stacks). New HEX badge, log lines, hit-preview shows "HEXED x2!", Compendium glossary entry. |
| **Lucky Find** (trait) | +5% consumable drop when packs cap at 10 — ~1 extra potion per run. | **20% chance a used consumable is not consumed.** Works in combat and from the character menu. |
| **Shadow Meld** (Shadowstrider trait) | +15 dodge after dodging — fights the dodge diminishing-returns curve. | **After you dodge, your next damaging attack is a guaranteed crit.** Dodge feeds offense now. |
| **Treasure Hunter** (trait) | Guaranteed the room's single 40% item roll. (Verified NOT a no-op — rooms are empty 60% of the time without it.) | **Treasure rooms give one additional guaranteed item** — 1 always, 2 when the normal roll also hits. Popup shows the bonus line. |
| **Maren "Proof of Craft" quest** | Socketing runes never counted — stuck at 0/2. | Both gear and Aspect socketing tick the quest. (Progress isn't retroactive — socket again to count.) |

### Test list (F5)
- **Arcanist:** Curse an enemy carrying burn/frost/Exposed, hit it with Arcane Burst → "Hexed! The reaction is doubled!" + doubled bonus, and other enemies gain "Hex Spread" (+2 dmg-taken, HEX badge on the cursed one, VUL on the others).
- **Any class w/ Lucky Find:** chug potions — roughly 1 in 5 should log "Lucky Find - X is not consumed!" and stay in the pack.
- **Shadowstrider w/ Shadow Meld:** dodge an enemy attack → "guaranteed CRIT" log, next attack crits (yellow popup).
- **Any class w/ Treasure Hunter:** open a treasure room → always at least one item, sometimes two (second shown as "+ Name [Rarity]" line).
- **Maren:** take Proof of Craft, socket 2 runes (unsocket/resocket counts) → 2/2 + tavern-board notice.

## ROUND 4 (2026-07-04) — Enemy Intent system (`INTENT_SPEC.md`)

Every enemy now telegraphs its NEXT action on a chip above its health bar, and the telegraph is **binding** — the enemy does what the chip says:

- **Red "ATK ~12-16"** — basic attack with the approximate damage you'd actually take (post-armor). Telegraph-spike attacks show the big number. "x2" = double-strike foes.
- **Purple "CAST ~12"** — a damaging spell.
- **Green "MEND"** — it will heal itself.
- **Amber effect word** ("STUN", "SILENCE", "WOUND"...) — a control/debuff move.
- **Control payoff:** Stun anything, Root a melee foe, or Silence a caster and its chip **greys out with a strike-through** — that move is cancelled. The foe keeps the same intent for its next turn, so the grey-out reads as "you bought a turn."
- If an enemy's action is spent on a whiff (Blink/Vanish/Shadow Step/Phantom Step), it re-rolls and the new chip **pulses** so the change is visible.
- One-time "Enemy Intent" coach-mark joins the combat tip cascade.

### Test list (F5)
- Enter any combat → every living enemy has a chip above its HP bar from turn one.
- Watch an "ATK ~N-M" enemy attack → the damage you take lands inside (or near) the band.
- Watch a "MEND"/amber chip enemy → it does exactly what it telegraphed.
- Stun/root/silence a foe whose chip applies → chip greys + strike-through, enemy skips, chip un-greys next turn.
- Dodge via Blink/Vanish → that enemy's chip pulses with a fresh intent.
- Click enemy HP bars still selects targets (bar rows moved 30px apart for the chips).

## QUEUED — approved, not yet built

1. ~~Enemy intent system~~ **BUILT (round 4, above).**
2. **Flavor pass** — one lore line per ability (past-lives voice), cast barks for ultimates, a keyword glossary (Sear / Exposed / Mark / Bleed...) in the Compendium.
3. **Expression picks** (`EXPRESSION_IDEAS.md`, in recommended order): school-tinted spell VFX sold by Vael → earned titles/epithets → borrowed-memory run abilities from shrines → pet combat stances → per-ability mastery notches → Knucklebones dice game at the tavern.

## HOW TO TEST THIS ROUND (F5)

- **Bloodwarden:** cast Undying, eat a killing blow → "UNDYING!" surge to 25% HP +3 Blood.
- **Arcanist:** cast Soulbind on an enemy, take hits → reflect + self-heal log lines.
- **Shadowstrider:** cast Evasive Roll, take a heavy hit → halved +1 Prep.
- **Any class:** kill a weak enemy with Strike → "Momentum!" AP refund; Second Wind while poisoned → cleanse line.
- **Petra:** full stock visible, no scroll hint, feed rows clickable.

## #26 ARCANIST MELEE KIT (2026-07-08) — NEW, M-approved design

Three melee SPELLS so a close-range Arcanist build exists. They ride the MELEE
weapon's flat damage (not the wand's), and root/silence rules treat them as melee.
All Vex-purchasable in a new premium tier above the 100/250/400 ladder, offense
category (they feed the same-category AP discount).

| Ability | Cost | What it does |
|---|---|---|
| **Blazing Palm** (Vex 500g) | 1 AP | 12 Fire melee spell. Banks **+1 Soul** on a landed hit. The close-range Soulfire. |
| **Gravewrack Grip** (Vex 800g) | 2 AP | 16 Void melee drain — **always hits, ignores armor**, and **Roots 1 turn** (melee enemies skip; detonators shatter the root for +30%). |
| **Soul Rend** (Vex 1200g) | 3 AP | 30 Arcane melee finisher. **Consumes up to 2 Souls for +8 damage each.** |

**F5 checks:** buy all three at Vex (new 500/800/1200 prices; CHA/Friend discounts
apply) → slot them → in combat: Blazing Palm logs "+1 Soul."; Gravewrack Grip never
misses, the enemy shows Rooted and a melee enemy skips its turn; Soul Rend with 2+
Souls logs "consumes 2 Souls (+16 dmg)" and the hit preview includes the bonus;
while Rooted, a detonator (e.g. Arcane Burst) on that target logs the shatter (+30%).
