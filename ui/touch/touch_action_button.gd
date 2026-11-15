class_name TouchActionButton
extends Control
## A round on-screen button that triggers an input action while touched.
##
## The touch handling is Godot's [TouchScreenButton], which presses the same
## input action as the keyboard does (GDD §9.2) and supports several fingers
## at once. This control gives it a place in the layout and its painted look
## (#83): an iron button that is pressed in while touched and glows red while
## its action is happening, with the cooldown and the meter drawn on top.

const FONT_SIZE: int = 20
const OUTLINE_SIZE: int = 5
const COOLDOWN: Color = UiPalette.TOUCH_COOLDOWN
const METER: Color = UiPalette.HUD_FILL

## The input action this button triggers.
var action: StringName
## The word shown on the button.
var label: String

## The action's painted icon, its base painted in (#96); without one the
## button shows the painted base and its word.
var _icon: Texture2D
var _base_normal: Texture2D = PaintedUi.texture("touch_button_base_normal")
var _base_pressed: Texture2D = PaintedUi.texture("touch_button_base_pressed")
var _base_active: Texture2D = PaintedUi.texture("touch_button_base_active")
var _button: TouchScreenButton = TouchScreenButton.new()
var _shape: CircleShape2D = CircleShape2D.new()
var _cooldown: float = 0.0
var _meter: float = 0.0
var _active: bool = false


func _init(button_action: StringName, button_label: String, diameter: float) -> void:
	action = button_action
	label = button_label
	_icon = PaintedUi.action_icon(button_action)
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
	if _icon != null:
		# Pressed in: a little darker; happening: ringed in crimson below.
		var tint: Color = Color(0.75, 0.72, 0.68) if _button.is_pressed() else Color.WHITE
		draw_texture_rect(_icon, Rect2(Vector2.ZERO, size), false, tint)
	else:
		var base: Texture2D = _base_normal
		if _active:
			base = _base_active
		elif _button.is_pressed():
			base = _base_pressed
		draw_texture_rect(base, Rect2(Vector2.ZERO, size), false)
	if _cooldown > 0.0:
		var points: PackedVector2Array = [center]
		var steps: int = maxi(ceili(32.0 * _cooldown), 2)
		for step: int in steps + 1:
			var angle: float = -PI / 2.0 + TAU * _cooldown * step / steps
			points.append(center + Vector2.from_angle(angle) * (radius - 3.0))
		draw_colored_polygon(points, COOLDOWN)
	if _meter > 0.0:
		draw_arc(center, radius - 7.0, -PI / 2.0, -PI / 2.0 + TAU * _meter, 48, METER, 5.0, true)
	if _icon != null:
		if _active:
			draw_arc(center, radius - 2.0, 0.0, TAU, 48, UiPalette.HUD_ACTIVE, 4.0, true)
		return
	var font: Font = get_theme_default_font()
	var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	var baseline: Vector2 = center + Vector2(-text_size.x / 2.0, text_size.y / 4.0)
	draw_string_outline(
		font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, OUTLINE_SIZE, Color.BLACK
	)
	draw_string(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, UiPalette.TEXT)
