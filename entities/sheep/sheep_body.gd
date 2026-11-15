class_name SheepBody
extends CharacterBody2D
## The body of every sheep: the NPC sheep of the flock and the Monster's
## disguise alike (GDD §3.2, §3.3).
##
## Whatever steers a sheep (the flock AI, the Monster player, a test) lives
## outside this scene and only uses the methods below. So a sheep never shows
## who controls it: node structure, draw order, motion, animation timing and
## sounds are the same for all of them.
##
## Sheep are solid against the world, each other and the Sheepherder, who
## pushes them aside through [method push] (GDD §3.3). A shot sheep stays as a
## body that can still be eaten; an eaten sheep disappears (GDD §3.1, §3.2).

## The sheep entered [param state].
signal state_changed(state: State)

## The sheep bleated.
signal bleated

## The living sheep was killed.
signal died(cause: GameEnums.DeathCause)

## What the sheep is doing. Bleating is not a state: a sheep can bleat while
## standing, walking or grazing.
enum State {
	IDLE,
	WALK,
	GRAZE,
	## Eating another creature, unable to do anything else. Every sheep body can
	## do this, but only the Monster ever does (GDD §3.2).
	DEVOUR,
	## Shot: the body lies on the ground for the rest of the round.
	CORPSE,
	## Eaten: the body disappears once the animation has played.
	EATEN,
}

const ANIMATION_IDLE: StringName = &"idle"
const ANIMATION_WALK: StringName = &"walk"
const ANIMATION_GRAZE: StringName = &"graze"
const ANIMATION_DEVOUR: StringName = &"devour"
const ANIMATION_CORPSE: StringName = &"corpse"
const ANIMATION_EATEN: StringName = &"eaten"
const ANIMATION_BLEAT: StringName = &"bleat"

## Below this speed a sheep counts as standing.
const WALK_SPEED_THRESHOLD: float = 5.0
## The walk animation never plays slower than this, even at a crawl.
const MIN_WALK_ANIMATION_SPEED: float = 0.4

## Everything this sheep can look like.
@export var catalog: SheepAppearanceCatalog

## Whether this device simulates the sheep. A sheep that is simulated on the
## other device does not walk by itself; it is put where it belongs.
var simulated: bool = true

## Whether something else decides where and how the sheep is shown, by calling
## [method present]. Replicated sheep are shown a moment in the past on every
## device, also on the one that simulates them, so that no sheep looks more
## current than another (see docs/networking.md, uniform presentation).
var presented_externally: bool = false:
	set(value):
		presented_externally = value
		if is_node_ready():
			_apply_presentation_mode()

## Top speed in pixels per second instead of the sheep speed from the stats;
## negative for none. Acceleration and turn rate stay those of every sheep.
## The Monster's player sets it (walk, sprint, spider).
var speed_override: float = -1.0

var _visual_seed: int = 0
var _appearance: SheepAppearance
var _motion: SheepMotion = SheepMotion.new()
var _move_input: Vector2 = Vector2.ZERO
var _push_velocity: Vector2 = Vector2.ZERO
var _grazing: bool = false
var _devour_left: float = 0.0
var _devour_duration: float = 0.0
var _visual_override: Node2D
## What is shown, which lags behind the simulation when the sheep is
## presented externally.
var _shown_speed: float = 0.0
var _shown_grazing: bool = false
var _state: State = State.IDLE
var _layers: Array[Sprite2D] = []
var _move_emitter: int = -1
var _graze_emitter: int = -1

@onready var _collision: CollisionShape2D = $Collision
@onready var _facing: Node2D = $Facing
@onready var _visual: Node2D = $Facing/Pose/Visual
@onready var _body_anchor: Node2D = $Facing/Pose/Visual/Body
@onready var _head_anchor: Node2D = $Facing/Pose/Visual/Head/HeadPose
@onready var _hit_shape: CollisionShape2D = $Facing/HitArea/Shape
@onready var _animation: AnimationPlayer = $Animation
@onready var _voice: AnimationPlayer = $Voice


func _ready() -> void:
	_build_layers()
	_apply_appearance()
	_apply_presentation_mode()
	_animation.animation_finished.connect(_on_animation_finished)
	# Its sounds come from where it is shown, like everything else of it.
	_move_emitter = Services.audio.start_emitter(AudioEvents.GRASS_MOVE, _facing)
	_graze_emitter = Services.audio.start_emitter(AudioEvents.GRAZE, _facing)
	_play_state_animation()


