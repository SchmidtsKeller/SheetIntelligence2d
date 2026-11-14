extends TestCase
## The input gate: which actions get through, and that every press gets its
## release.

# An alias for an enum type, so it is named like a type.
# gdlint: ignore=constant-name
const Role = GameEnums.Role

var _gate: InputGate
## Reported actions in order: "pressed shoot", "released shoot".
var _reports: Array[String] = []


func before_each() -> void:
	_reports.clear()
	_gate = InputGate.new()
	_gate.action_pressed.connect(
		func(action: StringName) -> void: _reports.append("pressed %s" % action)
	)
	_gate.action_released.connect(
		func(action: StringName) -> void: _reports.append("released %s" % action)
	)


func test_action_of_the_current_role_is_reported() -> void:
	_gate.set_role(Role.SHEEPHERDER)

	assert_true(_gate.press(InputActions.SHOOT))
	assert_true(_gate.is_held(InputActions.SHOOT))

	_gate.release(InputActions.SHOOT)
	assert_false(_gate.is_held(InputActions.SHOOT))
	assert_eq(_reports, ["pressed shoot", "released shoot"])


func test_action_of_the_other_role_is_not_reported() -> void:
	_gate.set_role(Role.SHEEPHERDER)

	assert_false(_gate.press(InputActions.EAT))

	assert_false(_gate.is_held(InputActions.EAT))
	assert_eq(_reports, [])


func test_without_a_role_nothing_is_reported() -> void:
	for action: StringName in [InputActions.SHOOT, InputActions.EAT, InputActions.PERK]:
		assert_false(_gate.press(action))


func test_held_action_is_pressed_only_once() -> void:
	_gate.set_role(Role.MONSTER)

	assert_true(_gate.press(InputActions.GRAZE))
	assert_false(_gate.press(InputActions.GRAZE))

	assert_eq(_reports, ["pressed graze"])


func test_releasing_an_action_that_is_not_held_reports_nothing() -> void:
	_gate.set_role(Role.MONSTER)

	_gate.release(InputActions.GRAZE)

	assert_eq(_reports, [])


func test_changing_the_role_releases_what_the_new_role_cannot_do() -> void:
	_gate.set_role(Role.MONSTER)
	_gate.press(InputActions.SPRINT)

	assert_true(_gate.set_role(Role.SHEEPHERDER))

	assert_false(_gate.is_held(InputActions.SPRINT))
	assert_eq(_reports, ["pressed sprint", "released sprint"])
	assert_false(_gate.set_role(Role.SHEEPHERDER), "the same role again changes nothing")


func test_switching_gameplay_input_off_releases_and_blocks_everything() -> void:
	_gate.set_role(Role.MONSTER)
	_gate.press(InputActions.GRAZE)

	assert_true(_gate.set_gameplay_enabled(false))

	assert_false(_gate.is_held(InputActions.GRAZE))
	assert_false(_gate.press(InputActions.BLEAT))
	assert_false(_gate.allows_movement())
	assert_false(_gate.allows_aiming())

	_gate.set_gameplay_enabled(true)
	assert_true(_gate.press(InputActions.BLEAT))
	assert_true(_gate.allows_movement())


func test_lock_releases_and_blocks_one_action() -> void:
	_gate.set_role(Role.MONSTER)
	_gate.press(InputActions.SPRINT)
	_gate.press(InputActions.GRAZE)

	_gate.add_lock(InputActions.SPRINT, &"eating")

	assert_false(_gate.is_held(InputActions.SPRINT))
	assert_true(_gate.is_held(InputActions.GRAZE), "other actions are not affected")
	assert_false(_gate.press(InputActions.SPRINT))

	_gate.remove_lock(InputActions.SPRINT, &"eating")
	assert_true(_gate.press(InputActions.SPRINT))


func test_movement_and_aim_can_be_locked_as_a_whole() -> void:
	_gate.add_lock(InputActions.MOVE, &"eating")
	assert_false(_gate.allows_movement())
	assert_true(_gate.allows_aiming())

	_gate.add_lock(InputActions.AIM, &"stunned")
	assert_false(_gate.allows_aiming())

	_gate.clear_locks(&"eating")
	assert_true(_gate.allows_movement())
	assert_false(_gate.allows_aiming(), "the other source still holds its lock")


func test_lock_stays_until_the_last_source_lets_go() -> void:
	_gate.add_lock(InputActions.MOVE, &"eating")
	_gate.add_lock(InputActions.MOVE, &"grazing")
	_gate.add_lock(InputActions.MOVE, &"grazing")

	_gate.remove_lock(InputActions.MOVE, &"eating")
	assert_true(_gate.is_locked(InputActions.MOVE))

	_gate.remove_lock(InputActions.MOVE, &"grazing")
	assert_false(_gate.is_locked(InputActions.MOVE))


func test_release_all_reports_a_release_for_every_held_action() -> void:
	_gate.set_role(Role.MONSTER)
	_gate.press(InputActions.GRAZE)
	_gate.press(InputActions.SPRINT)
	_reports.clear()

	_gate.release_all()

	assert_eq(_reports.size(), 2)
	assert_has(_reports, "released graze")
	assert_has(_reports, "released sprint")


func test_every_press_gets_its_release_whatever_happens() -> void:
	# Role change, lock, gameplay off: each ends a held action properly.
	_gate.set_role(Role.MONSTER)
	_gate.press(InputActions.EAT)
	_gate.set_role(Role.SHEEPHERDER)
	_gate.press(InputActions.SHOOT)
	_gate.add_lock(InputActions.SHOOT, &"reloading")
	_gate.press(InputActions.BELL)
	_gate.set_gameplay_enabled(false)

	var pressed: int = 0
	var released: int = 0
	for report: String in _reports:
		if report.begins_with("pressed"):
			pressed += 1
		else:
			released += 1
	assert_eq(pressed, 3)
	assert_eq(released, 3)
