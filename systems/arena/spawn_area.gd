class_name SpawnArea
extends Node2D
## A rectangle of the arena where characters may start a round, centered on
## this node.

## Width and height of the rectangle.
@export var size: Vector2 = Vector2(200.0, 200.0)


## The rectangle in world coordinates.
func get_area() -> Rect2:
	return Rect2(global_position - size / 2.0, size)
