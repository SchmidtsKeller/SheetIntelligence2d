class_name SessionCombatService
extends CombatService
## The real [CombatService]: the Sheepherder's firearm (GDD §3.1) and the
## Monster's attack and evolution (GDD §2.1, §3.2).
##
## Host-authoritative (docs/networking.md): a player's device asks the host
## for a shot or an attack, the host checks whether it is allowed, resolves
## what it does and announces the result to both devices. Both devices then
## update their state and emit the same signals.
##
## A bullet travels along the aim until it hits a sheep-like entity (NPC sheep
## or the Monster), a solid obstacle, or a border, where it has left the map.
## Only the first hit counts.
##
## The Monster's attack takes the Sheepherder if the kill is unlocked and they
## are in melee range, otherwise the nearest sheep in range, alive or shot.
## The Monster stands still while it eats; the cooldown starts when it is done.
##
## Both devices call [method begin_round] before the first shot; that is also
## when the service registers its events with the session.

const EVENT_SHOT_REQUEST: StringName = &"combat.shot_request"
const EVENT_SHOT: StringName = &"combat.shot"
## The Monster's device to the host: attack. [code][monster_position][/code]
const EVENT_EAT_REQUEST: StringName = &"combat.eat_request"
## Host to both: the Monster attacks. [code][target, target_id,
## target_position, monster_position, duration, cooldown][/code]
const EVENT_EAT: StringName = &"combat.eat"

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
var _sheepherder_alive: bool = true
var _monster_alive: bool = true
var _eaten: int = 0
var _eaten_alive: int = 0
var _form: GameEnums.MonsterForm = GameEnums.MonsterForm.SHEEP
var _eat_target: EatTarget = EatTarget.NONE
var _eat_target_id: int = -1
var _eat_left: float = 0.0
## The cooldown that starts when the running eating animation ends.
var _eat_cooldown: float = 0.0
var _eat_cooldown_left: float = 0.0


func _process(delta: float) -> void:
	advance(delta)


## Moves the reload, the eating animation and the attack cooldown forward by
## [param delta] seconds. Called every frame.
func advance(delta: float) -> void:
	_advance_reload(delta)
	_advance_eating(delta)


func _advance_reload(delta: float) -> void:
	if _reload_left <= 0.0:
		return
	_reload_left = maxf(_reload_left - delta, 0.0)
	if _reload_left == 0.0:
		reload_finished.emit()


func _advance_eating(delta: float) -> void:
	if not is_eating():
		_eat_cooldown_left = maxf(_eat_cooldown_left - delta, 0.0)
		return
	_eat_left -= delta
	if _eat_left > 0.0:
		return
	# What is left of this frame already counts toward the cooldown.
	_eat_cooldown_left = maxf(_eat_cooldown + _eat_left, 0.0)
	_eat_left = 0.0
	var target: EatTarget = _eat_target
	_eat_target = EatTarget.NONE
	eat_finished.emit(target, _eat_target_id, _eat_cooldown)
	_evolve()


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
	_sheepherder_alive = true
	_monster_alive = true
	_eaten = 0
	_eaten_alive = 0
	_stop_eating()
	ammo_changed.emit(_ammo, _capacity)
	eaten_count_changed.emit(0)
	if _form != GameEnums.MonsterForm.SHEEP:
		_form = GameEnums.MonsterForm.SHEEP
		monster_form_changed.emit(_form)


func end_round() -> void:
	_round_active = false
	_reload_left = 0.0
	_stop_eating()
	_sheepherder = null
	_monster = null


# --- Firearm ---------------------------------------------------------------------


func request_shot(origin: Vector2, direction: Vector2) -> bool:
	if not can_shoot() or direction.is_zero_approx():
		return false
	_register_events()
	return session.messenger.send_to_host(EVENT_SHOT_REQUEST, [origin, direction.normalized()])


func can_shoot() -> bool:
	return _round_active and _sheepherder_alive and _ammo > 0 and _reload_left <= 0.0


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


# --- Monster ---------------------------------------------------------------------


func request_eat() -> bool:
	if not can_eat():
		return false
	_register_events()
	return session.messenger.send_to_host(EVENT_EAT_REQUEST, [_monster.global_position])


func can_eat() -> bool:
	if not _may_eat():
		return false
	return _find_eat_target(_monster.global_position, 0.0)[0] != EatTarget.NONE


func is_eating() -> bool:
	return _eat_target != EatTarget.NONE


func get_eat_cooldown_remaining() -> float:
	return _eat_cooldown_left


func add_eat_blocker(source: StringName) -> void:
	if not _eat_blockers.has(source):
		_eat_blockers.append(source)


func remove_eat_blocker(source: StringName) -> void:
	_eat_blockers.erase(source)


func get_eaten_count() -> int:
	return _eaten


func get_eaten_alive_count() -> int:
	return _eaten_alive


func get_monster_form() -> GameEnums.MonsterForm:
	return _form


func can_kill_sheepherder() -> bool:
	return _eaten >= Services.perks.get_stat_int(StatIds.HERDER_KILL_THRESHOLD)


func is_monster_killable() -> bool:
	return get_monster_form() != GameEnums.MonsterForm.SPIDER and not is_ammo_depleted()


