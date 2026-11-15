extends TestCase
## The lobby, the perk picker and the scoreboard (#20), on one device: the
## flow from the lobby to the round and back, the perk choice and what the
## scoreboard says. Two devices are covered by test_match_flow.gd (the ready
## check) and the two-instance match check.

# Aliases for enum types, so they are named like types.
# gdlint: ignore=constant-name
const Role = GameEnums.Role
# gdlint: ignore=constant-name
const Screen = SceneFlowController.Screen
# gdlint: ignore=constant-name
const ResultsScreen = preload("res://ui/screens/results_screen.gd")

const LOBBY_SCENE: String = "res://ui/screens/lobby_screen.tscn"
const RESULTS_SCENE: String = "res://ui/screens/results_screen.tscn"
const ROUND_SCENE: String = "res://ui/screens/round_screen.tscn"

var _session: GameSession
var _flow: MatchFlow
var _scene_flow: SceneFlowController
var _loaded: PackedStringArray = []
var _lobby: Control


func before_each() -> void:
	_session = Services.session
	_flow = Services.match_flow
	if _session.is_active():
		_session.leave()
	_loaded.clear()
	_scene_flow = add_child_autofree(SceneFlowController.new())
	_scene_flow.scene_changer = func(path: String) -> Error:
		_loaded.append(path)
		return OK
	_scene_flow.go_to(Screen.LOBBY)
	_loaded.clear()
	_session.scene_flow = _scene_flow
	_lobby = add_child_autofree((load(LOBBY_SCENE) as PackedScene).instantiate())
	await wait_frames(1)


func after_each() -> void:
	_session.leave()
	_session.scene_flow = null
	await wait_frames(2)


# --- Lobby -----------------------------------------------------------------------


func test_without_a_second_device_the_lobby_offers_the_computer() -> void:
	assert_true(_shown("Offline"))
	assert_false(_shown("Match"))
	assert_true(_lobby.call(&"get_status_text").contains("computer"))


func test_a_match_against_the_computer_starts_with_the_perk_choice() -> void:
	_press(_lobby, "Monster vs. computer")
	await wait_frames(1)

	assert_true(_session.is_offline())
	assert_eq(_session.get_local_role(), Role.MONSTER)
	assert_false(_shown("Offline"))
	assert_true(_shown("Match"))
	assert_eq(_label("Role"), "In the first round you play the Monster")
	assert_eq(_label("Players"), "You (host) against the computer")
	assert_eq(_loaded, PackedStringArray(), "no round before the perk is chosen")


func test_ready_starts_the_match() -> void:
	_press(_lobby, "Sheepherder vs. computer")
	await wait_frames(1)
	_picker().choose(PerkIds.SPARE_BULLET)

	(_lobby.find_child("Ready", true, false) as Button).button_pressed = true
	await wait_frames(2)

	assert_eq(_loaded, PackedStringArray([ROUND_SCENE]))
	assert_eq(Services.perks.get_selected_perk(Role.SHEEPHERDER), PerkIds.SPARE_BULLET)
	assert_false(_picker().is_open(), "the choice is locked")


func test_leaving_goes_back_to_the_start() -> void:
	_press(_lobby, "Monster vs. computer")
	await wait_frames(1)

	_press(_lobby, "Leave")
	await wait_frames(1)

	assert_false(_session.is_active())
	assert_true(_shown("Offline"))
	assert_false(_shown("Match"))


# --- Perk picker -----------------------------------------------------------------


func test_the_picker_offers_only_the_pool_of_the_players_role() -> void:
	_session.play_offline(Role.MONSTER)
	await wait_frames(1)

	var choices: Array[StringName] = _picker().get_choices()

	var expected: Array[StringName] = Services.perks.get_available_perks(Role.MONSTER)
	expected.append(PerkIds.NONE)
	assert_eq(choices, expected)
	for perk_id: StringName in Services.perks.get_available_perks(Role.SHEEPHERDER):
		assert_null(_picker().get_button(perk_id), "no Sheepherder perk on the Monster's screen")
	var bat: String = _picker().get_button(PerkIds.ALLIED_BAT).text
	assert_true(bat.begins_with("Allied Bat · Companion"), bat)


