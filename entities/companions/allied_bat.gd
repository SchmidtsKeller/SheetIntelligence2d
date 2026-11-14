class_name AlliedBat
extends Node2D
## The Allied Bat (GDD §4.2), the Monster's companion perk.
##
## It flies in from a random point on the map edge nearest the Sheepherder and
## circles them. While it does, the flashlight cone's length and angle are
## each about 42 % shorter, for [member GameConfig.bat_disruption_duration]
## seconds; then it flies back out where it came from and is gone. It has no
## body and no hit area: bullets pass through it.
##
## Spawned by [BatEffect] through the session's entity registry as
## [constant KIND]. The host flies it; the other device shows it through its
## [NetTransform2D]. The host announces its arrival, and both devices then
## shrink the cone for the same time, so the light and what it reveals match.

## The bat reached the Sheepherder and the cone shrank. Emitted on both devices.
signal arrived

enum Phase {
	## Flying to the Sheepherder.
	APPROACH,
	## Circling the Sheepherder while the cone is shrunk.
	HARASS,
	## Flying away.
	LEAVE,
}

const KIND: StringName = &"allied_bat"
const SCENE_PATH: String = "res://entities/companions/allied_bat.tscn"
## Host to both: the bat reached the Sheepherder. [code][entity_id][/code]
const EVENT_ARRIVED: StringName = &"companion.bat_arrived"

## The entity id in the session, or -1 outside the registry (tests).
var entity_id: int = -1
## Whether this device flies the bat (the host).
var simulated: bool = true
## The session that carries the arrival. Defaults to [code]Services.session[/code].
var session: GameSession:
	get:
		if session == null:
			session = Services.session
		return session

var _phase: Phase = Phase.APPROACH
var _harass_left: float = 0.0
var _orbit_angle: float = 0.0
var _exit: Vector2 = Vector2.ZERO
var _gone: bool = false


## Registers the bat's kind with [param for_session], on both devices and
## before the host spawns it. The bat flies above everything else.
static func register(for_session: GameSession) -> void:
	for_session.entities.register_kind(
		KIND, AlliedBat.build.bind(for_session), AlliedBat.find_overlays_layer.bind(for_session)
	)


## Factory for [method NetEntityRegistry.register_kind].
static func build(
	new_entity_id: int, owner_id: int, data: Dictionary, for_session: GameSession = null
) -> Node:
	var bat: AlliedBat = (load(SCENE_PATH) as PackedScene).instantiate()
	bat.entity_id = new_entity_id
	if for_session != null:
		bat.session = for_session
	bat.simulated = owner_id == bat.session.messenger.get_local_id()
	bat.position = Vector2(data.get("x", 0.0), data.get("y", 0.0))
	return bat


## The layer above the arena's entities; [code]null[/code] without an arena.
static func find_overlays_layer(for_session: GameSession) -> Node:
	if not for_session.is_inside_tree():
		return null
	var arena: Arena = for_session.get_tree().get_first_node_in_group(Groups.ARENA) as Arena
	return arena.get_overlays_layer() if arena != null else null


## Where the bat comes in: a random point on the edge of [param bounds] that is
## nearest to [param target] (GDD §4.2).
static func entry_point(bounds: Rect2, target: Vector2, random: RandomNumberGenerator) -> Vector2:
	var to_left: float = target.x - bounds.position.x
	var to_right: float = bounds.end.x - target.x
	var to_top: float = target.y - bounds.position.y
	var to_bottom: float = bounds.end.y - target.y
	var nearest: float = minf(minf(to_left, to_right), minf(to_top, to_bottom))
	var along_x: float = random.randf_range(bounds.position.x, bounds.end.x)
	var along_y: float = random.randf_range(bounds.position.y, bounds.end.y)
	if nearest == to_left:
		return Vector2(bounds.position.x, along_y)
	if nearest == to_right:
		return Vector2(bounds.end.x, along_y)
	if nearest == to_top:
		return Vector2(along_x, bounds.position.y)
	return Vector2(along_x, bounds.end.y)


func _ready() -> void:
	_exit = global_position
	var messenger: NetMessenger = session.messenger
	messenger.register_event(EVENT_ARRIVED, NetMessenger.SenderRule.HOST_ONLY)
	messenger.subscribe(EVENT_ARRIVED, _on_arrived)


func _exit_tree() -> void:
	session.messenger.unsubscribe(EVENT_ARRIVED, _on_arrived)


func _physics_process(delta: float) -> void:
	advance(delta)


## Moves the bat on by [param delta] seconds. Called every physics frame; the
## host flies it, both devices count down the harassment.
func advance(delta: float) -> void:
	if _phase == Phase.HARASS:
		_harass_left = maxf(_harass_left - delta, 0.0)
		if _harass_left == 0.0:
			_phase = Phase.LEAVE
	if not simulated:
		return
	var perks: PerkService = Services.perks
	var herder: Node2D = perks.get_character(GameEnums.Role.SHEEPHERDER)
	var speed: float = perks.get_stat(StatIds.BAT_FLIGHT_SPEED)
	var radius: float = perks.get_stat(StatIds.BAT_ORBIT_RADIUS)
	if herder == null and _phase != Phase.LEAVE:
		_phase = Phase.LEAVE
	match _phase:
		Phase.APPROACH:
			_fly_towards(herder.global_position, speed * delta)
			if global_position.distance_to(herder.global_position) <= radius:
				_orbit_angle = (global_position - herder.global_position).angle()
				session.messenger.broadcast(EVENT_ARRIVED, [entity_id])
		Phase.HARASS:
			_orbit_angle += speed / maxf(radius, 1.0) * delta
			var goal: Vector2 = herder.global_position + Vector2.from_angle(_orbit_angle) * radius
			rotation = (goal - global_position).angle()
			global_position = goal
		Phase.LEAVE:
			_fly_towards(_exit, speed * delta)
			if global_position.is_equal_approx(_exit):
				_leave()


## What the bat is doing.
func get_phase() -> Phase:
	return _phase


## Seconds of harassment left; 0 before it arrives and after it is done.
func get_harass_left() -> float:
	return _harass_left


func _fly_towards(target: Vector2, step: float) -> void:
	if not global_position.is_equal_approx(target):
		rotation = (target - global_position).angle()
	global_position = global_position.move_toward(target, step)


func _leave() -> void:
	if _gone:
		return
	_gone = true
	if entity_id >= 0:
		session.entities.despawn(entity_id)
	else:
		queue_free()


## Both devices: the cone shrinks for the same time on both (GDD §4.2, §5).
func _on_arrived(payload: Array, _sender_id: int) -> void:
	if payload[0] != entity_id or _phase != Phase.APPROACH:
		return
	var perks: PerkService = Services.perks
	var duration: float = perks.get_stat(StatIds.BAT_DISRUPTION_DURATION)
	var factor: float = 1.0 - perks.get_stat(StatIds.BAT_CONE_SHRINK)
	for stat: StringName in [StatIds.FLASHLIGHT_CONE_ANGLE_DEG, StatIds.FLASHLIGHT_CONE_LENGTH]:
		perks.add_modifier(
			stat, PerkService.ModifierOp.MULTIPLY, factor, PerkIds.ALLIED_BAT, duration
		)
	_phase = Phase.HARASS
	_harass_left = duration
	Services.audio.play_event(AudioEvents.BAT, global_position)
	arrived.emit()
