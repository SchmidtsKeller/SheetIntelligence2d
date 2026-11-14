class_name VisionTarget
extends Node
## Lets the vision system decide whether its entity can be seen (GDD §3.1,
## §3.2). Add it as a child of anything that may be hidden: sheep, the
## characters, companions, blood. The entity's root must be in the group
## [constant Groups.DYNAMIC_ENTITIES].
##
## The vision system fades [member visual] in and out. Effects that belong to
## the entity (a muzzle flash, the bell's ring) are attached with
## [method attach], so they are shown only when the entity is.

## How the entity is seen.
enum Kind {
	## Characters, sheep, companions, bodies: hidden behind obstacles, and in
	## the dark for the Sheepherder.
	ENTITY,
	## Marks on the ground such as blood: in the dark for the Sheepherder, but
	## the Monster sees all of the ground.
	GROUND_MARK,
}

@export var kind: Kind = Kind.ENTITY
## The part that is shown or hidden. Defaults to the parent.
@export var visual: CanvasItem
## How far the entity reaches from the center of [member visual]. It counts as
## seen when any part of it is.
@export var radius: float = 16.0

## How visible the entity is on this device right now, from 0 to 1. Set by
## the vision system.
var shown: float = 1.0:
	set(value):
		shown = clampf(value, 0.0, 1.0)
		_apply()

var _effects: Array[CanvasItem] = []


func _ready() -> void:
	if visual == null:
		visual = get_parent() as CanvasItem


## Shows [param effect] only while the entity is shown.
func attach(effect: CanvasItem) -> void:
	_effects.append(effect)
	effect.visible = shown >= 0.5


## Where the entity is shown, in world coordinates.
func get_center() -> Vector2:
	var visual_2d: Node2D = visual as Node2D
	if visual_2d != null:
		return visual_2d.global_position
	var parent: Node2D = get_parent() as Node2D
	return parent.global_position if parent != null else Vector2.ZERO


## The points that decide whether the entity is seen: its center and four
## points at [member radius] around it.
func get_sample_points() -> PackedVector2Array:
	var center: Vector2 = get_center()
	return [
		center,
		center + Vector2(radius, 0.0),
		center + Vector2(-radius, 0.0),
		center + Vector2(0.0, radius),
		center + Vector2(0.0, -radius),
	]


func _apply() -> void:
	if visual != null:
		visual.modulate.a = shown
	for index: int in range(_effects.size() - 1, -1, -1):
		if is_instance_valid(_effects[index]):
			_effects[index].visible = shown >= 0.5
		else:
			_effects.remove_at(index)
