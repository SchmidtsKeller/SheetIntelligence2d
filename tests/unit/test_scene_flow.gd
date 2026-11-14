extends TestCase
## The scene flow walks boot → lobby → round → results and refuses shortcuts.

const Screen = SceneFlowController.Screen

var _flow: SceneFlowController
var _loaded_scenes: PackedStringArray = []
var _scene_change_result: Error = OK


func before_each() -> void:
	_loaded_scenes.clear()
	_scene_change_result = OK
	_flow = add_child_autofree(SceneFlowController.new())
	_flow.scene_changer = _fake_scene_change


func test_a_scene_outside_the_flow_is_no_screen() -> void:
	assert_eq(_flow.current_screen, Screen.NONE, "the test runner scene is not part of the flow")


func test_any_screen_can_be_entered_from_outside_the_flow() -> void:
	for screen: SceneFlowController.Screen in [
		Screen.BOOT, Screen.LOBBY, Screen.ROUND, Screen.RESULTS
	]:
		assert_true(SceneFlowController.can_transition(Screen.NONE, screen))
	assert_false(
		SceneFlowController.can_transition(Screen.LOBBY, Screen.NONE),
		"nothing leads out of the flow"
	)


func test_full_match_flow() -> void:
	assert_true(_flow.go_to(Screen.BOOT))
	assert_true(_flow.go_to(Screen.LOBBY))
	assert_true(_flow.go_to(Screen.ROUND))
	assert_true(_flow.go_to(Screen.RESULTS))
	assert_true(_flow.go_to(Screen.ROUND), "next round")
	assert_true(_flow.go_to(Screen.RESULTS))
	assert_true(_flow.go_to(Screen.LOBBY), "match over")

	assert_eq(_flow.current_screen, Screen.LOBBY)
	assert_eq(_loaded_scenes.size(), 7)
	assert_eq(_loaded_scenes[0], "res://ui/screens/boot_screen.tscn")
	assert_eq(_loaded_scenes[3], "res://ui/screens/results_screen.tscn")


func test_round_can_fall_back_to_the_lobby_on_disconnect() -> void:
	_flow.go_to(Screen.ROUND)

	assert_true(_flow.go_to(Screen.LOBBY))


func test_transition_table() -> void:
	var allowed: Dictionary[SceneFlowController.Screen, Array] = {
		Screen.BOOT: [Screen.LOBBY],
		Screen.LOBBY: [Screen.ROUND],
		Screen.ROUND: [Screen.RESULTS, Screen.LOBBY],
		Screen.RESULTS: [Screen.ROUND, Screen.LOBBY],
	}

	for from: SceneFlowController.Screen in allowed:
		for to: SceneFlowController.Screen in [
			Screen.BOOT, Screen.LOBBY, Screen.ROUND, Screen.RESULTS
		]:
			assert_eq(
				SceneFlowController.can_transition(from, to),
				allowed[from].has(to),
				(
					"%s → %s"
					% [SceneFlowController.screen_name(from), SceneFlowController.screen_name(to)]
				),
			)


func test_shortcut_is_refused_and_changes_nothing() -> void:
	_flow.go_to(Screen.BOOT)
	watch_signals(_flow)
	expect_error("cannot go from Boot to Results")

	assert_false(_flow.can_go_to(Screen.RESULTS))
	assert_false(_flow.go_to(Screen.RESULTS))

	assert_eq(_flow.current_screen, Screen.BOOT)
	assert_eq(_loaded_scenes.size(), 1, "only the boot scene was loaded")
	assert_signal_not_emitted(_flow, &"screen_changed")


func test_failed_scene_load_keeps_the_current_screen() -> void:
	_flow.go_to(Screen.BOOT)
	_scene_change_result = ERR_CANT_OPEN
	expect_error("could not load the scene of Lobby")

	assert_false(_flow.go_to(Screen.LOBBY))

	assert_eq(_flow.current_screen, Screen.BOOT)


func test_transitions_are_announced() -> void:
	_flow.go_to(Screen.BOOT)
	watch_signals(_flow)

	_flow.go_to(Screen.LOBBY)

	assert_signal_emitted_with(_flow, &"screen_changing", [Screen.BOOT, Screen.LOBBY])
	assert_signal_emitted_with(_flow, &"screen_changed", [Screen.LOBBY])


func test_next_screens_of_the_current_screen() -> void:
	_flow.go_to(Screen.RESULTS)

	assert_eq(_flow.get_next_screens(), [Screen.ROUND, Screen.LOBBY])


func test_a_task_can_replace_the_scene_of_a_screen() -> void:
	_flow.screen_scenes[Screen.LOBBY] = "res://ui/lobby/real_lobby.tscn"

	_flow.go_to(Screen.LOBBY)

	assert_eq(_loaded_scenes[0], "res://ui/lobby/real_lobby.tscn")


func test_every_screen_has_an_existing_scene() -> void:
	var flow: SceneFlowController = get_node(^"/root/SceneFlow")

	for screen: SceneFlowController.Screen in [
		Screen.BOOT, Screen.LOBBY, Screen.ROUND, Screen.RESULTS
	]:
		assert_true(
			flow.screen_scenes.has(screen),
			"%s has a scene" % SceneFlowController.screen_name(screen)
		)
		assert_true(
			ResourceLoader.exists(flow.screen_scenes[screen]),
			"%s exists" % flow.screen_scenes[screen]
		)


func test_placeholder_screens_can_be_instantiated() -> void:
	var flow: SceneFlowController = get_node(^"/root/SceneFlow")

	for screen: SceneFlowController.Screen in [Screen.LOBBY, Screen.ROUND, Screen.RESULTS]:
		var scene: PackedScene = load(flow.screen_scenes[screen])
		var instance: Node = add_child_autofree(scene.instantiate())
		assert_is(instance, Control)
		assert_gt(instance.get_child_count(), 0, "the placeholder builds its content")


func test_screen_names_are_readable() -> void:
	assert_eq(SceneFlowController.screen_name(Screen.LOBBY), "Lobby")
	assert_eq(SceneFlowController.screen_name(Screen.RESULTS), "Results")


func _fake_scene_change(path: String) -> Error:
	if _scene_change_result == OK:
		_loaded_scenes.append(path)
	return _scene_change_result