# --- Host: resolving an attack ---------------------------------------------------


func _on_eat_request(payload: Array, sender_id: int) -> void:
	if not session.messenger.is_host() or not _may_eat():
		return
	var from: Vector2 = payload[0]
	var remote: bool = sender_id != session.messenger.get_local_id()
	var lag: float = session.entities.interpolation_delay if remote else 0.0
	var found: Array = _find_eat_target(from, lag)
	var target: EatTarget = found[0]
	if target == EatTarget.NONE:
		return
	var is_sheep: bool = target != EatTarget.SHEEPHERDER
	if is_sheep and not swarm.kill_sheep(found[1], GameEnums.DeathCause.EATEN):
		return
	var perks: PerkService = Services.perks
	var duration: float = perks.get_stat(StatIds.EAT_DURATION)
	var cooldown: float = perks.get_stat(StatIds.EAT_COOLDOWN)
	session.messenger.broadcast(EVENT_EAT, [target, found[1], found[2], from, duration, cooldown])


## Whether the Monster could attack right now if something were in range.
func _may_eat() -> bool:
	return (
		_round_active
		and _monster_alive
		and is_instance_valid(_monster)
		and not is_eating()
		and _eat_cooldown_left <= 0.0
		and _eat_blockers.is_empty()
	)


## What an attack from [param from] takes: [code][EatTarget, sheep_id,
## target_position][/code], with [constant EatTarget.NONE] if nothing is in
## melee range.
## [br][param lag] is how old the attacker's picture of the others was, in
## seconds. A Monster on the other device sees everyone that far in the past
## (docs/networking.md), so a target counts as in range if it can have been in
## range then.
func _find_eat_target(from: Vector2, lag: float) -> Array:
	var perks: PerkService = Services.perks
	var reach: float = perks.get_stat(StatIds.MELEE_RANGE)
	if _sheepherder_alive and can_kill_sheepherder() and is_instance_valid(_sheepherder):
		var herder_reach: float = reach + perks.get_stat(StatIds.HERDER_MOVE_SPEED) * lag
		if from.distance_to(_sheepherder.global_position) <= herder_reach:
			return [EatTarget.SHEEPHERDER, -1, _sheepherder.global_position]
	var sheep_id: int = swarm.find_nearest_edible_sheep(from, reach)
	if sheep_id < 0 and lag > 0.0:
		var sheep_reach: float = reach + perks.get_stat(StatIds.SHEEP_MOVE_SPEED) * lag
		sheep_id = swarm.find_nearest_living_sheep(from, sheep_reach)
	if sheep_id < 0:
		return [EatTarget.NONE, -1, from]
	var body: bool = swarm.is_sheep_corpse(sheep_id)
	return [
		EatTarget.SHEEP_BODY if body else EatTarget.SHEEP,
		sheep_id,
		swarm.get_sheep_body(sheep_id).global_position,
	]


# --- Both devices: what an attack did --------------------------------------------


func _on_eat(payload: Array, _sender_id: int) -> void:
	var target: EatTarget = payload[0]
	var position: Vector2 = payload[2]
	_eat_target = target
	_eat_target_id = payload[1]
	_eat_left = payload[4]
	_eat_cooldown = payload[5]
	Services.audio.play_event(AudioEvents.EAT, payload[3])
	eat_started.emit(target, _eat_target_id, _eat_left)
	match target:
		EatTarget.SHEEP:
			_eaten_alive += 1
			sheep_killed.emit(_eat_target_id, GameEnums.DeathCause.EATEN, position)
			blood_spilled.emit(position)
			_count_eaten_sheep()
		EatTarget.SHEEP_BODY:
			# Its blood is on the ground since it was shot.
			_count_eaten_sheep()
		EatTarget.SHEEPHERDER:
			_sheepherder_alive = false
			_reload_left = 0.0
			sheepherder_killed.emit(position)


func _count_eaten_sheep() -> void:
	_eaten += 1
	eaten_count_changed.emit(_eaten)
	if _eaten == Services.perks.get_stat_int(StatIds.HERDER_KILL_THRESHOLD):
		sheepherder_kill_unlocked.emit()


## Turns the Monster into the spider once it has eaten enough.
func _evolve() -> void:
	var threshold: int = Services.perks.get_stat_int(StatIds.SPIDER_EVOLUTION_THRESHOLD)
	if _form == GameEnums.MonsterForm.SPIDER or not _monster_alive or _eaten < threshold:
		return
	_form = GameEnums.MonsterForm.SPIDER
	if is_instance_valid(_monster):
		Services.audio.play_event(AudioEvents.SPIDER_SCREECH, _monster.global_position)
	monster_form_changed.emit(_form)


func _stop_eating() -> void:
	_eat_target = EatTarget.NONE
	_eat_target_id = -1
	_eat_left = 0.0
	_eat_cooldown_left = 0.0


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
			_monster_alive = false
			_stop_eating()
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
	messenger.register_event(EVENT_EAT_REQUEST, NetMessenger.SenderRule.ANYONE)
	messenger.register_event(EVENT_EAT, NetMessenger.SenderRule.HOST_ONLY)
	messenger.subscribe(EVENT_EAT_REQUEST, _on_eat_request)
	messenger.subscribe(EVENT_EAT, _on_eat)
