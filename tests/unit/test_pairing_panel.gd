extends TestCase
## The pairing panel (GDD §8.1, §9.4), with a transport and a browser side
## that the test plays.


## Records what the panel asks of the browser and draws a 3x3 QR code.
class FakeBrowser:
	extends PairingBrowser

	var calls: PackedStringArray = []

	func is_available() -> bool:
		return true

	func qr_rows(_text: String) -> PackedStringArray:
		return ["101", "010", "101"]

	func scan() -> void:
		calls.append("scan")

	func enter(_title: String) -> void:
		calls.append("enter")

	func copy(text: String) -> void:
		calls.append("copy " + text)

	func close() -> void:
		calls.append("close")


var _network: FakeNetworkService
var _original_network: Node
var _browser: FakeBrowser
var _panel: PairingPanel


func before_each() -> void:
	# A session left open by an earlier test is closed first: replacing the
	# transport ends the session but would leave the old transport connected,
	# and later tests could not host again.
	if Services.session.get_connection_state() != NetworkService.ConnectionState.DISCONNECTED:
		Services.session.leave()
	_network = FakeNetworkService.new()
	_network.pairing = true
	_original_network = Services.replace(NetworkService, _network)
	_browser = FakeBrowser.new()
	_panel = PairingPanel.new()
	_panel.browser = _browser
	add_child_autofree(_panel)


func after_each() -> void:
	Services.replace(NetworkService, _original_network)
	_network.free()


func test_it_offers_to_host_or_join() -> void:
	assert_true(_panel.visible)
	assert_eq(_panel.get_step(), PairingPanel.Step.CHOOSE)
	assert_eq(
		_button_texts(),
		[
			"Host a game",
			"Join a game",
			PairingPanel.OFFLINE_HERDER,
			PairingPanel.OFFLINE_MONSTER,
		]
	)


