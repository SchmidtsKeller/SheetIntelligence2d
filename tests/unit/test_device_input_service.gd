extends TestCase
## The real input service, driven by simulated keys, pointer and actions.

# Aliases for enum types, so they are named like types.
# gdlint: ignore=constant-name
const Role = GameEnums.Role
# gdlint: ignore=constant-name
const Scheme = InputService.Scheme

var _input: DeviceInputService
var _pointer: Vector2 = Vector2.ZERO
var _pressed_keys: Array[Key] = []


func before_each() -> void:
	# The engine remembers for a frame that an action was just pressed. Let
	# what the previous test did fade, or it would look like a tap here.
	await wait_frames(2)
	_pointer = Vector2.ZERO
	_input = add_child_autofree(DeviceInputService.new())
	_input.pointer_world_position = func() -> Vector2: return _pointer
	# The test decides when input is read.
	_input.set_process(false)
	_input.set_process_input(false)
	_input.set_scheme_override(Scheme.KEYBOARD_MOUSE)


func after_each() -> void:
	for key: Key in _pressed_keys.duplicate():
		_release_key(key)
	for action: StringName in InputActions.ALL:
		Input.action_release(action)
	Input.flush_buffered_events()
	Input.emulate_touch_from_mouse = false


# --- HUD -------------------------------------------------------------------------


func test_the_hud_gets_the_key_of_an_action() -> void:
	assert_eq(_input.get_action_hint(InputActions.EAT), "E")
	assert_eq(_input.get_action_hint(InputActions.BLEAT), "F")
	assert_eq(_input.get_action_hint(InputActions.SHOOT), "LMB")
	assert_eq(_input.get_action_hint(&"no_such_action"), "")


func test_the_hud_shows_cooldowns_and_meters_on_the_touch_buttons() -> void:
	_input.show_action_state(InputActions.EAT, 0.4, 0.0, true)
	_input.show_action_state(InputActions.SPRINT, 0.0, 0.75, false)

	var eat: TouchActionButton = _input.get_touch_controls().get_button(InputActions.EAT)
	var sprint: TouchActionButton = _input.get_touch_controls().get_button(InputActions.SPRINT)
	assert_almost_eq(eat.get_cooldown(), 0.4, 0.0001)
	assert_almost_eq(sprint.get_meter(), 0.75, 0.0001)
	assert_eq(sprint.get_cooldown(), 0.0)


# --- Movement --------------------------------------------------------------------


func test_no_input_means_no_movement() -> void:
	assert_eq(_input.get_move_vector(), Vector2.ZERO)


func test_keyboard_moves_in_the_four_directions() -> void:
	_press_key(KEY_D)
	assert_eq(_input.get_move_vector(), Vector2.RIGHT)
	_release_key(KEY_D)

	_press_key(KEY_W)
	assert_eq(_input.get_move_vector(), Vector2.UP)
	_release_key(KEY_W)

	_press_key(KEY_LEFT)
	assert_eq(_input.get_move_vector(), Vector2.LEFT, "arrow keys work as well")
	_release_key(KEY_LEFT)

	_press_key(KEY_S)
	assert_eq(_input.get_move_vector(), Vector2.DOWN)


func test_keyboard_diagonal_is_not_faster_than_straight() -> void:
	_press_key(KEY_W)
	_press_key(KEY_D)

	var move: Vector2 = _input.get_move_vector()

	assert_almost_eq(move.length(), 1.0, 0.001, "normalized")
	assert_almost_eq(move, Vector2(1.0, -1.0).normalized(), 0.001)


func test_opposite_keys_cancel_out() -> void:
	_press_key(KEY_A)
	_press_key(KEY_D)

	assert_eq(_input.get_move_vector(), Vector2.ZERO)


func test_analog_input_keeps_its_strength() -> void:
	# A stick that is pushed halfway: the character walks, it does not run.
	Input.action_press(InputActions.MOVE_RIGHT, 0.6)

	var move: Vector2 = _input.get_move_vector()

	assert_gt(move.x, 0.3)
	assert_lt(move.x, 0.7)
	assert_eq(move.y, 0.0)


func test_analog_input_never_exceeds_full_speed() -> void:
	Input.action_press(InputActions.MOVE_RIGHT, 1.0)
	Input.action_press(InputActions.MOVE_DOWN, 1.0)

	assert_almost_eq(_input.get_move_vector().length(), 1.0, 0.001)


