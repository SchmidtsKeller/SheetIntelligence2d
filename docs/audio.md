# Audio: spatial sound and the Web build

How sounds are heard in the game (GDD §5, §7.2), why the Web build plays them the way it does (GDD §9.1), and what was measured while building it (#10). How to use the service from code is in the README, *Audio*.

## How a sound is heard

Every sound happens somewhere in the world and is heard from the local player's character (the *listener*), whether or not its source can be seen.

- **Range.** Each event belongs to a hearing-range class ([AudioEvents](../abstractions/types/audio_events.gd)): quiet (400 px), loud (800 px) or whole map. The volume falls from full at the listener to silence at the end of the range. Whole-map sounds fade out only at `audio_whole_map_distance` (8000 px, twice the arena's diagonal): they are heard everywhere, about half as loud across the whole arena, so their distance can still be judged.
- **Direction.** The sound pans by where it is across the screen: a sound at the edge of a 16:9 screen plays at 7/8 of its volume in the near ear and 1/8 in the far one (`audio_panning_strength` 3 × the project's 2D panning strength 0.5). Left and right are those of the screen; the listener never turns with the character.
- **Formula.** Playback is Godot's `AudioStreamPlayer2D`, for which `volume = (1 − distance / range)^attenuation` (attenuation 1 for every placeholder) and `pan = 0.5 + 0.5 × s × x / w`, limited to 0..1: `x` is how far the sound is to the right, `w` how much of the world the screen shows across, and `s` = 3 × 0.5. The right ear gets `volume × pan`, the left `volume × (1 − pan)`. [AudioMix.ear_gains()](../systems/audio/audio_mix.gd) states the same formula; the unit tests and the sound check use it, and the measurements below compare the browser's output with it.

| Event | Range | Heard by | Plays from |
|:--|:--|:--|:--|
| `grass_move`, `graze` | quiet | both | a sheep's or the Monster's picture (loop) |
| `herder_step` | quiet | both | the Sheepherder (loop) |
| `reload_click` | quiet | **the Sheepherder's player only** | the Sheepherder |
| `bleat`, `eat`, `dog_bark`, `bat` | loud | both | where it happens |
| `bell`, `gunshot`, `spider_screech` | whole map | both | where it happens |

**No audio tell.** NPC sheep and the Monster use the same cue, variations and range, and a sheep's sounds come from where it is shown, a moment in the past like its picture (see [no-tell-audit.md](no-tell-audit.md), points 6 and 7). The reload click is heard only by the Sheepherder, so the reload after the third shot does not reveal a Spare Bullet (GDD §4.1).

**Own sounds.** On a player's own device, the looping sounds of their own character (footsteps, rustle, grazing) play `audio_own_sound_volume_db` (−10 dB) quieter, so they don't cover the sounds nearby. The other player hears them as usual.

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

- **A short gap** each time a loop starts again: 8–32 ms in the measurements, with software rendering keeping the main thread busy. The loops are therefore long (rustle 8 s, grazing 12 s, footsteps 4 s), so a gap comes rarely and falls into sounds that have pauses of their own.
- **A loop always starts again where the sample was started.** So emitters always start from the beginning of their sound, never at a random point or where they last stopped.

### Measured how

Chrome 157 on Windows 11, headless with software rendering (SwiftShader), 48 kHz, debug Web build served from this computer. A script added before the page's own code wraps the page's `AudioContext` and copies everything sent to the speakers into an `AudioWorklet` on the audio thread, which records the level of each ear every 128 frames. The sound check (below) placed a steady 441 Hz tone at fixed positions for 0.8 s each and announced each step, so the levels could be matched to the position and compared with [AudioMix.ear_gains()](../systems/audio/audio_mix.gd), relative to the level at the listener. Latency is from the key press to the first sample of the sound at the speakers, using the browser's own estimate of its output latency.

A real device has a faster main thread than this headless setup, so loop gaps should be shorter there, and Stream may drop out less. Whether the result holds on phones is what the device tests below are for.

## The sound check

[systems/audio/sandbox/sound_check.tscn](../systems/audio/sandbox/sound_check.tscn) moves one sound source around the listener in the middle of the screen. Run it with **F6**, or open the Web build with `?sound-check` in the address, e.g. <https://schmidtskeller.github.io/SheetIntelligence2d/?sound-check>.

- **Sound** cycles through every event of the game and four test tones (`tone-quiet`, `tone-loud`, `tone-whole`, and the short `tone-burst`). One-shots repeat every 2 s; **P** plays one at once.
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

| Browser | Direction and range | Loops | Notes |
|:--|:-:|:-:|:--|
| Chrome 157, Windows (headless, measured) | ✅ | gaps of 8–32 ms per loop | see the measurements above |
| Chrome, Windows (by ear) | pending | pending | |
| Firefox, Windows (by ear) | pending | pending | |
| Chrome, Android (by ear) | pending | pending | |
| Safari, iOS and macOS | not tested | not tested | no device available |

## Sounds

The [AudioCatalog](../systems/audio/audio_catalog.tres) gives every event an [AudioCue](../systems/audio/audio_cue.gd): its variations, bus, volume, pitch variation and fade. Each one-shot picks a variation and a pitch at random; a loop uses its first sound, imported with looping on. The sound pass (#23) replaces the placeholders in the catalog; nothing else has to change.

The placeholders in `assets/audio/placeholder/` are CC0 recordings from Freesound and OpenGameArt, cut, converted to mono 44.1 kHz Ogg Vorbis and levelled; [assets/ATTRIBUTION.md](../assets/ATTRIBUTION.md) lists every source. Together they are 0.6 MB.

## Known limits

- **Loop gaps in the Web build** (see above). If they are audible on devices, the next step is longer loops, or a sound pass that hides the seam in a pause.
- **Panning follows the screen.** It goes by the share of the screen width, as in Godot: on a phone held upright, which shows less of the world across, a sound to the side pans further than on a wide screen.
- **Stream playback** is unusable without Thread Support. Revisiting that needs the Progressive Web App option ([web-build.md](web-build.md#decision-no-thread-support-no-progressive-web-app)).
- **Not heard by a person yet.** The measurements compare numbers; the device tests above are still to be done.
