class_name TouchActionButton
extends Control
## A round on-screen button that triggers an input action while touched.
##
## The touch handling is Godot's [TouchScreenButton], which presses the same
## input action as the keyboard does (GDD §9.2) and supports several fingers
## at once. This control gives it a place in the layout and a placeholder
## look.

const FILL: Color = Color(1.0, 1.0, 1.0, 0.16)
const FILL_PRESSED: Color = Color(1.0, 1.0, 1.0, 0.42)
const OUTLINE: Color = Color(1.0, 1.0, 1.0, 0.7)
const FONT_SIZE: int = 20
const COOLDOWN: Color = Color(0.0, 0.0, 0.0, 0.55)
const METER: Color = Color(0.92, 0.88, 0.78, 0.95)
const ACTIVE: Color = Color(0.85, 0.25, 0.2, 0.95)

## The input action this button triggers.
var action: StringName
## The word shown on the button.
var label: String

var _button: TouchScreenButton = TouchScreenButton.new()
var _shape: CircleShape2D = CircleShape2D.new()
var _cooldown: float = 0.0
var _meter: float = 0.0
var _active: bool = false


func _init(button_action: StringName, button_label: String, diameter: float) -> void:
	action = button_action
	label = button_label
	name = "%sButton" % String(button_action).to_pascal_case()
	custom_minimum_size = Vector2(diameter, diameter)
	size = custom_minimum_size
	# The finger goes to the TouchScreenButton, not to this control.
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_shape.radius = diameter / 2.0
	_button.name = "Touch"
	_button.shape = _shape
	_button.action = button_action
	_button.position = size / 2.0
	_button.pressed.connect(queue_redraw)
	_button.released.connect(queue_redraw)
	add_child(_button)


## Whether a finger is on the button.
func is_pressed() -> bool:
	return _button.is_pressed()


## What the HUD shows on the button: how much of a cooldown is left (1 to 0,
## a dark slice), a meter (0 to 1, a ring) and whether it is happening.
func show_state(cooldown: float, meter: float, active: bool) -> void:
	cooldown = clampf(cooldown, 0.0, 1.0)
	meter = clampf(meter, 0.0, 1.0)
	if is_equal_approx(cooldown, _cooldown) and is_equal_approx(meter, _meter):
		if active == _active:
			return
	_cooldown = cooldown
	_meter = meter
	_active = active
	queue_redraw()


func get_cooldown() -> float:
	return _cooldown


func get_meter() -> float:
	return _meter


func _draw() -> void:
	var center: Vector2 = size / 2.0
	var radius: float = size.x / 2.0
	draw_circle(center, radius, FILL_PRESSED if _button.is_pressed() else FILL)
	if _cooldown > 0.0:
		var points: PackedVector2Array = [center]
		var steps: int = maxi(ceili(32.0 * _cooldown), 2)
		for step: int in steps + 1:
			var angle: float = -PI / 2.0 + TAU * _cooldown * step / steps
			points.append(center + Vector2.from_angle(angle) * (radius - 3.0))
		draw_colored_polygon(points, COOLDOWN)
	draw_arc(center, radius - 1.5, 0.0, TAU, 48, ACTIVE if _active else OUTLINE, 3.0, true)
	if _meter > 0.0:
		draw_arc(center, radius - 7.0, -PI / 2.0, -PI / 2.0 + TAU * _meter, 48, METER, 5.0, true)
	var font: Font = get_theme_default_font()
	var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	var baseline: Vector2 = center + Vector2(-text_size.x / 2.0, text_size.y / 4.0)
	draw_string(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
