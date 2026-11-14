class_name ShotEffect
extends Node2D
## A shot, briefly: a muzzle flash and a tracer from the muzzle to where the
## bullet stopped. Frees itself. Placeholder until the art pass (#22).

const DURATION: float = 0.18
## How far in front of the shooter's center the muzzle is.
const MUZZLE_DISTANCE: float = 22.0
const TRACER_COLOR: Color = Color(1.0, 0.9, 0.6)
const FLASH_COLOR: Color = Color(1.0, 0.8, 0.3)

var _from: Vector2
var _to: Vector2


func _init(origin: Vector2, end_position: Vector2) -> void:
	var direction: Vector2 = (end_position - origin).normalized()
	_from = origin + direction * minf(MUZZLE_DISTANCE, origin.distance_to(end_position))
	_to = end_position


func _ready() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, ^"modulate:a", 0.0, DURATION)
	tween.tween_callback(queue_free)


func _draw() -> void:
	draw_line(_from, _to, TRACER_COLOR, 2.0)
	draw_circle(_from, 7.0, FLASH_COLOR)
