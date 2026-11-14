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
