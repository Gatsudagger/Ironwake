# Ironwake — Steam Input & Steam Deck notes (for the store build)

Drafted 2026-07-07 alongside input-abstraction chunk 7b. Decision of record (M-approved):
**plain XInput via GM's gamepad functions + Steam's default Gamepad template — no Steam
Input Action Set SDK work for EA.** The Action Set API (official per-device glyphs, overlay
rebinding) can be added post-EA without touching saves or the scr_input layer.

## Steamworks checklist (store side — M does these in the partner portal)
1. **Store page → Controller Support field**: set to **"Full Controller Support"** only if
   every flow below passes on a pad with the keyboard unplugged/untouched, INCLUDING text
   entry (see OSK section — until the OSK path is decided, declare **"Partial Controller
   Support"**; partial is honest and doesn't hurt Deck review).
2. **Steamworks → Application → Steam Input**: leave "Steam Input Default On" for the
   **Xbox/Generic Gamepad template**. This makes PS4/PS5/Switch/Deck controllers arrive as
   XInput — exactly what `input_pad()`/`pad_pressed()` read. Do NOT opt into "Steam Input
   API only".
3. Upload at least one build to a beta branch before requesting Deck compatibility review
   (Valve reviews whatever the default branch runs).

## What our layer already guarantees (7a + 7b)
- Every menu/screen drivable by d-pad/left stick + A/B/X/Y/LB/RB; contextual extras on
  LT/RT/Start/Select/L3/R3 (see INPUT_ABSTRACTION_SPEC.md chunk-7b table).
- Key legends switch to pad chips when the last-used device is a pad (`input_device()`),
  and back to key names on any keypress — Deck's "dock a keyboard" case works itself out.
- Mouse stays live alongside pad (Deck trackpad/touchscreen = mouse; single-touch=mouse
  is also the Android plan, so Deck touchscreen taps come along for free).

## Deck-specific verification list (M, on hardware or via Remote Play; ~30 min)
- [ ] **Resolution**: Deck is 1280×800 (16:10). We render 1920×1080 GUI; GM letterboxes to
      16:10 with small top/bottom bars unless "keep aspect ratio" is off. Check the
      viewport settings once on hardware; bars are acceptable for EA, stretching is not.
- [ ] **Text size**: fnt_ui_small legends at 1280 wide — readable on the 7" panel? (Worst
      case: the Bairc footer and shop legends. 7b already shortened pad footers.)
- [ ] Full run loop on pad only: title → slot → char create (SEE OSK) → hub → gate →
      floor → combat → loot → extract → hub. Cast with d-pad+A, End Turn RT, Items LT.
- [ ] Knucklebones + High Table (board RT/LT), Bairc action submenu (A), stash LB/RB tabs.
- [ ] Suspend/resume mid-combat (Deck sleep) — GM handles this, but verify audio resumes.
- [ ] 30 FPS cap NOT set anywhere (Deck review flags forced low caps).

## Text entry (the ONE real gap for "Full" support)
`keyboard_string` capture sites: character naming (char create), pet naming/renaming at
Bairc. On Deck without a physical keyboard the player must invoke the OSK manually
(**Steam + X**) — works, but Valve's "Verified" bar wants the game to summon it.
Options, in order of effort:
1. Ship EA with a one-line hint on the naming modals when `input_device() != 0`
   ("Steam + X opens the keyboard") — zero risk, done in GML. **Recommended for EA.**
2. Post-EA: Steamworks extension (`steam_show_floating_gamepad_text_input`) — GMEXT-Steamworks
   supports it; summons the Deck OSK automatically. Small, isolated, but adds the extension
   dependency to the Windows build — do it as its own chunk with its own F5.

## Known non-blockers
- F11 fullscreen toggle is keyboard-only by design (Deck is always fullscreen).
- Alt+click modifier paths are mouse-track only; pad has equivalent flows.
- Deck's 4 back-grip buttons: free real estate via user templates; nothing to do.
