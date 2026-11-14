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

## Corners of the drawn flashlight cone's arc.
const CONE_ARC_POINTS: int = 16

## The entity id in the session, or -1 outside the registry (sandboxes, tests).
var entity_id: int = -1
## Whether this device moves the Sheepherder.
var controlled_locally: bool = true
## The session that carries the bell and push events. Defaults to
## [code]Services.session[/code].
var session: GameSession:
	get:
		if session == null:
			session = Services.session
		return session

var _bell_cooldown_left: float = 0.0
var _cone_shape: Vector2 = Vector2.ZERO

@onready var _flashlight: Polygon2D = $Flashlight
@onready var _camera: Camera2D = $Camera


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
	_update_cone_shape()
	if controlled_locally:
		Services.input.action_pressed.connect(_on_action_pressed)
		_camera.enabled = true
		_camera.make_current()
		get_viewport().size_changed.connect(_update_zoom)
		_update_zoom()


func _exit_tree() -> void:
	var messenger: NetMessenger = session.messenger
	messenger.unsubscribe(EVENT_BELL_REQUEST, _on_bell_request)
	messenger.unsubscribe(EVENT_BELL, _on_bell)
	messenger.unsubscribe(EVENT_PUSH, _on_push)
	if Services.combat.shot_fired.is_connected(_on_shot_fired):
		Services.combat.shot_fired.disconnect(_on_shot_fired)
	if Services.input.action_pressed.is_connected(_on_action_pressed):
		Services.input.action_pressed.disconnect(_on_action_pressed)


func _process(_delta: float) -> void:
	_update_cone_shape()


func _physics_process(delta: float) -> void:
	_bell_cooldown_left = maxf(_bell_cooldown_left - delta, 0.0)
	if not controlled_locally:
		return
	var input: InputService = Services.input
	var speed: float = Services.perks.get_stat(StatIds.HERDER_MOVE_SPEED)
	var wish: Vector2 = input.get_move_vector() * speed
	velocity = wish
	move_and_slide()
	_push_sheep(wish)
	rotation = input.get_aim_direction(global_position).angle()


# --- Aim and flashlight ----------------------------------------------------------


## The direction the Sheepherder aims and shines the flashlight.
func get_aim_direction() -> Vector2:
	return Vector2.from_angle(global_rotation)


## The flashlight cone as it is right now, with perks and the bat applied. The
## real light and visibility come with #15.
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
	return _bell_cooldown_left <= 0.0


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
	match action:
		InputActions.SHOOT:
			# Aim where the player points right now, not where the last physics
			# step left the Sheepherder facing.
			var aim: Vector2 = Services.input.get_aim_direction(global_position)
			rotation = aim.angle()
			Services.combat.request_shot(global_position, aim)
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


func _on_shot_fired(origin: Vector2, end_position: Vector2, _result: int) -> void:
	_add_effect(ShotEffect.new(origin, end_position))


## Effects live in world coordinates, unaffected by the Sheepherder's turning.
func _add_effect(effect: Node2D) -> void:
	effect.top_level = true
	add_child(effect)


func _update_cone_shape() -> void:
	var perks: PerkService = Services.perks
	var shape: Vector2 = Vector2(
		perks.get_stat(StatIds.FLASHLIGHT_CONE_ANGLE_DEG),
		perks.get_stat(StatIds.FLASHLIGHT_CONE_LENGTH)
	)
	if shape == _cone_shape:
		return
	_cone_shape = shape
	var half_angle: float = deg_to_rad(shape.x) / 2.0
	var points: PackedVector2Array = [Vector2.ZERO]
	for index: int in CONE_ARC_POINTS + 1:
		var angle: float = lerpf(-half_angle, half_angle, float(index) / CONE_ARC_POINTS)
		points.append(Vector2.from_angle(angle) * shape.y)
	_flashlight.polygon = points


## Gameplay zoom: the camera shows as much world as a player may see.
func _update_zoom() -> void:
	var zoom: float = ViewRules.camera_zoom(
		get_viewport_rect().size, Services.config.get_view_max_world_size()
	)
	_camera.zoom = Vector2(zoom, zoom)
