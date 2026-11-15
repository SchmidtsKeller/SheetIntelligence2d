class_name PairingPanel
extends Control
## Pairs two devices with codes (GDD §8.1, §9.4) until the lobby (#20) has
## its own pairing: host or join, show this device's code as a QR code (or
## copy it), read the other device's code with the camera or as text, then
## connect. Once connected, a line shows the round trip of a ping through the
## multiplayer API.
##
## Without a second device, the player can start a match against the computer
## in either role instead (see [method GameSession.play_offline]).
##
## Shown only where the transport needs pairing codes: the Web build.
##
## The camera is on from Host or Join until this device's code is made: then
## browsers put the device's real addresses into the code instead of hidden
## names that the other device often cannot resolve (docs/pairing.md).

enum Step {
	CHOOSE,
	CAMERA,
	HOST_CODE,
	JOIN_READ,
	JOIN_CODE,
	CONNECTING,
	CONNECTED,
	FAILED,
}

const OFFLINE_HERDER: String = "Sheepherder vs. computer"
const OFFLINE_MONSTER: String = "Monster vs. computer"

const EVENT_PING: StringName = &"pairing.ping"
const EVENT_PONG: StringName = &"pairing.pong"
const PING_INTERVAL: float = 1.0
## Light border around the QR code, in modules, as scanners expect.
const QR_QUIET_ZONE: int = 4
## Share of the screen the QR code takes: along the long side beside the
## texts, and along the short side across them.
const QR_LONG_SHARE: float = 0.45
const QR_SHORT_SHARE: float = 0.8
const CAMERA_HINT: String = "Allowing the camera on both devices can help them find each other."

## The browser side. Tests set a fake before the panel enters the tree.
var browser: PairingBrowser

var _step: Step = Step.CHOOSE
var _code: String = ""
var _failure: String = ""
## Whether the player chose to host (or to join) and is asked for the camera.
var _hosting_next: bool = false
var _camera_allowed: bool = false
var _round_trip_ms: int = -1
var _ping_left: float = 0.0
var _background: ScreenBackdrop
var _layout: CenterContainer
var _columns: BoxContainer
var _title: Label
var _info: Label
var _problem: Label
var _qr: TextureRect
var _buttons: VBoxContainer
var _first_button: Button
var _status_bar: Label


func _ready() -> void:
	var session: GameSession = Services.session
	if not session.requires_pairing_codes():
		hide()
		set_process(false)
		return
	if browser == null:
		browser = PairingBrowser.new()
	_build()
	# Above what the screen adds in its own _ready, which runs after this one.
	move_to_front.call_deferred()
	session.pairing_code_ready.connect(_on_code_ready)
	session.session_started.connect(_on_session_started)
	session.session_ended.connect(_on_session_ended)
	browser.code_entered.connect(_on_code_entered)
	browser.failed.connect(_show_problem)
	browser.copy_finished.connect(_on_copy_finished)
	browser.camera_answered.connect(_on_camera_answered)
	var messenger: NetMessenger = session.messenger
	messenger.register_event(EVENT_PING, NetMessenger.SenderRule.ANYONE)
	messenger.register_event(EVENT_PONG, NetMessenger.SenderRule.ANYONE)
	messenger.subscribe(EVENT_PING, _on_ping)
	messenger.subscribe(EVENT_PONG, _on_pong)
	var playing: bool = session.has_remote_player() or session.is_offline()
	_go_to(Step.CONNECTED if playing else Step.CHOOSE)


func _exit_tree() -> void:
	if _layout == null:
		return
	var session: GameSession = Services.session
	session.pairing_code_ready.disconnect(_on_code_ready)
	session.session_started.disconnect(_on_session_started)
	session.session_ended.disconnect(_on_session_ended)
	session.messenger.unsubscribe(EVENT_PING, _on_ping)
	session.messenger.unsubscribe(EVENT_PONG, _on_pong)
	browser.close()


func _process(delta: float) -> void:
	if _step != Step.CONNECTED or not Services.session.has_remote_player():
		return
	_ping_left -= delta
	if _ping_left <= 0.0:
		_ping_left = PING_INTERVAL
		Services.session.messenger.send_to_remote(EVENT_PING, [Time.get_ticks_msec()])


## Which step of pairing is shown.
func get_step() -> Step:
	return _step


## The round trip of the last ping in milliseconds; -1 before the first.
func get_round_trip_ms() -> int:
	return _round_trip_ms


# --- Steps -----------------------------------------------------------------------


