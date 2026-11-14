class_name SessionCombatService
extends CombatService
## The real [CombatService], part 1: the Sheepherder's firearm (GDD §3.1).
##
## Host-authoritative (docs/networking.md): the Sheepherder's device asks the
## host for a shot, the host checks ammo and reload, resolves where the bullet
## goes and announces the result to both devices. Both devices then update
## ammo and reload and emit the same signals.
##
## A bullet travels along the aim until it hits a sheep-like entity (NPC sheep
## or the Monster), a solid obstacle, or a border, where it has left the map.
## Only the first hit counts. The Monster's attack and evolution arrive with
## #16; until then they answer like the stub.
##
## Both devices call [method begin_round] before the first shot; that is also
## when the service registers its events with the session.

const EVENT_SHOT_REQUEST: StringName = &"combat.shot_request"
const EVENT_SHOT: StringName = &"combat.shot"

## Farther than any arena. Every shot ends at a border before this.
const MAX_SHOT_DISTANCE: float = 100000.0

## The session whose messenger carries requests and results. Defaults to
## [code]Services.session[/code]; tests set their own.
var session: GameSession:
	get:
		if session == null:
			session = Services.session
		return session
	set(value):
		session = value
		_registered = false

## The flock, to kill the sheep a bullet hits. Defaults to
## [code]Services.swarm[/code].
var swarm: SwarmService:
	get:
		return swarm if swarm != null else Services.swarm

var _registered: bool = false
var _round_active: bool = false
var _sheepherder: Node2D
var _monster: Node2D
var _ammo: int = 0
var _capacity: int = 0
var _reload_duration: float = 0.0
var _reload_left: float = 0.0
var _shot_sheep: int = 0
var _eat_blockers: Array[StringName] = []


func _process(delta: float) -> void:
	advance(delta)


## Moves the reload forward by [param delta] seconds. Called every frame.
func advance(delta: float) -> void:
	if _reload_left <= 0.0:
		return
	_reload_left = maxf(_reload_left - delta, 0.0)
	if _reload_left == 0.0:
		reload_finished.emit()
		if is_instance_valid(_sheepherder):
			Services.audio.play_event(AudioEvents.RELOAD_CLICK, _sheepherder.global_position)


# --- Round lifecycle -------------------------------------------------------------


func begin_round(sheepherder: Node2D, monster: Node2D) -> void:
	_register_events()
	_sheepherder = sheepherder
	_monster = monster
	_round_active = true
	_capacity = Services.perks.get_stat_int(StatIds.FIREARM_AMMO)
	_ammo = _capacity
	_reload_left = 0.0
	_reload_duration = 0.0
	_shot_sheep = 0
	_eat_blockers.clear()
	ammo_changed.emit(_ammo, _capacity)
	eaten_count_changed.emit(0)


func end_round() -> void:
	_round_active = false
	_reload_left = 0.0
	_sheepherder = null
	_monster = null


# --- Firearm ---------------------------------------------------------------------


func request_shot(origin: Vector2, direction: Vector2) -> bool:
	if not can_shoot() or direction.is_zero_approx():
		return false
	_register_events()
	return session.messenger.send_to_host(EVENT_SHOT_REQUEST, [origin, direction.normalized()])


func can_shoot() -> bool:
	return _round_active and _ammo > 0 and _reload_left <= 0.0


func get_ammo() -> int:
	return _ammo


func get_ammo_capacity() -> int:
	return _capacity


func is_reloading() -> bool:
	return _reload_left > 0.0


func get_reload_progress() -> float:
	if _reload_left <= 0.0 or _reload_duration <= 0.0:
		return 1.0
	return 1.0 - _reload_left / _reload_duration


func is_ammo_depleted() -> bool:
	return _round_active and _ammo == 0


func get_shot_sheep_count() -> int:
	return _shot_sheep


# --- Monster (#16) ---------------------------------------------------------------


func request_eat() -> bool:
	return false


func can_eat() -> bool:
	return false


func is_eating() -> bool:
	return false


func get_eat_cooldown_remaining() -> float:
	return 0.0


func add_eat_blocker(source: StringName) -> void:
	if not _eat_blockers.has(source):
		_eat_blockers.append(source)


func remove_eat_blocker(source: StringName) -> void:
	_eat_blockers.erase(source)


func get_eaten_count() -> int:
	return 0


