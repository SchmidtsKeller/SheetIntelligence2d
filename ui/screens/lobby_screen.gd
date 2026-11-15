extends Control
## The lobby (GDD §2.1, §8.1, #20): where a match begins.
##
## Without a session it offers what this build can do: on the Web the
## [PairingPanel] above pairs two phones (or starts a match against the
## computer); on a desktop the lobby hosts or joins a game by address over the
## desktop transport (#99) and starts the match against the computer. Two
## desktop instances still pair by themselves with [code]--host[/code] and
## [code]--join[/code] (see [LaunchOptions]).
##
## In a session it shows both players, the role this player plays in the
## first round, the [PerkPicker] for that role and the Ready button. When both
## are ready, the [MatchFlow] starts the match. The screen holds no rules: it
## shows the session's and the flow's state and passes the player's choices on.

const HOST: String = "Host a game"
const JOIN: String = "Join a game"
const CANCEL: String = "Cancel"
const THIS_COMPUTER: String = "Hosts for this computer only"
const WHOLE_NETWORK: String = "Hosts for the whole network"
const OFFLINE_HERDER: String = "Sheepherder vs. computer"
const OFFLINE_MONSTER: String = "Monster vs. computer"
const READY: String = "Ready"
const NOT_READY: String = "Not ready yet"
const LEAVE: String = "Leave"
const LABEL_WIDTH: float = 460.0

## Port, address and network for Host and Join on a desktop. They start as
## the command line gives them ([code]--port[/code], [code]--join=[/code],
## [code]--lan[/code]); tests set their own.
var connect_options: LaunchOptions

var _session: GameSession
var _flow: MatchFlow
var _status: Label
var _connect_box: VBoxContainer
var _network_button: Button
var _address: LineEdit
var _waiting_box: VBoxContainer
var _offline_box: VBoxContainer
var _match_box: VBoxContainer
var _players: Label
var _role: Label
var _picker: PerkPicker
var _picker_board: GamePanel
var _ready_button: Button
var _other_ready: Label
## Why the last Host or Join did not start.
var _problem: String = ""


func _ready() -> void:
	_session = Services.session
	_flow = Services.match_flow
	if connect_options == null:
		connect_options = LaunchOptions.from_command_line()
	_build()
	_session.session_started.connect(_refresh)
	_session.session_ended.connect(_on_session_ended)
	_session.roles_changed.connect(_refresh)
	_flow.ready_changed.connect(_refresh)
	_refresh()


func _exit_tree() -> void:
	_session.session_started.disconnect(_refresh)
	_session.session_ended.disconnect(_on_session_ended)
	_session.roles_changed.disconnect(_refresh)
	_flow.ready_changed.disconnect(_refresh)


## The line that says how things stand.
func get_status_text() -> String:
	return _status.text


func get_picker() -> PerkPicker:
	return _picker


## Starts a match against the computer, this player in [param role] first.
func play_offline(role: GameEnums.Role) -> Error:
	return _session.play_offline(role)


## Hosts a game on this desktop and waits for the other instance to join.
func host_game() -> Error:
	if ServiceBootstrap.use_address_transport(Services, Services.config) == null:
		return ERR_UNAVAILABLE
	var error: Error = _session.host(connect_options.get_session_options())
	_after_connect_attempt(error, "Could not host a game (%s).")
	return error


## Joins the game hosted at [param address], on this computer or another one.
func join_game(address: String) -> Error:
	if ServiceBootstrap.use_address_transport(Services, Services.config) == null:
		return ERR_UNAVAILABLE
	address = address.strip_edges()
	connect_options.address = address if not address.is_empty() else LaunchOptions.DEFAULT_ADDRESS
	var error: Error = _session.join(connect_options.get_session_options())
	_after_connect_attempt(error, "Could not join the game (%s).")
	return error


## Stops hosting or joining before the other player is there.
func cancel_connecting() -> void:
	_session.leave()


## Says that this player is ready, or not anymore.
func set_ready(ready: bool) -> bool:
	return _flow.set_ready(ready)


func _after_connect_attempt(error: Error, failure: String) -> void:
	_problem = ""
	if error != OK:
		_problem = failure % error_string(error)
	_refresh()


func _is_connecting() -> bool:
	return (
		not _session.is_active()
		and _session.get_connection_state() == NetworkService.ConnectionState.CONNECTING
	)


func _connects_by_address() -> bool:
	return not _session.requires_pairing_codes() and ServiceBootstrap.can_connect_by_address()


