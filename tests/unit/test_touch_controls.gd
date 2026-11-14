extends TestCase
## The on-screen touch controls, operated by simulated fingers.

# Aliases for enum types, so they are named like types.
# gdlint: ignore=constant-name
const Role = GameEnums.Role
# gdlint: ignore=constant-name
const Scheme = InputService.Scheme

var _input: DeviceInputService
var _controls: TouchControls
## The fingers that are down, to lift them after the test.
var _fingers: Dictionary[int, Vector2] = {}


func before_each() -> void:
	_input = add_child_autofree(DeviceInputService.new())
	_input.set_process(false)
	_input.set_process_input(false)
	_input.set_scheme_override(Scheme.TOUCH)
	_controls = _input.get_touch_controls()
	# Let the layout settle, and let "just pressed" from the previous test fade.
	await wait_frames(2)


func after_each() -> void:
	for finger: int in _fingers.keys():
		_lift(finger)
	for action: StringName in InputActions.ALL:
		Input.action_release(action)
	Input.emulate_touch_from_mouse = false


# --- What is shown ---------------------------------------------------------------


func test_controls_are_hidden_without_a_role() -> void:
	assert_false(_controls.visible)


func test_controls_are_shown_for_a_player_in_the_touch_scheme() -> void:
	_input.set_role(Role.SHEEPHERDER)

	assert_true(_controls.visible)


func test_controls_are_hidden_in_the_keyboard_scheme() -> void:
	_input.set_role(Role.SHEEPHERDER)

	_input.set_scheme_override(Scheme.KEYBOARD_MOUSE)

	assert_false(_controls.visible)


func test_controls_are_hidden_while_gameplay_input_is_off() -> void:
	_input.set_role(Role.MONSTER)

	_input.set_gameplay_enabled(false)
	assert_false(_controls.visible)

	_input.set_gameplay_enabled(true)
	assert_true(_controls.visible)


func test_sheepherder_gets_both_sticks_and_their_two_buttons() -> void:
	_input.set_role(Role.SHEEPHERDER)

	assert_true(_controls.get_move_stick().visible)
	assert_true(_controls.get_aim_stick().visible)
	assert_eq(_visible_buttons(), [InputActions.SHOOT, InputActions.BELL])


func test_monster_gets_one_stick_and_its_five_buttons() -> void:
	_input.set_role(Role.MONSTER)

	assert_true(_controls.get_move_stick().visible)
	assert_false(_controls.get_aim_stick().visible, "the Monster has nothing to aim")
	assert_eq(
		_visible_buttons(),
		[
			InputActions.GRAZE,
			InputActions.BLEAT,
			InputActions.EAT,
			InputActions.SPRINT,
			InputActions.PERK
		]
	)


func test_switching_the_role_switches_the_buttons() -> void:
	_input.set_role(Role.SHEEPHERDER)

	_input.set_role(Role.MONSTER)

	assert_false(_controls.get_button(InputActions.SHOOT).visible)
	assert_true(_controls.get_button(InputActions.EAT).visible)


func test_sticks_trigger_the_same_actions_as_the_keyboard() -> void:
	var move: VirtualJoystick = _controls.get_move_stick()
	var aim: VirtualJoystick = _controls.get_aim_stick()

	assert_eq(move.action_left, InputActions.MOVE_LEFT)
	assert_eq(move.action_right, InputActions.MOVE_RIGHT)
	assert_eq(move.action_up, InputActions.MOVE_UP)
	assert_eq(move.action_down, InputActions.MOVE_DOWN)
	assert_eq(aim.action_left, InputActions.AIM_LEFT)
	assert_eq(aim.action_right, InputActions.AIM_RIGHT)
	assert_eq(aim.action_up, InputActions.AIM_UP)
	assert_eq(aim.action_down, InputActions.AIM_DOWN)


func test_every_ability_has_a_button_with_its_action() -> void:
	for role: GameEnums.Role in [Role.SHEEPHERDER, Role.MONSTER]:
		for action: StringName in InputActions.abilities_for(role):
			var button: TouchActionButton = _controls.get_button(action)
			if assert_not_null(button, "button for '%s'" % action):
				assert_eq(button.action, action)
				assert_ne(button.label, "")


