# Audio: spatial sound and the Web build

How sounds are heard in the game (GDD §5, §7.2), why the Web build plays them the way it does (GDD §9.1), what was measured while building it (#10), and the sounds of the sound pass (#23). How to use the service from code is in the README, *Audio*.

## How a sound is heard

Every sound happens somewhere in the world and is heard from the local player's character (the *listener*), whether or not its source can be seen.

- **Range.** Each event belongs to a hearing-range class ([AudioEvents](../abstractions/types/audio_events.gd)): quiet (400 px), loud (800 px) or whole map. The volume falls from full at the listener to silence at the end of the range. Whole-map sounds fade out only at `audio_whole_map_distance` (8000 px, twice the arena's diagonal): they are heard everywhere, about half as loud across the whole arena, so their distance can still be judged.
- **Direction.** The sound pans by where it is across the screen: a sound at the edge of a 16:9 screen plays at 7/8 of its volume in the near ear and 1/8 in the far one (`audio_panning_strength` 3 × the project's 2D panning strength 0.5). Left and right are those of the screen; the listener never turns with the character.
- **Formula.** Playback is Godot's `AudioStreamPlayer2D`, for which `volume = (1 − distance / range)^attenuation` (attenuation 1 for every sound so far) and `pan = 0.5 + 0.5 × s × x / w`, limited to 0..1: `x` is how far the sound is to the right, `w` how much of the world the screen shows across, and `s` = 3 × 0.5. The right ear gets `volume × pan`, the left `volume × (1 − pan)`. [AudioMix.ear_gains()](../systems/audio/audio_mix.gd) states the same formula; the unit tests and the sound check use it, and the measurements below compare the browser's output with it.

| Event | Range | Heard by | Plays from |
|:--|:--|:--|:--|
| `grass_move`, `graze` | quiet | both | a sheep's or the Monster's picture (loop) |
| `grass_run` | quiet | both | the picture of a sheep-like that moves faster than a sheep can: the sprinting Monster (loop, 4 dB louder than walking). Decided by the simulated speed and carried in the snapshots like grazing |
| `spider_move` | quiet | both | the spider, walking or running, instead of the rustle (loop) |
| `herder_step` | quiet | both | the Sheepherder (loop) |
| `reload_click`, `empty_click` | quiet | **the Sheepherder's player only** | the Sheepherder: the reload is done; fire was pressed with no bullet left |
| `bullet_impact` | quiet | both | where a bullet stops in an obstacle or the fence, never in a creature |
| `torch_ignite`, `torch_burn` | quiet | both | a torch when it is lit, then while it burns (loop) |
| `bleat`, `eat`, `dog_bark`, `bat` | loud | both | where it happens |
| `herder_death`, `monster_death` | loud | both | where the Sheepherder or the Monster dies |
| `bat_wings` | loud | both | the Allied Bat while it flies (loop) |
| `bell`, `gunshot`, `spider_screech` | whole map | both | where it happens |

**No audio tell.** NPC sheep and the Monster use the same cue, variations and range, and a sheep's sounds come from where it is shown, a moment in the past like its picture (see [no-tell-audit.md](no-tell-audit.md), points 6 and 7). The reload and empty clicks are heard only by the Sheepherder, so the reload after the third shot does not reveal a Spare Bullet (GDD §4.1).

**Own sounds.** On a player's own device, the looping sounds of their own character (footsteps, rustle, grazing) play `audio_own_sound_volume_db` (−10 dB) quieter, so they don't cover the sounds nearby. The other player hears them as usual.

## Cues and the ambience (#23)

**Cues** are not in the world: `play_ui` plays them on the UI bus, the same in both ears, on one device.

| Cue | When | Played by |
|:--|:--|:--|
| `ui_click` | a button of the menus is pressed | every [GameButton](../ui/components/game_button.gd) |
| `paired`, `player_left` | the two devices are connected; the other player left | [GameSoundCues](../systems/audio/game_sound_cues.gd) |
| `ready` | a player got ready in the lobby (not when one takes it back) | GameSoundCues |
| `countdown_tick`, `round_start` | each second of the countdown; the round begins | GameSoundCues |
| `round_win`, `round_lose`, `round_draw` | the round is decided, from this player's side | GameSoundCues |
| `match_end` | the last round is over | GameSoundCues |
| `invisibility_on`, `invisibility_off`, `bat_sent` | the Monster's active perk starts or ends; **its own player only** | the [HUD](../ui/hud/hud.gd) |
| `alert_out_of_bullets`, `alert_kill_unlocked`, `alert_perk_ready` | with the HUD's message: the last bullet is gone, the Monster may kill the Sheepherder now, the perk is ready again; **that player only** | the HUD |

**Ambience.** During a round ([RoundStage](../systems/match/round_stage.gd)), wind and crickets loop on the Ambience bus, and an owl hoots every 30 to 70 s. It fades in and out over 1 s. The bell and the gunshot duck it by `audio_ambience_duck_db` (−9 dB), which wears off over `audio_ambience_duck_time` (1.5 s), so those cues stay clear. There is no music (GDD §7.2).

## The Web build: Sample playback

The Web build keeps Godot's default for the Web, **Sample** playback (`audio/general/default_playback_type.web`). Every sound is a Web Audio buffer, and Godot sets its volume in each ear every physics frame. *Stream* playback, where Godot mixes everything itself, is not usable in a build without Thread Support ([web-build.md](web-build.md#decision-no-thread-support-no-progressive-web-app)): in the measurements below it dropped 40 to 50 % of the output.

| | Sample | Stream |
|:--|:--|:--|
| Volume and panning at 22 positions, compared with the formula | within 0.011 everywhere; silent beyond the range | off by up to 0.31; whole windows silent |
| A steady tone for 6 s | 1.6–1.8 % silent: one gap of 8–32 ms each time the 1 s loop starts again | 39–49 % silent: about 110 gaps |
| Key press to sound (incl. the 50 ms output latency the browser reports) | 82–94 ms | 134–156 ms |
| A 250 ms tone burst | 249.3 ms: the start is not cut | 457–548 ms: torn apart |
| Page hidden | silent, back when shown again | the same |

Also checked in Sample playback:

- **Autoplay.** The browser keeps audio suspended until the first click, tap or key press; Godot resumes it then, and the sound starts.
- **Volume.** The master volume, lowered to 70 % in the sound check, was 70 % after reloading the page (`user://settings.cfg` in the browser's storage).
- **A real round.** An offline round as the Sheepherder: silent while the flock was far away, then the player's footsteps, the bell and the gunshot; no errors on the page.

### Looping sounds in the Web build

Godot 4.7.2 does not let the browser loop a sample. When a looping sample ends, its `ended` event starts it again from the main thread (`SampleNode._addEndedListener` in `platform/web/js/libs/library_godot_audio.js`). Two things follow:

- **A short gap** each time a loop starts again: 8–32 ms in the measurements, with software rendering keeping the main thread busy. The loops are therefore long (7 to 20 s: rustle 7 s, footsteps 9.8 s, grazing 12 s, the wind and the crickets 20 s), so a gap comes rarely and falls into sounds that have pauses of their own.
- **A loop always starts again where the sample was started.** So emitters always start from the beginning of their sound, never at a random point or where they last stopped.

### Measured how

Chrome 157 on Windows 11, headless with software rendering (SwiftShader), 48 kHz, debug Web build served from this computer. A script added before the page's own code wraps the page's `AudioContext` and copies everything sent to the speakers into an `AudioWorklet` on the audio thread, which records the level of each ear every 128 frames. The sound check (below) placed a steady 441 Hz tone at fixed positions for 0.8 s each and announced each step, so the levels could be matched to the position and compared with [AudioMix.ear_gains()](../systems/audio/audio_mix.gd), relative to the level at the listener. Latency is from the key press to the first sample of the sound at the speakers, using the browser's own estimate of its output latency.

A real device has a faster main thread than this headless setup, so loop gaps should be shorter there, and Stream may drop out less. Whether the result holds on phones is what the device tests below are for.

## The sound check

[systems/audio/sandbox/sound_check.tscn](../systems/audio/sandbox/sound_check.tscn) moves one sound source around the listener in the middle of the screen. Run it with **F6**, or open the Web build with `?sound-check` in the address, e.g. <https://schmidtskeller.github.io/SheetIntelligence2d/?sound-check>.

- **Sound** cycles through every event of the game, every cue, `ambience`, and four test tones (`tone-quiet`, `tone-loud`, `tone-whole`, and the short `tone-burst`). One-shots and cues repeat every 2 s; **P** plays one at once. `ambience` plays the wind and the crickets; **P** plays an owl.
- **Motion:** orbit (the **Orbit** button sets the distance: 150 to 900 px), sweep from left to right, or still. A click or tap places the source.
- **Playback** switches between Sample and Stream (Web build only).
- The slider sets the master volume, which is kept for the next visit.
- The text says where the source is and how loud it should be in each ear. The rings show the quiet and loud ranges.

The address can set it up for scripted measurements: `sound=<event or tone>`, `motion=orbit|sweep|still`, `mode=sample|stream`, `repeat=0` (one-shots only on **P**), and `probe=<x>:<y>,<x>:<y>,…` with `dwell=<seconds>`, which stands the source at each position in turn and announces each step in `window.soundCheckStep`.

## Testing on devices

Use headphones, and hold a phone sideways: upright, it shows only about 400 px of the world across, so the source leaves the screen and the text is tiny. Open the sound check on the device and tap once, so the browser lets the page play sound. The page needs a secure context: the deployed build (HTTPS), `http://localhost:8060` on the computer that serves the build, or another device with the browser setting from [pairing.md](pairing.md#testing-on-devices). Over a plain `http://` address in the local network, Godot 4.7.2 does not start at all ("Secure Context – use HTTPS").

1. **Direction.** *Sound:* `bleat` or `tone-loud`, *Motion:* orbit. The sound has to go round your head in step with the dot: right ear when it is right of the centre, left ear when it is left, both alike above and below.
2. **Distance and range.** *Orbit* through the distances. With `grass_move` (quiet) the sound is gone at 500 px and beyond; with `bleat` (loud) at 900 px. With `bell` (whole map) it is always there, quieter further away.
3. **Loops.** `grass_move`, `graze` and `herder_step` for a minute each. Listen for gaps or clicks.
4. **Sample and Stream.** Switch *Playback* and repeat 1. In Stream, listen for crackling and delay.
5. **Hidden page.** Switch to another tab or app while a sound plays: it has to stop, and come back when you return.
6. **The sound pass (#23).** Go through the new events, the cues and `ambience`: is each one clear, and is anything far too loud or too quiet next to the others? Then play a round: the ambience has to stay under the sounds of the flock and dip when the bell rings.

| Browser | Direction and range | Loops | Notes |
|:--|:-:|:-:|:--|
| Chrome 157, Windows (headless, measured) | ✅ | gaps of 8–32 ms per loop | see the measurements above |
| Chrome, Windows (by ear) | ✅ | ✅ | 2026-11-15. Afterwards bleats were halved and the sprint made louder (#73) |
| Firefox, Windows (by ear) | pending | pending | |
| Chrome, Android (by ear) | pending | pending | |
| Safari, iOS and macOS | not tested | not tested | no device available |

## Sounds

The [AudioCatalog](../systems/audio/audio_catalog.tres) gives every event, cue and ambience layer an [AudioCue](../systems/audio/audio_cue.gd): its variations, bus, volume, pitch variation and fade, whether it ducks the ambience, and for a layer of one-shots (the owl) how often it plays. Each one-shot picks a variation and a pitch at random; a loop uses its first sound, imported with looping on. To change a sound, replace its file or its cue in the catalog; nothing else has to change.

The sounds are in `assets/audio/`, by who makes them: `sheep/`, `sheepherder/`, `monster/`, `companions/`, `world/` (the torches), `cues/` (one player's cues), `ui/` (menus and the round's flow) and `ambience/`. They are mono 44.1 kHz Ogg Vorbis, 1.9 MB together.

- **Recorded for the game** by FrankAntonGabriel: the eight bleats, the rustle and the Sheepherder's footsteps.
- **CC0**, from Freesound and OpenGameArt: everything else.

[assets/ATTRIBUTION.md](../assets/ATTRIBUTION.md) lists every source and what was taken from it.

**Levels.** Sounds in the world are levelled to a peak of −1 dBFS, their loops to an RMS of −27 dBFS; the catalog sets how loud each one plays. Cues are levelled by their loudest 300 ms (−20 to −26 dBFS, so that a short click and a long chord sound alike), the ambience to an RMS of −30 dBFS (wind) and −33 dBFS (crickets), and the catalog plays it 10 dB lower. These are starting points for listening on devices (step 6 above), not measured loudness.

## Known limits

- **Loop gaps in the Web build** (see above). If they are audible on devices, the next step is longer loops, or a sound pass that hides the seam in a pause.
- **Panning follows the screen.** It goes by the share of the screen width, as in Godot: on a phone held upright, which shows less of the world across, a sound to the side pans further than on a wide screen.
- **Stream playback** is unusable without Thread Support. Revisiting that needs the Progressive Web App option ([web-build.md](web-build.md#decision-no-thread-support-no-progressive-web-app)).
- **Partly heard by a person.** Chrome on Windows was checked by ear before the sound pass (#23); its sounds and the other devices are still to be heard.
