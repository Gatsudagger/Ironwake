# Ironwake — Aesthete Skin Portrait Prompts (MidJourney)

Numbered MidJourney prompts for a **character portrait that matches each unlockable skin Vael
(the Aesthete) sells**. The plan: generate one portrait per skin so that **unlocking the skin in
game also unlocks its matching portrait** (gating logic is a separate code step — see bottom).

There are **23 skins** (the "Default / Class Look" is excluded — it just uses the class portrait you
already chose). Numbers below are stable IDs — keep them when you name the exported files.

---

## How to use (read first — keeps all 23 portraits consistent)

1. **Framing:** head-and-shoulders bust, character centred, facing slightly off-axis. These get
   cropped into a square in-game, so keep the face in the upper-middle and leave a little headroom.
2. **Aspect / size:** generate square (`--ar 1:1`) and export at **512×512** (the existing portrait
   sprites are 512px). I'll downscale/import if you give me larger.
3. **Shared style block — APPEND THIS to every prompt** so all 23 share one look:

   ```
   head and shoulders character portrait, facing slightly to one side, dramatic rim lighting,
   dark atmospheric background, dark fantasy, painterly digital splash art, highly detailed,
   ominous mood, centred composition --ar 1:1 --v 6
   ```

4. **Lock the style across the whole set:** once you get a first portrait you like, grab its job and
   reuse it as a style reference on the rest — add `--sref <url-or-id>` (and optionally `--seed <n>`)
   to every other prompt. That's what makes the 23 read as one matching collection.
5. **Naming for import:** save each as `portrait_skin_<id>.png` (the `<id>` is in each entry). When
   you've got a batch, drop them in `C:\Asset_Library\` (or this folder) and I'll import them as
   `spr_portrait_skin_<id>` and wire the skin→portrait unlock.
6. **Gender** is listed per skin (matches the in-game cosmetic gender axis). Swap "man/woman" in the
   prompt if you'd rather a different read — the skins themselves are class- and body-agnostic.

> Each prompt below is the **subject line**; paste it, then the shared style block from step 3.

---

## Tier 0 — Ungated (buy anytime)

**1. Ashen Revenant** · `ashen` · male · 250g · *no unlock — "A gaunt revenant wreathed in ash-grey rags."*
> a gaunt undead revenant warrior, ash-grey tattered rags and a torn hood, pale cracked skin, hollow faintly-glowing eyes, drifting flecks of ash

**2. Emberforged** · `ember` · male · 250g · *no unlock — "Molten plate that glows with an inner fire."*
> a warrior clad in molten forged plate armour glowing with inner fire, glowing lava cracks running through dark metal, drifting ember sparks, heat haze

**3. Tideborn** · `tide` · female · 250g · *no unlock — "Robes that flow like deep water."*
> a sea-touched sorceress in flowing blue-green robes that ripple like deep water, pearl and coral accents, wet sheen, calm depthless eyes

**4. Wanderer's Garb** · `wanderer` · male · 250g · *no unlock — "A travel-worn cloak from a hundred roads."*
> a weary road-worn traveller in a dusty travel-worn hooded cloak, frayed leather straps and a worn pack, sun-weathered rugged face

**5. Hearthguard** · `hearth` · female · 300g · *no unlock — "Warm banded leather, fire-tested."*
> a stalwart guardian woman in warm fire-tested banded leather armour, faint ember glow at the seams, steady protective gaze, soot-marked

**6. Duskhide** · `duskhide` · male · 320g · *no unlock — "Dark, supple rogue's leathers."*
> a rogue in dark supple fitted leather armour, hood drawn up shadowing the eyes, fingerless gloves, twin dagger hilts, quiet and dangerous

**7. Pilgrim's Shroud** · `pilgrim` · female · 360g · *no unlock — "The hooded robe of a wandering ascetic."*
> a hooded ascetic pilgrim woman in a plain undyed grey robe, serene weathered face, simple prayer beads, faint holy calm

**8. Ironscale** · `ironscale` · male · 400g · *no unlock — "Riveted scale, dented from old wars."*
> a battle-hardened veteran in riveted iron scale armour, plates dented and scratched from old wars, grim scarred face, hard stare

---

## Tier 1 — Clear a full dungeon (`clear1`)

**9. Gravewalker** · `gravewalker` · male · 420g · *"Plate caked in the dirt of a hundred graves."*
> a grim death-knight in plate armour caked with grave dirt and clinging roots, hollow stare, faint necrotic green mist, smell of the tomb

