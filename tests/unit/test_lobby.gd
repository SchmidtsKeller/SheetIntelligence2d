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
# gdlint: ignore=constant-name
const LobbyScreen = preload("res://ui/screens/lobby_screen.gd")

const LOBBY_SCENE: String = "res://ui/screens/lobby_screen.tscn"
const RESULTS_SCENE: String = "res://ui/screens/results_screen.tscn"
const ROUND_SCENE: String = "res://ui/screens/round_screen.tscn"

var _session: GameSession
var _flow: MatchFlow
var _scene_flow: SceneFlowController
var _loaded: PackedStringArray = []
var _lobby: Control
## Set while a test connects over real sockets: the transport and the
## messenger's transmitter to restore afterwards.
var _original_network: Node
var _original_transmitter: Callable
## The other instance's side: a branch of the tree with its own multiplayer API.
var _remote_side: Node
var _remote: EnetNetworkService


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
	if _remote != null:
		_remote.close_session()
	# The connections are closed one frame after their session ended.
	await wait_frames(2)
	if _remote_side != null:
		get_tree().set_multiplayer(null, _remote_side.get_path())
		_remote_side = null
		_remote = null
	if _original_network != null:
		_session.messenger.transmitter = _original_transmitter
		Services.replace(NetworkService, _original_network).free()
		_original_network = null


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


# --- Host and Join on a desktop (#99) ----------------------------------------------


func test_the_desktop_lobby_offers_host_and_join() -> void:
	assert_true(_shown("Connect"))
	assert_true(_button_shown(LobbyScreen.HOST))
	assert_true(_button_shown(LobbyScreen.JOIN))
	assert_true(_button_shown(LobbyScreen.THIS_COMPUTER), "only this computer by default")
	assert_eq(_address().text, LaunchOptions.DEFAULT_ADDRESS)
	assert_true(_address().is_visible_in_tree())
	assert_false(_shown("Waiting"))
	assert_true(_lobby.call(&"get_status_text").contains("Host a game"))
	assert_is(Services.network, StubNetworkService, "no port is open before Host or Join")


func test_host_waits_and_the_other_instance_joins() -> void:
	var port: int = _connect_over_sockets()

	_press(_lobby, LobbyScreen.HOST)

	assert_is(Services.network, EnetNetworkService)
	assert_eq(_session.get_connection_state(), NetworkService.ConnectionState.CONNECTING)
	assert_true(_shown("Waiting"))
	assert_false(_shown("Connect"))
	assert_false(_shown("Offline"))
	assert_true(_lobby.call(&"get_status_text").contains("Waiting for the other player"))

	assert_eq(_remote.join_session({"address": "127.0.0.1", "port": port}), OK)
	await _wait_until(_session.is_active)

	assert_true(_session.is_active(), "the other instance joined")
	assert_true(_shown("Match"))
	assert_false(_shown("Waiting"))
	assert_eq(_label("Players"), "You (host) against the other player, connected")


func test_join_connects_to_the_address() -> void:
	var port: int = _connect_over_sockets()
	assert_eq(_remote.host_session({"port": port}), OK)
	_address().text = " 127.0.0.1 "

	_press(_lobby, LobbyScreen.JOIN)

	assert_true(_lobby.call(&"get_status_text").contains("Joining 127.0.0.1:%d" % port))
	await _wait_until(_session.is_active)

	assert_true(_session.is_active(), "joined the other instance")
	assert_false(_session.is_host())
	assert_eq(_label("Players"), "You (guest) against the other player, connected")


func test_cancel_goes_back_to_host_and_join() -> void:
	_connect_over_sockets()
	_press(_lobby, LobbyScreen.HOST)

	_press(_lobby, LobbyScreen.CANCEL)
	await wait_frames(1)

	assert_eq(_session.get_connection_state(), NetworkService.ConnectionState.DISCONNECTED)
	assert_true(_shown("Connect"))
	assert_true(_shown("Offline"))
	assert_false(_shown("Waiting"))


func test_the_host_can_open_the_game_to_the_network() -> void:
	(_lobby.find_child("Network", true, false) as Button).button_pressed = true

	assert_true(_connect_options().lan)
	assert_true(_button_shown(LobbyScreen.WHOLE_NETWORK))


func test_the_computer_is_still_offered_after_hosting() -> void:
	_connect_over_sockets()
	_press(_lobby, LobbyScreen.HOST)
	_press(_lobby, LobbyScreen.CANCEL)
	await wait_frames(1)

	_press(_lobby, "Monster vs. computer")
	await wait_frames(1)

	assert_true(_session.is_offline(), "the offline stand-in takes over from ENet")
	assert_eq(_label("Players"), "You (host) against the computer")


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


func _connect_options() -> LaunchOptions:
	return _lobby.get(&"connect_options") as LaunchOptions


func _address() -> LineEdit:
	return _lobby.find_child("Address", true, false) as LineEdit


func _button_shown(text: String) -> bool:
	for node: Node in _lobby.find_children("*", "Button", true, false):
		var button: Button = node
		if button.text == text and button.is_visible_in_tree():
			return true
	return false


## Lets the lobby connect over real sockets on this computer, on a free port,
## to an ENet transport that stands for the other instance. Messages are not
## sent: the other side has no session. Returns the port.
func _connect_over_sockets() -> int:
	_original_network = Services.replace(NetworkService, StubNetworkService.new())
	_original_transmitter = _session.messenger.transmitter
	_session.messenger.transmitter = func(_reliable: bool, _message: Array) -> void: pass
	_remote_side = add_child_autofree(Node.new())
	get_tree().set_multiplayer(SceneMultiplayer.new(), _remote_side.get_path())
	_remote = EnetNetworkService.new()
	_remote_side.add_child(_remote)
	var port: int = _free_port()
	_connect_options().port = port
	return port


func _wait_until(condition: Callable) -> void:
	for frame: int in 300:
		if condition.call():
			return
		await get_tree().process_frame


static func _free_port() -> int:
	var port: int = 0
	for _probe: int in 50:
		port = 30000 + randi() % 20000
		var socket: PacketPeerUDP = PacketPeerUDP.new()
		var bound: bool = socket.bind(port, "127.0.0.1") == OK
		socket.close()
		if bound:
			return port
	return port


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
