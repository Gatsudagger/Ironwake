# THE IRON VOW — hardcore profile modes

M design-locked 2026-07-28 (all four decisions = recommended options). FOR LAUNCH.
Standard Ironwake is unchanged and remains the default; the Vow is opt-in at
character creation. Old saves load as Standard automatically (field-tolerant).

## Modes
`global.vow_mode`: 0 = Standard (default) · 1 = **THE IRON VOW** (3 lives) ·
2 = **THE UNBROKEN VOW** (1 life). `global.vow_lives_left` = lives remaining.
Named "Vow", never "Hardcore" — Hardcore/Merciless are the DESCENT severities
(SYSTEMS_ENDLESS.md §3) and must not collide.

## Rules (locked)
1. **Flat lives, ever.** Every run DEFEAT (result -1) consumes a life — clears
   and extractions never do. Third death (or first, Unbroken) ends the character.
2. **Final death = the save file and resume checkpoint are deleted** at the
   defeat-settlement frame (same choke point as the IRONMAN clawback —
   SYSTEMS_RUN_RESUME.md §3 — so alt-F4 on the death screen cannot dodge it).
   The life decrement is written by the settlement save_game() the same frame.
3. **Memorial record** (`ironwake_memorial_<slot>.json`): written at final
   death — name, class, epithet, best floor, run count, clears, mode, date.
   The title slot card draws it as a gravestone. Not loadable. A New Game
   claiming the slot deletes it (same site that deletes stale checkpoints).
4. **Cosmetic prestige only** — no balance changes. A Vow character that
   reaches IRONWAKE STANDS is auto-granted an exclusive epithet: mode 1
   "the Thrice-Tempered", mode 2 "the Unbroken" (set at the win in end_run;
   changeable at Vael afterward like any epithet). Slot cards show a Vow badge
   + lives. Achievement hook noted for the achievements pass.

## Creation flow
class/stats → name → portrait → **VOW step (new)** → save_game → hub.
Three cards: STANDARD (default-selected) / THE IRON VOW / THE UNBROKEN VOW.
Picking a Vow opens a bordered CONFIRM/CANCEL popup (checkout standing rule)
with the full consequence text; Standard proceeds with no popup. Full input
parity: A/D + Enter, Esc back to portrait, cards tappable (hit-test in Draw).

## Death handling (obj_combat_controller Step defeat settlement)
Order inside the settle frame: `run_checkpoint_delete()` → `end_run(-1)` →
vow decrement → if lives > 0: `save_game()` (defeat screen adds "The Vow
holds — N breath(s) remain") → hub as normal. If lives hit 0: write memorial,
delete save file + checkpoint, `vow_fallen = true` → defeat screen shows the
fall ("THE VOW IS BROKEN" / "THE VOW WAS ABSOLUTE") → keypress goes to TITLE
(run_state_reset + audio_stop_all), never the hub.

## Surfaces (reference sync)
Title slot cards (badge "THE IRON VOW · 2 LIVES" / gravestone for memorials;
memorial slots excluded from the any-save Load gate), creation screen, defeat
screen copy, compendium "The Iron Vow" entry (Progression). Save fields
vow_mode / vow_lives_left in save_game + load_game + get_slot_preview +
new_game_reset — no SAVE_FORMAT_VERSION bump needed.
