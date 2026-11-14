class_name FlockSwarmService
extends SwarmService
## The NPC flock (GDD §3.3): ten sheep that wander, graze, bleat and come when
## the bell rings.
##
## The host simulates. It spawns the sheep as replicated entities, gives each
## one a [FlockAgent] that decides what it does, and passes the decisions to
## the sheep's [SheepBody]. The guest gets the same sheep through the entity
## registry and sees them move through [SheepNetSync]; deaths, bleats and the
## bell reach it as events. Every query works on both devices.
##
## Sheep are found in the arena of the running round (group
## [constant Groups.ARENA]), which also supplies the start positions and what
## the sheep have to steer around.

const SHEEP_SCENE: PackedScene = preload("res://entities/sheep/sheep.tscn")
const KIND: StringName = &"sheep"

## Host to both: a sheep died. [code][sheep_id, cause][/code]
const EVENT_KILLED: StringName = &"flock.sheep_killed"
## Host to both: a sheep bleats. [code][sheep_id][/code]
const EVENT_BLEAT: StringName = &"flock.bleat"
## Host to both: the bell rang. [code][origin, radius][/code]
const EVENT_BELL: StringName = &"flock.bell"
## Either device to the host: ring the bell. [code][origin, radius][/code]
const EVENT_BELL_REQUEST: StringName = &"flock.bell_request"

## The arena the flock lives in. Normally found by itself; tests with two
## devices in one scene tree give each device its own.
var arena: Arena

var _session: GameSession
var _perks: PerkService
var _settings: FlockSettings = FlockSettings.new()
var _arena: Arena
var _world: FlockWorld = FlockWorld.new()

## Every sheep of the round by id, dead ones included.
var _bodies: Dictionary[int, SheepBody] = {}
## The minds of the living sheep. Only on the host.
var _agents: Dictionary[int, FlockAgent] = {}
var _phases: Dictionary[int, GameEnums.SheepPhase] = {}
var _neighbours: Array[Node2D] = []
var _last_bell_origin: Vector2 = Vector2.ZERO
var _last_bell_radius: float = 0.0


## Connects the service to the session it replicates through and to the stat
## lookup it reads its tunables from.
func setup(session: GameSession, perks: PerkService) -> void:
	_session = session
	_perks = perks
	session.entities.register_kind(KIND, _build_sheep, _get_sheep_parent)
	session.entities.entity_spawned.connect(_on_entity_spawned)
	session.entities.entity_despawned.connect(_on_entity_despawned)
	var messenger: NetMessenger = session.messenger
	messenger.register_event(EVENT_KILLED, NetMessenger.SenderRule.HOST_ONLY)
	messenger.register_event(EVENT_BLEAT, NetMessenger.SenderRule.HOST_ONLY)
	messenger.register_event(EVENT_BELL, NetMessenger.SenderRule.HOST_ONLY)
	messenger.register_event(EVENT_BELL_REQUEST, NetMessenger.SenderRule.ANYONE)
	messenger.subscribe(EVENT_KILLED, _on_killed)
	messenger.subscribe(EVENT_BLEAT, _on_bleat)
	messenger.subscribe(EVENT_BELL, _on_bell)
	messenger.subscribe(EVENT_BELL_REQUEST, _on_bell_request)


func _physics_process(delta: float) -> void:
	if _agents.is_empty() or not is_instance_valid(_arena):
		return
	var positions: Dictionary[int, Vector2] = {}
	var others: PackedVector2Array = _get_neighbour_positions()
	var sum: Vector2 = Vector2.ZERO
	var heading_sum: Vector2 = Vector2.ZERO
	for sheep_id: int in _agents:
		var body: SheepBody = _bodies[sheep_id]
		positions[sheep_id] = body.global_position
		sum += body.global_position
		if body.get_speed() > SheepBody.WALK_SPEED_THRESHOLD:
			heading_sum += Vector2.from_angle(body.get_heading())
	for other: Vector2 in others:
		sum += other
	var count: int = positions.size() + others.size()
	_world.center = sum / count
	_world.heading = heading_sum.normalized() if heading_sum.length() > 0.5 else Vector2.ZERO

	for sheep_id: int in _agents.keys():
		var agent: FlockAgent = _agents[sheep_id]
		var body: SheepBody = _bodies[sheep_id]
		var neighbours: PackedVector2Array = others.duplicate()
		for other_id: int in positions:
			if other_id != sheep_id:
				neighbours.append(positions[other_id])
		_world.neighbours = neighbours
		body.set_move_input(agent.update(delta, positions[sheep_id], body.get_speed(), _world))
		if body.is_grazing() != agent.is_grazing():
			body.set_grazing(agent.is_grazing())
		if agent.take_bleat():
			_session.messenger.broadcast(EVENT_BLEAT, [sheep_id])
		var phase: GameEnums.SheepPhase = agent.get_phase()
		if _phases.get(sheep_id, -1) != phase:
			_phases[sheep_id] = phase
			sheep_phase_changed.emit(sheep_id, phase)


