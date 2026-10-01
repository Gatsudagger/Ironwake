# Achievements — post-launch additions (parked)

Steam allows adding achievements after release; shipped API names are permanent,
so anything here is safe to add later. Nothing below is built or wired.

## HARDCORE set (M asked 08-05, "we also need some hardcore achievements")

Ironwake already has two distinct hardcore axes, so the set should cover both
rather than blurring them:
- **The Iron Vow** (character creation, permanent): THE IRON VOW = 3 lives,
  THE UNBROKEN VOW = 1 life; a spent save leaves a gravestone.
- **Descent hardcore severity**: death can claim worn gear.

Proposed (names/conditions first-pass, all need M's lock):

| Suggested API | Display | Condition | Notes |
|---|---|---|---|
| ACH_VOW_UNBROKEN | The Unbroken | Win under THE UNBROKEN VOW (one life) | The hardest thing in the game today; ACH_IRON_VOW already covers any Vow win |
| ACH_VOW_A5 | Sworn and Ascended | Win a Vow run at Awakening 5 | Stacks the two difficulty axes |
| ACH_VOW_NO_TOWN | Alone in the Dark | Win a Vow run without buying anything from a keeper | Needs a new run-scoped "spent gold at an NPC" flag |
| ACH_DESCENT_HC_25 | Nothing to Lose | Descent floor 25 on hardcore severity | Reads severity at the depth check |
| ACH_LAST_LIFE | Down to the Last | Win a run with one Vow life remaining | vow_lives_left == 1 at the win site |
| ACH_MEGA_CURSE_VOW | Everything at Once | Win under a Vow carrying a tier-3 curse | Combines the two opt-in risk systems |
| ACH_NO_POTIONS | Dry Run | Full clear without drinking a single potion | Needs a run-scoped consumable-used counter (combat_state.used_consumable exists per fight, not per run) |
| ACH_DEATHLESS_VOW | Thrice-Tempered | Survive all three Iron Vow lives to a win | The epithet already exists for this shape |

**Wiring cost:** most read state that already exists at the end_run win site
(vow_mode, vow_lives_left, run_curses, selected_ascendance, descent severity).
Two need small new run-scoped flags (keeper spend, potions drunk).

## Other parked ideas
- A "no gear equipped" clear (Naked Run) — needs an equip-count check at the win.
- Pet-focused hardcore: win a Vow run with the same companion alive start to end.
- Speed: full clear under N rounds total (round counters already accumulate).

See ACHIEVEMENTS_SPEC.md for the shipped 67 and their wiring.
