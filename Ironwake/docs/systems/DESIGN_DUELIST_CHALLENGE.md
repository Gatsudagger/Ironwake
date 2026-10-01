# DESIGN — The Duelist (challenge event) (draft for M review, 2026-07-29)

**Status: BUILT 07-29 (same session, M's order), awaiting F5. Build notes: the
1-turn self-haste was dropped from his kit (no clean enemy-haste primitive); the
execute swing = +50% below 25% player HP; riposte stance = a flat 12 answer to
every melee blow he survives; Duelist Arts unlocks land AUTOMATICALLY at token
grant (combat log announces), Vex's DUELIST ARTS strip is the ladder readout;
The Ashen Blade goes straight to the STASH (death can't take it) and REMAPS the
Ashkeeper Blade art + Measured Riposte remaps the Counterblade icon until M
approves bespoke gens.**

## Origin
M (07-29): the original GDD had a rare awakening-scaled NPC fight — a duelist who
challenges you, and beating them within a turn limit graded the reward quality; gating
special skills/items behind it as hidden progression. No record survives in the current
docs beyond the "Duelist" boon name, so this is a fresh design from that memory.

## Concept
A rare event room: **"A figure waits in the empty hall, blade drawn."** A named duelist
(THE ASHEN DUELIST — same character every time; recurring rival tone) offers an
honorable duel. Accept or walk away (walking away is always safe — it's a flex room).

## §1 Placement & rarity
- Event-room pool entry, weight ~8% of event rolls, never on floor 1 of a run,
  at most ONE duel per run.
- Uses the existing event-room plumbing (`SYSTEMS_EVENTS.md` choice room opens into a
  normal combat with a special enemy + a post-combat resolver).

## §2 The duel
- 1v1 combat vs the Duelist — STRICT (M-locked): the active companion sits out.
  Humanoid elite frame, melee/phys, high dodge, uses the PLAYER-facing kit
  (Riposte stance = Counterblade's 12, an execute swing below 25%, a 1-turn
  self-haste). Base stats scale with Awakening like elites, +10%.
- **HE GROWS (M-locked 07-29): +10% stats per PREVIOUS encounter (lifetime,
  meta-persistent counter, uncapped).** A rival who keeps pace with you forever.
- **TURN PAR** shown on the intent chip area from round 1: "PAR: 6 TURNS".
  Par by awakening: A0-A1: 7, A2-A3: 6, A4-A5: 5. (M-locked as specced.)
- **Losing (M-locked 07-29): he is a friend, not a foe.** His killing blow stops
  at 1 HP, the duel ends, and HE HEALS YOU back to the HP you entered the room
  with. No reward, no other penalty. **NEVER a death: no gravestone, no Iron Vow
  life consumed, the run continues** — the duel can never ruin a hardcore file.

## §3 Graded rewards
| Result | Reward |
|---|---|
| Win ≤ par | **GOLD**: a Duelist Token + rare+ item (rarity rolls at elite weights +1 tier) |
| Win ≤ par+2 | **SILVER**: rare-weighted item + 25 dust |
| Win, slower | **BRONZE**: 15 dust + gold purse |

## §4 Hidden progression — Duelist Tokens
- Tokens are meta-persistent (saved like forge components). Vex gains a hidden
  trainer row that only APPEARS once you hold a token: **"Duelist Arts"**.
- 1st token: unlocks ability **Measured Riposte** (defense; 1 AP: until next turn,
  the first melee blow against you is answered at 150% of Counterblade's riposte).
- 2nd token: trait **Duelist's Poise** (start each 1v1 combat with +1 AP).
- 3rd token: item **The Ashen Blade** (legendary; the Duelist's own sword — after you
  dodge or riposte, your next ability costs 1 less AP).
- **He NEVER retires (M-locked 07-29):** after the 3-token arc, he keeps appearing —
  stronger every time (+10%/encounter) — and gold-tier wins keep paying the loot tier
  (elite-weights+1 item + 25 dust), just no further tokens. The rival outlives the arc.
- Room stays a hidden event roll (no map icon) — every meeting is a surprise.

## §5 Copy hooks (tone)
- Challenge: "Blades only. No pets, no gods, no debts. Beat me before the sixth bell."
- Loss (his mercy, 1 HP → healed): "Keep the arm. Come back when it's faster." *(he
  binds your wounds himself — the healing IS the characterization)*
- Gold win: "...So the stories were short by half. Take it. It was never mine to keep."
- A late rematch (5+ encounters): "You again. Good. I've been practicing."

## §6 Walkthrough decisions (M, 07-29 — ALL LOCKED)
Strict 1v1 (companion out); pars + reward tiers as specced; token ladder locked
(Measured Riposte → Duelist's Poise → The Ashen Blade); never retires, +10% per
encounter forever; loss = 1-HP mercy + full restore to room-entry HP, NEVER a
death (hardcore-safe); hidden event roll, no map icon.

---

## ART SPEC — The Ashen Duelist (added 08-08). NOT GENERATED. Needs M's yes.

**Bug found 08-08:** he had no sprite at all. He is cloned from an elite and then
RENAMED, and `enemy_sprite_map()` is keyed by NAME — so the lookup missed and the
duel was fought against an empty space. Patched to `spr_vault_sentinel` as a
stopgap so he is never blank; that is placeholder, not the intent.

### Concept
A lithe fencer, not an armoured elite. Rapier or sabre, light guard, weight on the
back foot — silhouette should read as SPEED where every other Ashen Vault enemy
reads as MASS. That contrast is the whole point: he is the one fight that is about
precision rather than attrition.

### Progressive tiers — the ledger already exists
`global.duelist_encounters` never resets and he gains +10% per prior duel forever.
So he should visibly accumulate the wins. `duelist_sprite_for()` is already written
and resolves highest-tier-first, falling back to the map entry, so **art can be
dropped in one tier at a time with no further code changes**.

| Tier | Asset | Fought | Read |
|---|---|---|---|
| 0 | `spr_ashen_duelist`    | first duel | Clean, unmarked. A challenger. |
| 1 | `spr_ashen_duelist_t1` | 2–4 prior  | Scarred, cloak notched, blade nicked. |
| 2 | `spr_ashen_duelist_t2` | 5–8 prior  | Trophies taken from you: your colours on his guard. |
| 3 | `spr_ashen_duelist_t3` | 9+ prior   | Ash-wreathed, barely a man any more. |

### Pipeline (house rules)
- Style-verify against the SHIPPED humanoid enemies (`spr_vault_sentinel`,
  `spr_skeleton_soldier`) for palette and scale BEFORE generating — the duel is in
  the Ashen Vault and he must belong to that family.
- Same canvas/pipeline as the other enemy sprites; do not invent a size.
- Show M the base image and get approval before animating or importing.

### Budget
Tier 0 alone (the shippable minimum, kills the placeholder): **~15–25 gens**.
All four tiers: **~60–100 gens**. Recommend tier 0 first, then judge.

---

## ART STATUS — 2026-08-09

**Tier 0 is LIVE.** `spr_ashen_duelist`, 97×97 single frame, matching the 07-14
boss batch exactly (same canvas, same pipeline: PixelLab
`create_1_direction_object` styled from `spr_infernal_revenant`).
M picked candidate [3] of 4 — a lithe hatted fencer, teal-grey coat, crimson
sash, slim rapier extended. Imported by `tools/import_trap_icons_0809.py`.

The `spr_vault_sentinel` stopgap is **retired** — `enemy_sprite_map()` now names
the real sprite, and `obj_combat_controller/Draw_64.gml` overrides that one map
entry once with `duelist_sprite_for(global.duelist_encounters)` right after
`enemy_sprite_map()` is read. That single override covers all three lookup sites
(inspect hit-box, death-linger ghost, standing draw) — they all read `_espr_map`,
so they stay in lockstep for free instead of drifting apart.

**Tiers 1–3 (`spr_ashen_duelist_t1/t2/t3`) are still unauthored.**
`duelist_sprite_for()` already walks down from the player's tier and lands on the
tier-0 base, so the feature is correct today and each tier can be dropped in
later with no code change. When they are authored, each one **does** need a
`global.__sprite_includes` entry — they resolve by `asset_get_index` string, and
only the tier-0 base is protected from stripping by being named directly in
`enemy_sprite_map()`.