func _physics_process(delta: float) -> void:
	if not is_alive():
		return
	if _devour_left > 0.0:
		_devour_left = maxf(_devour_left - delta, 0.0)
		if _devour_left == 0.0:
			_update_state()
	if simulated:
		var perks: PerkService = Services.perks
		var wish: Vector2 = Vector2.ZERO if _grazing or is_devouring() else _move_input
		var max_speed: float = (
			speed_override if speed_override >= 0.0 else perks.get_stat(StatIds.SHEEP_MOVE_SPEED)
		)
		var acceleration: float = perks.get_stat(StatIds.SHEEP_ACCELERATION)
		var turn_rate: float = deg_to_rad(perks.get_stat(StatIds.SHEEP_TURN_RATE_DEG))
		velocity = _motion.step(wish, max_speed, acceleration, turn_rate, delta) + _push_velocity
		_push_velocity = Vector2.ZERO
		move_and_slide()
	if not presented_externally:
		_show(_motion.heading, _motion.speed, _grazing)


# --- Look ------------------------------------------------------------------------


## Gives the sheep the look of [param visual_seed]. Can be called before or
## after the sheep enters the scene tree.
func set_visual_seed(visual_seed: int) -> void:
	_visual_seed = visual_seed
	if is_node_ready():
		_apply_appearance()


func get_visual_seed() -> int:
	return _visual_seed


## The look currently shown.
func get_appearance() -> SheepAppearance:
	return _appearance


# --- Steering --------------------------------------------------------------------


## Where the sheep should walk, with a length from 0 (stand) to 1 (full speed).
## Stays in effect until changed. Ignored while grazing or dead.
func set_move_input(direction: Vector2) -> void:
	_move_input = direction.limit_length(1.0)


## Lowers or raises the head to eat grass. A grazing sheep stands still
## (GDD §3.2). Returns [code]false[/code] for a dead sheep.
func set_grazing(grazing: bool) -> bool:
	if not is_alive():
		return false
	_grazing = grazing
	if not presented_externally:
		_shown_grazing = grazing
		_update_state()
	return true


## Bleats, unless the sheep is dead or already bleating. Returns whether it did.
func bleat() -> bool:
	if not is_alive() or _voice.is_playing():
		return false
	_voice.play(ANIMATION_BLEAT)
	Services.audio.play_event(AudioEvents.BLEAT, _facing.global_position)
	bleated.emit()
	return true


## Eats another creature for [param duration] seconds. The sheep stops at once
## and can neither walk nor graze until it is done; nothing aborts it but
## death (GDD §3.2). Returns [code]false[/code] for a dead sheep.
func devour(duration: float) -> bool:
	if not is_alive() or duration <= 0.0:
		return false
	_devour_duration = duration
	_devour_left = duration
	_motion.speed = 0.0
	_enter_state(State.DEVOUR)
	return true


## Moves the sheep by [param push_velocity] during the next physics step, on
## top of its own walking, e.g. when the Sheepherder walks into it. The push is
## blocked by the same obstacles as walking. Dead sheep cannot be pushed.
func push(push_velocity: Vector2) -> void:
	if is_alive():
		_push_velocity += push_velocity


# --- Presentation ----------------------------------------------------------------


## Replaces the sheep's look with [param visual], drawn where the sheep is
## shown and facing the same way; [code]null[/code] brings the sheep back.
## For the Monster's spider form (GDD §3.2).
func set_visual_override(visual: Node2D) -> void:
	if is_instance_valid(_visual_override):
		_visual_override.queue_free()
	_visual_override = visual
	(_facing.get_node(^"Pose") as Node2D).visible = visual == null
	if visual != null:
		_facing.add_child(visual)


## Shows the living sheep at [param shown_position], facing [param heading]
## (radians), as if walking at [param speed] and grazing or not. Only for a
## sheep that is [member presented_externally]; its animation and sounds
## follow what is shown, not the simulation.
func present(shown_position: Vector2, heading: float, speed: float, grazing: bool) -> void:
	if not is_alive():
		return
	_facing.global_position = shown_position
	_show(heading, speed, grazing)


# --- Death -----------------------------------------------------------------------


## Kills the sheep. [constant GameEnums.DeathCause.SHOT] leaves a body,
## [constant GameEnums.DeathCause.EATEN] makes it disappear; the body of a shot
## sheep can still be eaten. Returns [code]false[/code] if the sheep cannot die
## that way (e.g. it is already gone).
func kill(cause: GameEnums.DeathCause) -> bool:
	var was_alive: bool = is_alive()
	match cause:
		GameEnums.DeathCause.SHOT when was_alive:
			_enter_state(State.CORPSE)
		GameEnums.DeathCause.EATEN when was_alive or _state == State.CORPSE:
			_enter_state(State.EATEN)
		_:
			return false
	if was_alive:
		died.emit(cause)
	return true


## Whether the sheep is alive.
func is_alive() -> bool:
	return _state != State.CORPSE and _state != State.EATEN


