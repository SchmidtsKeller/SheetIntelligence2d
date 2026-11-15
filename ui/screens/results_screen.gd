extends Control
## The scoreboard (GDD §8.2, #20): how the last round ended, what both
## players scored in it and how the match stands; after the last round, who
## won the match and the record of every round.
##
## Between rounds each player sees the role they play next, chooses its perk
## and gets ready; when both are, the [MatchFlow] starts the next round, or a
## rematch once the match is over. The host can also end the match and take
## both back to the lobby. Perks are not shown: the Sheepherder's would tell
## the Monster too much about the rounds to come.

const READY: String = "Ready"
const NOT_READY: String = "Not ready yet"

var _session: GameSession
var _flow: MatchFlow
var _round_label: Label
var _headline_label: Label
var _details_label: Label
var _match_label: Label
var _hint_label: Label
var _next_role_label: Label
var _history_label: Label
var _picker: PerkPicker
var _next_board: GamePanel
var _ready_button: Button
var _lobby_button: Button


func _ready() -> void:
	_session = Services.session
	_flow = Services.match_flow
	_build_layout()
	_flow.phase_changed.connect(_on_phase_changed)
	_flow.ready_changed.connect(_refresh)
	_session.session_ended.connect(_on_session_ended)
	_session.roles_changed.connect(_refresh)
	_refresh()


func _exit_tree() -> void:
	_flow.phase_changed.disconnect(_on_phase_changed)
	_flow.ready_changed.disconnect(_refresh)
	_session.session_ended.disconnect(_on_session_ended)
	_session.roles_changed.disconnect(_refresh)


## Everything the screen says, line by line.
func get_text() -> String:
	var lines: PackedStringArray = [
		_round_label.text,
		_headline_label.text,
		_details_label.text,
		_match_label.text,
		_history_label.text,
		_next_role_label.text,
	]
	return "\n".join(lines)


func get_picker() -> PerkPicker:
	return _picker


## Says that this player is ready for the next round, or not anymore.
func set_ready(ready: bool) -> bool:
	return _flow.set_ready(ready)


func _refresh() -> void:
	var score: MatchScore = _flow.get_score()
	var result: RoundResult = _flow.get_last_result()
	var is_host: bool = not _session.is_active() or _session.is_host()
	_lobby_button.visible = is_host
	_refresh_next(result != null and _session.is_active())
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
	_history_label.text = describe_history(score, you) if score.is_over() else ""


## The next round: the role, the perk for it and who is ready.
func _refresh_next(going_on: bool) -> void:
	_next_role_label.visible = going_on
	_picker.visible = going_on
	_ready_button.visible = going_on
	_hint_label.visible = going_on
	_next_board.visible = going_on
	if not going_on:
		return
	var score: MatchScore = _flow.get_score()
	var role: String = GameEnums.role_name(_session.get_local_role())
	_next_role_label.text = (
		"In the rematch you play the %s" % role
		if score.is_over()
		else "In the next round you play the %s" % role
	)
	var you: MatchScore.Player = _flow.get_local_player()
	var ready: bool = _flow.is_ready(you)
	_ready_button.set_pressed_no_signal(ready)
	_ready_button.text = NOT_READY if ready else READY
	_ready_button.disabled = not _flow.may_get_ready()
	if _session.is_offline():
		_hint_label.text = ""
	elif _flow.is_ready(MatchScore.other_player(you)):
		_hint_label.text = "The other player is ready."
	else:
		_hint_label.text = "The other player is choosing a perk …"
	_picker.refresh()


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


## Every round of the match, seen by [param you]: who played what, who won
## and the points.
static func describe_history(score: MatchScore, you: MatchScore.Player) -> String:
	var lines: PackedStringArray = []
	for index: int in score.get_rounds_played():
		var result: RoundResult = score.get_round(index)
		var your_role: GameEnums.Role = score.get_role_in_round(index, you)
		var winner: int = score.get_round_winner(index)
		var outcome: String = "draw"
		if winner == you:
			outcome = "you won"
		elif winner == MatchScore.other_player(you):
			outcome = "you lost"
		var line: String = (
			"Round %d: you were the %s, %s (%d : %d)"
			% [
				index + 1,
				GameEnums.role_name(your_role),
				outcome,
				result.get_points(your_role),
				result.get_points(GameEnums.opposite_role(your_role)),
			]
		)
		lines.append(line)
	return "\n".join(lines)


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


func _on_ready_toggled(on: bool) -> void:
	set_ready(on)


func _back_to_lobby() -> void:
	if _session.is_active():
		_flow.request_lobby()
	else:
		SceneFlow.go_to(SceneFlowController.Screen.LOBBY)


func _build_layout() -> void:
	# What happened on the left, the next round on the right.
	var columns: Array[VBoxContainer] = TwoColumns.build(self)
	var past: VBoxContainer = columns[0]
	var next: VBoxContainer = columns[1]
	_next_board = TwoColumns.board_of(next)
	_round_label = _add_label(past, GameTheme.BODY)
	_headline_label = _add_label(past, GameTheme.HEADLINE)
	_details_label = _add_label(past, GameTheme.SMALL)
	_match_label = _add_label(past, GameTheme.HEADING)
	_history_label = _add_label(past, GameTheme.SMALL)
	_lobby_button = _add_button(past, "Back to lobby", _back_to_lobby)
	_next_role_label = _add_label(next, GameTheme.HEADING)
	_ready_button = _add_button(next, READY, Callable())
	_ready_button.name = "Ready"
	_ready_button.toggle_mode = true
	_ready_button.toggled.connect(_on_ready_toggled)
	_hint_label = _add_label(next, GameTheme.SMALL)
	_picker = PerkPicker.new()
	next.add_child(_picker)


func _add_label(layout: VBoxContainer, style: StringName) -> Label:
	var label: GameLabel = GameLabel.create(style)
	layout.add_child(label)
	return label


func _add_button(layout: VBoxContainer, text: String, action: Callable) -> Button:
	var button: GameButton = GameButton.create(text, action)
	layout.add_child(button)
	return button
