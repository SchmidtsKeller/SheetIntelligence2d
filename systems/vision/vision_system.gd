class_name VisionSystem
extends Node2D
## Decides, on this device, what the local player can see (GDD §3.1, §3.2).
##
## [b]Sheepherder:[/b] the world lies in heavy darkness in which only static
## scenery stays faintly visible. Entities and marks on the ground are seen
## only where the flashlight lights them: inside the cone and not in an
## obstacle's shadow.
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
## Place it in the world (not in a [CanvasLayer]): its darkness darkens the
## canvas it is in.

## The colour unlit areas keep in the Sheepherder's view.
@export var darkness: Color = Color(0.11, 0.11, 0.14)
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


func _ready() -> void:
	_canvas_modulate = CanvasModulate.new()
	_canvas_modulate.name = "Darkness"
	add_child(_canvas_modulate)
	_update_darkness()


func _process(delta: float) -> void:
	update(delta)


## Decides every target and moves it toward being shown or hidden. Called
## every frame.
func update(delta: float) -> void:
	var step: float = fade_speed * delta
	for target: VisionTarget in get_targets():
		var seen: bool = can_see(target)
		target.shown = move_toward(target.shown, 1.0 if seen else 0.0, step)


## Whether the local player can see [param target] right now.
func can_see(target: VisionTarget) -> bool:
	if viewer != null and target.get_parent() == viewer:
		return true
	if target.cloaked:
		return false
	match role:
		GameEnums.Role.SHEEPHERDER:
			return _is_lit(target)
		GameEnums.Role.MONSTER:
			return target.kind == VisionTarget.Kind.GROUND_MARK or _is_in_sight(target)
	return true


## Sheepherder: some part of the target is inside the cone and not in the
## shadow of an obstacle.
func _is_lit(target: VisionTarget) -> bool:
	var cone: FlashlightCone = _get_cone()
	if cone == null:
		return false
	var world: World2D = get_world_2d()
	for point: Vector2 in target.get_sample_points():
		if cone.contains(point) and WorldQueries.has_line_of_sight(world, cone.origin, point):
			return true
	return false


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


func _get_cone() -> FlashlightCone:
	var herder: Sheepherder = viewer as Sheepherder
	return herder.get_flashlight_cone() if herder != null else null


func _update_darkness() -> void:
	if _canvas_modulate == null:
		return
	_canvas_modulate.color = darkness
	_canvas_modulate.visible = role == GameEnums.Role.SHEEPHERDER
