# Hide in Sheep Clothing

An asymmetric 1v1 social deduction game for the browser. One player is the **Sheepherder**, who protects a flock and hunts an impostor with a flashlight and three bullets. The other is the **Monster**, disguised as a sheep, who eats the flock from the inside.

- Game design and technical overview: [game_design_technical_overview_document.md](game_design_technical_overview_document.md) (the "GDD")
- Workflow for contributors and agents: [CLAUDE.md](CLAUDE.md)
- Task order and dependencies: roadmap issue [#4](https://github.com/SchmidtsKeller/SheetIntelligence2d/issues/4)

## Requirements

- **Godot 4.7** (strictly this version, GDD §9.1), **standard build**. The project uses GDScript only. The .NET build of Godot can run the project and the tests, but it cannot export to the Web.
- For the Web build: the Web export templates of the same version (*Editor → Manage Export Templates*).

## Run the project

Open the folder in the Godot 4.7 editor and press **F5**, or from a terminal:

```bash
godot --path .
```

The game starts in the boot screen, which checks the services and hands over to the lobby. In the [lobby](#lobby-and-scoreboard) both players choose a perk and get ready; then the match begins: five rounds with the rules of GDD §2, each followed by the scoreboard (see [Round rules and match flow](#round-rules-and-match-flow)). Without a second instance you play alone, against the computer (see [Offline match against the computer](#offline-match-against-the-computer)).

The sheep gallery ([entities/sheep/gallery/sheep_gallery.tscn](entities/sheep/gallery/sheep_gallery.tscn), run it with **F6**) shows the sheep of one round at gameplay zoom, with buttons for every animation state, a new round and darkness with a light at the mouse.

The arena sandbox ([systems/arena/arena_sandbox.tscn](systems/arena/arena_sandbox.tscn), **F6**) shows the whole arena with a round's spawn layout. Its buttons let the sheep wander into obstacles and borders, switch the debug overlay (footprints, occluders, borders, spawn areas) and change the zoom.

The Sheepherder sandbox ([entities/sheepherder/sandbox/sheepherder_sandbox.tscn](entities/sheepherder/sandbox/sheepherder_sandbox.tscn), **F6**) puts you in the arena as the Sheepherder, among a round's sheep that stand still: walk with WASD, aim with the mouse, ring the bell with Space and shoot with the left mouse button.

The vision sandbox ([systems/vision/sandbox/vision_sandbox.tscn](systems/vision/sandbox/vision_sandbox.tscn), **F6**) shows a round's flock in the dark through the Sheepherder's flashlight, or as the Monster sees it, with a sheep in the Monster's slot to steer. Its overlay rings every entity green (seen) or red (hidden). Its perk picker gives the player whose view is shown a perk (Q uses the Monster's invisibility); the Monster's view shows nothing of the Sheepherder's perk.

The sound check ([systems/audio/sandbox/sound_check.tscn](systems/audio/sandbox/sound_check.tscn), **F6**, or the Web build with `?sound-check` in the address) moves one sound around the listener: choose the sound and how it moves, click to place it, and hear whether it comes from the right side and fades out at the end of its range. It says how loud the sound should be in each ear (see [docs/audio.md](docs/audio.md)).

The Monster sandbox ([entities/monster/sandbox/monster_sandbox.tscn](entities/monster/sandbox/monster_sandbox.tscn), **F6**) is a round without rules: you are the Monster among a round's flock, with a Sheepherder who only stands there. Walk with WASD, sprint with Shift, graze with C, bleat with F and eat with E; the status line shows stamina, the eaten count and the attack's cooldown, and a button lets the Sheepherder shoot at you. Started twice with `-- --host` and `-- --join`, it is the same round between two players.

### Two instances on one computer

The game is always played by two devices. For development, two desktop instances connect to each other by themselves:

```bash
godot --path . -- --host
```

```bash
godot --path . -- --join
```

Both end up in the lobby, which shows who is host and who plays which role. The match starts when both are ready; after every round both get ready again on the scoreboard. Flags for a simulated bad connection, the network demo scene and the automated two-instance checks are described in [docs/networking.md](docs/networking.md#development-two-instances-on-one-computer).

For automated checks, `--perk=<id>[,<id>]` selects perks for the roles an instance plays without the lobby, e.g. `godot --path . -- --join --perk=long_flashlight,invisibility`. The ids are those in [PerkIds](abstractions/types/perk_ids.gd).

## Run the tests

```bash
tools/run_tests.sh
```

On Windows:

```powershell
tools\run_tests.ps1
```

Both use the executable named by the `GODOT` environment variable, or `godot` from the `PATH`. On Windows, point `GODOT` at the `*_console.exe` so the output appears in the terminal. The exit code is 0 when all tests pass.

| Option | Effect |
|:--|:--|
| `--filter=<text>` | Run only tests whose file path or method name contains the text |
| `--quiet` | Print only failures and the summary |

The script imports the project and then runs the test scene. The two steps by hand:

```bash
godot --headless --path . --import
```

```bash
godot --headless --path . res://tests/test_runner.tscn
```

The import is needed once after cloning and whenever a `class_name` is added: scripts find each other's classes through the import cache in `.godot/`, which is not in the repository.

### Writing a test

A test file is a script named `test_*.gd` anywhere below `tests/` that extends `TestCase`. Every method starting with `test_` is one test:

```gdscript
extends TestCase

func test_bell_reaches_sheep_inside_the_radius() -> void:
	var swarm: StubSwarmService = autofree(StubSwarmService.new())
	watch_signals(swarm)

	swarm.ring_bell(Vector2.ZERO, 400.0)

	assert_signal_emitted_with(swarm, &"bell_rung", [Vector2.ZERO, 400.0])
```

`TestCase` ([tests/framework/test_case.gd](tests/framework/test_case.gd)) provides the assertions, signal watching, `autofree`, `before_each` / `after_each` hooks and `await wait_frames()`. A test fails if an assertion fails, if it makes no assertion, or if the engine reports an error that the test did not announce with `expect_error()`. That last rule is what catches script errors, which would otherwise pass silently in a headless run.

The harness lives in the repository and has no dependencies, so it cannot fall behind the engine version. GUT and gdUnit4 are the usual choices; they were not evaluated against Godot 4.7 for this project. The assertion names follow GUT's, so switching later is mostly a change of the base class.

## Web build

The game ships as a Web build. Details, including the reasoning behind the export settings, are in [docs/web-build.md](docs/web-build.md).

**Build and serve locally.** Export the Web build and serve it at <http://localhost:8060>:

```bash
tools/export_web.sh --serve
```

On Windows: `tools\export_web.ps1 --serve`. Add `--debug` for a debug build.

**Continuous integration.** Every pull request and every push to `main` runs the format and lint check, the import check with the unit tests, and the Web export. The exported build of a pull request can be downloaded from its CI run as the artifact `web-build`.

**Deployment.** Every push to `main` is deployed to GitHub Pages: <https://schmidtskeller.github.io/SheetIntelligence2d/>. Pages has to be enabled once by the repository owner (*Settings → Pages → Source: GitHub Actions*).

**Pairing.** In the Web build two browsers connect without a server, by exchanging a QR code or text code in each direction (WebRTC). How it works, what was measured and how to test it on devices is in [docs/pairing.md](docs/pairing.md).

**Test on your phone.** Open the deployed build on the phone, with both devices in the same Wi-Fi. A build served from your computer as `http://<lan-ip>:8060` is fine for layout and touch controls, but not for pairing: browsers allow camera and clipboard access only over HTTPS or on `localhost` (a Chrome flag helps on Android, see [docs/pairing.md](docs/pairing.md#testing-on-devices)).

**Thread Support** is off and the Progressive Web App option is not used, because GitHub Pages cannot send the cross-origin isolation headers that threads need. This affects audio latency in *Stream* mode; see the decision in [docs/web-build.md](docs/web-build.md#decision-no-thread-support-no-progressive-web-app).

## Architecture

The code follows two rules from GDD §9.2: **separation of concerns** through service contracts, and **one source of truth** for every number and name.

```text
res://
├── abstractions/     Service contracts (abstract classes) and the shared vocabulary in types/
├── services/         Service registry, composition root, implementations (stubs/ until the real ones exist)
├── entities/         Sheepherder, Monster, NPC sheep, companions, obstacles
├── systems/          Game config, scene flow, view rule, arena, session, input, flock, vision, audio, perks, match rules, seeded randomness
├── ui/               Screens, lobby, HUD
├── assets/           Sprites, shaders, audio
├── tests/            Test harness (framework/) and tests (unit/)
├── tools/            Developer scripts: tests, import check, Web export, local server
├── web/              Page files that ship next to the exported game
└── docs/             Decisions and how-tos
```

### Service contracts

Each core system is an `@abstract` class in `abstractions/` that extends `Node`:

| Contract | Responsibility |
|:--|:--|
| `InputService` | Movement and aim vectors, action signals; unifies keyboard/mouse and touch; role-aware; action locks |
| `NetworkService` | The connection between the two devices: lifecycle, host/guest, pairing codes, the `MultiplayerPeer` |
| `SwarmService` | The NPC flock: spawning, bell, deaths, living count, flock neighbours |
| `CombatService` | Firearm (ammo, reload, shots), the Monster's attack, evolution, all kill events |
| `PerkService` | Perk selection and the modifier-aware stat lookup |
| `AudioService` | Sound events at world positions, emitters, listener, hearing ranges |

Every contract has a stub in `services/stubs/`, which is registered until the real implementation is merged (input, the flock, combat, perks and audio are real by now). A stub is inert but honours the contract (the `PerkService` stub returns the plain config values, the `NetworkService` stub is an offline session of one), so a feature can be built and tested before the real implementation of a neighbouring service is merged.

### Service registry

`Services` (autoload, [services/services.gd](services/services.gd)) maps each contract to its current implementation:

```gdscript
var speed: float = Services.perks.get_stat(StatIds.HERDER_MOVE_SPEED)
Services.audio.play_event(AudioEvents.BELL, global_position)
Services.resolve(SwarmService)            # the same, by contract
Services.replace(InputService, fake)      # swap an implementation, e.g. in a test
```

- Asking for a contract without an implementation is a programming error and fails loudly.
- Implementations become children of the registry, named after their **contract**. Their node path (`/root/Services/NetworkService`) is the same on both devices whatever the implementation, which RPCs rely on.
- [services/service_bootstrap.gd](services/service_bootstrap.gd) is the composition root: the only place that names concrete implementations. A task that delivers a real service changes one line there.

**Rule:** gameplay, UI and entity code never reference a concrete service class, only the contract.

### Game configuration and stats

[systems/config/game_config.gd](systems/config/game_config.gd) holds every number of GDD §5 with the documented default; the shipped instance `game_config.tres` can be tuned in the editor. A test compares both against the GDD table.

**Rule:** no gameplay code contains a gameplay number, and none reads `GameConfig` directly. It asks the stat lookup:

```gdscript
var cone_angle: float = Services.perks.get_stat(StatIds.FLASHLIGHT_CONE_ANGLE_DEG)
var bullets: int = Services.perks.get_stat_int(StatIds.FIREARM_AMMO)
```

`get_stat` returns the base value with all active modifiers applied. That is how *Wide Flashlight*, *Spare Bullet* or the bat change behaviour later without any change to the code that uses the number. A stat id is the name of its `GameConfig` property; a test keeps `StatIds` and `GameConfig` identical.

### Shared vocabulary

`abstractions/types/` names everything two systems have to agree on, so nobody types a string or a magic number twice:

| Class | Contents |
|:--|:--|
| `GameEnums` | `Role`, `RoundOutcome`, `RoundEndReason`, `SheepPhase`, `DeathCause`, `MonsterForm`, `HearingRange` |
| `PerkIds` | The ids of the eight perks; which role's pool each is in comes from the perk catalog |
| `AudioEvents` | The sound events and their hearing-range class |
| `StatIds` | The stats of the lookup |
| `InputActions` | The input actions and the action set of each role |
| `PhysicsLayers` | The 2D physics layers as bit masks |
| `Groups` | The node groups |

### Seeded randomness

Everything both devices derive from a seed, such as the look of a sheep, uses [SeededRandom](systems/random/seeded_random.gd), never `RandomNumberGenerator` or the global `randi()`. It is integer-only, so a seed gives the same numbers on every platform; Godot documents the algorithm of `RandomNumberGenerator` as an implementation detail.

### Arena and line of sight

The [Arena](systems/arena/arena.gd) is the playing field. It provides:

- its bounds and play area
- the layers to place things in (entities, decals, overlays)
- obstacle footprints for steering
- free-position sampling and a round's spawn layout
- camera limits

Its size comes from the config, and the borders are built from it.

Every obstacle type is a scene with the [ArenaObstacle](entities/obstacles/arena_obstacle.gd) script. Its `Footprint` polygon is the one shape that blocks movement, sight and light: the light occluder is built from it. Its `Art` sprite only shows it.

**Painted pieces (#83).** The obstacles, the fence, the river, the torches and the scattered ground details are painted, and so are the menu boards, buttons and touch controls ([PaintedUi](ui/theme/painted_ui.gd)). They are cut from two collage sheets in `resources/art_sources/` (`uiElements.webp`, `MapElements.webp`) by [tools/cut_art_sheets.gd](tools/cut_art_sheets.gd), which knows where each piece sits on its sheet, removes the flat background and writes one PNG per piece into `assets/ui/painted/` and `assets/arena/painted/`. After editing a sheet, cut again and re-import:

```bash
godot --headless --path . --script res://tools/cut_art_sheets.gd
```

The HUD's action icons, bars and bullet icon and the large board are painted too (#96). Nothing on screen says "Placeholder" any more: what has no image yet is drawn plainly or left out (`PlaceholderArt.marks_shown` brings the marks back while developing). What still waits for a painted image is listed in [toBeCreatedAsImage.txt](toBeCreatedAsImage.txt), and [toBeCreatedAsImagePrompts.md](toBeCreatedAsImagePrompts.md) has a ready-to-paste generation prompt for each of them and for the placeholder sounds.

**Font (#86).** All text is set in *IM Fell English* (`assets/fonts/`, SIL Open Font License), old print with worn ink: through the shared theme, and as the fallback font of everything else, set at start-up by `GameTheme.use_font_everywhere()` from the `SceneFlow` autoload (not through the `gui/theme/custom_font` project setting, which fails the first import of a fresh clone). Its digits are old-style figures, so the small HUD texts are set a little larger.

**Rule:** whatever asks "can A see B" or "what does this ray hit" uses [WorldQueries](systems/arena/world_queries.gd). Only obstacles and borders (physics layer `world`) block sight; characters and sheep never do. A ray that ends at a border, not an obstacle, has left the map.

### The flock

`Services.swarm` is the `FlockSwarmService` ([services/swarm/flock_swarm_service.gd](services/swarm/flock_swarm_service.gd)): the ten NPC sheep of a round (GDD §3.3). The host simulates them; the guest gets the same sheep through the session.

```gdscript
Services.swarm.spawn_flock(round_seed)                      # host, once the arena is in the tree
Services.swarm.ring_bell(origin, Services.perks.get_stat(StatIds.BELL_RADIUS))   # either device
Services.swarm.kill_sheep(sheep_id, GameEnums.DeathCause.SHOT)                   # host
Services.swarm.register_neighbour(monster_body)             # the flock treats it as one of its own
```

- **Behaviour.** Each sheep has a [FlockAgent](systems/flock/flock_agent.gd) that strings together plain segments: walk a short way, stand, graze, and bleat now and then. Where a walk leads is decided when it starts: somewhere nearby, leaning toward where the others are heading and back toward the flock when the sheep has strayed. While walking, the forces in [FlockSteering](systems/flock/flock_steering.gd) keep it apart from the others and clear of obstacles and borders. There is nothing in it a player could not do with a stick and two buttons, which is the point: the Monster has to pass as one of them.
- **Bell.** Living sheep within the radius walk to where it rang, stop a few steps short and return to normal after `bell_follow_time`. Sheep outside the radius do not react.
- **Tuning.** Every duration, distance and chance is in the *Flock* group of the game config.
- **Deterministic start.** Positions, looks and minds follow from the round seed. A round has `flock_size + 1` slots for sheep-like entities; [RoundCast](systems/flock/round_cast.gd) names the slot the flock leaves free for the Monster, so the Monster (#16) and the round (#17) take its position and visual seed from the same place.
- **The arena** is found through the group `arena`; the sheep live in its entities layer.

The flock sandbox ([systems/flock/sandbox/flock_sandbox.tscn](systems/flock/sandbox/flock_sandbox.tscn), **F6**) shows a round's flock in the arena, with one more sheep in the Monster's slot that can be steered with the Monster's keys. A click rings the bell there; the buttons start a new flock, switch the debug overlay (activity, target and steering per sheep, the reach of the last bell), run a time lapse and kill a sheep.

### The Monster

The [Monster](entities/monster/monster.gd) (GDD §3.2) has no body of its own. It is one node inside the shared sheep body, spawned in the slot the flock leaves free:

```gdscript
Monster.register(Services.session)                                   # both devices, before the round
Services.session.entities.spawn(Monster.KIND, owner_id, Monster.spawn_data(round_seed, arena))   # host
Services.combat.begin_round(sheepherder, Monster.of(body).get_body())
```

- **Disguise.** Same scene, same replication and same layer as an NPC sheep, steered through the same motion model, grazing and bleat. Whatever would tell it apart on the Sheepherder's device is a bug: [docs/no-tell-audit.md](docs/no-tell-audit.md) is the checklist, and `tests/unit/test_monster_no_tell.gd` works through it.
- **Sprint.** Hold to move at `monster_sprint_speed` while the stamina lasts ([MonsterStamina](entities/monster/monster_stamina.gd)). An empty meter ends the sprint until the button is let go of; it refills whenever the Monster is not sprinting.
- **Eating.** `Services.combat.request_eat()` asks the host, which looks for something within `melee_range`: a living sheep, the body of a shot one, or the Sheepherder once `herder_kill_threshold` sheep are eaten. The Monster is locked for `eat_duration`, and the cooldown starts when that ends. Other systems can forbid the attack with `add_eat_blocker()` and ask `is_eating()`.
- **Evolution.** Every eaten sheep counts, also the body of one the Sheepherder shot (which gives no points: `get_eaten_alive_count()`). At `spider_evolution_threshold` the Monster becomes the [spider](entities/monster/spider_visual.gd) when it has finished eating: faster, without sprint or mimicry, and bullets do nothing to it.
- **For the HUD:** `get_stamina_ratio()`, `is_sprinting()` and `get_form()` on the Monster; `get_eaten_count()`, `get_eat_cooldown_remaining()`, `can_kill_sheepherder()` and `is_monster_killable()` on the combat service.

### Vision

What a player sees is decided on their own device by the [VisionSystem](systems/vision/vision_system.gd) (GDD §3.1, §3.2). It changes only what is drawn, never the simulation or what is sent.

- **Sheepherder:** a dim night (darker, not black), in which static scenery stays readable. Entities and blood are seen only where light falls on them: the [flashlight](entities/sheepherder/flashlight_light.gd) or a lit [torch](entities/torch/torch.gd), not blocked by an obstacle. [LightRules](systems/vision/light_rules.gd) gives every point a light level from 0 to 1: full inside the cone and near a torch, fading out softly beyond. An entity is shown as bright as the light on it and counts as seen at half light or more. The bots' senses ([BotSenses](systems/bots/bot_senses.gd)) ask the same `LightRules`, so the bots see what a player would.
- **Monster:** no darkness. Entities are seen unless an obstacle hides them; all of the ground is seen, including blood and the Sheepherder's light. It sees the world through its [NightVision](systems/vision/night_vision.gd) (#90): a dark-red vignette at the edges of the screen and a subtle filter (less saturated, shifted toward red and amber, a little grain, lifted shadows), a little stronger in spider form. It is shown only on the Monster's device, below the HUD, the touch controls and the banners, and changes nothing of what is seen. Its look is tuned in [night_vision.tscn](systems/vision/night_vision.tscn).
- **Everybody** always sees their own character.
- **The invisible Monster** (a cloaked `VisionTarget`) is seen by nobody else; its own player sees it faded.

**Rule:** anything that may be hidden (a character, a sheep, a companion, a mark on the ground) has a [VisionTarget](systems/vision/vision_target.gd) child that names the part to fade, and its root is in the group `dynamic_entities`. Effects that belong to it (a muzzle flash, an eating effect) are attached to that target with `attach()`, so they are never seen when the entity is not. There are no rules per entity type.

**Torches** stand at fixed spots in the arena (`Torches` in [arena.tscn](systems/arena/arena.tscn)). The host lights one when a living Sheepherder walks up to it and announces it with `arena.torch_lit`; it burns for the rest of the round. The flicker, the sway of the flashlight while walking and the dust and embers are presentation only.

The round puts a `VisionSystem` into the world (for example the arena's overlays layer) and sets its `role` and `viewer`, the local player's character. A [BloodDecalSpawner](entities/evidence/blood_decal_spawner.gd) leaves blood wherever the combat service reports it.

### Audio

`Services.audio` is the `SpatialAudioService` ([services/audio/spatial_audio_service.gd](services/audio/spatial_audio_service.gd)). Every sound is played where it happens and heard from the local player's character (GDD §7.2), whether or not its source can be seen.

```gdscript
Services.audio.play_event(AudioEvents.BLEAT, global_position)                  # a one-shot in the world
var steps: int = Services.audio.start_emitter(AudioEvents.HERDER_STEP, self)   # a loop that follows a node
Services.audio.set_emitter_playing(steps, walking)
Services.audio.set_listener(character)                                         # the round does this
```

- **Hearing ranges.** [AudioEvents](abstractions/types/audio_events.gd) gives each event its range class: quiet (400 px), loud (800 px) or whole map. A sound fades from full at the listener to silence at the end of its range, and pans by where it is across the screen ([AudioMix](systems/audio/audio_mix.gd)). Whole-map sounds fade out only at `audio_whole_map_distance` (8000 px), so they are heard everywhere and still sound further away.
- **Catalog.** The [AudioCatalog](systems/audio/audio_catalog.tres) gives every event an [AudioCue](systems/audio/audio_cue.gd): its variations, bus, volume, pitch variation and fade. The sounds are placeholders, listed with their sources in [assets/ATTRIBUTION.md](assets/ATTRIBUTION.md); the sound pass (#23) replaces them in the catalog.
- **No audio tell.** NPC sheep and the Monster share every sound, and a sheep's sounds come from where it is shown, with the same delay as its picture.
- **Own sounds.** On a player's own device, the looping sounds of their own character (footsteps, rustle, grazing) play `audio_own_sound_volume_db` (−10 dB) quieter, so they don't cover the sounds nearby.
- **The reload click** is heard only by the Sheepherder's player, so the Spare Bullet stays hidden (GDD §4.1).
- **Buses:** Master, Effects, Ambience and UI ([default_bus_layout.tres](default_bus_layout.tres)). `set_bus_volume` keeps the volume in `user://settings.cfg` for the next start.
- **Web build.** Audio starts with the first click, tap or key press (a browser rule), and is muted while the page is hidden. The playback type and what was measured are in [docs/audio.md](docs/audio.md).

### Perks

`Services.perks` is the `SessionPerkService` ([services/perks/session_perk_service.gd](services/perks/session_perk_service.gd)): the stat lookup with its modifiers, both players' perk choice and the active perks (GDD §4).

- **Data.** Every perk is a [PerkDefinition](systems/perks/perk_definition.gd) resource in [systems/perks/definitions/](systems/perks/definitions), listed in the [catalog](systems/perks/perk_catalog.tres): its role, kind, name, description and icon. A passive perk lists [modifiers](systems/perks/perk_modifier.gd) that set a stat to the configured value of another (Wide Flashlight sets `flashlight_cone_angle_deg` to `perk_wide_flashlight_angle_deg`), so every number stays in the game config. A perk that does more names a [PerkEffect](systems/perks/perk_effect.gd) script: triggered with the perk button (`triggered`), like [InvisibilityEffect](systems/perks/effects/invisibility_effect.gd) and the bat, or running from the moment the round has its character, like the dog. A new perk is a new resource in the catalog, plus an effect script if it does more than change stats.
- **Round.** Each player selects one perk from their role's pool; the host locks both selections at round start and clears them after the round. Lock before `CombatService.begin_round`, which reads the magazine size.
- **Both devices** know both perks and apply the same modifiers, so every stat has the same value on both. Keeping the Sheepherder's choice off the Monster's screen is up to what is drawn there.
- **Active perks** are triggered with the `perk` action (`Services.perks.use_perk(role)`, which ends a running invisibility early). The host decides when one starts and ends; `is_perk_active`, `get_perk_charge` and `get_perk_cooldown_remaining` are what the HUD shows. Both characters register themselves with `register_character`, so perks find them with `get_character(role)`.
- **Companions** (GDD §4.1, §4.2) are replicated entities that the host simulates:
  - The [ShepherdDog](entities/companions/shepherd_dog.gd) stays near the Sheepherder all round. It barks and faces the Monster while the Monster eats a living sheep within 800 px, and passes through sheep and the Sheepherder.
  - The [AlliedBat](entities/companions/allied_bat.gd) flies in from the edge nearest the Sheepherder. While it circles them, the flashlight cone is shorter and narrower. Bullets pass through it.
  - Their numbers are in the *Companions* and *Perks* groups of the game config. In the [Monster sandbox](entities/monster/sandbox/monster_sandbox.tscn), start with `-- --perk=shepherd_dog,allied_bat` (Q sends the bat).

```gdscript
Services.perks.select_perk(GameEnums.Role.MONSTER, PerkIds.INVISIBILITY)   # the player's device
Services.perks.lock_selection()                                           # host, at round start
Services.perks.use_perk(GameEnums.Role.MONSTER)                           # the perk button
```

### Round rules and match flow

A match is a Best of 5 (GDD §2.3). `Services.match_flow` ([systems/match/match_flow.gd](systems/match/match_flow.gd)) runs it on the host and replicates it, so both devices always agree on the phase, the timer and the scores:

```text
setup → spawn → countdown → active → resolved → results ─┬→ setup   (next round with swapped roles, or a rematch)
                                                         └→ lobby   (the host ends the match)
```

| Phase | Lasts | What happens |
|:--|:--|:--|
| `SETUP` | `round_setup_duration` (0 s until the perk selection of #20 exists) | The window for choosing perks |
| `SPAWN` | a moment | The host locks the perks, draws the round's seed and the [RoundStage](systems/match/round_stage.gd) builds the round: flock, Sheepherder, Monster, vision, a clean ground, full ammo and no cooldowns |
| `COUNTDOWN` | `round_countdown_duration`, 3 s | Everybody is in place; nobody can act |
| `ACTIVE` | `round_duration`, 180 s | The round. **Gameplay input is enabled only in this phase** |
| `RESOLVED` | `round_resolved_duration`, 3 s | The round is decided and stays on screen with its outcome |
| `RESULTS` | until the host continues | The results screen. The perks of the round are cleared and the players get the roles of the next round, so each can choose a perk for the role they are about to play |

**Who wins a round** is decided by [RoundRules](systems/match/round_rules.gd), which has no scene, no session and no clock and is tested case by case in `tests/unit/test_round_rules.gd`:

- The **Sheepherder** wins by shooting the Monster before it is the spider.
- The **Monster** wins by killing the Sheepherder, which it can once `herder_kill_threshold` sheep are eaten.
- When the **time runs out**, the player with more points wins the round; equal points are a draw, which is no round win for anybody.
- An empty magazine ends nothing: the Monster cannot be killed anymore, and the round goes on.
- **Points** are always recorded, whoever wins: the Monster gets 1 for every sheep it ate alive (0 for the body of a shot one), the Sheepherder 1 for every sheep that survived and −2 for every sheep they shot.
- **Same tick.** The host reports lethal events in the order its combat service decides them, and the first one decides the round. The timer is looked at after the events of a tick, so a kill in the tick in which the time runs out still counts.

**The match.** [MatchScore](systems/match/match_score.gd) keeps the record of every round ([RoundResult](systems/match/round_result.gd)) and who played which role. All five rounds are played. Round 1 is played in the roles the session drew at random when it started, which are the ones the lobby shows; they swap after every round, and a rematch draws them anew when the last results come up, so that the players choose perks for the roles they will play. The player with more round wins takes the match; equal wins are a draw.

```gdscript
var flow: MatchFlow = Services.match_flow
flow.phase_changed.connect(_on_phase_changed)      # both devices
flow.round_resolved.connect(_on_round_resolved)    # both devices, with the RoundResult
flow.get_phase()                                   # MatchFlow.Phase
flow.get_round_time_left()                         # seconds, the same on both devices
flow.get_round_number()                            # 1 to 5
flow.get_score().get_round_wins(flow.get_local_player())
flow.get_last_result().get_sheepherder_points()
flow.request_next_round()                          # host, on the results screen
flow.request_rematch()                             # host, after the last round
flow.request_lobby()                               # host: end the match
flow.set_ready(true)                               # either device, in the lobby and on the results
flow.is_ready(MatchScore.Player.GUEST)             # the computer of an offline match always is
```

The host starts a match by taking both devices to the round screen: `Services.session.request_screen(SceneFlowController.Screen.ROUND)`. The [round screen](ui/screens/round_screen.gd) shows the round and the role in a plain line and carries the [HUD](#in-game-hud); the [results screen](ui/screens/results_screen.gd) is the scoreboard (see [Lobby and scoreboard](#lobby-and-scoreboard)). When the connection is lost, the match ends on the remaining device and it returns to the lobby.

### In-game HUD

The [Hud](ui/hud/hud.gd) on the round screen shows each player what their role needs (GDD §8.2, #21), and nothing of the other role's:

| Role | Elements |
|:--|:--|
| Both | Round timer, short messages ("Out of bullets", "You can kill the Sheepherder now", "… is ready") |
| Sheepherder | Bullets (3, or 4 with *Spare Bullet*), reload progress, Fire and Bell with their cooldowns; in the world, the [aim line](entities/sheepherder/aim_line.gd) to the first obstacle (it passes through sheep, so it never reveals a hidden one) |
| Monster | Evolution bar with the kill and the spider milestones (and when the spider is out of reach), living sheep, stamina, Graze / Bleat / Eat / Sprint and the active perk with its charge and cooldown |

- **Display only.** The HUD reads what the match flow, the combat service, the perk service and the round's characters expose; the arithmetic is in [HudReadout](ui/hud/hud_readout.gd), tested on its own. It switches with the roles by itself.
- **Keyboard and mouse:** the actions sit in a row at the bottom, each with its key, which the input layer names (`InputService.get_action_hint`).
- **Touchscreen:** no icons next to the buttons; the HUD hands each action's cooldown and meter to its touch button (`InputService.show_action_state`), which draws them. The HUD's own elements stay at the top, away from the controls in the bottom corners.

### Lobby and scoreboard

From page load to the first round (GDD §8.1, #20): pair once, see your role, choose a perk, get ready.

- **[Lobby](ui/screens/lobby_screen.gd).** Without a session, the Web build shows the pairing of #7 ([PairingPanel](ui/pairing/pairing_panel.gd)); a desktop build shows the match against the computer. In a session: who plays against whom, your role in round 1, the [PerkPicker](ui/lobby/perk_picker.gd), Ready and Leave.
- **Perk choice.** One perk from the pool of the role you play next, or none; each shows its name, its type (passive, active, companion) and what it does. The other role's perks and choice never appear on your screen (GDD §8.1). Ready locks the choice; it can be taken back until the other player is ready too.
- **Ready.** `MatchFlow.set_ready` tells the host; when both are ready, the host starts the match, the next round or the rematch. Offline, the computer is always ready.
- **[Scoreboard](ui/screens/results_screen.gd).** Left: the round's outcome and reason, both players' points with where they come from (GDD §8.2), the round wins and, after the last round, the winner and every round from your view. Right: the role you play next, the perk choice and Ready. The host can end the match and take both back to the lobby. Perks are not revealed.
- **Disconnects.** Losing the other player on any screen ends the session and returns to the lobby, which says why; on the Web the pairing panel offers to pair again.
- **Layout.** Two columns, so a phone held sideways shows all of it; smaller screens scroll.

### Offline match against the computer

One player can play a whole match on one device, without pairing (#57). In the Web build the lobby offers **Sheepherder vs. computer** and **Monster vs. computer** next to Host and Join; on the desktop the lobby has the same two buttons. The chosen role is the player's in round 1; the roles swap after every round as usual. Then the player chooses a perk and gets ready, like in a match of two.

- **Offline session.** `Services.session.play_offline()` starts a session of this device alone on every build. Where the transport needs a second device (WebRTC pairing), an offline transport stands in until the session ends; hosting or joining from the lobby ends the offline session first.
- **Bots.** The [RoundStage](systems/match/round_stage.gd) spawns the character nobody plays for this device, marked as a bot's: it gets its own [BotInput](systems/bots/bot_input.gd), never `Services.input`, and no camera. A [MonsterBot](systems/bots/monster_bot.gd) or [SheepherderBot](systems/bots/sheepherder_bot.gd) presses its buttons, only while the player may act too.
- **The bot Monster** hides with the flock's own mind ([FlockAgent](systems/flock/flock_agent.gd)) and is drawn through the same delay as the flock, so it has no built-in tell. It hunts when the attack is ready and the light cannot reach the meal (out of reach, behind an obstacle, or behind the Sheepherder's back), walks away from the blood, and goes for the Sheepherder once it may kill them.
- **The bot Sheepherder** sees only what its light shows ([BotSenses](systems/bots/bot_senses.gd)) and hears eating roughly where it was. It suspects a sheep it sees eating, running, or standing where it heard eating, shoots the most suspicious one after a reaction time and with an aiming error, keeps near the flock, sweeps its light, rings the bell and runs from the spider. It never knows which sheep is the Monster, so it can shoot the wrong one.
- **Tuning.** Every bot number is in the *Bots* group of the game config.

**Bot against bot.** [systems/bots/check/bot_match_check.tscn](systems/bots/check/bot_match_check.tscn) gives the player's character a bot as well and plays whole matches faster than real time, printing every round:

```bash
godot --headless --path . res://systems/bots/check/bot_match_check.tscn -- --speed=6 --matches=2
```

### Scene flow

`SceneFlow` (autoload, [systems/flow/scene_flow_controller.gd](systems/flow/scene_flow_controller.gd)) knows which screen is shown and which may follow:

```text
boot → lobby → round → results ─┬→ round   (next round)
                 │              └→ lobby   (match over)
                 └→ lobby                  (disconnect)
```

`SceneFlow.go_to(SceneFlowController.Screen.ROUND)` changes the scene and refuses transitions the flow does not allow. Each screen is a scene in `ui/screens/`; a task replaces a placeholder (the lobby is the last one) by setting `SceneFlow.screen_scenes[...]`.

### Session and replication

`Services.session` ([systems/session/game_session.gd](systems/session/game_session.gd)) sits between the connection and the game. It knows who is host, who plays which role and which screen both devices are on, and it owns the building blocks every networked feature uses: reliable ordered events, unreliable snapshots with interpolation, host-owned synced values, and spawning of replicated entities with stable ids.

The host decides the flock, combat and the round; each player moves their own character. The conventions (authority table, channels, tick rate, how to add a replicated entity or event) are in [docs/networking.md](docs/networking.md).

**Rule:** gameplay code talks to the session, never to a transport or to Godot's multiplayer API directly.

## Project settings

### Display and the view-fairness rule

- Base viewport **1280 × 720**, stretch mode `canvas_items`, aspect `expand`, Compatibility renderer (required for the Web).
- `expand` lets the UI use the whole screen on any device, which the touch controls need. On its own it would also show more of the world on wider screens, and the Monster sees everything in view. So the amount of visible world is capped separately: every gameplay camera takes its zoom from `ViewRules.camera_zoom()` ([systems/view/view_rules.gd](systems/view/view_rules.gd)), which fits the view into **1600 × 900 world pixels** (`GameConfig.view_max_world_*`). A 16:9 screen sees exactly that; any other shape sees less along one axis and never more.

### Input actions

Declared in the InputMap and named in `InputActions`. Only the `InputService` implementation reads them.

| Action | Default | Role |
|:--|:--|:--|
| `move_left` / `move_right` / `move_up` / `move_down` | `A` `D` `W` `S` and arrow keys | both |
| `aim_left` / `aim_right` / `aim_up` / `aim_down` | none: the mouse aims on PC, the right virtual joystick on touch | Sheepherder |
| `shoot` | left mouse button | Sheepherder |
| `bell` | `Space` | Sheepherder |
| `graze` (hold) | `C` | Monster |
| `bleat` | `F` | Monster |
| `eat` | `E` | Monster |
| `sprint` (hold) | `Shift` | Monster |
| `perk` | `Q` | Monster |

The bindings are a proposal. `Ctrl`, `Alt` and the function keys are avoided because browsers use them.

### Input and touch controls

`Services.input` is the `DeviceInputService` ([services/input/device_input_service.gd](services/input/device_input_service.gd)). It turns the input actions into what character controllers consume:

```gdscript
var move: Vector2 = Services.input.get_move_vector()                 # length 0..1
var aim: Vector2 = Services.input.get_aim_direction(global_position)  # unit vector, never zero
Services.input.action_pressed.connect(_on_action_pressed)            # abilities of the current role
Services.input.add_lock(InputActions.MOVE, &"eating")                # gameplay asks for locks
```

- **Keyboard and mouse:** 8-way movement that is no faster diagonally; the aim points from the character to the mouse pointer.
- **Touch:** the on-screen controls ([ui/touch/touch_controls.gd](ui/touch/touch_controls.gd)) are Godot's `VirtualJoystick` and `TouchScreenButton` nodes, which trigger the same input actions as the keys. The movement stick is analog; the aim keeps its direction when the aim stick is released. Several fingers work at once.
- **Role-aware:** only the abilities of the current role are reported, and only that role's touch controls are shown. The Sheepherder gets a second stick to aim plus Fire and Bell; the Monster gets Eat, Sprint, Graze, Bleat and Perk.
- **A press always gets its release:** when the role changes, gameplay input is switched off, an action is locked, the touch controls disappear, or the window or tab loses focus.
- **Which controls are shown** follows the device in use: touch controls on a touchscreen, switching whenever the player touches the screen or uses keyboard or mouse. `-- --touch-controls` and `-- --desktop-controls` force one of them; forced touch controls can be operated with the mouse.

**Rule:** nothing outside the input layer reads a device or the InputMap.

The input sandbox ([systems/input/sandbox/input_sandbox.tscn](systems/input/sandbox/input_sandbox.tscn), run it with **F6**) shows the live vectors and actions and steers a placeholder character with nothing but the input service, with buttons to switch the role, the controls and gameplay input.

### Physics layers and groups

| 2D physics layer | Name | Used for |
|:-:|:--|:--|
| 1 | `world` | Obstacles and arena borders; blocks movement |
| 2 | `sheepherder` | The Sheepherder's body |
| 3 | `sheep` | NPC sheep and the disguised Monster alike |
| 4 | `companions` | Shepherd Dog, Allied Bat |
| 5 | `hitbox` | Hit areas for firearm rays and melee attacks |

| Group | Members |
|:--|:--|
| `sheepherder` | The Sheepherder character |
| `sheep_like` | NPC sheep and the Monster, in either form |
| `companions` | Shepherd Dog, Allied Bat |
| `dynamic_entities` | Everything the vision system may hide |
| `obstacles` | Solid props that block movement and line of sight |
| `static_scenery` | Static map elements that stay faintly visible in darkness |
| `arena` | The arena of the running round |

NPC sheep and the Monster share every layer and group they are in, so neither can be used to tell them apart (GDD §3.2, "No Built-in Tell").

## Code conventions

- **Formatted and linted.** CI checks every script with `gdformat` and `gdlint` from [gdtoolkit](https://github.com/Scony/godot-gdscript-toolkit) 4.5.0; the settings are in `gdformatrc` and `gdlintrc`. Install it with `pipx install "gdtoolkit==4.5.0"`, then format with `gdformat $(git ls-files '*.gd')` and lint with `gdlint $(git ls-files '*.gd')` before pushing.
- **Static typing everywhere.** Every variable, parameter and return value has a type. The project setting `debug/gdscript/warnings/untyped_declaration` is set to *Error*, so untyped code does not compile.
- Definitions follow the style guide's order: signals, enums, constants, exported variables, variables, then functions.
- Naming follows the [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html): `snake_case` for files, functions and variables; `PascalCase` for classes and nodes; `CONSTANT_CASE` for constants and enum values; a leading `_` for private members; signals in the past tense (`sheep_died`).
- Contracts are named `<Thing>Service`, stubs `Stub<Thing>Service`, tests `tests/unit/test_<subject>.gd`.
- Public classes, methods and signals carry `##` documentation comments.
- Commit the `.uid` files Godot creates next to scripts; they keep references stable when files move.
