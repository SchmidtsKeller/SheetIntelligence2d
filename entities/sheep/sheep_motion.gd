class_name SheepMotion
extends RefCounted
## How a sheep moves: it turns toward where it wants to go at a limited rate
## and speeds up or slows down at a limited acceleration.
##
## Every sheep-like entity steps the same model with the same numbers, whether
## the flock AI or the Monster player steers it, so the motion itself is never
## a tell (GDD §3.2, "No Built-in Tell").

## Direction the sheep faces and walks, in radians (0 = +x).
var heading: float = 0.0
## Current walking speed, in pixels per second.
var speed: float = 0.0


## Advances the motion by [param delta] seconds and returns the new velocity.
## [param wish] is where the steering wants to go, with a length from 0 (stand)
## to 1 (full [param max_speed]); longer vectors are shortened. A sheep that
## stops keeps its heading.
func step(
	wish: Vector2, max_speed: float, acceleration: float, turn_rate: float, delta: float
) -> Vector2:
	var limited: Vector2 = wish.limit_length(1.0)
	if not limited.is_zero_approx():
		heading = rotate_toward(heading, limited.angle(), turn_rate * delta)
	speed = move_toward(speed, limited.length() * max_speed, acceleration * delta)
	return get_velocity()


## The current velocity.
func get_velocity() -> Vector2:
	return Vector2.from_angle(heading) * speed
