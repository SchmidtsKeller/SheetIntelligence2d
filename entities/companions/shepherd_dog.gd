class_name ShepherdDog
extends CharacterBody2D
## The Friendly Shepherd Dog (GDD §4.1), a companion perk of the Sheepherder.
##
## It stays near the Sheepherder and steers around obstacles. It passes through
## sheep and the Sheepherder, so it never blocks anyone. When the Monster
## starts to eat a living sheep within the loud hearing range of the dog, the
## dog barks and faces the Monster for as long as the Monster eats; otherwise
## it gives no hint at all.
##
## Spawned by [DogEffect] through the session's entity registry as
## [constant KIND]. The host simulates it; the other device shows it through
## its [NetTransform2D]. The bark is an event, so both players hear it.

## The dog barked. Emitted on both devices.
signal barked

const KIND: StringName = &"shepherd_dog"
const SCENE_PATH: String = "res://entities/companions/shepherd_dog.tscn"
## Host to both: the dog barks. [code][entity_id][/code]
const EVENT_BARK: StringName = &"companion.dog_bark"
## Closer than this to its spot, the dog stands.
const ARRIVE_DISTANCE: float = 12.0
## How long the dog keeps one spot next to the Sheepherder, at least and at most.
const SPOT_TIME_MIN: float = 2.5
const SPOT_TIME_MAX: float = 6.0
## Obstacles and borders closer than this push the dog away.
const AVOID_MARGIN: float = 40.0
const AVOID_WEIGHT: float = 1.5
## The room the dog needs around its center.
const CLEARANCE: float = 16.0
## A dog that falls far behind and moves less than [constant STUCK_PROGRESS]
## in [constant STUCK_TIME] seconds is stuck and comes back to the Sheepherder.
const STUCK_TIME: float = 2.0
const STUCK_PROGRESS: float = 40.0

## Animations of the painted frames (#74).
const ANIMATION_IDLE: StringName = &"idle"
const ANIMATION_WALK: StringName = &"walk"
const ANIMATION_RUN: StringName = &"run"
const ANIMATION_BARK: StringName = &"bark"
## Below this speed the dog is shown standing.
const WALK_FROM: float = 8.0
## From this share of the dog speed on, the dog is shown running.
const RUN_FROM: float = 0.75
## The speed the walk frames are drawn for, as a share of the dog speed.
const WALK_FRAMES_SPEED: float = 0.5
## The walk frames never play slower than this.
const MIN_WALK_SPEED_SCALE: float = 0.5
## How quickly the shown speed follows the movement, per second. On the other
## device the dog moves in steps, one per snapshot.
const SPEED_SMOOTHING: float = 8.0

## The entity id in the session, or -1 outside the registry (tests).
var entity_id: int = -1
## Whether this device moves the dog (the host).
var simulated: bool = true
## The session that carries the bark. Defaults to [code]Services.session[/code].
var session: GameSession:
	get:
		if session == null:
			session = Services.session
		return session

## Where the dog wants to be, relative to the Sheepherder.
var _spot: Vector2 = Vector2.ZERO
var _spot_left: float = 0.0
var _alert_left: float = 0.0
var _alert_at: Vector2 = Vector2.ZERO
var _stuck_for: float = 0.0
var _stuck_check_at: Vector2 = Vector2.ZERO
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
var _shown_position: Vector2 = Vector2.ZERO
var _shown_speed: float = 0.0

@onready var _art: AnimatedSprite2D = $Art


## Registers the dog's kind with [param for_session], on both devices and
## before the host spawns it. The dog lives in the arena's entity layer.
static func register(for_session: GameSession) -> void:
	for_session.entities.register_kind(
		KIND, ShepherdDog.build.bind(for_session), Monster.find_entities_layer.bind(for_session)
	)


## Factory for [method NetEntityRegistry.register_kind].
static func build(
	new_entity_id: int, owner_id: int, data: Dictionary, for_session: GameSession = null
) -> Node:
	var dog: ShepherdDog = (load(SCENE_PATH) as PackedScene).instantiate()
	dog.entity_id = new_entity_id
	if for_session != null:
		dog.session = for_session
	dog.simulated = owner_id == dog.session.messenger.get_local_id()
	dog.position = Vector2(data.get("x", 0.0), data.get("y", 0.0))
	return dog


func _ready() -> void:
	_random.randomize()
	_shown_position = global_position
	_stuck_check_at = global_position
	var messenger: NetMessenger = session.messenger
	messenger.register_event(EVENT_BARK, NetMessenger.SenderRule.HOST_ONLY)
	messenger.subscribe(EVENT_BARK, _on_bark)
	if simulated:
		Services.combat.eat_started.connect(_on_eat_started)


func _exit_tree() -> void:
	session.messenger.unsubscribe(EVENT_BARK, _on_bark)
	if Services.combat.eat_started.is_connected(_on_eat_started):
		Services.combat.eat_started.disconnect(_on_eat_started)


func _physics_process(delta: float) -> void:
	advance(delta)


