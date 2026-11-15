class_name Sheepherder
extends CharacterBody2D
## The Sheepherder (GDD §3.1): patrols, aims a flashlight through 360°, rings
## the bell and fires the single-shot firearm.
##
## Spawned through the session's entity registry as [constant KIND]. Only the
## device of the player who plays the Sheepherder moves it, from
## [InputService]. Its position and its rotation, which is the aim, travel in
## the snapshots. Shots and bell rings are asked of the host, which decides
## (docs/networking.md).
##
## Sheep are solid. The Sheepherder pushes the sheep it walks into (GDD §3.3),
## on the device that simulates that sheep.

## The bell rang at [param origin]. Emitted on both devices.
signal bell_rung(origin: Vector2, radius: float)

const KIND: StringName = &"sheepherder"
const SCENE_PATH: String = "res://entities/sheepherder/sheepherder.tscn"

const EVENT_BELL_REQUEST: StringName = &"sheepherder.bell_request"
const EVENT_BELL: StringName = &"sheepherder.bell"
const EVENT_PUSH: StringName = &"sheepherder.push"
## How long the Sheepherder has to stand still before their steps stop. On
## the other device they move only in the frames a snapshot is shown, so a
## single frame without movement is not a stop.
const STEPS_STOP_DELAY: float = 0.15

## Animations of the painted frames (#74).
const ANIMATION_IDLE: StringName = &"idle"
const ANIMATION_WALK: StringName = &"walk"
const ANIMATION_RUN: StringName = &"run"
const ANIMATION_FIRE: StringName = &"fire"
## The walk frames are drawn for the Sheepherder's speed; from this many times
## that speed on, the run frames are shown.
const RUN_FRAMES_FROM: float = 1.25
## The walk frames never play slower than this.
const MIN_WALK_SPEED_SCALE: float = 0.4
## How quickly the shown speed follows the movement, per second. On the other
## device the Sheepherder moves in steps, one per snapshot.
const SPEED_SMOOTHING: float = 8.0

## The entity id in the session, or -1 outside the registry (sandboxes, tests).
var entity_id: int = -1
## Whether this device moves the Sheepherder.
var controlled_locally: bool = true
## Whether a bot plays the Sheepherder (offline): they are moved on this
## device, but through their own [member input] and without a camera.
var is_bot: bool = false
## The controls the Sheepherder listens to when moved on this device. Defaults
## to [code]Services.input[/code], the player's; a bot's Sheepherder has a
## [BotInput].
var input: InputService:
	get:
		return input if input != null else Services.input
## The session that carries the bell and push events. Defaults to
## [code]Services.session[/code].
var session: GameSession:
	get:
		if session == null:
			session = Services.session
		return session

var _bell_cooldown_left: float = 0.0
var _alive: bool = true
## The perk service this Sheepherder registered with.
var _perks: PerkService
var _steps_emitter: int = 0
var _steps_position: Vector2 = Vector2.ZERO
var _still_time: float = STEPS_STOP_DELAY
var _shown_speed: float = 0.0

@onready var _art: AnimatedSprite2D = $Art
@onready var _camera: Camera2D = $Camera
@onready var _vision_target: VisionTarget = $VisionTarget


## Factory for [method NetEntityRegistry.register_kind]. Bind
## [param for_session] when the registry belongs to another session than
## [code]Services.session[/code].
static func build(
	new_entity_id: int, owner_id: int, data: Dictionary, for_session: GameSession = null
) -> Node:
	var herder: Sheepherder = (load(SCENE_PATH) as PackedScene).instantiate()
	herder.entity_id = new_entity_id
	if for_session != null:
		herder.session = for_session
	herder.controlled_locally = owner_id == herder.session.messenger.get_local_id()
	if BotInput.is_bot_data(data):
		herder.is_bot = true
		herder.input = BotInput.new(GameEnums.Role.SHEEPHERDER)
	herder.position = Vector2(data.get("x", 0.0), data.get("y", 0.0))
	return herder


func _ready() -> void:
	var messenger: NetMessenger = session.messenger
	messenger.register_event(EVENT_BELL_REQUEST, NetMessenger.SenderRule.ANYONE)
	messenger.register_event(EVENT_BELL, NetMessenger.SenderRule.HOST_ONLY)
	messenger.register_event(EVENT_PUSH, NetMessenger.SenderRule.ANYONE)
	messenger.subscribe(EVENT_BELL_REQUEST, _on_bell_request)
	messenger.subscribe(EVENT_BELL, _on_bell)
	messenger.subscribe(EVENT_PUSH, _on_push)
	Services.combat.shot_fired.connect(_on_shot_fired)
	Services.combat.sheepherder_killed.connect(_on_killed)
	Services.combat.reload_finished.connect(_on_reload_finished)
	_steps_emitter = Services.audio.start_emitter(AudioEvents.HERDER_STEP, self)
	_steps_position = global_position
	# The companions (the dog, the Monster's bat) find the Sheepherder here.
	_perks = Services.perks
	_perks.register_character(GameEnums.Role.SHEEPHERDER, self)
	if controlled_locally:
		input.action_pressed.connect(_on_action_pressed)
	if controlled_locally and not is_bot:
		_camera.enabled = true
		_camera.make_current()
		var aim_line: AimLine = AimLine.new()
		aim_line.name = "AimLine"
		add_child(aim_line)
		get_viewport().size_changed.connect(_update_zoom)
		_update_zoom()


