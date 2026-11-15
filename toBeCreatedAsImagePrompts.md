# Prompts for the placeholders

A ready-to-paste generation prompt for every image and sound that is still a placeholder in the game (#86). The list of what is missing, where it is used and at which size is in [toBeCreatedAsImage.txt](toBeCreatedAsImage.txt); the art style is in [resources/documents/art_style_constraints.md](resources/documents/art_style_constraints.md). Remove a prompt when its piece is in the game.

## How to use them

There are two ways to make the pictures. Either works; the sheets are faster.

**One piece at a time.** Paste the piece's prompt, with the style block and the "avoid" block below appended, into an image generator. Remove the flat background, scale to the stated size and save the PNG under the stated name.

**A whole sheet at once** (sections 3 and 4). The sheet prompts ask for a labelled collage on a flat charcoal background, in the same format as `resources/art_sources/uiElements.webp` and `MapElements.webp`. Save the sheet in `resources/art_sources/`, add its pieces' rectangles to `tools/cut_art_sheets.gd` and run it:

```bash
godot --headless --path . --script res://tools/cut_art_sheets.gd
```

The tool removes the background and writes one PNG per piece. Pieces cut from a 1024 px sheet are small; ask the generator for the largest size it offers.

**Animations** (section 5) are made as a short video clip from a start image and turned into a sprite sheet, as in #30 and #74. The painted packs in `assets/` face **right** (+x), so the start image is a frame of the pack and the clip faces right. Bring the result in with `tools/import_sprite_pack.gd`.

**Sounds** (section 6) go into `assets/audio/` under the stated name, replacing the file in `assets/audio/placeholder/`.

## 1. Style block (append to every image prompt)

```text
Art style: atmospheric realism painting, traditional oil painting on canvas with visible, textured brushstrokes; impasto in the lit areas, thin dark washes in the shadows; a subtle canvas texture beneath the paint. Heavy chiaroscuro, tenebrism: harsh directional light against deep umber and charcoal shadows. Muted, desaturated, earthy palette: raw umber, burnt sienna, olive green, muddy brown, charcoal black, darkwood tones; highlights in pale sickly yellow or cold white; blood only as dark oxidized crimson or rust. Grim, tense, macabre survival-horror mood, realistic proportions.
```

## 2. Avoid block (append to every image prompt)

```text
Avoid: 3D render, CGI, Octane or Unreal look, digital smoothing, airbrushing, cel shading, comic or ink outlines, anime, manga, cartoon, flat vector shapes, flat colours, bright or saturated or cheerful colours, neon, modern sci-fi, polished fantasy, photographic hyper-realism, text or letters (unless asked for), watermarks, signatures, frames, drop shadows, glows that spill onto the background.
```

For world pieces (section 5) also append:

```text
Strict 90-degree zenithal camera, seen directly from above, orthographic; no 3/4 view, no isometric angle, no tilt, no horizon, no side view; no shadow painted under the subject (the game lights it).
```

---

## 3. Menus

### `ui_logo` — the game's title

1024x256 (4:1), transparent background; shown about 440x76 px, must read at 300 px wide on a phone.

```text
The words "Hide in Sheep Clothing" as a painted title logo for a horror game, one line, centred. Worn, uneven old-print lettering in pale sickly yellow, as if painted with a loaded brush on dark wood and partly scraped off; ink bleeding at the edges, small chips and scratches. A subtle hint of horror: the "S" of "Sheep" is a curl of wool that ends in a single claw. Every letter clearly legible. Isolated on a flat solid charcoal background (#31312F), no other elements.
```

### `ui_backdrop` — the picture behind every menu

1920x1080 (16:9), opaque. It is cropped to 4:3 and widened to 21:9: keep the middle calm and the detail at the edges. Very low contrast behind the boards, so text stays readable.

```text
A pasture at night seen directly from above (90-degree zenithal view, ground filling the whole frame), almost black. Dark wet grass and mud, a few pale sheep shapes barely visible at the left and right edges, one of them standing apart from the others. In one corner the faint orange glow of a lantern on the ground, its light falling only a short way. The middle third of the picture is quiet and very dark with almost no detail. Very low overall contrast, nothing bright except the lantern glow.
```

### `perk_icon_<id>` — one icon per perk, and "no perk"

128x128 each, transparent; shown at 44, 76 and 108 px. One simple object per icon with a clear silhouette that reads at 44 px.

| Id | Prompt |
|:--|:--|
| `perk_icon_wide_flashlight` | `A small icon: an old brass flashlight seen from above, its beam fanning out wide across dark ground. Single object, centred, clear silhouette, high contrast against a flat charcoal background (#31312F).` |
| `perk_icon_long_flashlight` | `A small icon: an old brass flashlight seen from above, its beam a long narrow shaft reaching far into darkness. Single object, centred, clear silhouette, high contrast against a flat charcoal background (#31312F).` |
| `perk_icon_faster_reload` | `A small icon: a single brass rifle cartridge being pushed into an open breech, a quick motion streak behind it. Single object, centred, clear silhouette, high contrast against a flat charcoal background (#31312F).` |
| `perk_icon_shepherd_dog` | `A small icon: the head of a scruffy grey sheepdog seen from above, ears alert, one eye catching the light. Single subject, centred, clear silhouette, high contrast against a flat charcoal background (#31312F).` |
| `perk_icon_spare_bullet` | `A small icon: one brass cartridge half hidden in the folds of a worn leather pouch. Single object, centred, clear silhouette, high contrast against a flat charcoal background (#31312F).` |
| `perk_icon_faster_consumption` | `A small icon: gnashing jaws with long yellowed teeth, a trace of dark oxidized blood at the gums. Single subject, centred, clear silhouette, high contrast against a flat charcoal background (#31312F).` |
| `perk_icon_invisibility` | `A small icon: the silhouette of a sheep seen from above, fading into mist from its rump to its head, half transparent. Single subject, centred, clear outline, against a flat charcoal background (#31312F).` |
| `perk_icon_allied_bat` | `A small icon: a large dark bat with ragged leathery wings spread, seen from above. Single subject, centred, clear silhouette, high contrast against a flat charcoal background (#31312F).` |
| `perk_icon_none` | `A small icon: an empty rusty iron hook hanging from a nail, nothing on it. Single object, centred, clear silhouette, high contrast against a flat charcoal background (#31312F).` |

### Sheet: Asset Pack 5, menus and perk icons

```text
ASSET PACK 5: MENU ART & PERK ICONS (EASY CUT). A collage sheet for a horror game's menus on a flat, solid, high-contrast charcoal background (#31312F). Each piece stands apart from the others with a clean, distinct outline and no shadow or glow blending into the background; under each piece its file name in small plain white letters. Pieces: the painted title logo "Hide in Sheep Clothing" in worn pale-yellow old-print letters (ui_logo.png); nine round icons in one row, each one simple object with a clear silhouette: a flashlight with a wide beam (perk_icon_wide_flashlight.png), a flashlight with a long narrow beam (perk_icon_long_flashlight.png), a cartridge pushed into an open breech (perk_icon_faster_reload.png), a sheepdog's head (perk_icon_shepherd_dog.png), a cartridge half hidden in a leather pouch (perk_icon_spare_bullet.png), gnashing jaws (perk_icon_faster_consumption.png), a sheep fading into mist (perk_icon_invisibility.png), a bat with spread wings (perk_icon_allied_bat.png), an empty iron hook (perk_icon_none.png).
```

The backdrop is too large for a sheet; make it on its own.

---

## 4. HUD

The action icons, their round base and the bars are painted and in the game (#96); no prompts needed. The Perk action shows its perk's icon (section 3).

### `hud_milestone_kill`, `hud_milestone_spider` — the two marks on the evolution bar

32x48 each, transparent.

```text
hud_milestone_kill: a tiny skull of a sheep, bone white with dark eye sockets, seen from the front, as a small marker. Isolated on a flat charcoal background (#31312F).
hud_milestone_spider: a single bristly black spider leg, bent at the joint, as a small marker. Isolated on a flat charcoal background (#31312F).
```

### `hud_bullet`, `hud_bullet_empty` — one bullet of the magazine

64x64 each, transparent; shown about 28x28.

```text
hud_bullet: a single brass rifle cartridge seen from the side, upright, worn and slightly dented, catching a pale light. Isolated on a flat charcoal background (#31312F).
hud_bullet_empty: the outline of the same cartridge, dull and dark, only its edge faintly visible, as an empty slot. Isolated on a flat charcoal background (#31312F).
```

### `hud_timer_plate` — a plate behind the round timer

256x80 nine-patch, transparent edges.

```text
A small dented tin plate, wider than high, nailed at its two ends, its middle calm and plain so numbers can be written on it. Seen from directly above. Isolated on a flat charcoal background (#31312F).
```

### Sheet: Asset Pack 6, HUD

```text
ASSET PACK 6: HUD DETAILS (EASY CUT). A collage sheet for a horror game's HUD on a flat, solid, high-contrast charcoal background (#31312F). Each piece stands apart with a clean, distinct outline and no shadow or glow blending into the background; under each piece its file name in small plain white letters. Pieces: a tiny sheep skull (hud_milestone_kill.png) and a bristly spider leg (hud_milestone_spider.png); a brass cartridge (hud_bullet.png) and its dull outline (hud_bullet_empty.png); a small dented tin plate (hud_timer_plate.png).
```

---

## 5. The world

### `fx_blood_decal_01` … `_03` — blood on the ground

512x512 each, transparent. Make three, each with its own shape.

```text
Strict top-down view, seen from directly above. A pool of dark oxidized blood soaked into grass and mud, with an irregular splatter around it; a unique shape, no body, no objects. A single visual effect element, centred, on a flat solid charcoal background (#31312F).
```

### `bat_fly_sheet`, `bat_harass_sheet` — the Allied Bat

Video clip, then a sprite sheet of six equal cells in one row (1536x256 in #30, or the cell size of the painted packs in `assets/`). Seamless loops.

```text
bat_fly: flight cycle of a large dark bat with ragged leathery wings, through one full wing beat. Short animation clip of 2 to 3 seconds. Fixed static camera in a strict top-down view, seen from directly above, no tilt, no camera movement, no zoom, no cuts. The bat faces the right edge of the frame, stays centred at the same scale and flaps in place; it does not travel across the frame. The clip loops seamlessly: the last frame matches the first. Flat solid charcoal background (#31312F) that stays exactly the same in every frame.
bat_harass: the same bat attacking erratically: tight frantic wing beats, claws out, darting a little from side to side but staying centred. Same camera, background and loop rules as bat_fly.
```

### Sheep: `sheep_bleat`, `sheep_death_shot`, `sheep_death_eaten`

Start image: a frame of `idle` from `assets/sheep/sheep_sheet.png`, which faces right. The clip faces right too, so the result matches the painted sheep. The Monster's disguise uses the very same sheep, so make no separate version for it (no built-in tell).

```text
sheep_bleat: the painted sheep in the start image bleating: it lifts its head slightly, opens its mouth, then closes it again and returns to the start pose. Plays once.
sheep_death_shot: the painted sheep in the start image being shot: it jolts, collapses onto its side and lies still, a small dark wound in its wool. Plays once and holds the final pose.
sheep_death_eaten: the painted sheep in the start image being devoured: it collapses, its body is torn apart and shrinks away, leaving only dark blood on the ground. Disturbing but not gory in close detail. Plays once and holds the final pose.
For all three: short animation clip of 2 to 3 seconds. Fixed static camera in a strict top-down view, seen from directly above, no tilt, no camera movement, no zoom, no cuts. The sheep faces the right edge of the frame, stays centred at the same scale and moves in place. Flat solid charcoal background (#31312F) that stays exactly the same in every frame. Keep the look of the start image exactly: same wool, same colours, same brushwork.
```

### Spider: `spider_transform`

Start image: a frame of `idle` from `assets/sheep/sheep_sheet.png`; end pose: a frame of `idle` from `assets/monster/spider_sheet.png`. Both face right.

```text
Transformation: the painted sheep in the start image convulses, its wool splits open, long bristly legs burst out of its body, and it becomes the giant spider of the end image: eight long bristly legs, a swollen dark body, many small pale eyes, shreds of bloody wool still clinging to its back. Short animation clip of 2 to 3 seconds. Fixed static camera in a strict top-down view, seen from directly above, no tilt, no camera movement, no zoom, no cuts. The creature faces the right edge of the frame, stays centred and transforms in place. Plays once and holds the final pose. Flat solid charcoal background (#31312F) that stays exactly the same in every frame.
```

### Sheepherder: `sheepherder_reload`, `sheepherder_bell_ring`, `sheepherder_death`

Start image: a frame of `idle` from `assets/sheepherder/sheepherder_sheet.png`, facing right.

```text
sheepherder_reload: the sheepherder in the start image slowly reloads his single-shot rifle: opens the breech, inserts one cartridge, closes it, and returns to the start pose. Plays once.
sheepherder_bell_ring: the sheepherder in the start image raises the brass bell at his belt and swings it to ring it, then lowers it again. Plays once.
sheepherder_death: the sheepherder in the start image is struck down: he staggers, drops the flashlight and the rifle, falls and lies motionless. Plays once and holds the final pose.
For all three: short animation clip of 2 to 3 seconds. Fixed static camera in a strict top-down view, seen from directly above, no tilt, no camera movement, no zoom, no cuts. He faces the right edge of the frame, stays centred at the same scale and moves in place. Flat solid charcoal background (#31312F) that stays exactly the same in every frame. Keep the look of the start image exactly.
```

---

## 6. Sounds

For a sound generator. Mono, 44.1 kHz, Ogg Vorbis, peak about −3 dBFS, no music, no voices, no reverb tail unless asked for; loops must loop without a click. The game places them in space itself, so record them dry and close.

| File | Length | Prompt |
|:--|:--|:--|
| `bleat_01.ogg` … `bleat_04.ogg` | 0.8–1.5 s each | `A single adult sheep bleating once, close and dry, outdoors at night. Four takes that differ in pitch and shape: a short flat "baa", a long wavering one, a low hoarse one, a nervous higher one.` |
| `grass_move_loop.ogg` | 4–8 s, loop | `Steady rustling of tall dry grass as a sheep walks through it slowly, close and dry, no footsteps on hard ground, seamless loop.` |
| `graze_loop.ogg` | 6–12 s, loop | `A sheep grazing up close: soft tearing of grass blades and slow chewing, calm, dry, seamless loop.` |
| `herder_step_loop.ogg` | 4 s, loop | `Heavy leather boots walking at an even pace on damp grass and soft earth, one step every half second, close and dry, seamless loop.` |
| `bell_01.ogg` … `bell_03.ogg` | 1.5–3 s each | `A small old brass hand bell rung once in the open at night, a slightly dull, dented tone with a short natural decay. Three takes with a different swing each.` |
| `gunshot.ogg` | 1.5–2.5 s | `One shot of an old bolt-action rifle fired in an open field at night, a hard crack and a short rolling echo across the pasture.` |
| `reload_click.ogg` | 0.3–0.8 s | `The metallic click and slide of a single-shot rifle's breech closing on a cartridge, close and dry.` |
| `eat.ogg` | 1–1.5 s | `A predator tearing into flesh and wool: a wet rip, a crunch and a gulp, close, unsettling but short. Not cartoonish.` |
| `spider_screech.ogg` | 1.5–2.5 s | `A huge creature's shrill, chittering screech, part insect clicking and part animal scream, rising and cutting off, heard across a field at night.` |
| `dog_bark.ogg` | 0.5–1 s | `One sharp warning bark of a medium-sized sheepdog outdoors at night, close and dry.` |
| `bat_01.ogg` … `bat_03.ogg` | 0.3–1 s each | `A large bat's high squeak and leathery wing flutter close by, three short takes that differ.` |
