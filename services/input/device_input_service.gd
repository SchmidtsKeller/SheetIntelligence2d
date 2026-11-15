class_name DeviceInputService
extends InputService
## The real [InputService]: keyboard and mouse, or the on-screen touch
## controls (GDD §9.2).
##
## Both kinds of device trigger the same input actions (see [InputActions]):
## keys and mouse buttons through the InputMap, the virtual joysticks and
## touch buttons of [TouchControls] directly. This service turns the actions
## into movement and aim vectors and into pressed / released signals, so that
## character controllers never see a device.
##
## It also decides which controls are shown. It starts with touch controls on
## a touchscreen and switches whenever the player uses the other kind of
## device. For debugging, [code]--touch-controls[/code] and
## [code]--desktop-controls[/code] on the command line force one of them.

const FLAG_TOUCH: String = "--touch-controls"
const FLAG_DESKTOP: String = "--desktop-controls"
const NO_OVERRIDE: int = -1

## The aim stick has to be pushed at least this far to change the aim.
const AIM_STICK_DEADZONE: float = 0.3
## A pointer closer than this to the character, in pixels, does not change
## the aim: the direction would flip with every tremble of the hand.
const POINTER_DEADZONE: float = 6.0

## Where the pointer is in world coordinates: [code]() -> Vector2[/code].
## Tests replace it.
var pointer_world_position: Callable = _get_pointer_world_position

var _gate: InputGate = InputGate.new()
var _detected_scheme: Scheme = Scheme.KEYBOARD_MOUSE
var _scheme_override: int = NO_OVERRIDE
var _last_aim: Vector2 = Vector2.RIGHT
## Per ability, the frame in which its press was last passed on. One press is
## passed on once, however often the service looks in that frame.
var _press_seen_in_frame: Dictionary[StringName, int] = {}
## Whether the device really has a touchscreen, asked before this service
## starts to emulate one for debugging.
var _has_touchscreen: bool = false
var _touch_controls: TouchControls


func _init() -> void:
	# Report input before the nodes that consume it run.
	process_priority = -100
	_gate.action_pressed.connect(action_pressed.emit)
	_gate.action_released.connect(action_released.emit)


func _ready() -> void:
	_has_touchscreen = (
		DisplayServer.is_touchscreen_available() and not Input.emulate_touch_from_mouse
	)
	if _has_touchscreen:
		_detected_scheme = Scheme.TOUCH
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.has(FLAG_TOUCH):
		_scheme_override = Scheme.TOUCH
	elif arguments.has(FLAG_DESKTOP):
		_scheme_override = Scheme.KEYBOARD_MOUSE
	_touch_controls = TouchControls.new()
	add_child(_touch_controls)
	_touch_controls.setup(self)
	_apply_scheme()


func _process(_delta: float) -> void:
	poll()


func _input(event: InputEvent) -> void:
	observe_event(event)


func _notification(what: int) -> void:
	# A key that is down when the window or tab loses focus never reports its
	# release. Let go of everything, so nothing stays held for ever.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_let_go_of_everything()


## Reads the ability actions and reports what changed. Called every frame.
func poll() -> void:
	var frame: int = Engine.get_process_frames()
	for action: StringName in InputActions.abilities_for(_gate.get_role()):
		var down: bool = Input.is_action_pressed(action)
		# Already up again, but pressed in this frame, and that press has not
		# been passed on yet: the action went down and up between two looks.
		# Such a tap must not get lost.
		var tapped: bool = (
			not down
			and Input.is_action_just_pressed(action)
			and _press_seen_in_frame.get(action, -1) != frame
		)
		if down or tapped:
			_press_seen_in_frame[action] = frame
			_gate.press(action)
		if not down:
			_gate.release(action)


