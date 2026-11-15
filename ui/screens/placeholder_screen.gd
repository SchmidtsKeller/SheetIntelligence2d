extends Control
## A placeholder for a screen of the scene flow.
##
## Shows which screen this is, the state of the session, and one button per
## screen the flow allows next, so the whole flow can be walked through before
## the real screens exist. While a session is running, the host's buttons take
## both devices along. The tasks that build the real lobby, round and results
## replace these scenes.

## Heading shown on the screen.
@export var title: String = "Screen"
## One line saying what will be here.
@export_multiline var description: String = ""

var _session_label: Label
var _buttons: Array[Button] = []


func _ready() -> void:
	GameTheme.apply(self)
	ScreenBackdrop.fill(self)
	var layout: VBoxContainer = VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	layout.grow_horizontal = Control.GROW_DIRECTION_BOTH
	layout.grow_vertical = Control.GROW_DIRECTION_BOTH
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override(&"separation", 16)
	add_child(layout)

	layout.add_child(GameLabel.create(GameTheme.TITLE, title))

	if not description.is_empty():
		layout.add_child(GameLabel.create(GameTheme.BODY, description))

	_session_label = GameLabel.create(GameTheme.BODY)
	layout.add_child(_session_label)

	for screen: SceneFlowController.Screen in SceneFlow.get_next_screens():
		var label: String = "Go to %s" % SceneFlowController.screen_name(screen)
		var button: GameButton = GameButton.create(label, _go_to.bind(screen))
		layout.add_child(button)
		_buttons.append(button)

	var session: GameSession = Services.session
	session.session_started.connect(_refresh)
	session.session_ended.connect(_refresh.unbind(2))
	session.roles_changed.connect(_refresh)
	_refresh()


## With a session, only the host changes the screen, and for both devices.
func _go_to(screen: SceneFlowController.Screen) -> void:
	if Services.session.is_active():
		Services.session.request_screen(screen)
	else:
		SceneFlow.go_to(screen)


func _refresh() -> void:
	var session: GameSession = Services.session
	_session_label.text = _describe(session)
	var may_navigate: bool = not session.is_active() or session.is_host()
	for button: Button in _buttons:
		button.disabled = not may_navigate
		button.tooltip_text = "" if may_navigate else "The host changes the screen."


static func _describe(session: GameSession) -> String:
	if session.is_active():
		var who: String = "Host" if session.is_host() else "Guest"
		var link: String = "connected" if session.has_remote_player() else "offline"
		return (
			"%s (%s), playing the %s." % [who, link, GameEnums.role_name(session.get_local_role())]
		)
	if session.get_connection_state() == NetworkService.ConnectionState.CONNECTING:
		return "Waiting for the other player …"
	if not session.last_end_message.is_empty():
		return "Session ended: %s" % session.last_end_message
	return "No session."
