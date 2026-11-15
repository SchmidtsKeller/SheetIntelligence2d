extends Control
## The results screen: how the last round ended, what both players scored in
## it and how the match stands; after the last round, who won the match.
##
## Plain text and three buttons, so the whole match can be played before the
## scoreboard exists. The host moves both devices on: to the next round, into
## a new match once this one is over, or back to the lobby.

var _session: GameSession
var _flow: MatchFlow
var _round_label: Label
var _headline_label: Label
var _details_label: Label
var _match_label: Label
var _hint_label: Label
var _next_button: Button
var _rematch_button: Button
var _lobby_button: Button


func _ready() -> void:
	_session = Services.session
	_flow = Services.match_flow
	_build_layout()
	_flow.phase_changed.connect(_on_phase_changed)
	_session.session_ended.connect(_on_session_ended)
	_refresh()


func _exit_tree() -> void:
	_flow.phase_changed.disconnect(_on_phase_changed)
	_session.session_ended.disconnect(_on_session_ended)


## Everything the screen says, line by line.
func get_text() -> String:
	return "\n".join(
		[_round_label.text, _headline_label.text, _details_label.text, _match_label.text]
	)


func _refresh() -> void:
	var score: MatchScore = _flow.get_score()
	var result: RoundResult = _flow.get_last_result()
	var is_host: bool = not _session.is_active() or _session.is_host()
	_next_button.visible = is_host and result != null and not score.is_over()
	_rematch_button.visible = is_host and result != null and score.is_over()
	_lobby_button.visible = is_host
	_hint_label.visible = not is_host
	if result == null:
		_round_label.text = ""
		_headline_label.text = "No round was played"
		_details_label.text = ""
		_match_label.text = ""
		return
	var you: MatchScore.Player = _flow.get_local_player()
	_round_label.text = "Round %d of %d" % [score.get_rounds_played(), score.get_rounds_total()]
	_headline_label.text = "%s\n%s" % [result.get_headline(), result.get_reason_text()]
	var details: PackedStringArray = [
		describe_sheepherder(result, _who_played(score, GameEnums.Role.SHEEPHERDER, you)),
		describe_monster(result, _who_played(score, GameEnums.Role.MONSTER, you)),
		"",
		describe_standing(score, you),
	]
	_details_label.text = "\n".join(details)
	_match_label.text = describe_match(score, you)


## The Sheepherder's points in [param result] and where they come from.
static func describe_sheepherder(result: RoundResult, who: String) -> String:
	return (
		"Sheepherder (%s): %d points. %d sheep survived (%+d), %d shot (%+d)."
		% [
			who,
			result.get_sheepherder_points(),
			result.surviving_sheep,
			result.herder_surviving_points,
			result.shot_sheep,
			result.herder_shot_points,
		]
	)


## The Monster's points in [param result] and where they come from.
static func describe_monster(result: RoundResult, who: String) -> String:
	return (
		"Monster (%s): %d points. %d sheep eaten alive (%+d), %d shot sheep eaten (+0)."
		% [
			who,
			result.get_monster_points(),
			result.eaten_sheep,
			result.monster_eaten_points,
			result.eaten_bodies,
		]
	)


## The round wins and the points of all rounds, seen by [param you].
static func describe_standing(score: MatchScore, you: MatchScore.Player) -> String:
	var other: MatchScore.Player = MatchScore.other_player(you)
	return (
		"Round wins: you %d, opponent %d, draws %d.\nPoints in all rounds: you %d, opponent %d."
		% [
			score.get_round_wins(you),
			score.get_round_wins(other),
			score.get_draws(),
			score.get_total_points(you),
			score.get_total_points(other),
		]
	)


## Who won the match, seen by [param you]; empty while rounds are left.
static func describe_match(score: MatchScore, you: MatchScore.Player) -> String:
	var other: MatchScore.Player = MatchScore.other_player(you)
	var wins: String = "%d to %d" % [score.get_round_wins(you), score.get_round_wins(other)]
	var outcome: MatchScore.Outcome = score.get_outcome()
	if outcome == MatchScore.Outcome.UNDECIDED:
		return ""
	if outcome == MatchScore.Outcome.DRAW:
		return "The match is a draw, %s." % wins
	var host_won: bool = outcome == MatchScore.Outcome.HOST_WIN
	var you_won: bool = host_won == (you == MatchScore.Player.HOST)
	return ("You win the match, %s." if you_won else "You lose the match, %s.") % wins


static func _who_played(score: MatchScore, role: GameEnums.Role, you: MatchScore.Player) -> String:
	var last: int = score.get_rounds_played() - 1
	return "you" if score.get_role_in_round(last, you) == role else "opponent"


func _on_phase_changed(_phase: MatchFlow.Phase) -> void:
	_refresh()


func _on_session_ended(_reason: NetworkService.DisconnectReason, _message: String) -> void:
	_refresh()


func _next_round() -> void:
	_flow.request_next_round()


func _rematch() -> void:
	_flow.request_rematch()


func _back_to_lobby() -> void:
	if _session.is_active():
		_flow.request_lobby()
	else:
		SceneFlow.go_to(SceneFlowController.Screen.LOBBY)


func _build_layout() -> void:
	var layout: VBoxContainer = VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	layout.grow_horizontal = Control.GROW_DIRECTION_BOTH
	layout.grow_vertical = Control.GROW_DIRECTION_BOTH
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override(&"separation", 16)
	add_child(layout)
	_round_label = _add_label(layout, 20)
	_headline_label = _add_label(layout, 36)
	_details_label = _add_label(layout, 16)
	_match_label = _add_label(layout, 28)
	_next_button = _add_button(layout, "Next round", _next_round)
	_rematch_button = _add_button(layout, "Rematch", _rematch)
	_lobby_button = _add_button(layout, "Back to lobby", _back_to_lobby)
	_hint_label = _add_label(layout, 16)
	_hint_label.text = "The host continues."


func _add_label(layout: VBoxContainer, font_size: int) -> Label:
	var label: Label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", font_size)
	layout.add_child(label)
	return label


func _add_button(layout: VBoxContainer, text: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(240.0, 56.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(action)
	layout.add_child(button)
	return button
