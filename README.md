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

The game starts in the boot screen, which checks the services and hands over to the lobby. Lobby, round and results are placeholder screens for now; their buttons walk through the scene flow.

The sheep gallery ([entities/sheep/gallery/sheep_gallery.tscn](entities/sheep/gallery/sheep_gallery.tscn), run it with **F6**) shows the sheep of one round at gameplay zoom, with buttons for every animation state, a new round and darkness with a light at the mouse.

The arena sandbox ([systems/arena/arena_sandbox.tscn](systems/arena/arena_sandbox.tscn), **F6**) shows the whole arena with a round's spawn layout. Its buttons let the sheep wander into obstacles and borders, switch the debug overlay (footprints, occluders, borders, spawn areas) and change the zoom.

### Two instances on one computer

The game is always played by two devices. For development, two desktop instances connect to each other by themselves:

```bash
godot --path . -- --host
```

```bash
godot --path . -- --join
```

Both end up in the lobby, which shows who is host and who plays which role; the host's buttons take both instances through the screens. Flags for a simulated bad connection, the network demo scene and the automated two-instance check are described in [docs/networking.md](docs/networking.md#development-two-instances-on-one-computer).

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

**Test on your phone.** Open the deployed build on the phone, with both devices in the same Wi-Fi. A build served from your computer as `http://<lan-ip>:8060` is fine for layout and touch controls, but not for pairing: browsers allow camera and clipboard access only over HTTPS or on `localhost`.

**Thread Support** is off and the Progressive Web App option is not used, because GitHub Pages cannot send the cross-origin isolation headers that threads need. This affects audio latency in *Stream* mode; see the decision in [docs/web-build.md](docs/web-build.md#decision-no-thread-support-no-progressive-web-app).

## Architecture

The code follows two rules from GDD §9.2: **separation of concerns** through service contracts, and **one source of truth** for every number and name.

```text
res://
├── abstractions/     Service contracts (abstract classes) and the shared vocabulary in types/
├── services/         Service registry, composition root, implementations (stubs/ until the real ones exist)
├── entities/         Sheepherder, Monster, NPC sheep, companions, obstacles
├── systems/          Game config, scene flow, view rule, arena, seeded randomness; later lighting, AI, swarm
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

Every contract has a stub in `services/stubs/` that is registered by default. A stub is inert but honours the contract (the `PerkService` stub returns the plain config values, the `NetworkService` stub is an offline session of one), so a feature can be built and tested before the real implementation of a neighbouring service is merged.

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
| `PerkIds` | The eight perks and the pool of each role |
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

Every obstacle type is a scene with the [ArenaObstacle](entities/obstacles/arena_obstacle.gd) script. Its `Footprint` polygon is the one shape that blocks movement, sight and light: the light occluder is built from it.

**Rule:** whatever asks "can A see B" or "what does this ray hit" uses [WorldQueries](systems/arena/world_queries.gd). Only obstacles and borders (physics layer `world`) block sight; characters and sheep never do. A ray that ends at a border, not an obstacle, has left the map.

### Scene flow

`SceneFlow` (autoload, [systems/flow/scene_flow_controller.gd](systems/flow/scene_flow_controller.gd)) knows which screen is shown and which may follow:

```text
boot → lobby → round → results ─┬→ round   (next round)
                 │              └→ lobby   (match over)
                 └→ lobby                  (disconnect)
```

`SceneFlow.go_to(SceneFlowController.Screen.ROUND)` changes the scene and refuses transitions the flow does not allow. Each screen is a scene in `ui/screens/`; a task replaces a placeholder by setting `SceneFlow.screen_scenes[...]`.

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

NPC sheep and the Monster share every layer and group they are in, so neither can be used to tell them apart (GDD §3.2, "No Built-in Tell").

## Code conventions

- **Formatted and linted.** CI checks every script with `gdformat` and `gdlint` from [gdtoolkit](https://github.com/Scony/godot-gdscript-toolkit) 4.5.0; the settings are in `gdformatrc` and `gdlintrc`. Install it with `pipx install "gdtoolkit==4.5.0"`, then format with `gdformat $(git ls-files '*.gd')` and lint with `gdlint $(git ls-files '*.gd')` before pushing.
- **Static typing everywhere.** Every variable, parameter and return value has a type. The project setting `debug/gdscript/warnings/untyped_declaration` is set to *Error*, so untyped code does not compile.
- Definitions follow the style guide's order: signals, enums, constants, exported variables, variables, then functions.
- Naming follows the [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html): `snake_case` for files, functions and variables; `PascalCase` for classes and nodes; `CONSTANT_CASE` for constants and enum values; a leading `_` for private members; signals in the past tense (`sheep_died`).
- Contracts are named `<Thing>Service`, stubs `Stub<Thing>Service`, tests `tests/unit/test_<subject>.gd`.
- Public classes, methods and signals carry `##` documentation comments.
- Commit the `.uid` files Godot creates next to scripts; they keep references stable when files move.