func test_the_host_shows_its_code_and_connects_with_the_answer() -> void:
	_press("Host a game")
	assert_eq(_network.get_connection_state(), NetworkService.ConnectionState.CONNECTING)
	assert_eq(_button_texts(), ["Cancel"], "while the code is made")

	_network.pairing_code_ready.emit("OFFER")

	assert_eq(_panel.get_step(), PairingPanel.Step.HOST_CODE)
	assert_eq(_button_texts(), ["Copy code", "Scan answer", "Enter answer", "Cancel"])
	var qr: TextureRect = _qr()
	assert_true(qr.visible)
	assert_eq(qr.texture.get_size(), Vector2(3 + 2 * PairingPanel.QR_QUIET_ZONE, 11))
	_press("Copy code")
	_press("Scan answer")
	assert_eq(_browser.calls, PackedStringArray(["copy OFFER", "scan"]))

	_browser.code_entered.emit("ANSWER")

	assert_eq(_network.submitted_codes, PackedStringArray(["ANSWER"]))
	assert_eq(_panel.get_step(), PairingPanel.Step.CONNECTING)
	_network.simulate_started()
	assert_eq(_panel.get_step(), PairingPanel.Step.CONNECTED)
	assert_eq(_panel.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the lobby below takes clicks")


func test_a_refused_code_is_explained_and_can_be_read_again() -> void:
	_press("Host a game")
	_network.pairing_code_ready.emit("OFFER")
	_network.refusal = "Wrong code: the host scans the guest's answer."

	_browser.code_entered.emit("OFFER")

	assert_eq(_panel.get_step(), PairingPanel.Step.HOST_CODE)
	assert_true(_labels().has("Wrong code: the host scans the guest's answer."))
	assert_eq(_button_texts(), ["Copy code", "Scan answer", "Enter answer", "Cancel"])


func test_the_guest_reads_the_offer_then_shows_its_answer() -> void:
	_press("Join a game")
	assert_eq(_panel.get_step(), PairingPanel.Step.JOIN_READ)
	assert_eq(_button_texts(), ["Scan code", "Enter code", "Cancel"])
	_press("Enter code")
	assert_eq(_browser.calls, PackedStringArray(["enter"]))

	_browser.code_entered.emit("OFFER")
	assert_eq(_panel.get_step(), PairingPanel.Step.JOIN_CODE)
	assert_eq(_button_texts(), ["Cancel"], "while the answer is made")
	_network.pairing_code_ready.emit("ANSWER")

	assert_eq(_button_texts(), ["Copy answer", "Cancel"])
	assert_true(_qr().visible)


func test_a_failed_connection_says_why_and_starts_over() -> void:
	_press("Join a game")

	_network.simulate_ended(NetworkService.DisconnectReason.CONNECTION_FAILED, "No way through.")

	assert_eq(_panel.get_step(), PairingPanel.Step.FAILED)
	assert_true(_labels().has("No way through."))
	_press("Try again")
	assert_eq(_panel.get_step(), PairingPanel.Step.CHOOSE)


func test_cancel_closes_the_attempt() -> void:
	_press("Host a game")
	_network.pairing_code_ready.emit("OFFER")

	_press("Cancel")

	assert_eq(_network.get_connection_state(), NetworkService.ConnectionState.DISCONNECTED)
	assert_eq(_panel.get_step(), PairingPanel.Step.CHOOSE)
	assert_has(_browser.calls, "close")


func test_alone_the_player_takes_on_the_computer_in_the_role_they_chose() -> void:
	for choice: Array in [
		[PairingPanel.OFFLINE_HERDER, GameEnums.Role.SHEEPHERDER],
		[PairingPanel.OFFLINE_MONSTER, GameEnums.Role.MONSTER],
	]:
		var flow: SceneFlowController = _note_taking_flow()

		_press(choice[0])

		assert_true(Services.session.is_offline(), "no second device")
		assert_eq(Services.session.get_local_role(), choice[1])
		assert_eq(flow.current_screen, SceneFlowController.Screen.ROUND)
		assert_eq(_panel.get_step(), PairingPanel.Step.CHOOSE, "nothing to pair")
		Services.session.leave()
		Services.session.scene_flow = null


func test_after_playing_offline_the_player_can_pair_again() -> void:
	_note_taking_flow()
	_press(PairingPanel.OFFLINE_MONSTER)

	_press("Host a game")

	assert_false(Services.session.is_offline())
	assert_eq(_network.get_connection_state(), NetworkService.ConnectionState.CONNECTING)
	assert_eq(_panel.get_step(), PairingPanel.Step.HOST_CODE)
	Services.session.leave()
	Services.session.scene_flow = null


func test_it_stays_hidden_where_devices_connect_by_address() -> void:
	_network.pairing = false
	var panel: PairingPanel = PairingPanel.new()
	panel.browser = FakeBrowser.new()

	add_child_autofree(panel)

	assert_false(panel.visible)


func test_a_qr_code_is_drawn_one_pixel_per_module_with_a_quiet_zone() -> void:
	var image: Image = PairingPanel.qr_image(["10", "01"])
	var quiet: int = PairingPanel.QR_QUIET_ZONE

	assert_eq(image.get_size(), Vector2i(2 + 2 * quiet, 2 + 2 * quiet))
	assert_eq(image.get_pixel(quiet, quiet), Color.BLACK)
	assert_eq(image.get_pixel(quiet + 1, quiet), Color.WHITE)
	assert_eq(image.get_pixel(quiet + 1, quiet + 1), Color.BLACK)
	assert_eq(image.get_pixel(0, 0), Color.WHITE, "the quiet zone")
	assert_null(PairingPanel.qr_image([]))


# --- Helpers ---------------------------------------------------------------------


func _buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for node: Node in _panel.find_children("*", "Button", true, false):
		if not node.is_queued_for_deletion():
			buttons.append(node)
	return buttons


func _button_texts() -> Array[String]:
	var texts: Array[String] = []
	for button: Button in _buttons():
		texts.append(button.text)
	return texts


func _press(text: String) -> void:
	for button: Button in _buttons():
		if button.text == text:
			button.pressed.emit()
			return
	fail_test("no button '%s' in %s" % [text, _button_texts()])


## Lets the session change screens through a flow that only takes notes.
func _note_taking_flow() -> SceneFlowController:
	var flow: SceneFlowController = add_child_autofree(SceneFlowController.new())
	flow.scene_changer = func(_path: String) -> Error: return OK
	flow.go_to(SceneFlowController.Screen.LOBBY)
	Services.session.scene_flow = flow
	return flow


func _labels() -> Array[String]:
	var texts: Array[String] = []
	for node: Node in _panel.find_children("*", "Label", true, false):
		texts.append((node as Label).text)
	return texts


func _qr() -> TextureRect:
	return _panel.find_children("*", "TextureRect", true, false)[0]