## Notices which kind of device the player is using.
func observe_event(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_set_detected_scheme(Scheme.TOUCH)
	elif event is InputEventKey:
		_set_detected_scheme(Scheme.KEYBOARD_MOUSE)
	elif event is InputEventMouse and event.device != InputEvent.DEVICE_ID_EMULATION:
		# Touches also arrive as emulated mouse events; those do not count.
		_set_detected_scheme(Scheme.KEYBOARD_MOUSE)


func get_move_vector() -> Vector2:
	if not _gate.allows_movement():
		return Vector2.ZERO
	return Input.get_vector(
		InputActions.MOVE_LEFT,
		InputActions.MOVE_RIGHT,
		InputActions.MOVE_UP,
		InputActions.MOVE_DOWN
	)


func get_aim_direction(aim_origin: Vector2) -> Vector2:
	if not _gate.allows_aiming():
		return _last_aim
	var stick: Vector2 = Input.get_vector(
		InputActions.AIM_LEFT,
		InputActions.AIM_RIGHT,
		InputActions.AIM_UP,
		InputActions.AIM_DOWN,
		AIM_STICK_DEADZONE
	)
	if not stick.is_zero_approx():
		_last_aim = stick.normalized()
	elif get_scheme() == Scheme.KEYBOARD_MOUSE:
		var to_pointer: Vector2 = pointer_world_position.call() - aim_origin
		if to_pointer.length() > POINTER_DEADZONE:
			_last_aim = to_pointer.normalized()
	return _last_aim


func is_action_held(action: StringName) -> bool:
	return _gate.is_held(action)


func set_role(role: GameEnums.Role) -> void:
	if _gate.set_role(role):
		role_changed.emit(role)


func get_role() -> GameEnums.Role:
	return _gate.get_role()


func set_gameplay_enabled(enabled: bool) -> void:
	if _gate.set_gameplay_enabled(enabled):
		gameplay_enabled_changed.emit(enabled)


func is_gameplay_enabled() -> bool:
	return _gate.is_gameplay_enabled()


func add_lock(action: StringName, source: StringName) -> void:
	_gate.add_lock(action, source)


func remove_lock(action: StringName, source: StringName) -> void:
	_gate.remove_lock(action, source)


func clear_locks(source: StringName) -> void:
	_gate.clear_locks(source)


func is_locked(action: StringName) -> bool:
	return _gate.is_locked(action)


func get_scheme() -> Scheme:
	if _scheme_override != NO_OVERRIDE:
		return _scheme_override as Scheme
	return _detected_scheme


func set_scheme_override(scheme: Scheme) -> void:
	var before: Scheme = get_scheme()
	_scheme_override = scheme
	_apply_scheme()
	if get_scheme() != before:
		scheme_changed.emit(get_scheme())


func clear_scheme_override() -> void:
	var before: Scheme = get_scheme()
	_scheme_override = NO_OVERRIDE
	_apply_scheme()
	if get_scheme() != before:
		scheme_changed.emit(get_scheme())


## The on-screen controls this service shows in the touch scheme.
func get_action_hint(action: StringName) -> String:
	if not InputMap.has_action(action):
		return ""
	for event: InputEvent in InputMap.action_get_events(action):
		var key: InputEventKey = event as InputEventKey
		if key != null:
			var code: Key = key.physical_keycode
			if code == KEY_NONE:
				code = key.keycode
			return OS.get_keycode_string(code)
		var mouse: InputEventMouseButton = event as InputEventMouseButton
		if mouse != null:
			match mouse.button_index:
				MOUSE_BUTTON_LEFT:
					return "LMB"
				MOUSE_BUTTON_RIGHT:
					return "RMB"
	return ""


func show_action_state(action: StringName, cooldown: float, meter: float, active: bool) -> void:
	var button: TouchActionButton = _touch_controls.get_button(action)
	if button != null:
		button.show_state(cooldown, meter, active)


func get_touch_controls() -> TouchControls:
	return _touch_controls


func _set_detected_scheme(scheme: Scheme) -> void:
	if scheme == _detected_scheme:
		return
	var before: Scheme = get_scheme()
	_detected_scheme = scheme
	if get_scheme() != before:
		scheme_changed.emit(get_scheme())


func _apply_scheme() -> void:
	# Forcing touch controls on a desktop only makes sense if the mouse can
	# operate them.
	Input.emulate_touch_from_mouse = _scheme_override == Scheme.TOUCH and not _has_touchscreen


func _let_go_of_everything() -> void:
	# Clear the engine's own state as well: it would otherwise keep reporting
	# the key as down until a release that never comes.
	for action: StringName in InputActions.ALL:
		if Input.is_action_pressed(action):
			Input.action_release(action)
	_gate.release_all()


func _get_pointer_world_position() -> Vector2:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return Vector2.ZERO
	# The canvas transform holds the camera: this turns a screen position
	# into a world position.
	return viewport.get_canvas_transform().affine_inverse() * viewport.get_mouse_position()