func test_one_perk_at_a_time_and_none_is_a_choice() -> void:
	_session.play_offline(Role.SHEEPHERDER)
	await wait_frames(1)

	_picker().choose(PerkIds.WIDE_FLASHLIGHT)
	_picker().choose(PerkIds.LONG_FLASHLIGHT)
	await wait_frames(1)

	assert_eq(_picker().get_selected(), PerkIds.LONG_FLASHLIGHT)
	assert_true(_picker().get_button(PerkIds.LONG_FLASHLIGHT).button_pressed)
	assert_false(_picker().get_button(PerkIds.WIDE_FLASHLIGHT).button_pressed)

	_picker().choose(PerkIds.NONE)
	await wait_frames(1)

	assert_eq(_picker().get_selected(), PerkIds.NONE)
	assert_true(_picker().get_button(PerkIds.NONE).button_pressed)


func test_the_picker_follows_the_role() -> void:
	_session.play_offline(Role.SHEEPHERDER)
	await wait_frames(1)

	_session.assign_roles(Role.MONSTER)
	await wait_frames(1)

	assert_not_null(_picker().get_button(PerkIds.INVISIBILITY))
	assert_null(_picker().get_button(PerkIds.SPARE_BULLET))


func test_a_locked_selection_cannot_be_changed() -> void:
	_session.play_offline(Role.SHEEPHERDER)
	await wait_frames(1)
	Services.perks.lock_selection()
	_picker().refresh()

	assert_false(_picker().choose(PerkIds.SPARE_BULLET))
	assert_true(_picker().get_button(PerkIds.SPARE_BULLET).disabled)
	Services.perks.clear_selection()


# --- Scoreboard ------------------------------------------------------------------


func test_the_history_lists_every_round_from_the_players_view() -> void:
	var score: MatchScore = MatchScore.new(2)
	score.record_round(_result(GameEnums.RoundOutcome.SHEEPHERDER_WIN, 10, 0), Role.SHEEPHERDER)
	score.record_round(_result(GameEnums.RoundOutcome.MONSTER_WIN, 4, 6), Role.MONSTER)

	var history: String = ResultsScreen.describe_history(score, MatchScore.Player.HOST)

	var expected: String = (
		"Round 1: you were the Sheepherder, you won (10 : 0)\n"
		+ "Round 2: you were the Monster, you won (6 : 4)"
	)
	assert_eq(history, expected)
	assert_eq(
		ResultsScreen.describe_history(score, MatchScore.Player.GUEST).get_slice("\n", 0),
		"Round 1: you were the Monster, you lost (0 : 10)"
	)


func test_the_scoreboard_never_names_a_perk() -> void:
	_session.play_offline(Role.MONSTER)
	await wait_frames(1)
	Services.perks.select_perk(Role.SHEEPHERDER, PerkIds.SPARE_BULLET)
	var score: MatchScore = MatchScore.new(1)
	score.record_round(_result(GameEnums.RoundOutcome.SHEEPHERDER_WIN, 10, 0), Role.MONSTER)
	_session.state.set_value(MatchFlow.KEY_SCORE, score.to_data())
	var results: Control = add_child_autofree((load(RESULTS_SCENE) as PackedScene).instantiate())
	await wait_frames(1)

	var text: String = results.call(&"get_text")

	for perk_id: StringName in Services.perks.get_available_perks(Role.SHEEPHERDER):
		var perk: PerkDefinition = PerkCatalog.load_default().get_perk(perk_id)
		assert_false(text.contains(perk.display_name), "%s is not shown" % perk.display_name)
	assert_true(text.contains("you were the Monster"), text)


# --- Helpers ---------------------------------------------------------------------


func _picker() -> PerkPicker:
	return _lobby.call(&"get_picker")


func _shown(node_name: String) -> bool:
	var node: Control = _lobby.find_child(node_name, true, false)
	return node != null and node.is_visible_in_tree()


func _label(node_name: String) -> String:
	return (_lobby.find_child(node_name, true, false) as Label).text


func _press(screen: Node, text: String) -> void:
	for node: Node in screen.find_children("*", "Button", true, false):
		var button: Button = node
		if button.text == text and button.is_visible_in_tree():
			button.pressed.emit()
			return
	fail_test("no button '%s'" % text)


func _result(outcome: GameEnums.RoundOutcome, herder: int, monster: int) -> RoundResult:
	var result: RoundResult = RoundResult.new()
	result.outcome = outcome
	result.reason = GameEnums.RoundEndReason.TIMEOUT
	result.surviving_sheep = herder
	result.herder_surviving_points = herder
	result.eaten_sheep = monster
	result.monster_eaten_points = monster
	return result
