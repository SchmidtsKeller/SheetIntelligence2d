class_name VisionDebugOverlay
extends Node2D
## Shows what the vision system decides: a ring around every target, green
## when the local player sees it and red when not, and its sample points.

const SEEN_COLOR: Color = Color(0.3, 1.0, 0.4)
const HIDDEN_COLOR: Color = Color(1.0, 0.3, 0.3)

## The vision system whose decisions are shown.
var vision: VisionSystem


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if vision == null:
		return
	var to_local: Transform2D = get_global_transform().affine_inverse()
	for target: VisionTarget in vision.get_targets():
		var color: Color = SEEN_COLOR if vision.can_see(target) else HIDDEN_COLOR
		draw_arc(to_local * target.get_center(), target.radius + 6.0, 0.0, TAU, 24, color, 2.0)
		for point: Vector2 in target.get_sample_points():
			draw_circle(to_local * point, 2.0, color)