func _exit_tree() -> void:
	var messenger: NetMessenger = session.messenger
	messenger.unsubscribe(EVENT_BELL_REQUEST, _on_bell_request)
	messenger.unsubscribe(EVENT_BELL, _on_bell)
	messenger.unsubscribe(EVENT_PUSH, _on_push)
	if Services.combat.shot_fired.is_connected(_on_shot_fired):
		Services.combat.shot_fired.disconnect(_on_shot_fired)
	if Services.combat.sheepherder_killed.is_connected(_on_killed):
		Services.combat.sheepherder_killed.disconnect(_on_killed)
	if Services.combat.reload_finished.is_connected(_on_reload_finished):
		Services.combat.reload_finished.disconnect(_on_reload_finished)
	if input.action_pressed.is_connected(_on_action_pressed):
		input.action_pressed.disconnect(_on_action_pressed)
	if is_instance_valid(_perks):
		_perks.unregister_character(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_bot and is_instance_valid(input):
		input.free()


func _physics_process(delta: float) -> void:
	_bell_cooldown_left = maxf(_bell_cooldown_left - delta, 0.0)
	if not controlled_locally or not _alive:
		return
	var speed: float = Services.perks.get_stat(StatIds.HERDER_MOVE_SPEED)
	var wish: Vector2 = input.get_move_vector() * speed
	velocity = wish
	move_and_slide()
	_push_sheep(wish)
	rotation = input.get_aim_direction(global_position).angle()


## Footsteps and animation on both devices, from what is shown of the
## Sheepherder.
func _process(delta: float) -> void:
	var moved: float = global_position.distance_to(_steps_position)
	if global_position != _steps_position:
		_steps_position = global_position
		_still_time = 0.0
	else:
		_still_time += delta
	if delta > 0.0:
		_shown_speed = lerpf(_shown_speed, moved / delta, 1.0 - exp(-SPEED_SMOOTHING * delta))
	var walking: bool = _alive and _still_time < STEPS_STOP_DELAY
	Services.audio.set_emitter_playing(_steps_emitter, walking)
	_animate(walking)


## Whether the Sheepherder is alive. The Monster's attack kills them at once
## (GDD §3.2); a dead Sheepherder neither moves nor shoots nor rings the bell.
func is_alive() -> bool:
	return _alive


func _on_killed(_position: Vector2) -> void:
	_alive = false
	velocity = Vector2.ZERO
	Services.audio.play_event(AudioEvents.HERDER_DEATH, global_position)


# --- Aim and flashlight ----------------------------------------------------------


## The direction the Sheepherder aims and shines the flashlight.
func get_aim_direction() -> Vector2:
	return Vector2.from_angle(global_rotation)


## The flashlight cone as it is right now, with perks and the bat applied. The
## [FlashlightLight] shows it; the [VisionSystem] decides what it reveals.
func get_flashlight_cone() -> FlashlightCone:
	var perks: PerkService = Services.perks
	return FlashlightCone.new(
		global_position,
		get_aim_direction(),
		perks.get_stat(StatIds.FLASHLIGHT_CONE_ANGLE_DEG),
		perks.get_stat(StatIds.FLASHLIGHT_CONE_LENGTH)
	)


## The camera that follows the Sheepherder on its player's device.
func get_camera() -> Camera2D:
	return _camera


# --- Bell ------------------------------------------------------------------------


## Asks the host to ring the bell here. Returns whether the request went out.
func ring_bell() -> bool:
	if not can_ring_bell():
		return false
	return session.messenger.send_to_host(EVENT_BELL_REQUEST, [entity_id, global_position])


func can_ring_bell() -> bool:
	return _alive and _bell_cooldown_left <= 0.0


## Seconds until the bell can ring again; 0 when ready.
func get_bell_cooldown_remaining() -> float:
	return _bell_cooldown_left


func _on_bell_request(payload: Array, _sender_id: int) -> void:
	if payload[0] != entity_id or not session.messenger.is_host() or not can_ring_bell():
		return
	session.messenger.broadcast(EVENT_BELL, [entity_id, payload[1]])


func _on_bell(payload: Array, _sender_id: int) -> void:
	if payload[0] != entity_id:
		return
	var origin: Vector2 = payload[1]
	var radius: float = Services.perks.get_stat(StatIds.BELL_RADIUS)
	_bell_cooldown_left = Services.perks.get_stat(StatIds.BELL_COOLDOWN)
	if session.messenger.is_host():
		Services.swarm.ring_bell(origin, radius)
	Services.audio.play_event(AudioEvents.BELL, origin)
	_add_effect(BellRingEffect.new(origin, radius))
	bell_rung.emit(origin, radius)


# --- Input -----------------------------------------------------------------------


func _on_action_pressed(action: StringName) -> void:
	if not _alive:
		return
	match action:
		InputActions.SHOOT:
			# Aim where the player points right now, not where the last physics
			# step left the Sheepherder facing.
			var aim: Vector2 = input.get_aim_direction(global_position)
			rotation = aim.angle()
			var empty: bool = Services.combat.is_ammo_depleted()
			Services.combat.request_shot(global_position, aim)
			# Only its own player hears the empty rifle, like the reload.
			if empty and not is_bot:
				Services.audio.play_event(AudioEvents.EMPTY_CLICK, global_position)
		InputActions.BELL:
			ring_bell()


# --- Pushing sheep ---------------------------------------------------------------


## Pushes every living sheep the last move ran into, with the part of
## [param wish] that pointed into it.
func _push_sheep(wish: Vector2) -> void:
	for index: int in get_slide_collision_count():
		var collision: KinematicCollision2D = get_slide_collision(index)
		var sheep: SheepBody = collision.get_collider() as SheepBody
		if sheep == null or not sheep.is_alive():
			continue
		var into: float = wish.dot(-collision.get_normal())
		if into > 0.0:
			_push(sheep, -collision.get_normal() * into)


## A sheep moves on the device that simulates it: here, or on the other one.
func _push(sheep: SheepBody, push_velocity: Vector2) -> void:
	var sheep_id: int = _entity_id_of(sheep)
	if sheep_id < 0 or session.entities.is_local_authority(sheep_id):
		sheep.push(push_velocity)
	else:
		session.messenger.send_to_remote(EVENT_PUSH, [sheep_id, push_velocity])


func _on_push(payload: Array, _sender_id: int) -> void:
	var sheep_id: int = payload[0]
	var sheep: SheepBody = session.entities.get_entity(sheep_id) as SheepBody
	if sheep != null and session.entities.is_local_authority(sheep_id):
		sheep.push(payload[1])


func _entity_id_of(node: Node) -> int:
	for id: int in session.entities.get_entity_ids():
		if session.entities.get_entity(id) == node:
			return id
	return -1


# --- Presentation ----------------------------------------------------------------


func _on_shot_fired(origin: Vector2, end_position: Vector2, result: int) -> void:
	_add_effect(ShotEffect.new(origin, end_position))
	# Where the bullet stopped in an obstacle or the fence; never in a creature,
	# which in the dark would tell the Sheepherder they hit something.
	if result in [CombatService.ShotResult.HIT_OBSTACLE, CombatService.ShotResult.MISSED]:
		Services.audio.play_event(AudioEvents.BULLET_IMPACT, end_position)
	if _alive:
		_art.speed_scale = 1.0
		_art.play(ANIMATION_FIRE)


## Idle, walk or run, from what is shown. A shot plays to its end first; a dead
## Sheepherder keeps the frame they died with.
func _animate(walking: bool) -> void:
	if not _alive:
		_art.pause()
		return
	if _art.animation == ANIMATION_FIRE and _art.is_playing():
		return
	var animation: StringName = ANIMATION_IDLE
	var speed_scale: float = 1.0
	if walking:
		var top: float = Services.perks.get_stat(StatIds.HERDER_MOVE_SPEED)
		var relative: float = _shown_speed / top if top > 0.0 else 1.0
		animation = ANIMATION_RUN if relative >= RUN_FRAMES_FROM else ANIMATION_WALK
		speed_scale = maxf(relative, MIN_WALK_SPEED_SCALE) if animation == ANIMATION_WALK else 1.0
	_art.speed_scale = speed_scale
	if _art.animation != animation or not _art.is_playing():
		_art.play(animation)


## The animation shown, for tests.
func get_animation() -> StringName:
	return _art.animation


## Only the Sheepherder's own player hears the reload: after the third shot it
## would tell the Monster of a Spare Bullet (GDD §4.1).
func _on_reload_finished() -> void:
	if controlled_locally and not is_bot and _alive:
		Services.audio.play_event(AudioEvents.RELOAD_CLICK, global_position)


## Effects live in world coordinates, unaffected by the Sheepherder's turning,
## and are seen only when the Sheepherder is (GDD §3.2).
func _add_effect(effect: Node2D) -> void:
	effect.top_level = true
	add_child(effect)
	_vision_target.attach(effect)


## Gameplay zoom: the camera shows as much world as a player may see.
func _update_zoom() -> void:
	var zoom: float = ViewRules.camera_zoom(
		get_viewport_rect().size, Services.config.get_view_max_world_size()
	)
	_camera.zoom = Vector2(zoom, zoom)
