# Networking: session and replication conventions

The game is always a session of two devices: one **host** and one **guest** (GDD §9.4). This document describes the layer between the raw connection and the game, and the rules every networked feature follows. The code is in [systems/session/](../systems/session).

## Layers

```text
Gameplay (flock, Sheepherder, Monster, round rules)
        │  uses
GameSession ── roles, screens, lifecycle            Services.session
  ├─ messenger   events and snapshots               NetMessenger
  ├─ state       host-owned values                  SyncedState
  └─ entities    spawning and transforms            NetEntityRegistry, NetTransform2D, SheepNetSync
        │  talks only to
NetworkService (contract) ── the transport
  ├─ StubNetworkService     offline: a session of one
  ├─ EnetNetworkService     desktop development, two instances
  └─ WebRTC transport       the Web build (#7)
```

`GameSession` and everything above it never name a transport. They work the same offline, over ENet and over WebRTC.

## Who decides what (authority)

| What | Decided by | How the other device learns it |
|:--|:--|:--|
| NPC flock: positions, behaviour phases, bleats, deaths, visual seeds | Host | Snapshots (position, heading, grazing), events (spawns, phase changes, deaths, bleats, bell) |
| Combat: shots, hits, deaths, eating, blood, ammo | Host | Events |
| Round and match state: timer, scores, outcome | Host | Synced state, events |
| Roles | Host | Synced state |
| Which screen both devices are on | Host | Events, with a ready handshake |
| Which entities exist | Host | Spawn and despawn events |
| A player's own character: position, rotation, aim | That player's device | Snapshots |
| A player's actions (shoot, eat, bell, perk) | Requested by that player's device, **decided by the host** | Request event to the host, result event to both |

So each player moves their own character without waiting for the network, which keeps controls immediate on a local network. Anything that can change the outcome of a round is validated and decided by the host.