func test_controls_stay_inside_the_screen() -> void:
	var screen: Rect2 = Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)

	for role: GameEnums.Role in [Role.SHEEPHERDER, Role.MONSTER]:
		_input.set_role(role)
		for control: Control in _visible_controls():
			assert_true(
				screen.encloses(control.get_global_rect()), "%s is on the screen" % control.name
			)


func test_controls_do_not_overlap() -> void:
	for role: GameEnums.Role in [Role.SHEEPHERDER, Role.MONSTER]:
		_input.set_role(role)
		var controls: Array[Control] = _visible_controls()
		for first: int in controls.size():
			for second: int in range(first + 1, controls.size()):
				assert_false(
					controls[first].get_global_rect().intersects(controls[second].get_global_rect()),
					"%s and %s" % [controls[first].name, controls[second].name]
				)


func test_left_hand_moves_and_right_hand_acts() -> void:
	var middle: float = get_viewport().get_visible_rect().size.x / 2.0

	for role: GameEnums.Role in [Role.SHEEPHERDER, Role.MONSTER]:
		_input.set_role(role)
		assert_lt(_controls.get_move_stick().get_global_rect().end.x, middle)
		for control: Control in _visible_controls():
			if control != _controls.get_move_stick():
				assert_gt(control.get_global_rect().position.x, middle, String(control.name))


# --- Fingers ---------------------------------------------------------------------


func test_finger_on_a_button_presses_its_action() -> void:
	_input.set_role(Role.MONSTER)
	watch_signals(_input)

	_touch(0, _center_of(_controls.get_button(InputActions.EAT)))
	_input.poll()

	assert_true(Input.is_action_pressed(InputActions.EAT), "the same action a key would press")
	assert_true(_input.is_action_held(InputActions.EAT))
	assert_signal_emitted_with(_input, &"action_pressed", [InputActions.EAT])

	_lift(0)
	_input.poll()

	assert_false(_input.is_action_held(InputActions.EAT))
	assert_signal_emitted_with(_input, &"action_released", [InputActions.EAT])


func test_hold_button_stays_held_until_the_finger_lifts() -> void:
	_input.set_role(Role.MONSTER)
	_touch(0, _center_of(_controls.get_button(InputActions.SPRINT)))

	for frame: int in 10:
		_input.poll()
	assert_true(_input.is_action_held(InputActions.SPRINT))

	_lift(0)
	_input.poll()
	assert_false(_input.is_action_held(InputActions.SPRINT))


func test_finger_that_slides_off_a_button_still_releases_it_when_lifted() -> void:
	_input.set_role(Role.MONSTER)
	var button: TouchActionButton = _controls.get_button(InputActions.GRAZE)
	_touch(0, _center_of(button))
	_input.poll()
	assert_true(_input.is_action_held(InputActions.GRAZE))

	_drag(0, _center_of(button) + Vector2(-400.0, -300.0))
	_lift(0)
	_input.poll()

	assert_false(Input.is_action_pressed(InputActions.GRAZE))
	assert_false(_input.is_action_held(InputActions.GRAZE), "no action stays stuck")


func test_finger_beside_the_buttons_presses_nothing() -> void:
	_input.set_role(Role.MONSTER)
	watch_signals(_input)

	_touch(0, get_viewport().get_visible_rect().size / 2.0)
	_input.poll()

	assert_signal_not_emitted(_input, &"action_pressed")


func test_move_stick_gives_analog_movement() -> void:
	_input.set_role(Role.MONSTER)
	var center: Vector2 = _center_of(_controls.get_move_stick())

	_touch(0, center)
	_drag(0, center + Vector2(200.0, 0.0))

	var full: Vector2 = _input.get_move_vector()
	assert_almost_eq(full, Vector2.RIGHT, 0.05, "pushed all the way")

	_drag(0, center + Vector2(0.0, -40.0))
	var partial: Vector2 = _input.get_move_vector()
	assert_lt(partial.y, -0.1, "pushed up a little")
	assert_gt(partial.y, -0.9, "not at full speed")
	assert_almost_eq(partial.x, 0.0, 0.05)

	_lift(0)
	assert_eq(_input.get_move_vector(), Vector2.ZERO)