## Shows the dog standing, walking or running, from how it is seen to move, on
## both devices. A bark plays to its end first.
func _process(delta: float) -> void:
	if delta > 0.0:
		var speed: float = global_position.distance_to(_shown_position) / delta
		_shown_speed = lerpf(_shown_speed, speed, 1.0 - exp(-SPEED_SMOOTHING * delta))
	_shown_position = global_position
	if _art.animation == ANIMATION_BARK and _art.is_playing():
		return
	var animation: StringName = ANIMATION_IDLE
	var speed_scale: float = 1.0
	var top: float = Services.perks.get_stat(StatIds.DOG_MOVE_SPEED)
	if _shown_speed >= WALK_FROM and top > 0.0:
		var relative: float = _shown_speed / top
		animation = ANIMATION_RUN if relative >= RUN_FROM else ANIMATION_WALK
		if animation == ANIMATION_WALK:
			speed_scale = maxf(relative / WALK_FRAMES_SPEED, MIN_WALK_SPEED_SCALE)
	_art.speed_scale = speed_scale
	if _art.animation != animation or not _art.is_playing():
		_art.play(animation)


## The animation shown, for tests.
func get_animation() -> StringName:
	return _art.animation


## Moves the dog on by [param delta] seconds: follows the Sheepherder, or faces
## the Monster while it barks. Called every physics frame; only the host moves it.
func advance(delta: float) -> void:
	if not simulated:
		return
	var herder: Node2D = Services.perks.get_character(GameEnums.Role.SHEEPHERDER)
	if herder == null:
		return
	if _alert_left > 0.0:
		_alert_left = maxf(_alert_left - delta, 0.0)
		rotation = (_alert_at - global_position).angle()
		return
	velocity = _wish(herder, delta) * Services.perks.get_stat(StatIds.DOG_MOVE_SPEED)
	_slide(velocity * delta)
	if velocity.length() > 1.0:
		rotation = velocity.angle()
	_come_back_if_stuck(herder, delta)


## Moves by [param motion], sliding along whatever it runs into. Unlike
## move_and_slide, which takes the engine's frame time, this moves exactly as
## far as [method advance] was told.
func _slide(motion: Vector2) -> void:
	var collision: KinematicCollision2D = move_and_collide(motion)
	if collision != null:
		move_and_collide(collision.get_remainder().slide(collision.get_normal()))


## Whether the dog is barking at the Monster right now. Only known on the host.
func is_alerting() -> bool:
	return _alert_left > 0.0


## Which way the dog wants to walk, with a length from 0 to 1.
func _wish(herder: Node2D, delta: float) -> Vector2:
	var perks: PerkService = Services.perks
	_spot_left -= delta
	if _spot_left <= 0.0:
		var near: float = perks.get_stat(StatIds.DOG_FOLLOW_DISTANCE_MIN)
		var far: float = perks.get_stat(StatIds.DOG_FOLLOW_DISTANCE_MAX)
		_spot = Vector2.from_angle(_random.randf() * TAU) * _random.randf_range(near, far)
		_spot_left = _random.randf_range(SPOT_TIME_MIN, SPOT_TIME_MAX)
	var to_spot: Vector2 = herder.global_position + _spot - global_position
	if to_spot.length() < ARRIVE_DISTANCE:
		return Vector2.ZERO
	var wish: Vector2 = to_spot.normalized()
	var arena: Arena = get_tree().get_first_node_in_group(Groups.ARENA) as Arena
	if arena != null:
		var push: Vector2 = FlockSteering.obstacle_avoidance(
			global_position, arena.get_obstacle_footprints(), AVOID_MARGIN
		)
		push += FlockSteering.border_avoidance(global_position, arena.get_play_area(), AVOID_MARGIN)
		wish += push * AVOID_WEIGHT
	return wish.limit_length(1.0)


## A dog that cannot get round an obstacle comes back to the Sheepherder's side.
func _come_back_if_stuck(herder: Node2D, delta: float) -> void:
	var far: float = Services.perks.get_stat(StatIds.DOG_FOLLOW_DISTANCE_MAX)
	if global_position.distance_to(herder.global_position) <= far * 2.0:
		_stuck_for = 0.0
		_stuck_check_at = global_position
		return
	_stuck_for += delta
	if _stuck_for < STUCK_TIME:
		return
	_stuck_for = 0.0
	if global_position.distance_to(_stuck_check_at) < STUCK_PROGRESS:
		global_position = herder.global_position
	_stuck_check_at = global_position


# --- The alarm -------------------------------------------------------------------


## Host: the Monster started to eat. The dog only notices a living sheep being
## eaten within its hearing range (GDD §4.1).
func _on_eat_started(target: CombatService.EatTarget, _target_id: int, duration: float) -> void:
	if target != CombatService.EatTarget.SHEEP:
		return
	var monster: Node2D = Services.perks.get_character(GameEnums.Role.MONSTER)
	if monster == null:
		return
	var reach: float = Services.perks.get_stat(StatIds.HEARING_RANGE_LOUD)
	if monster.global_position.distance_to(global_position) > reach:
		return
	_alert_left = duration
	_alert_at = monster.global_position
	rotation = (_alert_at - global_position).angle()
	session.messenger.broadcast(EVENT_BARK, [entity_id])


func _on_bark(payload: Array, _sender_id: int) -> void:
	if payload[0] != entity_id:
		return
	Services.audio.play_event(AudioEvents.DOG_BARK, global_position)
	_art.speed_scale = 1.0
	_art.play(ANIMATION_BARK)
	barked.emit()