func _go_to(step: Step) -> void:
	_step = step
	_problem.text = ""
	if step == Step.CHOOSE or step == Step.JOIN_READ:
		_code = ""
	var connected: bool = step == Step.CONNECTED
	_background.visible = not connected
	_layout.visible = not connected
	_status_bar.visible = connected
	# Once connected, the lobby below takes the clicks.
	mouse_filter = Control.MOUSE_FILTER_IGNORE if connected else Control.MOUSE_FILTER_STOP
	_ping_left = 0.0
	for button: Node in _buttons.get_children():
		button.queue_free()
	_first_button = null
	_qr.visible = false
	match step:
		Step.CHOOSE:
			_show(
				"Play together",
				(
					"Both devices must be in the same Wi-Fi. One hosts, the other joins.\n"
					+ "No second device? Play against the computer."
				)
			)
			_add_button("Host a game", _ask_for_camera.bind(true))
			_add_button("Join a game", _ask_for_camera.bind(false))
			_add_button(OFFLINE_HERDER, play_offline.bind(GameEnums.Role.SHEEPHERDER))
			_add_button(OFFLINE_MONSTER, play_offline.bind(GameEnums.Role.MONSTER))
		Step.CAMERA:
			_show(
				"Camera",
				(
					"Allow the camera, so the two devices can find each other directly."
					+ " It also reads the other device's code."
				)
			)
			_add_button("Cancel", _cancel)
		Step.HOST_CODE:
			_show_code(
				"Host",
				(
					"1. Let the other player scan this code, or send it with Copy code.\n"
					+ "2. Then read the answer their device shows."
				)
			)
			if not _code.is_empty():
				_add_button("Copy code", browser.copy.bind(_code))
				_add_button("Scan answer", browser.scan)
				_add_button("Enter answer", browser.enter.bind("Paste the other player's answer."))
			_add_button("Cancel", _cancel)
		Step.JOIN_READ:
			_show("Join", "Read the code the host's device shows.")
			_add_button("Scan code", browser.scan)
			_add_button("Enter code", browser.enter.bind("Paste the host's code."))
			_add_button("Cancel", _cancel)
		Step.JOIN_CODE:
			_show_code(
				"Join",
				(
					"Let the host scan this answer, or send it with Copy answer.\n"
					+ "The game connects as soon as the host has read it."
				)
			)
			if not _code.is_empty():
				_add_button("Copy answer", browser.copy.bind(_code))
			_add_button("Cancel", _cancel)
		Step.CONNECTING:
			_show("Connecting …", "")
			_add_button("Cancel", _cancel)
		Step.CONNECTED:
			_update_status_bar()
		Step.FAILED:
			_show("Not connected", _failure)
			_add_button("Try again", _go_to.bind(Step.CHOOSE))
	# Keyboard and gamepad players start on the first choice.
	if _first_button != null:
		_first_button.grab_focus.call_deferred()


func _ask_for_camera(hosting: bool) -> void:
	_hosting_next = hosting
	_go_to(Step.CAMERA)
	browser.request_camera()


func _on_camera_answered(granted: bool) -> void:
	if _step != Step.CAMERA:
		return
	_camera_allowed = granted
	if _hosting_next:
		_host()
	else:
		_join()


func _host() -> void:
	var error: Error = Services.session.host()
	if error != OK:
		_fail("Could not start hosting (%s)." % error_string(error))
		return
	_go_to(Step.HOST_CODE)


## Starts a match on this device alone, against the computer: this player is
## [param role] in the first round, and the roles swap after every round.
func play_offline(role: GameEnums.Role) -> void:
	browser.close()
	var session: GameSession = Services.session
	# The lobby below takes over: the perk for the first round, then Ready.
	var error: Error = session.play_offline(role)
	if error != OK:
		_fail("Could not start the match (%s)." % error_string(error))


func _join() -> void:
	var error: Error = Services.session.join()
	if error != OK:
		_fail("Could not start joining (%s)." % error_string(error))
		return
	_go_to(Step.JOIN_READ)


func _cancel() -> void:
	browser.close()
	if Services.session.get_connection_state() != NetworkService.ConnectionState.DISCONNECTED:
		Services.session.leave()
	_go_to(Step.CHOOSE)


func _fail(message: String) -> void:
	browser.release_camera()
	_failure = message if _camera_allowed else message + "\n" + CAMERA_HINT
	_go_to(Step.FAILED)


# --- What happened ---------------------------------------------------------------


func _on_code_ready(code: String) -> void:
	browser.release_camera()
	_code = code
	_go_to(Step.HOST_CODE if _step == Step.HOST_CODE else Step.JOIN_CODE)


func _on_code_entered(code: String) -> void:
	var session: GameSession = Services.session
	var error: Error = session.submit_pairing_code(code)
	if error == ERR_INVALID_DATA:
		_show_problem(session.get_pairing_problem())
		return
	if error != OK:
		_show_problem("This code cannot be used now (%s)." % error_string(error))
		return
	# The host connects now; the guest first shows its answer.
	_go_to(Step.CONNECTING if _step == Step.HOST_CODE else Step.JOIN_CODE)