func test_aim_stick_aims_and_keeps_the_aim_when_released() -> void:
	_input.set_role(Role.SHEEPHERDER)
	var center: Vector2 = _center_of(_controls.get_aim_stick())

	_touch(0, center)
	_drag(0, center + Vector2(0.0, 200.0))
	assert_almost_eq(_input.get_aim_direction(Vector2.ZERO), Vector2.DOWN, 0.05)

	_lift(0)
	assert_almost_eq(_input.get_aim_direction(Vector2.ZERO), Vector2.DOWN, 0.05, "kept")


func test_move_aim_and_fire_at_the_same_time() -> void:
	# Three fingers: left thumb on the move stick, right thumb on the aim
	# stick, and another finger on Fire.
	_input.set_role(Role.SHEEPHERDER)
	var move_center: Vector2 = _center_of(_controls.get_move_stick())
	var aim_center: Vector2 = _center_of(_controls.get_aim_stick())

	_touch(0, move_center)
	_drag(0, move_center + Vector2(-200.0, 0.0))
	_touch(1, aim_center)
	_drag(1, aim_center + Vector2(0.0, -200.0))
	_touch(2, _center_of(_controls.get_button(InputActions.SHOOT)))
	_input.poll()

	assert_almost_eq(_input.get_move_vector(), Vector2.LEFT, 0.05)
	assert_almost_eq(_input.get_aim_direction(Vector2.ZERO), Vector2.UP, 0.05)
	assert_true(_input.is_action_held(InputActions.SHOOT))

	_lift(2)
	_input.poll()
	assert_false(_input.is_action_held(InputActions.SHOOT))
	assert_almost_eq(_input.get_move_vector(), Vector2.LEFT, 0.05, "the other fingers stay down")


func test_hiding_the_controls_lets_go_of_what_was_touched() -> void:
	_input.set_role(Role.MONSTER)
	_touch(0, _center_of(_controls.get_button(InputActions.SPRINT)))
	_input.poll()
	assert_true(_input.is_action_held(InputActions.SPRINT))

	_input.set_scheme_override(Scheme.KEYBOARD_MOUSE)
	_input.poll()

	assert_false(Input.is_action_pressed(InputActions.SPRINT))
	assert_false(_input.is_action_held(InputActions.SPRINT))


func _visible_buttons() -> Array[StringName]:
	var actions: Array[StringName] = []
	for action: StringName in InputActions.SHEEPHERDER_ACTIONS + InputActions.MONSTER_ACTIONS:
		if _controls.get_button(action).visible:
			actions.append(action)
	return actions


func _visible_controls() -> Array[Control]:
	var controls: Array[Control] = []
	for stick: VirtualJoystick in [_controls.get_move_stick(), _controls.get_aim_stick()]:
		if stick.visible:
			controls.append(stick)
	for action: StringName in _visible_buttons():
		controls.append(_controls.get_button(action))
	return controls


static func _center_of(control: Control) -> Vector2:
	return control.get_global_rect().get_center()


func _touch(finger: int, position: Vector2) -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = finger
	event.position = position
	event.pressed = true
	_fingers[finger] = position
	# Positions are canvas coordinates, not window pixels.
	get_viewport().push_input(event, true)


func _drag(finger: int, position: Vector2) -> void:
	var event: InputEventScreenDrag = InputEventScreenDrag.new()
	event.index = finger
	event.position = position
	event.relative = position - _fingers[finger]
	_fingers[finger] = position
	# Positions are canvas coordinates, not window pixels.
	get_viewport().push_input(event, true)


func _lift(finger: int) -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = finger
	event.position = _fingers[finger]
	event.pressed = false
	_fingers.erase(finger)
	# Positions are canvas coordinates, not window pixels.
	get_viewport().push_input(event, true)
