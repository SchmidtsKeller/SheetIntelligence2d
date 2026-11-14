class_name WorldHit
extends RefCounted
## Where a ray hit the solid world (see [WorldQueries]).

## The point the ray hit.
var position: Vector2
## The surface normal at [member position].
var normal: Vector2
## The body that was hit: an obstacle, or a border of the arena.
var collider: Object


func _init(
	hit_position: Vector2 = Vector2.ZERO,
	hit_normal: Vector2 = Vector2.ZERO,
	hit_collider: Object = null
) -> void:
	position = hit_position
	normal = hit_normal
	collider = hit_collider


## Whether the ray hit an obstacle (tree, barn, ...) rather than a border of the
## arena. A bullet that reaches a border has left the map.
func is_obstacle() -> bool:
	return collider is Node and (collider as Node).is_in_group(Groups.OBSTACLES)
