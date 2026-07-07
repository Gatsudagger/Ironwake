# Ironwake — Input Abstraction Layer (gamepad → Steam Deck → Android touch)

Drafted 2026-07-07 while M's Steamworks tax verification pends. This layer is BOTH the last
pre-Steam engineering item (gamepad) and the first mile of the Android port (touch): one
action vocabulary, three device backends. Work happens on a branch, mechanically, with M's
Windows F5 as the regression gate per chunk.

## Census (2026-07-07)
- ~350 raw `keyboard_check*` sites, 157 mouse sites, 116 already behind `nav_*()` wrappers.
- Existing wrappers (scr_stats ~1449): `key_nav` (hold-repeat), `nav_up/down/left/right`
  (arrows+WASD, menu tick), `wrap_index`. These become the pattern for everything else.

## Action vocabulary (scr_input, new script)
| Action fn | Keyboard today | Gamepad | Touch (later) |
|---|---|---|---|
| `input_confirm()` | Enter / Space | A | tap focused row / button |
| `input_cancel()` | Esc / Backspace | B | back button / edge swipe |
| `input_nav_up/down/left/right()` | arrows + WASD (via key_nav) | d-pad + left stick (repeat) | drag / tap rows directly |
| `input_tab_next/prev()` | E / Q | RB / LB | tap tab chips |
| `input_page_detail()` | Tab | Y | long-press |
| `input_menu()` | I | Start | on-screen button |
| `input_action(id)` | letter hotkeys (T stash, H history, O settings, C consumables, R reroll, G codex, P perm-alloc, ...) | contextual: X + radial or footer buttons | on-screen buttons from the key-legend footers |

Design rules:
1. **The key-legend footers are the contract.** Every screen already declares its keys in a
   `ui_draw_key_legend` footer (~35 sites). Those legends become device-aware (show key names,
   button glyphs, or nothing on touch) — and on touch they become the tappable buttons.
2. Letter hotkeys map through a single `input_action("stash")`-style registry so gamepad can
   rebind them contextually and touch can render them as buttons. No raw `ord("T")` outside
   scr_input when done.
3. Mouse stays fully supported (157 sites already exist; touch maps single-touch to mouse —
   Windows code paths mostly carry over).
4. `input_*` functions are the ONLY place device state is read. Device detection:
   last-used wins (keyboard/mouse vs gamepad), `os_type` forces touch.

## Migration order (each chunk = one M F5 regression pass)
1. scr_input + rewire the GLOBAL primitives (confirm/cancel/nav) in obj_game_controller.
2. Hub controller (biggest input surface: NPC list, overlays, hotkeys).
3. Combat controller (ability keys 1-5, targeting, C consumables, Tab detail).
4. Floor controller + events/shrines.
5. Title/slot picker/char create.
6. Shops/Maren/Sable/Vael/Vex/Bairc screens (tab idiom is uniform — mostly mechanical).
7. Gamepad backend + glyph footers + Steam Input config.
8. (Android phase) touch backend + on-screen buttons from legends + 20:9 safe areas.

## Non-goals now
Key REMAP ui (near-free later once everything routes through scr_input), touch backend
implementation (Android phase), Steam Deck verification checklist (needs gamepad done).
