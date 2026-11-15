extends Node2D
## The round screen: the [RoundStage] with the round's world and, on top, the
## little a player has to know before the HUD exists: the round, their role,
## the timer, the countdown and who won.
##
## The [MatchFlow] starts the round once both devices are here. Started
## without a session (F6, or the lobby's buttons to play offline) the screen
## plays the match on one device: this player gets a role, a bot plays the
## other one (see [RoundStage]).
## With [code]--host[/code] or [code]--join[/code] on the command line it
## starts the session itself (docs/networking.md).

## The layer of the status and the banners: above the world and the
## [NightVision] (#90), below the [Hud].
const OVERLAY_LAYER: int = 30

var _session: GameSession
var _flow: MatchFlow
var _status: Label
var _banner: Label
var _hud: Hud

@onready var _stage: RoundStage = $Stage


func _ready() -> void:
	_session = Services.session
	_flow = Services.match_flow
	_build_overlay()
	_hud = Hud.new(_stage)
	add_child(_hud)
	if _session.is_active():
		# Arriving with the session's screen change, the flow starts the round
		# when both devices are ready.
		if not _session.is_changing_screen() and _session.is_host():
			_flow.start_round()
		return
	_session.session_started.connect(_on_session_started)
	var options: LaunchOptions = LaunchOptions.from_command_line()
	if options.wants_session():
		var error: Error = options.start_session(_session)
		if error != OK:
			_banner.text = "Could not start the session: %s" % error_string(error)
	else:
		_session.play_offline()


func _exit_tree() -> void:
	if _session.session_started.is_connected(_on_session_started):
		_session.session_started.disconnect(_on_session_started)


func _process(_delta: float) -> void:
	_status.text = get_status_text()
	_banner.text = get_banner_text()


func get_stage() -> RoundStage:
	return _stage


func get_hud() -> Hud:
	return _hud


## The line at the top: the round and this player's role. The timer is on
## the HUD.
func get_status_text() -> String:
	if not _flow.is_match_running():
		return ""
	return (
		"Round %d of %d  |  You are the %s"
		% [
			_flow.get_round_number(),
			_flow.get_rounds_total(),
			GameEnums.role_name(_session.get_local_role()),
		]
	)


## The words in the middle of the screen: what the round is waiting for, or
## how it ended.
func get_banner_text() -> String:
	match _flow.get_phase():
		MatchFlow.Phase.IDLE:
			return "" if _session.is_active() else "Waiting for the other player …"
		MatchFlow.Phase.SETUP, MatchFlow.Phase.SPAWN:
			return "Get ready"
		MatchFlow.Phase.COUNTDOWN:
			return str(maxi(ceili(_flow.get_phase_time_left()), 1))
		MatchFlow.Phase.RESOLVED, MatchFlow.Phase.RESULTS:
			var result: RoundResult = _flow.get_last_result()
			if result == null:
				return ""
			return "%s\n%s" % [result.get_headline(), result.get_reason_text()]
		_:
			return ""


## [param seconds] as minutes and seconds, rounded up: the timer shows 0:00
## only when the time is over.
static func format_time(seconds: float) -> String:
	return HudReadout.format_time(seconds)


func _on_session_started() -> void:
	if _session.is_host():
		_flow.start_round()


func _build_overlay() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "Overlay"
	layer.layer = OVERLAY_LAYER
	add_child(layer)
	# Top right: the top left is the HUD's.
	_status = GameLabel.create(GameTheme.HUD_TEXT, "", "Status")
	GameTheme.apply(_status)
	_status.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_status.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status.position += Vector2(-12.0, 12.0)
	layer.add_child(_status)
	_banner = GameLabel.create(GameTheme.HUD_TITLE, "", "Banner")
	GameTheme.apply(_banner)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_banner)