func get_monster_form() -> GameEnums.MonsterForm:
	return GameEnums.MonsterForm.SHEEP


func can_kill_sheepherder() -> bool:
	return false


func is_monster_killable() -> bool:
	return get_monster_form() != GameEnums.MonsterForm.SPIDER and not is_ammo_depleted()


# --- Host: resolving a shot ------------------------------------------------------


func _on_shot_request(payload: Array, _sender_id: int) -> void:
	if not session.messenger.is_host() or not can_shoot():
		return
	var origin: Vector2 = payload[0]
	var direction: Vector2 = payload[1]
	var outcome: Array = _resolve(origin, direction)
	var result: ShotResult = outcome[1]
	var sheep_id: int = outcome[2]
	if result == ShotResult.HIT_SHEEP and sheep_id >= 0:
		swarm.kill_sheep(sheep_id, GameEnums.DeathCause.SHOT)
	var reload: float = Services.perks.get_stat(StatIds.FIREARM_RELOAD_TIME)
	session.messenger.broadcast(
		EVENT_SHOT, [origin, outcome[0], result, sheep_id, _ammo - 1, reload]
	)


## Where the bullet from [param origin] along [param direction] ends:
## [code][end_position, ShotResult, sheep_id][/code]. The sheep id is -1
## unless an NPC sheep was hit.
func _resolve(origin: Vector2, direction: Vector2) -> Array:
	var world: World2D = _world()
	var wall: WorldHit = WorldQueries.raycast(world, origin, direction, MAX_SHOT_DISTANCE)
	var end: Vector2 = wall.position if wall != null else origin + direction * MAX_SHOT_DISTANCE
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		origin, end, PhysicsLayers.HITBOX
	)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	var target: Node = _sheep_like_owner(hit.get("collider") as Node)
	if target == null:
		var into_obstacle: bool = wall != null and wall.is_obstacle()
		return [end, ShotResult.HIT_OBSTACLE if into_obstacle else ShotResult.MISSED, -1]
	var position: Vector2 = hit["position"]
	if target == _monster:
		var spider: bool = get_monster_form() == GameEnums.MonsterForm.SPIDER
		return [position, ShotResult.HIT_SPIDER if spider else ShotResult.HIT_MONSTER, -1]
	return [position, ShotResult.HIT_SHEEP, swarm.get_sheep_id(target as Node2D)]


func _world() -> World2D:
	if is_instance_valid(_sheepherder) and _sheepherder.is_inside_tree():
		return _sheepherder.get_world_2d()
	return get_viewport().world_2d


## The sheep-like entity a hit area belongs to, or [code]null[/code].
static func _sheep_like_owner(node: Node) -> Node:
	while node != null:
		if node.is_in_group(Groups.SHEEP_LIKE):
			return node
		node = node.get_parent()
	return null


# --- Both devices: what a shot did -----------------------------------------------


func _on_shot(payload: Array, _sender_id: int) -> void:
	var origin: Vector2 = payload[0]
	var end: Vector2 = payload[1]
	var result: ShotResult = payload[2]
	var sheep_id: int = payload[3]
	_ammo = payload[4]
	_reload_duration = payload[5]
	_reload_left = _reload_duration if _ammo > 0 else 0.0
	Services.audio.play_event(AudioEvents.GUNSHOT, origin)
	shot_fired.emit(origin, end, result)
	ammo_changed.emit(_ammo, _capacity)
	match result:
		ShotResult.HIT_SHEEP:
			_shot_sheep += 1
			sheep_killed.emit(sheep_id, GameEnums.DeathCause.SHOT, end)
			blood_spilled.emit(end)
		ShotResult.HIT_MONSTER:
			monster_shot.emit(end)
	if _ammo > 0:
		reload_started.emit(_reload_duration)
	else:
		ammo_depleted.emit()


func _register_events() -> void:
	if _registered or session == null:
		return
	_registered = true
	var messenger: NetMessenger = session.messenger
	messenger.register_event(EVENT_SHOT_REQUEST, NetMessenger.SenderRule.ANYONE)
	messenger.register_event(EVENT_SHOT, NetMessenger.SenderRule.HOST_ONLY)
	messenger.subscribe(EVENT_SHOT_REQUEST, _on_shot_request)
	messenger.subscribe(EVENT_SHOT, _on_shot)
