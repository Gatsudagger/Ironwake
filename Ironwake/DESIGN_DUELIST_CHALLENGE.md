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
