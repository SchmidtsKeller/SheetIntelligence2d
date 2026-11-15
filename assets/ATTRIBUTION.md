# Third-party assets

Every asset in `assets/` that was not made for this project, with its source and licence. Add a row for each asset you add.

## Sounds (placeholders, #10)

All are **CC0 1.0** (<https://creativecommons.org/publicdomain/zero/1.0/>), as stated on each source page. The Freesound sounds were taken from the site's public 192 kbps Ogg Vorbis previews (`-hq.ogg`), not the original uploads. Each was mixed down to mono, resampled to 44.1 kHz, cut, levelled and encoded as Ogg Vorbis; the loops were made seamless with a crossfade. The sound pass (#23) replaces them.

| File in `assets/audio/placeholder/` | Source | Author | What was taken |
|:--|:--|:--|:--|
| `grass_move_loop.ogg` | [Rustling grass](https://freesound.org/people/Wigglesworth/sounds/767220/) | Wigglesworth | 3.5–11.5 s as a loop |
| `graze_loop.ogg` | [sheep chewing gras](https://freesound.org/people/krnd/sounds/319782/) | krnd | 20–32 s as a loop |
| `herder_step_loop.ogg` | [Hiking Boot Footsteps on Grass](https://freesound.org/people/Fission9/sounds/521587/) | Fission9 | eight of its steps, one every 0.5 s |
| `bell_01.ogg` … `bell_03.ogg` | [Ringing Small Hand Bell](https://freesound.org/people/Hano_van_Dalen/sounds/767307/) | Hano_van_Dalen | the rings at 0.35 s, 4.45 s and 10.2 s |
| `gunshot.ogg` | [gun lee enfield 303 rifle clean shot](https://freesound.org/people/kyles/sounds/450853/) | kyles | the shot and its tail |
| `reload_click.ogg` | [Diablo 12g pistol 6 inch, closing breech quickly 1](https://freesound.org/people/FOSSarts/sounds/741047/) | FOSSarts | the click at 0.6 s |
| `eat.ogg` | [rip_tear FLESH!](https://freesound.org/people/aust_paul/sounds/30931/) | aust_paul | the whole sound |
| `spider_screech.ogg` | [Spider Attack 2](https://freesound.org/people/kongg_/sounds/672712/) | kongg_ | the whole sound |
| `dog_bark.ogg` | [Single Dog Bark](https://freesound.org/people/kwahmah_02/sounds/277058/) | kwahmah_02 | the bark |
| `bat_01.ogg` … `bat_03.ogg` | [Bat Screeches](https://opengameart.org/content/bat-screeches) (from [fruit_bats3](https://freesound.org/s/104205/) by polymorpheva) | AntumDeluge | `bat_01` to `bat_03.flac` of the pack |

## Sheep bleats (#95)

Made for this project by the team, not third-party assets. `audio/sheep/bleat_01.wav` … `bleat_08.wav` are the cleaned takes `resources/sounds/NPC/Pass1/Sheep1.wav` … `Sheep8.wav` (mono, 48 kHz), unchanged; the raw takes and the editing project are in `resources/sounds/NPC/Raw/`. Godot compresses them (QOA) on import.

## Character animations (#74)

Made for this project by the team, not third-party assets. The painted top-down characters were animated and baked into Godot `SpriteFrames` packs (384x384 cells, facing +x) with the team's AI Studio app "MonsterWalk" (Google AI Studio, Gemini), which rigs the source paintings and bakes keyframed walk cycles. The packs were imported with `tools/import_sprite_pack.gd`: cropped to what the frames cover, scaled down (0.4, the spider 0.5) and repacked; the animations, frame rates and loops are unchanged.

| Files | Pack | Animations (frames @ fps) |
|:--|:--|:--|
| `sheep/sheep_sheet.png`, `sheep/sheep_frames.tres` | NPC Sheep (`resources/animations/npc/all/x/`, #95) | idle 14 @ 10, graze 20 @ 12, walk 18 @ 20, sprint 14 @ 24, eat_feed 20 @ 20 |
| `monster/spider_sheet.png`, `monster/spider_frames.tres` | Giant Scary Monster (spider) (`resources/animations/monster/all/x/`, #95) | idle 16 @ 12, stalk 20 @ 14, walk 22 @ 25, eat_lunge 14 @ 24, eat_feed 20 @ 20 |
| `sheepherder/sheepherder_sheet.png`, `sheepherder/sheepherder_frames.tres` | The Shepherd | idle 14 @ 10, walk 18 @ 20, run 14 @ 24, fire 16 @ 22 |
| `companions/shepherd_dog_sheet.png`, `companions/shepherd_dog_frames.tres` | Friendly Shepherd Dog | idle 14 @ 10, walk 18 @ 22, run 14 @ 26, bark 14 @ 22 |

## Font (#86)

| File in `assets/fonts/` | Font | Author | Licence |
|:--|:--|:--|:--|
| `IMFellEnglish-Regular.ttf` | [IM Fell English](https://fonts.google.com/specimen/IM+Fell+English), from the [Google Fonts repository](https://github.com/google/fonts/tree/main/ofl/imfellenglish) (`IMFeENrm28P.ttf`, renamed) | Igino Marini | SIL Open Font License 1.1, `assets/fonts/OFL.txt` |

## Painted UI and map pieces (#83)

Made for this project by the team, not third-party assets. Two painted collage sheets from the team's React art page (`assetsInsideReactPageTemp/`): "Asset Pack 2: UI buttons & boards" and "Asset Pack 4: environment & obstacles". The sources are kept in `resources/art_sources/` (not in the build); `tools/cut_art_sheets.gd` cut them into one PNG per piece and made the flat background transparent.

| Folder | Pieces |
|:--|:--|
| `ui/painted/` | `ui_board`; `ui_button_*` and `ui_choice_button_*` (normal, hover, pressed, disabled, focus); `touch_joystick_base`, `touch_joystick_tip`; `touch_button_base_normal`, `_pressed`, `_active` |
| `arena/painted/` | `tree_01`, `tree_02`, `bush_01`, `barn_01`, `shed_01`, `hay_bale_01`, `fence_straight`, `fence_corner`, `torch_01`, `river_water_tile`, `river_bank_straight`, `river_bank_corner`, `ground_grass_tile`, `ground_grass_patch_01`, `ground_hill_01`, `ground_flowers_01` |

## Painted board, HUD bars and icons (#96)

Made for this project by the team, not third-party assets, from the team's React art page (`assetsInsideReactPageTemp/`). The sources are kept in `resources/art_sources/` (`board_large.png`, `hud_bars.png`, `hud_icons.png`); `tools/cut_art_sheets.gd` cut them into `ui/painted/`: `ui_board_large`, `hud_bar_empty`, `hud_bar_fill_gold`, `hud_bar_fill_olive`, `icon_bullets`, `icon_shoot`, `icon_bell`, `icon_graze`, `icon_bleat`, `icon_eat`, `icon_print`.

## Painted ground (#76)

Made for this project by the team, not third-party assets. The five painted terrain images (grass turf, clover meadow, dirt path, gravel, mud) come from the team's AI Studio ground page ("grasUpdate", Google AI Studio, Gemini). `tools/bake_ground.gd` made them seamless, scaled them to 512x512 and derived from them the normal maps (their brightness as height) and the gloss in the alpha channel; it also generated `layout.png` and `relief.png`, the arena's terrain layout, hills, wetness and cart ruts. The tiles lie one below the other in `terrain_albedo.png` (colour and gloss) and `terrain_normal.png` (normal maps), one layer each of a texture array (#101).

| Layer of `arena/ground/terrain_albedo.png` and `terrain_normal.png` | Source image |
|:--|:--|
| 0, grass | `terrain_grass_turf_1794741903241.jpg` |
| 1, clover | `terrain_clover_meadow_1794741902823.jpg` |
| 2, path | `terrain_dirt_path_1794741905313.jpg` |
| 3, gravel | `terrain_gravel_dirt_1794741903283.jpg` |
| 4, mud | `terrain_mud_puddle_1794741903398.jpg` |
| `layout.png`, `relief.png` | generated |