# --- Contract --------------------------------------------------------------------


func spawn_flock(round_seed: int) -> void:
	if not _session.is_active() or not _session.is_host():
		push_error("FlockSwarmService: only the host of a running session spawns the flock.")
		return
	_arena = _find_arena()
	if _arena == null:
		push_error("FlockSwarmService: there is no arena to put the flock in.")
		return
	despawn_flock()
	_settings = FlockSettings.from_stats(_perks)
	_prepare_world()
	# One slot more than the flock has sheep: the Monster takes the free one.
	var slot_count: int = _perks.get_stat_int(StatIds.FLOCK_SIZE) + 1
	var monster_slot: int = RoundCast.monster_slot(round_seed, slot_count)
	var seeds: PackedInt64Array = RoundCast.visual_seeds(round_seed, slot_count)
	var positions: Array[Vector2] = _arena.get_spawn_layout(round_seed, slot_count).sheep_positions
	var owner_id: int = _session.get_local_peer_id()
	for slot: int in slot_count:
		if slot == monster_slot:
			continue
		var data: Dictionary = {
			"seed": seeds[slot],
			"x": positions[slot].x,
			"y": positions[slot].y,
			"mind": RoundCast.behaviour_seed(round_seed, slot),
		}
		_session.entities.spawn(KIND, owner_id, data)


func despawn_flock() -> void:
	if not _session.is_host():
		return
	for sheep_id: int in _bodies.keys():
		_session.entities.despawn(sheep_id)


func ring_bell(origin: Vector2, radius: float) -> void:
	_session.messenger.send_to_host(EVENT_BELL_REQUEST, [origin, radius])


func kill_sheep(sheep_id: int, cause: GameEnums.DeathCause) -> bool:
	if not _session.is_host() or not _bodies.has(sheep_id):
		return false
	var body: SheepBody = _bodies[sheep_id]
	# A shot sheep leaves a body that can still be eaten, but nothing dies twice.
	var can_die: bool = (
		body.is_alive()
		or (cause == GameEnums.DeathCause.EATEN and body.get_state() == SheepBody.State.CORPSE)
	)
	if not can_die:
		return false
	return _session.messenger.broadcast(EVENT_KILLED, [sheep_id, cause])


func get_living_count() -> int:
	return get_living_sheep_ids().size()


func get_living_sheep_ids() -> Array[int]:
	var ids: Array[int] = []
	for sheep_id: int in _bodies:
		if _bodies[sheep_id].is_alive():
			ids.append(sheep_id)
	return ids


func is_sheep_alive(sheep_id: int) -> bool:
	return _bodies.has(sheep_id) and _bodies[sheep_id].is_alive()


func get_sheep_body(sheep_id: int) -> Node2D:
	return _bodies.get(sheep_id)


func get_sheep_id(body: Node2D) -> int:
	for sheep_id: int in _bodies:
		if _bodies[sheep_id] == body:
			return sheep_id
	return -1


func find_nearest_living_sheep(position: Vector2, max_distance: float) -> int:
	var nearest_id: int = -1
	var nearest_distance: float = max_distance
	for sheep_id: int in _bodies:
		var body: SheepBody = _bodies[sheep_id]
		var distance: float = position.distance_to(body.global_position)
		if body.is_alive() and distance <= nearest_distance:
			nearest_distance = distance
			nearest_id = sheep_id
	return nearest_id


