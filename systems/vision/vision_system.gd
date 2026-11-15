class_name VisionSystem
extends Node2D
## Decides, on this device, what the local player can see (GDD §3.1, §3.2).
##
## [b]Sheepherder:[/b] the night is dim, not black: static scenery stays
## readable. Entities and marks on the ground are seen only where light falls
## on them: the flashlight or a lit torch, not blocked by an obstacle (see
## [LightRules]). An entity in the soft edge of a light is shown as dim as
## the light there.
## [br][b]Monster:[/b] no darkness. Entities are seen unless an obstacle stands
## between them and the Monster; the ground, with its marks and the
## Sheepherder's light, is always seen.
## [br]Everybody always sees their own character. A
## [member VisionTarget.cloaked] entity, the invisible Monster, is seen by
## nobody else.
##
## Every entity with a [VisionTarget] is decided the same way; there are no
## rules per entity type. The decision only changes what is drawn here. It
## never touches the simulation or what is sent to the other device.
##
## The Monster sees the world through its [NightVision]: a red vignette and a
## subtle filter, shown on this device only while its player is the Monster.
## It is a look only and changes nothing of what is seen.
##
## Place it in the world (not in a [CanvasLayer]): its darkness darkens the
## canvas it is in.

## The Monster's look; its parameters are tuned in the scene.
const NIGHT_VISION_SCENE: PackedScene = preload("res://systems/vision/night_vision.tscn")

## The colour unlit areas keep in the Sheepherder's view: darker and colder
## than the light, not black (#63).
@export var darkness: Color = Color(0.3, 0.31, 0.39)
## How fast an entity fades in or out, in full fades per second.
@export var fade_speed: float = 8.0

## The local player's role. [constant GameEnums.Role.NONE] shows everything.
var role: GameEnums.Role = GameEnums.Role.NONE:
	set(value):
		role = value
		_update_darkness()

## The local player's character: the Sheepherder (whose flashlight decides) or
## the Monster (from whose position it sees).
var viewer: Node2D

var _canvas_modulate: CanvasModulate
var _night_vision: NightVision


func _ready() -> void:
	_canvas_modulate = CanvasModulate.new()
	_canvas_modulate.name = "Darkness"
	add_child(_canvas_modulate)
	_night_vision = NIGHT_VISION_SCENE.instantiate()
	add_child(_night_vision)
	_update_darkness()


func _process(delta: float) -> void:
	update(delta)
	_night_vision.spider = _is_viewer_a_spider()


## The Monster's night vision: shown only while the local player is the
## Monster.
func get_night_vision() -> NightVision:
	return _night_vision


## Decides every target and moves it toward how visible it is. Called every
## frame.
func update(delta: float) -> void:
	var step: float = fade_speed * delta
	var torches: Array[Torch] = _lit_torches()
	for target: VisionTarget in get_targets():
		target.shown = move_toward(target.shown, _visibility(target, torches), step)


## How visible [param target] is to the local player right now, from 0 to 1.
func get_visibility(target: VisionTarget) -> float:
	return _visibility(target, _lit_torches())


## Whether the local player can see [param target] right now: it is at least
## half visible.
func can_see(target: VisionTarget) -> bool:
	return get_visibility(target) >= LightRules.SEEN_LEVEL


func _visibility(target: VisionTarget, torches: Array[Torch]) -> float:
	if viewer != null and target.get_parent() == viewer:
		return 1.0
	if target.cloaked:
		return 0.0
	match role:
		GameEnums.Role.SHEEPHERDER:
			return _light_on(target, torches)
		GameEnums.Role.MONSTER:
			var seen: bool = target.kind == VisionTarget.Kind.GROUND_MARK or _is_in_sight(target)
			return 1.0 if seen else 0.0
	return 1.0


## Sheepherder: the brightest light on any part of the target.
func _light_on(target: VisionTarget, torches: Array[Torch]) -> float:
	var cone: FlashlightCone = _get_cone()
	var world: World2D = get_world_2d()
	var best: float = 0.0
	for point: Vector2 in target.get_sample_points():
		best = maxf(best, LightRules.level_at(world, point, cone, torches))
		if best >= 1.0:
			break
	return best


## Monster: no obstacle hides all of the target from the Monster.
func _is_in_sight(target: VisionTarget) -> bool:
	if viewer == null:
		return false
	var eye: Vector2 = viewer.global_position
	for point: Vector2 in target.get_sample_points():
		if WorldQueries.has_line_of_sight(get_world_2d(), eye, point):
			return true
	return false


## Every target in the world.
func get_targets() -> Array[VisionTarget]:
	var targets: Array[VisionTarget] = []
	for entity: Node in get_tree().get_nodes_in_group(Groups.DYNAMIC_ENTITIES):
		for child: Node in entity.get_children():
			if child is VisionTarget:
				targets.append(child)
	return targets


func _lit_torches() -> Array[Torch]:
	if role != GameEnums.Role.SHEEPHERDER:
		return []
	return LightRules.lit_torches(get_tree())


func _get_cone() -> FlashlightCone:
	var herder: Sheepherder = viewer as Sheepherder
	return herder.get_flashlight_cone() if herder != null else null


func _is_viewer_a_spider() -> bool:
	if role != GameEnums.Role.MONSTER or not is_instance_valid(viewer):
		return false
	var monster: Monster = Monster.of(viewer)
	return monster != null and monster.get_form() == GameEnums.MonsterForm.SPIDER


## The darkness for the Sheepherder, the night vision for the Monster.
func _update_darkness() -> void:
	if _canvas_modulate == null:
		return
	_canvas_modulate.color = darkness
	_canvas_modulate.visible = role == GameEnums.Role.SHEEPHERDER
	_night_vision.visible = role == GameEnums.Role.MONSTER