func test_stick_inside_its_dead_zone_does_not_move() -> void:
	Input.action_press(InputActions.MOVE_RIGHT, 0.1)

	assert_eq(_input.get_move_vector(), Vector2.ZERO)


func test_locked_movement_reports_nothing() -> void:
	_press_key(KEY_D)

	_input.add_lock(InputActions.MOVE, &"eating")
	assert_eq(_input.get_move_vector(), Vector2.ZERO)

	_input.remove_lock(InputActions.MOVE, &"eating")
	assert_eq(_input.get_move_vector(), Vector2.RIGHT, "the key is still down")


func test_no_movement_while_gameplay_input_is_off() -> void:
	_press_key(KEY_D)

	_input.set_gameplay_enabled(false)

	assert_eq(_input.get_move_vector(), Vector2.ZERO)


# --- Aim -------------------------------------------------------------------------


func test_mouse_aims_from_the_character_to_the_pointer() -> void:
	_pointer = Vector2(500.0, 300.0)

	assert_almost_eq(_input.get_aim_direction(Vector2(300.0, 300.0)), Vector2.RIGHT)
	assert_almost_eq(_input.get_aim_direction(Vector2(500.0, 600.0)), Vector2.UP)
	assert_almost_eq(
		_input.get_aim_direction(Vector2(400.0, 400.0)), Vector2(1.0, -1.0).normalized()
	)


func test_aim_is_always_a_unit_vector() -> void:
	_pointer = Vector2(1234.0, -987.0)

	assert_almost_eq(_input.get_aim_direction(Vector2(10.0, 20.0)).length(), 1.0)


func test_pointer_on_the_character_keeps_the_last_aim() -> void:
	_pointer = Vector2(100.0, 500.0)
	var origin: Vector2 = Vector2(100.0, 100.0)
	assert_almost_eq(_input.get_aim_direction(origin), Vector2.DOWN)

	_pointer = origin + Vector2(2.0, -1.0)

	assert_almost_eq(_input.get_aim_direction(origin), Vector2.DOWN, 0.0001, "no flipping around")


func test_aim_starts_with_a_direction() -> void:
	assert_eq(_input.get_aim_direction(Vector2.ZERO), Vector2.RIGHT, "never a zero vector")


func test_aim_stick_sets_the_aim() -> void:
	_input.set_scheme_override(Scheme.TOUCH)
	Input.action_press(InputActions.AIM_UP, 1.0)

	assert_almost_eq(_input.get_aim_direction(Vector2.ZERO), Vector2.UP)

	Input.action_press(InputActions.AIM_LEFT, 1.0)
	assert_almost_eq(_input.get_aim_direction(Vector2.ZERO), Vector2(-1.0, -1.0).normalized())


func test_aim_is_kept_when_the_stick_is_released() -> void:
	_input.set_scheme_override(Scheme.TOUCH)
	Input.action_press(InputActions.AIM_DOWN, 1.0)
	_input.get_aim_direction(Vector2.ZERO)

	Input.action_release(InputActions.AIM_DOWN)

	assert_almost_eq(_input.get_aim_direction(Vector2.ZERO), Vector2.DOWN)


func test_aim_stick_that_is_barely_touched_does_not_change_the_aim() -> void:
	_input.set_scheme_override(Scheme.TOUCH)
	Input.action_press(InputActions.AIM_UP, 1.0)
	_input.get_aim_direction(Vector2.ZERO)
	Input.action_release(InputActions.AIM_UP)

	Input.action_press(InputActions.AIM_RIGHT, 0.2)

	assert_almost_eq(_input.get_aim_direction(Vector2.ZERO), Vector2.UP)


func test_pointer_does_not_aim_in_the_touch_scheme() -> void:
	_input.set_scheme_override(Scheme.TOUCH)
	_pointer = Vector2(0.0, 900.0)

	assert_eq(_input.get_aim_direction(Vector2.ZERO), Vector2.RIGHT, "a touch is not a pointer")


func test_locked_aim_keeps_its_direction() -> void:
	_pointer = Vector2(0.0, 100.0)
	_input.get_aim_direction(Vector2.ZERO)

	_input.add_lock(InputActions.AIM, &"stunned")
	_pointer = Vector2(100.0, 0.0)

	assert_almost_eq(_input.get_aim_direction(Vector2.ZERO), Vector2.DOWN)


# --- Actions ---------------------------------------------------------------------


