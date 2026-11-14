class_name BellRingEffect
extends Node2D
## The bell, briefly: a ring that spreads out to the bell's radius and fades.
## Frees itself. Placeholder until the art pass (#22).

const DURATION: float = 0.8
const COLOR: Color = Color(1.0, 0.95, 0.7)

var _radius: float
var _progress: float = 0.0:
	set(value):
		_progress = value
		queue_redraw()


func _init(origin: Vector2, radius: float) -> void:
	position = origin
	_radius = radius


func _ready() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, ^"_progress", 1.0, DURATION)
	tween.tween_callback(queue_free)


func _draw() -> void:
	var color: Color = COLOR
	color.a = 1.0 - _progress
	draw_arc(Vector2.ZERO, _radius * _progress, 0.0, TAU, 64, color, 3.0)