**10. Bloodsworn** · `bloodsworn` · female · 480g · *"A crimson warsuit sworn in blood."*
> a fierce warrior woman in a crimson blood-red warsuit etched with dark oath-sigils, blood-flecked, burning resolve in her eyes

**11. Cryptlight** · `cryptlight` · male · 550g · *"The lantern-bearer's tattered wraps."*
> a crypt lantern-bearer in tattered grey burial wraps, lifting a pale ghost-blue lantern that lights his gaunt face, eerie underglow

---

## Tier 2 — Clear an A1 (Awakening 1) dungeon (`awk1`)

**12. Frostbitten** · `frostbit` · female · 600g · *"Mail rimed with everlasting frost."*
> a frost-armoured warrior woman, chainmail rimed with everlasting frost and jagged ice crystals, pale-blue skin, frozen breath, glacial chill

**13. Cinderclad** · `cinderclad` · male · 680g · *"Charred warplate still warm to the touch."*
> a warrior in charred blackened warplate still glowing with live embers, thin curls of smoke, ash-streaked face, smouldering heat

**14. Mirewalker** · `mirewalker` · male · 750g · *"Bog-shrouded hide that drips and reeks."*
> a swamp stalker in bog-shrouded hide and moss-draped leather, dripping muck and tangled weeds, murky green gloom, sunken wary eyes

---

## Tier 3 — Clear an A2 dungeon (`awk2`)

**15. Stormcaller** · `stormcall` · female · 820g · *"Robes crackling with caged lightning."*
> a storm-mage woman in dark robes crackling with caged lightning, electric arcs leaping across her, wind-swept hair, charged static glow

**16. Bonechoir** · `bonechoir` · male · 900g · *"Armor bound from the singing dead."*
> a necromancer warrior in armour lashed together from bones and skulls, faint ghostly choir-light spilling from the joints, macabre and solemn

**17. Veilbinder** · `veilbind` · female · 1000g · *"A shadow-mage's shroud of woven dark."*
> a shadow-mage woman in a shroud of woven living darkness, face half-veiled in shadow, tendrils of dark smoke curling around her, mysterious

---

## Tier 4 — Clear an A3 dungeon (`awk3`)

**18. Goldwrought** · `goldwrought` · female · 1150g · *"Regalia beaten from dungeon gold."*
> a regal warrior woman in ornate golden regalia beaten from looted treasure, gleaming filigree and gem inlays, proud opulent bearing

**19. Voidtouched** · `voidtouch` · male · 1250g · *"Dark plate eaten through by stars."*
> a void-knight in dark plate armour eaten through with holes that reveal a glittering starfield within, cosmic purple glow, unsettling and silent

**20. Sanguine Regalia** · `sanguine` · female · 1400g · *"The blood-dark finery of a vampire lord."*
> an elegant vampire-lord woman in blood-dark crimson and black finery, pale flawless skin, faint fangs, aristocratic and predatory

---

## Tier 5 — Clear an A4 dungeon (`awk4`)

**21. Dawnbreaker** · `dawnbreak` · male · 1550g · *"Radiant crusader plate that never dims."*
> a radiant crusader in gleaming gold-and-white plate that never dims, soft halo of holy light behind him, resolute noble face

**22. Doomherald** · `doomherald` · male · 1750g · *"The apocalyptic raiment of a warlord."*
> a doom warlord in apocalyptic spiked black-and-crimson raiment, menacing horned helm, hellish red glow, towering and merciless

**23. Eternal Sovereign** · `sovereign` · female · 2000g · *"Crown regalia worn beyond death itself."*
> an undead queen in eternal crown regalia, ghostly tattered royal gown, blackened skeletal crown, regal and worn beyond death, majestic and cold

---

## Wiring the unlock (code step, when art is ready)

The portraits are currently one flat pool (`global.portrait_sprites`, chosen at char-creation / via
Vael's Portrait tab for 100g). To make a portrait **unlock with its skin**, I'd add a parallel
catalogue mapping `skin id → spr_portrait_skin_<id>` and gate it on `vael_skin_owned(id)` (same check
the skins already use). Drop the finished PNGs and tell me whether you want them:
- **(a)** auto-added to the char-creation / Vael portrait list once the skin is owned, or
- **(b)** a separate "skin portraits" section.

Hand me the images (named `portrait_skin_<id>.png`) and I'll import all 23 + wire the gating.
