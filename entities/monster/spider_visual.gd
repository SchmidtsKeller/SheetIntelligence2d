class_name SpiderVisual
extends Node2D
## Placeholder look of the Monster's spider form (GDD §3.2): a giant spider
## drawn in code. Its legs move while it walks and its jaws snap while it
## eats. Final art replaces this node.
##
## It is drawn facing +x, like the sheep it replaces (see
## [method SheepBody.set_visual_override]).

const BODY_COLOR: Color = Color(0.09, 0.07, 0.06)
const ABDOMEN_COLOR: Color = Color(0.14, 0.1, 0.08)
const LEG_COLOR: Color = Color(0.06, 0.05, 0.04)
const EYE_COLOR: Color = Color(0.72, 0.68, 0.45)
const JAW_COLOR: Color = Color(0.3, 0.08, 0.06)

const LEGS_PER_SIDE: int = 4
const LEG_REACH: float = 78.0
const LEG_WIDTH: float = 5.0
## Leg cycles per second while walking, and jaw snaps per second while eating.
const STEP_RATE: float = 3.0
const SNAP_RATE: float = 6.0

## The body whose state decides what the spider is shown doing.
var body: SheepBody

var _step: float = 0.0
var _snap: float = 0.0


func _process(delta: float) -> void:
	if not is_instance_valid(body):
		return
	match body.get_state():
		SheepBody.State.WALK:
			_step = fposmod(_step + delta * STEP_RATE, 1.0)
		SheepBody.State.DEVOUR:
			_snap = fposmod(_snap + delta * SNAP_RATE, 1.0)
		_:
			_snap = 0.0
	queue_redraw()


func _draw() -> void:
	for side: float in [-1.0, 1.0]:
		for leg: int in LEGS_PER_SIDE:
			_draw_leg(side, leg)
	draw_circle(Vector2(-26.0, 0.0), 30.0, ABDOMEN_COLOR)
	draw_circle(Vector2(12.0, 0.0), 19.0, BODY_COLOR)
	var bite: float = sin(_snap * TAU) * 0.35
	for side: float in [-1.0, 1.0]:
		var jaw_base: Vector2 = Vector2(27.0, 7.0 * side)
		var jaw_tip: Vector2 = jaw_base + Vector2.from_angle((-0.5 + bite) * side) * 16.0
		draw_line(jaw_base, jaw_tip, JAW_COLOR, 4.0)
		draw_circle(Vector2(24.0, 5.0 * side), 2.5, EYE_COLOR)
		draw_circle(Vector2(19.0, 11.0 * side), 1.8, EYE_COLOR)


## One leg in two segments: up to the knee, then down to the ground. Legs next
## to each other step in turns.
func _draw_leg(side: float, leg: int) -> void:
	var spread: float = lerpf(-0.9, 0.9, float(leg) / (LEGS_PER_SIDE - 1))
	var phase: float = _step * TAU + (PI if (leg % 2 == 0) == (side > 0.0) else 0.0)
	var swing: float = sin(phase) * 0.18
	var hip: Vector2 = Vector2(10.0 - 6.0 * leg, 12.0 * side)
	var direction: Vector2 = Vector2.from_angle((PI / 2.0 - spread + swing) * side)
	var knee: Vector2 = hip + direction * LEG_REACH * 0.5 + Vector2(6.0, 0.0)
	var foot: Vector2 = hip + direction * LEG_REACH
	draw_line(hip, knee, LEG_COLOR, LEG_WIDTH)
	draw_line(knee, foot, LEG_COLOR, LEG_WIDTH * 0.7)
