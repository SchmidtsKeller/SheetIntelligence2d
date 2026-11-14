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

## The input action this button triggers.
var action: StringName
## The word shown on the button.
var label: String

var _button: TouchScreenButton = TouchScreenButton.new()
var _shape: CircleShape2D = CircleShape2D.new()


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


func _draw() -> void:
	var center: Vector2 = size / 2.0
	var radius: float = size.x / 2.0
	draw_circle(center, radius, FILL_PRESSED if _button.is_pressed() else FILL)
	draw_arc(center, radius - 1.5, 0.0, TAU, 48, OUTLINE, 3.0, true)
	var font: Font = get_theme_default_font()
	var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	var baseline: Vector2 = center + Vector2(-text_size.x / 2.0, text_size.y / 4.0)
	draw_string(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
