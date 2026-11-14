class_name FlashlightCone
extends RefCounted
## The Sheepherder's flashlight cone at one moment (GDD §3.1, §5): where it
## starts, where it points, how wide and how long it is.

## Where the cone starts, in world coordinates.
var origin: Vector2
## The direction the cone points, a unit vector.
var direction: Vector2
## The full opening angle, in degrees.
var angle_deg: float
## How far the cone reaches, in pixels.
var length: float


func _init(
	cone_origin: Vector2, cone_direction: Vector2, cone_angle_deg: float, cone_length: float
) -> void:
	origin = cone_origin
	direction = cone_direction.normalized()
	angle_deg = cone_angle_deg
	length = cone_length


## Whether [param point] lies inside the cone: no farther than [member length]
## from the origin and within half the opening angle of the direction, edges
## included. Obstacles are not considered; see [WorldQueries].
func contains(point: Vector2) -> bool:
	var offset: Vector2 = point - origin
	if offset.length() > length:
		return false
	if offset.is_zero_approx():
		return true
	# angle_to gives the shortest signed angle, so directions around ±180° work.
	return absf(direction.angle_to(offset)) <= deg_to_rad(angle_deg) / 2.0
