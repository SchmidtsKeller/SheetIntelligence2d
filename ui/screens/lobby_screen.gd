extends Control
## The lobby (GDD §2.1, §8.1, #20): where a match begins.
##
## Without a session it offers what this build can do: on the Web the
## [PairingPanel] above pairs two phones (or starts a match against the
## computer); on a desktop the match against the computer is here, and two
## instances pair with [code]--host[/code] and [code]--join[/code].
##
## In a session it shows both players, the role this player plays in the
## first round, the [PerkPicker] for that role and the Ready button. When both
## are ready, the [MatchFlow] starts the match. The screen holds no rules: it
## shows the session's and the flow's state and passes the player's choices on.

const OFFLINE_HERDER: String = "Sheepherder vs. computer"
const OFFLINE_MONSTER: String = "Monster vs. computer"
const READY: String = "Ready"
const NOT_READY: String = "Not ready yet"
const LEAVE: String = "Leave"

var _session: GameSession
var _flow: MatchFlow
var _status: Label
var _offline_box: VBoxContainer
var _match_box: VBoxContainer
var _players: Label
var _role: Label
var _picker: PerkPicker
var _ready_button: Button
var _other_ready: Label


func _ready() -> void:
	_session = Services.session
	_flow = Services.match_flow
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


## Says that this player is ready, or not anymore.
func set_ready(ready: bool) -> bool:
	return _flow.set_ready(ready)


func _refresh() -> void:
	var in_session: bool = _session.is_active()
	_offline_box.visible = not in_session and not _session.requires_pairing_codes()
	_match_box.visible = in_session
	_picker.visible = in_session
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
	_role.text = "In the first round you play the %s" % GameEnums.role_name(
		_session.get_local_role()
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
	var lines: PackedStringArray = []
	if not _session.last_end_message.is_empty():
		lines.append("The last session ended: %s" % _session.last_end_message)
	if not _session.requires_pairing_codes():
		lines.append(
			"Play against the computer, or start two instances with -- --host and -- --join."
		)
	return "\n".join(lines)


func _on_session_ended(_reason: NetworkService.DisconnectReason, _message: String) -> void:
	_refresh()


func _on_ready_toggled(on: bool) -> void:
	set_ready(on)


# --- Layout ----------------------------------------------------------------------


func _build() -> void:
	var columns: Array[VBoxContainer] = TwoColumns.build(self)
	var layout: VBoxContainer = columns[0]

	var title: Label = _add_label(layout, "Title", 40)
	title.text = "Hide in Sheep Clothing"
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	_status = _add_label(layout, "Status", 18)

	_offline_box = VBoxContainer.new()
	_offline_box.name = "Offline"
	_offline_box.add_theme_constant_override(&"separation", 10)
	layout.add_child(_offline_box)
	_add_button(_offline_box, OFFLINE_HERDER, play_offline.bind(GameEnums.Role.SHEEPHERDER))
	_add_button(_offline_box, OFFLINE_MONSTER, play_offline.bind(GameEnums.Role.MONSTER))

	_match_box = VBoxContainer.new()
	_match_box.name = "Match"
	_match_box.add_theme_constant_override(&"separation", 12)
	layout.add_child(_match_box)
	_players = _add_label(_match_box, "Players", 20)
	_role = _add_label(_match_box, "Role", 26)
	_picker = PerkPicker.new()
	columns[1].add_child(_picker)
	_ready_button = _add_button(_match_box, READY, Callable())
	_ready_button.name = "Ready"
	_ready_button.toggle_mode = true
	_ready_button.toggled.connect(_on_ready_toggled)
	_other_ready = _add_label(_match_box, "OtherReady", 16)
	var leave: Button = _add_button(_match_box, LEAVE, _session.leave)
	leave.name = "Leave"


func _add_label(parent: Control, label_name: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.name = label_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 460.0
	label.add_theme_font_size_override(&"font_size", font_size)
	parent.add_child(label)
	return label


func _add_button(parent: Control, text: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(320.0, 56.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if action.is_valid():
		button.pressed.connect(action)
	parent.add_child(button)
	return button
