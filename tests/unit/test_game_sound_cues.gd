extends TestCase
## The sounds of the game's flow: connecting, leaving, getting ready, the
## countdown, the start and the outcome of a round, the end of the match (#23).


## A session whose answers the test sets.
class FakeSession:
	extends GameSession

	var remote: bool = true
	var role: GameEnums.Role = GameEnums.Role.SHEEPHERDER

	func has_remote_player() -> bool:
		return remote

	func get_local_role() -> GameEnums.Role:
		return role


## A match flow whose answers the test sets.
class FakeFlow:
	extends MatchFlow

	var phase: MatchFlow.Phase = MatchFlow.Phase.IDLE
	var time_left: float = 0.0
	var ready_players: Array[MatchScore.Player] = []

	func get_phase() -> MatchFlow.Phase:
		return phase

	func get_phase_time_left() -> float:
		return time_left

	func is_ready(player: MatchScore.Player) -> bool:
		return ready_players.has(player)


var _audio: StubAudioService
var _original_audio: Node
var _session: FakeSession
var _flow: FakeFlow
var _cues: GameSoundCues


func before_each() -> void:
	_audio = StubAudioService.new(Services.config)
	_original_audio = Services.replace(AudioService, _audio)
	_session = autofree(FakeSession.new())
	_flow = autofree(FakeFlow.new())
	_cues = add_child_autofree(GameSoundCues.new())
	_cues.set_process(false)
	_cues.setup(_session, _flow)


func after_each() -> void:
	Services.replace(AudioService, _original_audio)
	_audio.free()


func test_connecting_to_the_other_device_sounds_but_playing_alone_does_not() -> void:
	_session.remote = false
	_session.session_started.emit()
	assert_eq(_audio.get_cues(), [] as Array[StringName], "offline")

	_session.remote = true
	_session.session_started.emit()

	assert_eq(_audio.get_cues(), [AudioEvents.PAIRED] as Array[StringName])


func test_only_the_other_player_leaving_sounds() -> void:
	_session.session_ended.emit(NetworkService.DisconnectReason.LOCAL_CLOSE, "")
	_session.session_ended.emit(NetworkService.DisconnectReason.REMOTE_CLOSE, "left")

	assert_eq(_audio.get_cues(), [AudioEvents.PLAYER_LEFT] as Array[StringName])


func test_the_countdown_ticks_every_second_and_the_round_starts() -> void:
	_flow.phase = MatchFlow.Phase.COUNTDOWN
	_flow.phase_changed.emit(MatchFlow.Phase.COUNTDOWN)

	for time_left: float in [3.0, 2.6, 2.0, 1.4, 0.5]:
		_flow.time_left = time_left
		_cues._process(0.0)
	_flow.phase = MatchFlow.Phase.ACTIVE
	_flow.phase_changed.emit(MatchFlow.Phase.ACTIVE)
	_cues._process(0.0)

	var expected: Array[StringName] = [
		AudioEvents.COUNTDOWN_TICK,
		AudioEvents.COUNTDOWN_TICK,
		AudioEvents.COUNTDOWN_TICK,
		AudioEvents.ROUND_START,
	]
	assert_eq(_audio.get_cues(), expected)


func test_each_player_hears_the_round_from_their_side() -> void:
	var herder_won: RoundResult = RoundResult.new()
	herder_won.outcome = GameEnums.RoundOutcome.SHEEPHERDER_WIN
	var draw: RoundResult = RoundResult.new()
	draw.outcome = GameEnums.RoundOutcome.DRAW

	_session.role = GameEnums.Role.SHEEPHERDER
	_flow.round_resolved.emit(herder_won)
	_session.role = GameEnums.Role.MONSTER
	_flow.round_resolved.emit(herder_won)
	_flow.round_resolved.emit(draw)

	var expected: Array[StringName] = [
		AudioEvents.ROUND_WIN, AudioEvents.ROUND_LOSE, AudioEvents.ROUND_DRAW
	]
	assert_eq(_audio.get_cues(), expected)


func test_the_end_of_the_match_sounds() -> void:
	_flow.match_finished.emit(MatchScore.Outcome.HOST_WIN)

	assert_eq(_audio.get_cues(), [AudioEvents.MATCH_END] as Array[StringName])


func test_getting_ready_sounds_but_not_getting_unready() -> void:
	for ready: Array in [[0], [0, 1], [0], []]:
		_flow.ready_players.assign(ready)
		_flow.ready_changed.emit()

	var expected: Array[StringName] = [AudioEvents.READY, AudioEvents.READY]
	assert_eq(_audio.get_cues(), expected)
