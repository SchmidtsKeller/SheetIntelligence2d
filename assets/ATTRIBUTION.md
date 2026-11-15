# Third-party assets

Every asset in `assets/` that was not made for this project, with its source and licence. Add a row for each asset you add.

## Sounds (#10, #23)

### Recorded for this project

Recorded by FrankAntonGabriel of the team, not third-party assets. The sources are in `resources/sounds/` (not in the build). The bleats are the cleaned takes, unchanged (mono, 48 kHz; Godot compresses them with QOA on import, #95); the raw takes and the editing project are in `resources/sounds/NPC/Raw/`. The rustle and the footsteps were looped, levelled and encoded like the rest.

| File in `assets/audio/` | Source in `resources/sounds/` | What was taken |
|:--|:--|:--|
| `sheep/bleat_01.wav` … `bleat_08.wav` | `NPC/Pass1/Sheep1.wav` … `Sheep8.wav` | the whole take |
| `sheep/grass_move_loop.ogg` | `Walk2.wav` | 1.2–8.2 s as a loop |
| `sheepherder/herder_step_loop.ogg` | `Walk1.wav` | 1.0–10.8 s as a loop |

### CC0

All are **CC0 1.0** (<https://creativecommons.org/publicdomain/zero/1.0/>), as stated on each source page. The Freesound sounds were taken from the site's public high-quality Ogg Vorbis previews (`-hq.ogg`), not the original uploads. Each was mixed down to mono (the wind: its left channel), resampled to 44.1 kHz, cut, levelled and encoded as Ogg Vorbis; the loops were made seamless with a crossfade.

| File in `assets/audio/` | Source | Author | What was taken |
|:--|:--|:--|:--|
| `sheep/graze_loop.ogg` | [sheep chewing gras](https://freesound.org/people/krnd/sounds/319782/) | krnd | 20–32 s as a loop |
| `sheepherder/bell_01.ogg` … `bell_03.ogg` | [Ringing Small Hand Bell](https://freesound.org/people/Hano_van_Dalen/sounds/767307/) | Hano_van_Dalen | the rings at 0.35 s, 4.45 s and 10.2 s |
| `sheepherder/gunshot.ogg` | [gun lee enfield 303 rifle clean shot](https://freesound.org/people/kyles/sounds/450853/) | kyles | the shot and its tail |
| `sheepherder/reload_click.ogg` | [Diablo 12g pistol 6 inch, closing breech quickly 1](https://freesound.org/people/FOSSarts/sounds/741047/) | FOSSarts | the click at 0.6 s |
| `sheepherder/empty_click.ogg` | [A rifle being dry fired once](https://freesound.org/people/ser%C3%B8ut%C5%8Dnin--depriv%C9%99d/sounds/725402/) | serøutōnin--deprivəd | the click |
| `sheepherder/bullet_impact_01.ogg`, `_02.ogg` | [Single rock hitting wood](https://freesound.org/people/worthahep88/sounds/319226/), [Single Rock hitting wood 2](https://freesound.org/people/worthahep88/sounds/319228/) | worthahep88 | the hit of each |
| `sheepherder/herder_death.ogg` | [Voice_AdultMale_DeathScream_03](https://freesound.org/people/MrFossy/sounds/547182/) | MrFossy | the whole scream |
| `monster/eat.ogg` | [rip_tear FLESH!](https://freesound.org/people/aust_paul/sounds/30931/) | aust_paul | the whole sound |
| `monster/spider_screech.ogg` | [Spider Attack 2](https://freesound.org/people/kongg_/sounds/672712/) | kongg_ | the whole sound |
| `monster/spider_move_loop.ogg` | [bug legs tapping](https://freesound.org/people/c64cosmin/sounds/828623/) | c64cosmin | played at 0.7 times the speed (lower), then 8 s from 4 s on as a loop |
| `monster/monster_death.ogg` | [monster_sound_big_death](https://freesound.org/people/Leadstarson/sounds/568000/) | Leadstarson | the whole sound |
| `companions/dog_bark.ogg` | [Single Dog Bark](https://freesound.org/people/kwahmah_02/sounds/277058/) | kwahmah_02 | the bark |
| `companions/bat_01.ogg` … `bat_03.ogg` | [Bat Screeches](https://opengameart.org/content/bat-screeches) (from [fruit_bats3](https://freesound.org/s/104205/) by polymorpheva) | AntumDeluge | `bat_01` to `bat_03.flac` of the pack |
| `companions/bat_wings_loop.ogg` | [G12-03-Bats flying](https://freesound.org/people/craigsmith/sounds/437935/) | craigsmith | 10–18.4 s (three circles) as a loop |
| `world/torch_ignite.ogg` | [flame burst ignite bbq barbecue](https://freesound.org/people/kyles/sounds/637533/) | kyles | the first 0.9 s |
| `world/torch_burn_loop.ogg` | [Torch Crackle](https://freesound.org/people/kentnelson64/sounds/647221/) | kentnelson64 | 95–105 s as a loop |
| `cues/invisibility_on.ogg`, `invisibility_off.ogg` | [Ghostly Whoosh - Horror Game UI](https://freesound.org/people/TommasoMotteran/sounds/850767/) | TommasoMotteran | the first 1.6 s; `off` is it reversed |
| `cues/bat_sent.ogg` | [Flutter Short](https://freesound.org/people/RutgerMuller/sounds/51144/) | RutgerMuller | the whole sound |
| `cues/alert_out_of_bullets.ogg` | [Thud2](https://freesound.org/people/BMacZero/sounds/96137/) | BMacZero | the whole sound |
| `cues/alert_kill_unlocked.ogg` | [bommm](https://freesound.org/people/ubergossen/sounds/13663/) | ubergossen | the whole sound |
| `cues/alert_perk_ready.ogg` | [Music box note](https://freesound.org/people/thomasjaunism/sounds/218459/) | thomasjaunism | the first 1.8 s |
| `ui/ui_click.ogg` | [Wooden Click](https://freesound.org/people/BenjaminNelan/sounds/321083/) | BenjaminNelan | the whole sound |
| `ui/ready.ogg` | [User Interface Elegant Wooden Confirmation Sound](https://freesound.org/people/qubodup/sounds/822568/) | qubodup | the whole sound |
| `ui/paired.ogg` | [Ship Bell Two Chimes](https://freesound.org/people/Sojan/sounds/353232/) | Sojan | both chimes |
| `ui/player_left.ogg` | [Boom_01](https://freesound.org/people/Faulkin/sounds/336487/) | Faulkin | the whole sound |
| `ui/countdown_tick.ogg` | [clock-tick-01](https://freesound.org/people/pbimal/sounds/534094/) | pbimal | the tick |
| `ui/round_start.ogg` | [gong_brown_80cm_felt_mallet](https://freesound.org/people/glenm8/sounds/853153/) | glenm8 | the first 4 s |
| `ui/round_win.ogg`, `round_lose.ogg`, `round_draw.ogg` | [Piano _ Chord C](https://freesound.org/people/owstu/sounds/639869/), [Piano _ Chord a](https://freesound.org/people/owstu/sounds/639874/), [Piano _ Chord e](https://freesound.org/people/owstu/sounds/639873/) | owstu | the first 3–3.5 s of each |
| `ui/match_end.ogg` | [BELL](https://freesound.org/people/kgeshev/sounds/378799/) | kgeshev | the toll |
| `ambience/wind_loop.ogg` | [Looping Gentle Wind Ambience on an Open Desert Plain](https://freesound.org/people/dhallcomposer/sounds/697217/) | dhallcomposer | 1–21 s of the left channel as a loop |
| `ambience/crickets_loop.ogg` | [Night Crickets 02](https://freesound.org/people/Vrymaa/sounds/805466/) | Vrymaa | 22–42 s as a loop |
| `ambience/owl_01.ogg` … `owl_03.ogg` | [owl_hooting … 068-074](https://freesound.org/people/Gerent/sounds/558396/), [… 037-044](https://freesound.org/people/Gerent/sounds/558397/), [… 007-015](https://freesound.org/people/Gerent/sounds/558398/) | Gerent | the hoots, low-passed at 2.5 kHz |

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