func test_key_press_and_release_are_reported() -> void:
	_input.set_role(Role.MONSTER)
	watch_signals(_input)

	_press_key(KEY_E)
	_input.poll()
	assert_true(_input.is_action_held(InputActions.EAT))
	assert_signal_emitted_with(_input, &"action_pressed", [InputActions.EAT])

	_release_key(KEY_E)
	_input.poll()
	assert_false(_input.is_action_held(InputActions.EAT))
	assert_signal_emitted_with(_input, &"action_released", [InputActions.EAT])


func test_mouse_button_shoots() -> void:
	_input.set_role(Role.SHEEPHERDER)
	watch_signals(_input)
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true

	Input.parse_input_event(click)
	Input.flush_buffered_events()
	_input.poll()

	assert_signal_emitted_with(_input, &"action_pressed", [InputActions.SHOOT])
	click = click.duplicate()
	click.pressed = false
	Input.parse_input_event(click)
	Input.flush_buffered_events()


func test_held_action_is_reported_once_however_long_it_is_held() -> void:
	_input.set_role(Role.MONSTER)
	watch_signals(_input)
	Input.action_press(InputActions.SPRINT)

	for frame: int in 5:
		_input.poll()

	assert_signal_emit_count(_input, &"action_pressed", 1)
	assert_signal_not_emitted(_input, &"action_released")
	assert_true(_input.is_action_held(InputActions.SPRINT))


func test_key_tap_within_one_frame_is_not_missed() -> void:
	# Down and up again before the service looks: the key is never seen down.
	_input.set_role(Role.MONSTER)
	watch_signals(_input)

	_press_key(KEY_F)
	_release_key(KEY_F)
	_input.poll()

	assert_signal_emit_count(_input, &"action_pressed", 1)
	assert_signal_emitted_with(_input, &"action_pressed", [InputActions.BLEAT])
	assert_signal_emitted_with(_input, &"action_released", [InputActions.BLEAT])
	assert_false(_input.is_action_held(InputActions.BLEAT))

	_input.poll()
	assert_signal_emit_count(_input, &"action_pressed", 1, "one tap, one press")


func test_touch_tap_within_one_frame_is_not_missed() -> void:
	# Touch buttons press actions directly; the engine reports such a press
	# one frame later.
	_input.set_role(Role.MONSTER)
	watch_signals(_input)

	Input.action_press(InputActions.BLEAT)
	Input.action_release(InputActions.BLEAT)
	_input.poll()
	await wait_frames(1)
	_input.poll()

	assert_signal_emit_count(_input, &"action_pressed", 1)
	assert_signal_emit_count(_input, &"action_released", 1)


func test_ordinary_release_is_not_mistaken_for_a_tap() -> void:
	_input.set_role(Role.MONSTER)
	_press_key(KEY_F)
	_input.poll()
	watch_signals(_input)

	_release_key(KEY_F)
	_input.poll()
	_input.poll()

	assert_signal_not_emitted(_input, &"action_pressed")
	assert_signal_emit_count(_input, &"action_released", 1)


func test_actions_of_the_other_role_are_ignored() -> void:
	_input.set_role(Role.SHEEPHERDER)
	watch_signals(_input)

	_press_key(KEY_E)
	_press_key(KEY_Q)
	_input.poll()

	assert_signal_not_emitted(_input, &"action_pressed")
	assert_false(_input.is_action_held(InputActions.EAT))


func test_role_change_releases_and_switches_the_action_set() -> void:
	_input.set_role(Role.MONSTER)
	Input.action_press(InputActions.GRAZE)
	_input.poll()
	watch_signals(_input)

	_input.set_role(Role.SHEEPHERDER)

	assert_signal_emitted_with(_input, &"action_released", [InputActions.GRAZE])
	assert_signal_emitted_with(_input, &"role_changed", [Role.SHEEPHERDER])
	assert_eq(_input.get_role(), Role.SHEEPHERDER)

	_press_key(KEY_SPACE)
	_input.poll()
	assert_true(_input.is_action_held(InputActions.BELL))


func test_locked_action_is_released_and_resumes_when_the_lock_ends() -> void:
	_input.set_role(Role.MONSTER)
	Input.action_press(InputActions.SPRINT)
	_input.poll()

	_input.add_lock(InputActions.SPRINT, &"eating")
	_input.poll()
	assert_false(_input.is_action_held(InputActions.SPRINT), "released by the lock")

	_input.remove_lock(InputActions.SPRINT, &"eating")
	_input.poll()
	assert_true(_input.is_action_held(InputActions.SPRINT), "the key was held all along")