func register_neighbour(body: Node2D) -> void:
	if body != null and not _neighbours.has(body):
		_neighbours.append(body)


func unregister_neighbour(body: Node2D) -> void:
	_neighbours.erase(body)


# --- For the debug overlay and tests ---------------------------------------------


## The mind of a living sheep; [code]null[/code] on the guest and for dead sheep.
func get_agent(sheep_id: int) -> FlockAgent:
	return _agents.get(sheep_id)


## Where and how far the bell last rang; the radius is 0 if it never did.
func get_last_bell() -> Dictionary:
	return {"origin": _last_bell_origin, "radius": _last_bell_radius}


func get_settings() -> FlockSettings:
	return _settings


## What the sheep that decided last knew about its surroundings.
func get_world() -> FlockWorld:
	return _world


# --- Internals -------------------------------------------------------------------


func _find_arena() -> Arena:
	if is_instance_valid(arena):
		return arena
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(Groups.ARENA) as Arena


## Sheep live in the arena's y-sorted layer for entities.
func _get_sheep_parent() -> Node:
	var found: Arena = _find_arena()
	return found.get_entities_layer() if found != null else null


func _prepare_world() -> void:
	_world.play_area = _arena.get_play_area()
	_world.footprints = _arena.get_obstacle_footprints()
	var field: Arena = _arena
	var clearance: float = _settings.body_clearance
	_world.is_free = func(point: Vector2) -> bool: return field.is_free(point, clearance)


func _get_neighbour_positions() -> PackedVector2Array:
	var positions: PackedVector2Array = []
	for neighbour: Node2D in _neighbours.duplicate():
		if is_instance_valid(neighbour):
			positions.append(neighbour.global_position)
		else:
			_neighbours.erase(neighbour)
	return positions


## Builds a sheep; the same on both devices.
func _build_sheep(_entity_id: int, _owner_id: int, data: Dictionary) -> Node:
	var body: SheepBody = SHEEP_SCENE.instantiate()
	body.set_visual_seed(data["seed"])
	body.position = Vector2(data["x"], data["y"])
	body.set_meta(&"mind_seed", data["mind"])
	var sync: SheepNetSync = SheepNetSync.new()
	sync.name = "NetSync"
	body.add_child(sync)
	return body


func _on_entity_spawned(sheep_id: int, entity: Node) -> void:
	var body: SheepBody = entity as SheepBody
	if body == null or not body.has_meta(&"mind_seed"):
		return
	_bodies[sheep_id] = body
	if _session.is_host():
		_agents[sheep_id] = FlockAgent.new(body.get_meta(&"mind_seed"), _settings)
	sheep_spawned.emit(sheep_id, body.get_visual_seed())
	living_count_changed.emit(get_living_count())


func _on_entity_despawned(sheep_id: int) -> void:
	if not _bodies.has(sheep_id):
		return
	_bodies.erase(sheep_id)
	_agents.erase(sheep_id)
	_phases.erase(sheep_id)


func _on_killed(payload: Array, _sender_id: int) -> void:
	var sheep_id: int = payload[0]
	var cause: GameEnums.DeathCause = payload[1]
	if not _bodies.has(sheep_id):
		return
	var body: SheepBody = _bodies[sheep_id]
	var was_alive: bool = body.is_alive()
	if not body.kill(cause):
		return
	_agents.erase(sheep_id)
	_phases.erase(sheep_id)
	if was_alive:
		sheep_died.emit(sheep_id, cause, body.global_position)
		living_count_changed.emit(get_living_count())


func _on_bleat(payload: Array, _sender_id: int) -> void:
	var sheep_id: int = payload[0]
	if _bodies.has(sheep_id):
		_bodies[sheep_id].bleat()


func _on_bell_request(payload: Array, _sender_id: int) -> void:
	_session.messenger.broadcast(EVENT_BELL, payload)


func _on_bell(payload: Array, _sender_id: int) -> void:
	_last_bell_origin = payload[0]
	_last_bell_radius = payload[1]
	for sheep_id: int in _agents:
		if _bodies[sheep_id].global_position.distance_to(_last_bell_origin) <= _last_bell_radius:
			_agents[sheep_id].start_bell(_last_bell_origin)
	bell_rung.emit(_last_bell_origin, _last_bell_radius)