func _on_copy_finished(copied: bool) -> void:
	if copied:
		_show_problem("Copied. Send it to the other player, e.g. with a messenger.")


func _on_session_started() -> void:
	browser.close()
	_round_trip_ms = -1
	_go_to(Step.CONNECTED)


func _on_session_ended(reason: NetworkService.DisconnectReason, message: String) -> void:
	browser.close()
	if reason == NetworkService.DisconnectReason.LOCAL_CLOSE:
		_go_to(Step.CHOOSE)
	else:
		_fail(message)


func _on_ping(payload: Array, _sender_id: int) -> void:
	Services.session.messenger.send_to_remote(EVENT_PONG, payload)


func _on_pong(payload: Array, _sender_id: int) -> void:
	_round_trip_ms = Time.get_ticks_msec() - int(payload[0])
	_update_status_bar()


# --- Presentation ----------------------------------------------------------------


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	GameTheme.apply(self)
	_background = ScreenBackdrop.fill(self)
	_layout = CenterContainer.new()
	_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_layout)
	# The QR code beside the texts on a landscape screen, above them on a phone.
	_columns = BoxContainer.new()
	_columns.alignment = BoxContainer.ALIGNMENT_CENTER
	_columns.add_theme_constant_override(&"separation", 32)
	_layout.add_child(_columns)
	_qr = TextureRect.new()
	_qr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_qr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_qr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_qr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_qr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_columns.add_child(_qr)
	var texts: VBoxContainer = VBoxContainer.new()
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.custom_minimum_size.x = 360.0
	texts.add_theme_constant_override(&"separation", 12)
	_columns.add_child(GamePanel.create("Board", texts))
	_title = _add_label(texts, GameTheme.TITLE)
	_info = _add_label(texts, GameTheme.BODY)
	_buttons = VBoxContainer.new()
	_buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_buttons.add_theme_constant_override(&"separation", 8)
	texts.add_child(_buttons)
	# Below the buttons and with room for three lines, so the buttons do not
	# move under the player's finger when a message appears.
	_problem = _add_label(texts, GameTheme.WARNING)
	_problem.custom_minimum_size.y = 90.0
	_status_bar = _add_label(self, GameTheme.SMALL)
	_status_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_status_bar.offset_top = 8.0
	get_viewport().size_changed.connect(_fit_to_screen)
	_fit_to_screen()


func _show(title: String, info: String) -> void:
	_title.text = title
	_info.text = info


func _show_code(title: String, info: String) -> void:
	if _code.is_empty():
		_show(title, "Preparing the code …")
		return
	_show(title, info)
	var image: Image = qr_image(browser.qr_rows(_code))
	if image == null:
		_show_problem("No QR code here: use Copy, and paste the code on the other device.")
		return
	_qr.texture = ImageTexture.create_from_image(image)
	_qr.visible = true


func _fit_to_screen() -> void:
	var screen: Vector2 = get_viewport_rect().size
	_columns.vertical = screen.y > screen.x
	var side: float = minf(screen.x, screen.y) * QR_SHORT_SHARE
	side = minf(side, maxf(screen.x, screen.y) * QR_LONG_SHARE)
	_qr.custom_minimum_size = Vector2(side, side)


func _show_problem(message: String) -> void:
	_problem.text = message


func _update_status_bar() -> void:
	var session: GameSession = Services.session
	if session.is_offline():
		_status_bar.text = "Playing against the computer"
		return
	var who: String = "host" if session.is_host() else "guest"
	var ping: String = (
		", round trip %d ms" % _round_trip_ms if _round_trip_ms >= 0 else ", measuring …"
	)
	_status_bar.text = "Connected as %s%s" % [who, ping]


func _add_button(text: String, action: Callable) -> void:
	var button: GameButton = GameButton.create(text, action)
	_buttons.add_child(button)
	if _first_button == null:
		_first_button = button


static func _add_label(parent: Control, style: StringName) -> Label:
	var label: GameLabel = GameLabel.create(style).wrapped()
	parent.add_child(label)
	return label


## A black-on-white image of the QR code [param rows], one pixel per module,
## with the quiet zone; [code]null[/code] for no rows.
static func qr_image(rows: PackedStringArray) -> Image:
	if rows.is_empty():
		return null
	var side: int = rows.size() + QR_QUIET_ZONE * 2
	var image: Image = Image.create_empty(side, side, false, Image.FORMAT_L8)
	image.fill(Color.WHITE)
	for y: int in rows.size():
		var row: String = rows[y]
		for x: int in row.length():
			if row[x] == "1":
				image.set_pixel(x + QR_QUIET_ZONE, y + QR_QUIET_ZONE, Color.BLACK)
	return image