func _refresh() -> void:
	var in_session: bool = _session.is_active()
	var connecting: bool = _is_connecting()
	var choosing: bool = not in_session and not connecting
	_connect_box.visible = choosing and _connects_by_address()
	_waiting_box.visible = connecting and not _session.requires_pairing_codes()
	_offline_box.visible = choosing and not _session.requires_pairing_codes()
	_match_box.visible = in_session
	_picker.visible = in_session
	_picker_board.visible = in_session
	_network_button.set_pressed_no_signal(connect_options.lan)
	_network_button.text = WHOLE_NETWORK if connect_options.lan else THIS_COMPUTER
	_status.text = _describe_status()
	if not in_session:
		return
	var you: MatchScore.Player = _flow.get_local_player()
	var other: MatchScore.Player = MatchScore.other_player(you)
	var who: String = "host" if _session.is_host() else "guest"
	var opponent: String = (
		"the computer" if _session.is_offline() else "the other player, connected"
	)
	_players.text = "You (%s) against %s" % [who, opponent]
	_role.text = (
		"In the first round you play the %s" % GameEnums.role_name(_session.get_local_role())
	)
	var ready: bool = _flow.is_ready(you)
	_ready_button.set_pressed_no_signal(ready)
	_ready_button.text = NOT_READY if ready else READY
	_ready_button.disabled = not _flow.may_get_ready()
	if _session.is_offline():
		_other_ready.text = ""
	elif _flow.is_ready(other):
		_other_ready.text = "The other player is ready."
	else:
		_other_ready.text = "The other player is choosing a perk …"
	_picker.refresh()


func _describe_status() -> String:
	if _session.is_active():
		return "The match starts when both are ready."
	if _is_connecting():
		if _session.is_host():
			var reach: String = (
				"other computers can join" if connect_options.lan else "on this computer"
			)
			return (
				"Hosting on port %d (%s). Waiting for the other player …"
				% [connect_options.port, reach]
			)
		return "Joining %s:%d …" % [connect_options.address, connect_options.port]
	var lines: PackedStringArray = []
	if not _problem.is_empty():
		lines.append(_problem)
	if not _session.last_end_message.is_empty():
		lines.append("The last session ended: %s" % _session.last_end_message)
	if _connects_by_address():
		lines.append(
			"Host a game, or join one at the host's address (127.0.0.1 is this computer)."
			+ " No second player? Play against the computer."
		)
	elif not _session.requires_pairing_codes():
		lines.append("Play against the computer.")
	return "\n".join(lines)


func _on_session_ended(_reason: NetworkService.DisconnectReason, _message: String) -> void:
	_refresh()


func _on_ready_toggled(on: bool) -> void:
	set_ready(on)


func _on_network_toggled(on: bool) -> void:
	connect_options.lan = on
	_refresh()


func _on_join_pressed() -> void:
	join_game(_address.text)


func _on_address_submitted(address: String) -> void:
	join_game(address)


# --- Layout ----------------------------------------------------------------------


func _build() -> void:
	var columns: Array[VBoxContainer] = TwoColumns.build(self)
	var layout: VBoxContainer = columns[0]
	_picker_board = TwoColumns.board_of(columns[1])

	var title: GameLabel = GameLabel.create(GameTheme.TITLE, "Hide in Sheep Clothing", "Title")
	GameLabel.mark_as_logo(title)
	layout.add_child(title)
	_status = _add_label(layout, "Status", GameTheme.BODY)

	_connect_box = _add_box(layout, "Connect", 10)
	_add_button(_connect_box, HOST, host_game)
	_network_button = _add_button(_connect_box, THIS_COMPUTER, Callable())
	_network_button.name = "Network"
	_network_button.toggle_mode = true
	_network_button.toggled.connect(_on_network_toggled)
	_address = LineEdit.new()
	_address.name = "Address"
	_address.text = connect_options.address
	_address.placeholder_text = LaunchOptions.DEFAULT_ADDRESS
	_address.custom_minimum_size = GameButton.MENU_SIZE
	_address.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_address.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_address.text_submitted.connect(_on_address_submitted)
	_connect_box.add_child(_address)
	_add_button(_connect_box, JOIN, _on_join_pressed)

	_waiting_box = _add_box(layout, "Waiting", 10)
	_add_button(_waiting_box, CANCEL, cancel_connecting)

	_offline_box = _add_box(layout, "Offline", 10)
	_add_button(_offline_box, OFFLINE_HERDER, play_offline.bind(GameEnums.Role.SHEEPHERDER))
	_add_button(_offline_box, OFFLINE_MONSTER, play_offline.bind(GameEnums.Role.MONSTER))

	_match_box = _add_box(layout, "Match", 12)
	_players = _add_label(_match_box, "Players", GameTheme.BODY)
	_role = _add_label(_match_box, "Role", GameTheme.HEADING)
	_picker = PerkPicker.new()
	columns[1].add_child(_picker)
	_ready_button = _add_button(_match_box, READY, Callable())
	_ready_button.name = "Ready"
	_ready_button.toggle_mode = true
	_ready_button.toggled.connect(_on_ready_toggled)
	_other_ready = _add_label(_match_box, "OtherReady", GameTheme.SMALL)
	var leave: Button = _add_button(_match_box, LEAVE, _session.leave)
	leave.name = "Leave"


func _add_box(parent: Control, box_name: String, separation: int) -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.name = box_name
	box.add_theme_constant_override(&"separation", separation)
	parent.add_child(box)
	return box


func _add_label(parent: Control, label_name: String, style: StringName) -> Label:
	var label: GameLabel = GameLabel.create(style, "", label_name).wrapped(LABEL_WIDTH)
	parent.add_child(label)
	return label


func _add_button(parent: Control, text: String, action: Callable) -> Button:
	var button: GameButton = GameButton.create(text, action)
	parent.add_child(button)
	return button
