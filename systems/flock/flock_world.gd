class_name FlockWorld
extends RefCounted
## What a sheep of the flock knows about its surroundings when it decides
## what to do next. Filled in by the swarm service for each sheep.

## Where sheep may be.
var play_area: Rect2 = Rect2()
## The obstacles, as convex polygons in world coordinates.
var footprints: Array[PackedVector2Array] = []
## Positions of the other sheep-like entities: the rest of the flock and the
## registered neighbours (the Monster), with no difference between them.
var neighbours: PackedVector2Array = []
## The middle of all sheep-like entities.
var center: Vector2 = Vector2.ZERO
## The direction the others are walking in, on average; zero if they stand.
var heading: Vector2 = Vector2.ZERO
## Whether a sheep fits at a point: [code](point: Vector2) -> bool[/code].
var is_free: Callable = func(_point: Vector2) -> bool: return true
