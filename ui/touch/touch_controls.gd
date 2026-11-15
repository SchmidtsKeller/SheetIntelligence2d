class_name TouchControls
extends CanvasLayer
## The on-screen controls for touch devices: a movement joystick on the left,
## and on the right what the current role needs.
##
## [codeblock lang=text]
## Sheepherder: move stick | aim stick, Fire, Bell
## Monster:     move stick | Eat, Sprint (hold), Graze (hold), Bleat, Perk
## [/codeblock]
##
## Sticks are Godot's [VirtualJoystick], buttons its [TouchScreenButton]: both
## trigger the same input actions as the keyboard (GDD §9.2), so nothing
## outside the input layer knows that a touchscreen is involved. Several
## fingers work at the same time (move, aim and a button).
##
## The controls are only shown in the touch scheme, while gameplay input is
## on and the player has a role. The looks are placeholders, marked as such
## until the art pass (#70) paints them.

const STICK_SIZE: float = 220.0
const BUTTON_SIZE: float = 108.0
const GAP: float = 18.0
## Distance to the screen edge, on top of the device's safe area.
const EDGE_MARGIN: float = 36.0

const LABELS: Dictionary[StringName, String] = {
	InputActions.SHOOT: "Fire",
	InputActions.BELL: "Bell",
	InputActions.GRAZE: "Graze",
	InputActions.BLEAT: "Bleat",
	InputActions.EAT: "Eat",
	InputActions.SPRINT: "Sprint",
	InputActions.PERK: "Perk",
}

var _input: InputService
var _root: Control = Control.new()
var _move_stick: VirtualJoystick
var _aim_stick: VirtualJoystick
var _buttons: Dictionary[StringName, TouchActionButton] = {}


func _init() -> void:
	name = "TouchControls"
	layer = 50
	_root.name = "Root"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The painted sticks come from the theme (#83).
	GameTheme.apply(_root)
	add_child(_root)

	_move_stick = _create_stick(
		"MoveStick",
		InputActions.MOVE_LEFT,
		InputActions.MOVE_RIGHT,
		InputActions.MOVE_UP,
		InputActions.MOVE_DOWN
	)
	_aim_stick = _create_stick(
		"AimStick",
		InputActions.AIM_LEFT,
		InputActions.AIM_RIGHT,
		InputActions.AIM_UP,
		InputActions.AIM_DOWN
	)
	for action: StringName in LABELS:
		var button: TouchActionButton = TouchActionButton.new(action, LABELS[action], BUTTON_SIZE)
		_buttons[action] = button
		_root.add_child(button)


func _ready() -> void:
	_root.resized.connect(_layout)
	_layout()


## Connects the controls to the input service whose state they follow.
func setup(input: InputService) -> void:
	_input = input
	input.role_changed.connect(_refresh.unbind(1))
	input.scheme_changed.connect(_refresh.unbind(1))
	input.gameplay_enabled_changed.connect(_refresh.unbind(1))
	_refresh()


## The button for [param action], or [code]null[/code].
func get_button(action: StringName) -> TouchActionButton:
	return _buttons.get(action)


func get_move_stick() -> VirtualJoystick:
	return _move_stick


func get_aim_stick() -> VirtualJoystick:
	return _aim_stick


func _refresh() -> void:
	var role: GameEnums.Role = _input.get_role()
	var was_visible: bool = visible
	visible = (
		_input.get_scheme() == InputService.Scheme.TOUCH
		and _input.is_gameplay_enabled()
		and role != GameEnums.Role.NONE
	)
	_aim_stick.visible = InputActions.role_aims(role)
	var abilities: Array[StringName] = InputActions.abilities_for(role)
	for action: StringName in _buttons:
		_buttons[action].visible = abilities.has(action)
	if was_visible and not visible:
		_release_everything()
	_layout()


## A control that disappears under a finger must not leave its action held.
func _release_everything() -> void:
	for action: StringName in InputActions.ALL:
		if Input.is_action_pressed(action):
			Input.action_release(action)


func _layout() -> void:
	if not is_inside_tree():
		return
	var area: Rect2 = _get_usable_area()
	var left: float = area.position.x + EDGE_MARGIN
	var right: float = area.end.x - EDGE_MARGIN
	var bottom: float = area.end.y - EDGE_MARGIN

	_move_stick.position = Vector2(left, bottom - STICK_SIZE)
	_aim_stick.position = Vector2(right - STICK_SIZE, bottom - STICK_SIZE)

	# Sheepherder: the buttons sit above the aim stick, a short way for the thumb.
	var above_stick: float = bottom - STICK_SIZE - GAP - BUTTON_SIZE
	_place(InputActions.SHOOT, right - BUTTON_SIZE, above_stick)
	_place(InputActions.BELL, right - 2.0 * BUTTON_SIZE - GAP, above_stick)

	# Monster: a block of buttons in the corner. Eat is where the thumb rests;
	# Sprint is next to it, because it is held while the other thumb steers.
	var column_1: float = right - BUTTON_SIZE
	var column_2: float = right - 2.0 * BUTTON_SIZE - GAP
	var row_1: float = bottom - BUTTON_SIZE
	var row_2: float = bottom - 2.0 * BUTTON_SIZE - GAP
	var row_3: float = bottom - 3.0 * BUTTON_SIZE - 2.0 * GAP
	_place(InputActions.EAT, column_1, row_1)
	_place(InputActions.SPRINT, column_2, row_1)
	_place(InputActions.GRAZE, column_1, row_2)
	_place(InputActions.BLEAT, column_2, row_2)
	_place(InputActions.PERK, column_1, row_3)


func _place(action: StringName, x: float, y: float) -> void:
	_buttons[action].position = Vector2(x, y)


## The part of the canvas that is not covered by a notch or rounded corners.
func _get_usable_area() -> Rect2:
	var canvas: Rect2 = Rect2(Vector2.ZERO, _root.size)
	# Browsers keep a page inside the safe area by themselves, and on a
	# desktop the "safe area" is that of the whole screen, not of the window.
	if not OS.has_feature("mobile") or OS.has_feature("web"):
		return canvas
	var window_size: Vector2 = DisplayServer.window_get_size()
	var safe: Rect2 = DisplayServer.get_display_safe_area()
	if not safe.has_area() or window_size.x <= 0.0 or window_size.y <= 0.0:
		return canvas
	var units_per_pixel: Vector2 = canvas.size / window_size
	return Rect2(safe.position * units_per_pixel, safe.size * units_per_pixel).intersection(canvas)


func _create_stick(
	stick_name: String, left: StringName, right: StringName, up: StringName, down: StringName
) -> VirtualJoystick:
	var stick: VirtualJoystick = VirtualJoystick.new()
	stick.name = stick_name
	stick.joystick_mode = VirtualJoystick.JOYSTICK_FIXED
	stick.visibility_mode = VirtualJoystick.VISIBILITY_ALWAYS
	stick.custom_minimum_size = Vector2(STICK_SIZE, STICK_SIZE)
	stick.size = stick.custom_minimum_size
	stick.joystick_size = STICK_SIZE * 0.8
	stick.tip_size = STICK_SIZE * 0.36
	stick.deadzone_ratio = 0.15
	stick.action_left = left
	stick.action_right = right
	stick.action_up = up
	stick.action_down = down
	_root.add_child(stick)
	return stick
