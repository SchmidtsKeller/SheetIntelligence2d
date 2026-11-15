class_name GameSoundCues
extends Node
## The sounds of the game's flow (#23), not placed in the world: the two
## devices connecting, the other player leaving, a player getting ready, the
## countdown, the start of a round, its outcome from this player's side and
## the end of the match.
##
## Listens to the session and the match flow for the whole run, whichever
## screen is shown; the composition root creates it.

var _session: GameSession
var _flow: MatchFlow
var _ready_players: int = 0
var _last_tick: int = 0


func setup(session: GameSession, flow: MatchFlow) -> void:
	_session = session
	_flow = flow
	session.session_started.connect(_on_session_started)
	session.session_ended.connect(_on_session_ended)
	flow.phase_changed.connect(_on_phase_changed)
	flow.round_resolved.connect(_on_round_resolved)
	flow.match_finished.connect(_on_match_finished)
	flow.ready_changed.connect(_on_ready_changed)


## One tick for every second the countdown has left.
func _process(_delta: float) -> void:
	if _flow == null or _flow.get_phase() != MatchFlow.Phase.COUNTDOWN:
		return
	var second: int = ceili(_flow.get_phase_time_left())
	if second > 0 and second != _last_tick:
		_last_tick = second
		Services.audio.play_ui(AudioEvents.COUNTDOWN_TICK)


func _on_session_started() -> void:
	if _session.has_remote_player():
		Services.audio.play_ui(AudioEvents.PAIRED)


func _on_session_ended(reason: NetworkService.DisconnectReason, _message: String) -> void:
	if reason == NetworkService.DisconnectReason.REMOTE_CLOSE:
		Services.audio.play_ui(AudioEvents.PLAYER_LEFT)


func _on_phase_changed(phase: MatchFlow.Phase) -> void:
	match phase:
		MatchFlow.Phase.COUNTDOWN:
			_last_tick = 0
		MatchFlow.Phase.ACTIVE:
			Services.audio.play_ui(AudioEvents.ROUND_START)


## From this player's side: the roles of the round are still those it was
## played in (they swap with the results).
func _on_round_resolved(result: RoundResult) -> void:
	var winner: GameEnums.Role = result.get_winner_role()
	if winner == GameEnums.Role.NONE:
		Services.audio.play_ui(AudioEvents.ROUND_DRAW)
	elif winner == _session.get_local_role():
		Services.audio.play_ui(AudioEvents.ROUND_WIN)
	else:
		Services.audio.play_ui(AudioEvents.ROUND_LOSE)


func _on_match_finished(_outcome: MatchScore.Outcome) -> void:
	Services.audio.play_ui(AudioEvents.MATCH_END)


func _on_ready_changed() -> void:
	var count: int = 0
	for player: MatchScore.Player in [MatchScore.Player.HOST, MatchScore.Player.GUEST]:
		count += int(_flow.is_ready(player))
	if count > _ready_players:
		Services.audio.play_ui(AudioEvents.READY)
	_ready_players = count