func test_nothing_is_reported_while_gameplay_input_is_off() -> void:
	_input.set_role(Role.MONSTER)
	Input.action_press(InputActions.GRAZE)
	_input.poll()
	watch_signals(_input)

	_input.set_gameplay_enabled(false)
	_input.poll()

	assert_signal_emitted_with(_input, &"action_released", [InputActions.GRAZE])
	assert_signal_emitted_with(_input, &"gameplay_enabled_changed", [false])
	assert_false(_input.is_action_held(InputActions.GRAZE))


func test_losing_focus_releases_what_is_held() -> void:
	# The tab goes to the background while a key is down: its release never
	# arrives, so the hold must end here.
	_input.set_role(Role.MONSTER)
	_press_key(KEY_SHIFT)
	_press_key(KEY_D)
	_input.poll()
	assert_true(_input.is_action_held(InputActions.SPRINT))
	watch_signals(_input)

	_input.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_input.poll()

	assert_signal_emitted_with(_input, &"action_released", [InputActions.SPRINT])
	assert_false(_input.is_action_held(InputActions.SPRINT))
	assert_eq(_input.get_move_vector(), Vector2.ZERO, "movement stops as well")
	assert_signal_emit_count(_input, &"action_pressed", 0, "and nothing presses itself again")


# --- Control scheme --------------------------------------------------------------


func test_touching_the_screen_switches_to_touch_controls() -> void:
	_input.clear_scheme_override()
	_input.observe_event(InputEventKey.new())
	watch_signals(_input)

	_input.observe_event(InputEventScreenTouch.new())

	assert_eq(_input.get_scheme(), Scheme.TOUCH)
	assert_signal_emitted_with(_input, &"scheme_changed", [Scheme.TOUCH])


func test_using_the_keyboard_switches_back() -> void:
	_input.clear_scheme_override()
	_input.observe_event(InputEventScreenDrag.new())

	_input.observe_event(InputEventKey.new())

	assert_eq(_input.get_scheme(), Scheme.KEYBOARD_MOUSE)


func test_a_real_mouse_switches_back() -> void:
	_input.clear_scheme_override()
	_input.observe_event(InputEventScreenTouch.new())
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.device = InputEvent.DEVICE_ID_MOUSE

	_input.observe_event(motion)

	assert_eq(_input.get_scheme(), Scheme.KEYBOARD_MOUSE)


func test_mouse_events_made_from_touches_do_not_switch_back() -> void:
	_input.clear_scheme_override()
	_input.observe_event(InputEventScreenTouch.new())
	var emulated: InputEventMouseButton = InputEventMouseButton.new()
	emulated.device = InputEvent.DEVICE_ID_EMULATION

	_input.observe_event(emulated)

	assert_eq(_input.get_scheme(), Scheme.TOUCH)


func test_override_wins_over_the_device_in_use() -> void:
	_input.set_scheme_override(Scheme.TOUCH)
	watch_signals(_input)

	_input.observe_event(InputEventKey.new())

	assert_eq(_input.get_scheme(), Scheme.TOUCH)
	assert_signal_not_emitted(_input, &"scheme_changed")


func test_clearing_the_override_returns_to_the_device_in_use() -> void:
	_input.clear_scheme_override()
	_input.observe_event(InputEventKey.new())
	_input.set_scheme_override(Scheme.TOUCH)
	watch_signals(_input)

	_input.clear_scheme_override()

	assert_eq(_input.get_scheme(), Scheme.KEYBOARD_MOUSE)
	assert_signal_emitted_with(_input, &"scheme_changed", [Scheme.KEYBOARD_MOUSE])


func test_same_scheme_again_is_not_announced() -> void:
	_input.clear_scheme_override()
	_input.observe_event(InputEventKey.new())
	watch_signals(_input)

	_input.observe_event(InputEventKey.new())

	assert_signal_not_emitted(_input, &"scheme_changed")


func test_application_uses_the_device_input_service() -> void:
	assert_is(Services.input, DeviceInputService)
	assert_eq(Services.input.get_role(), Role.NONE, "no role until a round sets one")


func _press_key(key: Key) -> void:
	_send_key(key, true)
	_pressed_keys.append(key)


func _release_key(key: Key) -> void:
	_send_key(key, false)
	_pressed_keys.erase(key)


func _send_key(key: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