**Hidden information is enforced at presentation level only.** Both devices receive all positions; the vision system decides what is drawn. This is accepted for a local 1v1 game without anti-cheat (#8).

## Two channels

| | Events | Snapshots |
|:--|:--|:--|
| Delivery | Reliable and ordered: each arrives exactly once, in the order sent | Unreliable: a lost one is replaced by the next |
| Used for | Everything that must not be lost: shots, deaths, blood, scores, spawns, role and screen changes | Continuous state: transforms |
| Rate | When something happens | `GameConfig.net_tick_rate`, 20 per second |
| Transfer channel | 1 | 2 |

Separate transfer channels keep a resent event from holding up snapshots.

### Events

An event has a name and a payload of plain data. It is registered on both devices with a rule saying who may send it:

```gdscript
const EVENT_GUNSHOT: StringName = &"combat.gunshot"

var messenger: NetMessenger = Services.session.messenger
messenger.register_event(EVENT_GUNSHOT, NetMessenger.SenderRule.HOST_ONLY)
messenger.subscribe(EVENT_GUNSHOT, _on_gunshot)

# Host: announce what happened. Handled here at once, and on the guest on arrival.
messenger.broadcast(EVENT_GUNSHOT, [origin, end_position, result])

func _on_gunshot(payload: Array, sender_id: int) -> void:
	...
```

| Method | Handled on | Use |
|:--|:--|:--|
| `broadcast` | Both devices | The host announces a fact |
| `send_to_host` | The host (immediately, if this device is the host) | A player asks for something; the code is identical on both devices |
| `send_to_remote` | The other device only | Rarely needed |

A `HOST_ONLY` event sent by the guest is refused on the guest and ignored on the host. Name events `<system>.<what_happened>`.

### Snapshots and interpolation

Several times per second each device sends one snapshot with the state of every entity it owns. What that state is, the entity's `NetTransform2D` decides: position and rotation by default, more in a subclass (a sheep adds whether it grazes). The receiving device does not show these states as they arrive. It shows every replicated entity `GameConfig.net_interpolation_delay` (0.1 s) in the past, interpolated between two states that have already arrived. As long as packets arrive within that delay, motion is smooth however unevenly they come in. If nothing newer has arrived, an entity keeps its course for at most `net_max_extrapolation` (0.1 s) and then stands still.

### Uniform presentation rule

> On each device, every sheep-like entity reaches the screen through the same interpolation path.

Otherwise the network itself becomes a tell. For a hosting Sheepherder the NPC sheep are simulated on their own device and would move perfectly, while the Monster arrives over the network. So an entity that must be indistinguishable sets `NetTransform2D.delayed_visual`: its visible part is then drawn from the same buffer, with the same delay, on the device that simulates it as on the other one. The character a player controls themself is exempt on their own device, where its picture has to follow the input.

**Sheep** use [SheepNetSync](../entities/sheep/sheep_net_sync.gd), a `NetTransform2D` for a `SheepBody`. It goes one step further than `delayed_visual`: on both devices the sheep's picture, its walk animation and its grazing all come from the buffered state, so the animation cannot run ahead of the picture either. Grazing travels in the snapshot as a flag instead of as an event, which shows it at the matching moment and repairs itself after lost packets. The flock (#13) spawns every NPC sheep with it. The [Monster](../entities/monster/monster.gd) uses the same component for its sheep body, with `live_on_owner = true` so that it follows the input on the Monster's own device and is shown delayed everywhere else. [no-tell-audit.md](no-tell-audit.md) lists what is compared between the two.

**Flock events** (all decided by the host, see [FlockSwarmService](../services/swarm/flock_swarm_service.gd)):

| Event | Sender | Payload |
|:--|:--|:--|
| `flock.sheep_killed` | Host | `[sheep_id, cause]` |
| `flock.bleat` | Host | `[sheep_id]` |
| `flock.phase` | Host | `[sheep_id, phase]` |
| `flock.bell` | Host | `[origin, radius]` |
| `flock.bell_request` | Either device, to the host | `[origin, radius]` |

The phase event feeds `SwarmService.sheep_phase_changed` on both devices, for game logic. What a sheep is *shown* doing comes from the snapshots alone.

**Combat events** (see [SessionCombatService](../services/combat/session_combat_service.gd)):

| Event | Sender | Payload |
|:--|:--|:--|
| `combat.shot_request` | Either device, to the host | `[origin, direction]` |
| `combat.shot` | Host | `[origin, end_position, result, sheep_id, ammo_left, reload_time]` |
| `combat.eat_request` | Either device, to the host | `[monster_position]` |
| `combat.eat` | Host | `[target, target_id, target_position, monster_position, duration, cooldown]` |

A request carries where the player's own character was when they pressed the button, because that device is the one that knows. The host decides against its own state of everything else. The Monster's player sees the others `net_interpolation_delay` in the past, so the host accepts an attack from the other device if the target can have been in reach that long ago. The result event carries the durations, so both devices count the same lock and cooldown even while a perk changes them.

Everything that follows from an attack (the dead sheep, the blood, the eaten count, the unlocked kill, the spider) is derived from `combat.eat` on both devices in the same order; nothing of it is sent separately.

**Monster events:**

| Event | Sender | Payload |
|:--|:--|:--|
| `monster.bleat` | The Monster's device, to the other | `[entity_id]` |

The Monster's grazing travels in its snapshots like a sheep's, and its eating animation starts from `combat.eat`.

## Session

`Services.session` answers what every system needs to know:

```gdscript
var session: GameSession = Services.session
session.is_active()            # a session is up (also offline)
session.is_host()              # this device decides (also true offline and without a session)
session.has_remote_player()    # a second device takes part
session.get_local_role()       # GameEnums.Role
session.roles_changed          # signal, both devices
```

**Roles.** The host assigns roles at random when the session starts (GDD §2.3: random in round 1) and swaps them with `swap_roles()` after every round. The assignment is synced state, so both devices always agree.

**Screens.** `session.request_screen(SceneFlowController.Screen.ROUND)` on the host takes both devices along: both load the scene, each reports when it is ready, and only then `screen_entered` is emitted on both. Start a round on `screen_entered`, not in `_ready`, so neither device starts ahead of the other.

**Disconnect.** When the connection is lost, the session ends on the remaining device: replicated entities are removed, a round or results screen is left for the lobby, and `session_ended` carries the reason and a message for the player (`session.last_end_message`).

**Synced state.** For values that change rarely and must never diverge:

```gdscript
session.state.set_value(&"round.number", 3)        # host only
session.state.get_value(&"round.number", 1)        # both devices
session.state.value_changed.connect(_on_value)     # both devices
```

## How to add a replicated entity

1. Build the entity as a scene or in code, with a `NetTransform2D` as a direct child of its root `Node2D`. For a sheep-like entity, point `delayed_visual` at its visible part.
2. Register a factory for its kind on both devices, before the host spawns one. The factory must build the same node on both devices from the same data:

   ```gdscript
   session.entities.register_kind(&"sheep", _build_sheep)

   func _build_sheep(entity_id: int, owner_id: int, data: Dictionary) -> Node:
   	var sheep: Node2D = SHEEP_SCENE.instantiate()
   	sheep.position = Vector2(data["x"], data["y"])
   	sheep.setup(data["seed"])
   	return sheep
   ```

3. Tell the registry where entities live: `session.entities.spawn_root = $World/Entities`. A kind that belongs somewhere else names its parent when it is registered, as a function that is asked at every spawn: `register_kind(&"sheep", _build_sheep, _get_sheep_parent)`. Do not move an entity to another parent after it was spawned; the registry takes that for its removal.
4. On the host, spawn it for its owner: `var id: int = session.entities.spawn(&"sheep", owner_peer_id, {"x": 100.0, "y": 80.0, "seed": 42})`. The id is the same on both devices and is how events refer to the entity.
5. On the owning device, move the root node as usual. Nothing else is needed: the transform travels in the snapshots and the other device shows it interpolated. Use `session.entities.is_local_authority(id)` to run simulation code only on the owner.
6. Send everything that happens once (a death, a sound, an animation trigger) as an event that names the entity id. A state that lasts and must match the picture belongs in the snapshot instead: extend `NetTransform2D` and override `capture`, `receive` and `present`, as `SheepNetSync` does.
7. On the host, remove it with `despawn(id)`; `despawn_all()` at the end of a round.

Spawn data and event payloads must be plain data: numbers, strings, vectors, arrays, dictionaries. No objects or node references.

## Development: two instances on one computer

```bash
godot --path . -- --host
```

```bash
godot --path . -- --join
```

The two instances connect by themselves over the desktop dev transport (ENet). It only accepts connections from the same computer unless the host adds `--lan`; a guest on another computer joins with `--join=<address>`. `--port=<number>` changes the port (default 24565). The Web build never uses this transport; it connects through pairing codes (#7).

| Flag | Effect |
|:--|:--|
| `--net-latency=<ms>` | Delay every incoming message |
| `--net-jitter=<ms>` | Add a random extra delay per message |
| `--net-loss=<percent>` | Drop that share of incoming snapshots (events are never dropped) |

Give the flags to both instances for a connection that is bad in both directions.

**Demo.** [systems/session/demo/net_demo.tscn](../systems/session/demo/net_demo.tscn) shows the framework without any gameplay: each instance moves its own box and sees the other's, with buttons to swap roles, send an event, take both to the Round screen and leave.

```bash
godot --path . res://systems/session/demo/net_demo.tscn -- --host
```

```bash
godot --path . res://systems/session/demo/net_demo.tscn -- --join
```

**Automated check with two instances.** `tools/test_two_instances.sh` starts a host and a guest, lets them run a scripted scenario against each other and fails if either saw something unexpected: connection, roles and swap, 30 events in order in both directions, smooth movement of the other box, the screen change with its handshake, and the guest's return to the lobby when the host leaves. It accepts the network flags, e.g. `tools/test_two_instances.sh --net-latency=80 --net-jitter=40 --net-loss=10`.

`tools/test_two_instances.sh monster` does the same for a round's lethal part, in the [Monster sandbox](../entities/monster/sandbox/monster_sandbox.tscn) with scripted players and a shortened cooldown: the guest's Monster walks, sprints, grazes, bleats, eats sheep until it is the spider, takes a bullet and kills the host's Sheepherder. Both instances check that they saw the same thing, and the host that the Monster moved without jumps. It accepts the network flags as well.

**Offline.** Without a flag nothing connects. `Services.session.host()` then starts an offline session: this device is the host, there is no remote player, and all the code above runs unchanged. Sandbox scenes and unit tests use this.

## Rules for transports

Learned while building the dev transport; they apply to the WebRTC transport as well:

- **Install the peer before it connects.** Godot's multiplayer API only knows a device whose connection it saw being made. A peer that is assigned after it connected leads to "unknown peer ID" errors on the first RPC. The transport therefore sets `multiplayer.multiplayer_peer` when hosting or joining starts, and reports `session_started` from the API's `peer_connected` signal.
- **Never replace or close a connection from inside its own poll.** Signals such as `peer_disconnected` are emitted while the connection is being polled; closing it right there crashes the engine. Note what was reported and act on it in `_process`.
