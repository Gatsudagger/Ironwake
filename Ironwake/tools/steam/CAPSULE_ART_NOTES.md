# Ironwake - Capsule / Key Art Plan (2026-07-13)

Decision (M): title/key art background = **MidJourney** (M generates, owns commercial
rights, matches existing portrait/NPC art). NOT PixelLab (wrong tool for large marketing
art). **No text in the AI image** - Claude composites the IRONWAKE logotype (Cinzel
Decorative, licensed OFL title font) + tagline "The town remembers." in Python, then
exports every required size from the one approved master.

## MidJourney prompts for M (generate at 16:9 or wider, pick the best, iterate)

1. `gothic dark fantasy town gate at night, iron portcullis, warm lantern light against
   cold blue moonlit mountains, cobblestone path leading into darkness, painterly key art,
   dramatic composition, empty sky upper third for title text, no text, no characters
   --ar 16:9`
2. `lone hooded adventurer with a small glowing winged creature companion standing before
   a massive dark dungeon gate, gothic town behind them, lanterns, night, moon, painterly
   dark fantasy key art, cinematic, no text --ar 16:9`
3. `dark fantasy tavern-town nestled under a cliff, glowing windows, a dungeon entrance
   yawning below, night vista, shooting star, gothic painterly style, muted palette with
   warm lantern accents, no text --ar 16:9`

Also generate one TALL variant of the winner (`--ar 2:3`) for the vertical/library
capsules so heads/focal points survive the crop.

## Required outputs (Claude composites from the approved master)

| Asset | Size | Notes |
|---|---|---|
| Header capsule | 920x430 | logo centered or left, tagline under |
| Small capsule | 462x174 | logo dominates - must read at tiny size |
| Main capsule | 1232x706 | full art + logo |
| Vertical capsule | 748x896 | tall crop |
| Library capsule | 600x900 | tall crop, logo upper third |
| Library hero | 3840x1240 | wide crop, NO logo (Steam overlays the logo file) |
| Library logo | transparent PNG | logotype only, ~1280w |
| App icon | 32x32 + 184x184 | emblem crop (gate/lantern motif), not the full scene |

Workflow: M drops MidJourney candidates into `Ironwake\_for_review\` (review-folder
rule) -> M picks the master -> Claude builds all sizes with PIL + Cinzel Decorative ->
outputs back into `_for_review\` for M's final pass -> M uploads to Steamworks
(Graphical Assets page), which completes the last Store Presence checklist items
besides screenshots.

## Screenshots (separate task, needs M at the game, ~20 min)
shot list = STEAM_PAGE_KIT.md section 8; guided one-target-at-a-time; 1920x1080
fullscreen; drop as shot1..shot7 into Ironwake\Screenshots (folder can be cleared of
the 07-13 Steamworks nav PNGs first).
