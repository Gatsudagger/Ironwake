# Ironwake - social media posts (X / Twitter)

Two to three posts a day for the first two weeks. Each day has its own folder; each post is a
`.md` with the text to copy-paste and the image to attach (in `images/`). All images were
composed from the game's own sprites so they match what players actually see.

## Rules of thumb
- Plain language. Short sentences. One idea per post.
- Lead with the picture. The text should still make sense without it.
- Link to the store on launch-type posts only (https://store.steampowered.com/app/4954740/Ironwake/). Don't link every post.
- Tags on the first post of the day only: #indiegame #roguelite #pixelart #gamedev #IndieGameDev
- Reply to your own post with extra detail instead of writing a wall.
- When someone answers, answer back - that's what the algorithm and the players both want.

## Schedule
| Day | Theme | Posts |
|---|---|---|
| 1 | Launch | announcement, what it is, thank-you + ask for reviews |
| 2 | Creatures: the idea | eggs, three stages, found-alive |
| 3 | Scions + signature moves | lineup, Vaultling, Crypt Bat |
| 4 | Bairc's garden | the garden, feeding/treats, bond |
| 5 | Classes | three classes, Arcanist, Shadowstrider |
| 6 | Combat | action points, intents, detonations |
| 7 | Dungeons | three dungeons, bosses, Awakening tiers |
| 8 | The camp | NPCs, camp bonds, tavern board |
| 9 | Crafting | Pattern Book, runes, temper/reforge |
| 10 | Odd encounters | Ashen Duelist, Merchant's Ghost, Banshee in a Bottle |
| 11 | Corruption / capstones / Awakened | |
| 12 | Android | touch, input parity |
| 13 | Challenge | Iron Vow / Descent, achievements |
| 14 | Community | show us your creatures, patch cadence, thanks |

## Images (images/)
- abilities_sample.png
- bosses.png
- classes.png
- duelist_and_ghost.png
- dungeons.png
- eggs_lineup.png
- enemies_sample.png
- npcs_camp.png
- pets_lineup_adults.png
- pets_lineup_babies.png
- scions_lineup.png
- stages_frostmarten.png
- stages_luna_moth.png
- stages_pyre_bison.png
- stages_saber_hound.png

Posts marked **Attach: (clip/screenshot)** need a capture from the game - those are the ones
where real footage beats a sprite sheet (combat, garden, Pattern Book, phone).

Regenerate everything with `python tools/make_social_posts.py` (it overwrites this folder).