func is_grazing() -> bool:
	return _grazing and is_alive()


## Whether the sheep is in the middle of eating another creature.
func is_devouring() -> bool:
	return _devour_left > 0.0 and is_alive()


func get_state() -> State:
	return _state


## Direction the sheep faces, in radians (0 = +x).
func get_heading() -> float:
	return _motion.heading


## Current walking speed in pixels per second, without pushes.
func get_speed() -> float:
	return _motion.speed


# --- Internals -------------------------------------------------------------------


func _build_layers() -> void:
	if catalog == null:
		push_error("SheepBody: no appearance catalog is set.")
		return
	for slot: SheepAppearanceSlot in catalog.slots:
		var layer: Sprite2D = Sprite2D.new()
		layer.name = String(slot.id).to_pascal_case()
		var anchor: Node2D = (
			_head_anchor if slot.anchor == SheepAppearanceSlot.Anchor.HEAD else _body_anchor
		)
		anchor.add_child(layer)
		_layers.append(layer)


func _apply_appearance() -> void:
	if catalog == null:
		return
	_appearance = SheepAppearanceGenerator.generate(_visual_seed, catalog)
	for slot_index: int in _layers.size():
		var layer: Sprite2D = _layers[slot_index]
		var part_index: int = _appearance.part_indices[slot_index]
		layer.visible = part_index != SheepAppearance.NONE
		if not layer.visible:
			layer.texture = null
			continue
		var part: SheepAppearancePart = catalog.slots[slot_index].parts[part_index]
		var tint_index: int = _appearance.tint_indices[slot_index]
		layer.texture = part.texture
		layer.position = part.offset
		layer.self_modulate = (
			part.tints[tint_index] if tint_index != SheepAppearance.NONE else Color.WHITE
		)
	_visual.scale = Vector2(_appearance.length_permille, _appearance.width_permille) / 1000.0


func _apply_presentation_mode() -> void:
	# A sheep that is shown from outside is drawn where it is told, not where
	# its body is.
	_facing.top_level = presented_externally
	if presented_externally:
		_facing.global_position = global_position
	else:
		_facing.position = Vector2.ZERO


func _show(heading: float, speed: float, grazing: bool) -> void:
	_facing.rotation = heading
	_shown_speed = speed
	_shown_grazing = grazing
	_update_state()


func _update_state() -> void:
	if not is_alive():
		return
	var state: State = State.IDLE
	if _devour_left > 0.0:
		state = State.DEVOUR
	elif _shown_grazing:
		state = State.GRAZE
	elif _shown_speed > WALK_SPEED_THRESHOLD:
		state = State.WALK
	if state != _state:
		_enter_state(state)
	if _state == State.WALK:
		var max_speed: float = Services.perks.get_stat(StatIds.SHEEP_MOVE_SPEED)
		_animation.speed_scale = (
			maxf(_shown_speed / max_speed, MIN_WALK_ANIMATION_SPEED) if max_speed > 0.0 else 1.0
		)


func _enter_state(state: State) -> void:
	_state = state
	if not is_alive():
		_motion.speed = 0.0
		velocity = Vector2.ZERO
		_grazing = false
		_devour_left = 0.0
		_shown_speed = 0.0
		_shown_grazing = false
		if presented_externally:
			# The body lies where the sheep died, not where it was last shown.
			_facing.global_position = global_position
		_voice.stop()
		_collision.set_deferred(&"disabled", true)
		_hit_shape.set_deferred(&"disabled", true)
	Services.audio.set_emitter_playing(_move_emitter, state == State.WALK)
	Services.audio.set_emitter_playing(_graze_emitter, state == State.GRAZE)
	_play_state_animation()
	state_changed.emit(state)


func _play_state_animation() -> void:
	_animation.speed_scale = 1.0
	match _state:
		State.IDLE:
			_animation.play(ANIMATION_IDLE)
		State.WALK:
			_animation.play(ANIMATION_WALK)
		State.GRAZE:
			_animation.play(ANIMATION_GRAZE)
		State.DEVOUR:
			var length: float = _animation.get_animation(ANIMATION_DEVOUR).length
			_animation.play(ANIMATION_DEVOUR, -1.0, length / _devour_duration)
		State.CORPSE:
			_animation.play(ANIMATION_CORPSE)
		State.EATEN:
			# The sheep vanishes exactly while the Monster eats (GDD §3.2), which
			# the Faster Consumption perk shortens.
			var duration: float = Services.perks.get_stat(StatIds.EAT_DURATION)
			var eaten_length: float = _animation.get_animation(ANIMATION_EATEN).length
			_animation.play(
				ANIMATION_EATEN, -1.0, eaten_length / duration if duration > 0.0 else 1.0
			)


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == ANIMATION_EATEN:
		hide()
