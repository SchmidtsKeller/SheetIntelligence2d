extends Node
## Automated check of a whole match with two real instances.
##
## Start one instance with [code]--host[/code] and one with [code]--join[/code]
## (see `tools/test_two_instances.sh match`). Scripted players play a Best of 5
## on the real round and results screens, and every round ends another way:
## [br]1. the Monster eats five sheep and kills the Sheepherder
## [br]2. the Sheepherder shoots the Monster
## [br]3. nobody does anything: the time runs out, 10 to 0 for the Sheepherder
## [br]4. the Monster eats five sheep and waits: the time runs out, 5 to 5, a draw
## [br]5. the Sheepherder fires every bullet into the fence; the Monster, which
## cannot be killed anymore, eats five sheep and kills the Sheepherder
##
## Each instance prints what it observed and exits with code 0 if everything
## held: the roles swap after every round, both devices see the same phases,
## the same round records and the same match result, the guest's timer is
## within 0.1 s of the host's, nobody can act outside an active round, and at
## the end both are back in the lobby without a match.
##
## To keep the check short, both instances play short rounds with a quick
## attack and a quick reload. The network flags [code]--net-latency[/code],
## [code]--net-jitter[/code] and [code]--net-loss[/code] apply, so the same
## check runs on a bad connection.

# Aliases for enum types, so they are named like types.
# gdlint: ignore=constant-name
const Role = GameEnums.Role
# gdlint: ignore=constant-name
const Phase = MatchFlow.Phase
# gdlint: ignore=constant-name
const Outcome = GameEnums.RoundOutcome
# gdlint: ignore=constant-name
const Reason = GameEnums.RoundEndReason

const EVENT_TIMER: StringName = &"matchcheck.timer"
const EVENT_SCORE: StringName = &"matchcheck.score"

const GIVE_UP_AFTER: float = 150.0
const FAR: float = 100000.0
const PRESS_INTERVAL: float = 0.25
## How close the Monster stands to what it eats; less than the melee range.
const EAT_DISTANCE: float = 36.0
const SHEEP_TO_EAT: int = 5
## Where the Monster waits for the Sheepherder's bullet in round 2.
const TARGET_DISTANCE: float = 110.0
const SHOT_RANGE: float = 200.0
const STILL_FOR: float = 0.4
const TIMER_REPORT_INTERVAL: float = 0.5
## How far the two timers may be apart (acceptance criterion of the round rules).
const TIMER_TOLERANCE: float = 0.1
const RESULTS_READ_TIME: float = 0.5

# The shortened match.
const ROUND_DURATION: float = 12.0
const COUNTDOWN_DURATION: float = 1.5
const RESOLVED_DURATION: float = 1.0
const EAT_DURATION: float = 0.3
const EAT_COOLDOWN: float = 0.3
const RELOAD_TIME: float = 0.3

## What every round must come to: [code][the host's role, outcome, reason,
## the Sheepherder's points, the Monster's points][/code].
const EXPECTED_ROUNDS: Array[Array] = [
	[Role.SHEEPHERDER, Outcome.MONSTER_WIN, Reason.SHEEPHERDER_KILLED, 5, 5],
	[Role.MONSTER, Outcome.SHEEPHERDER_WIN, Reason.MONSTER_SHOT, 10, 0],
	[Role.SHEEPHERDER, Outcome.SHEEPHERDER_WIN, Reason.TIMEOUT, 10, 0],
	[Role.MONSTER, Outcome.DRAW, Reason.TIMEOUT, 5, 5],
	[Role.SHEEPHERDER, Outcome.MONSTER_WIN, Reason.SHEEPHERDER_KILLED, 5, 5],
]
const EXPECTED_HOST_WINS: int = 1
const EXPECTED_GUEST_WINS: int = 3
const EXPECTED_DRAWS: int = 1

var _session: GameSession
var _flow: MatchFlow
var _input: StubInputService
var _label: String = "?"
var _hosting: bool = false
var _finished: bool = false
var _total_time: float = 0.0
var _since_press: float = 0.0

# What happened, on both devices.
var _phases_seen: Dictionary[int, bool] = {}
var _input_violations: int = 0
var _refused_presses: int = 0
var _roles_played: Array[GameEnums.Role] = []
var _results: Array[RoundResult] = []
var _match_outcome: int = -1
var _aborted: bool = false
var _back_in_lobby: bool = false

# The players' scripts.
var _placed_in_round: int = 0
var _copy_previous: Vector2
var _copy_still_for: float = 0.0

# The timer: the guest tells when its round ends, the host compares.
var _since_timer_report: float = 0.0
var _timer_reports: int = 0
var _timer_worst_difference: float = 0.0

# The end of the match.
var _results_shown_for: float = 0.0
var _next_requested_in_round: int = 0
var _score_sent: bool = false
var _guest_score: Dictionary = {}
var _lobby_requested: bool = false


func _ready() -> void:
	# Survive the scene changes of the match.
	reparent.call_deferred(get_tree().root)
	Engine.max_fps = 60
	_session = Services.session
	_flow = Services.match_flow
	var options: LaunchOptions = LaunchOptions.from_command_line()
	_hosting = options.mode == LaunchOptions.Mode.HOST
	_label = "host" if _hosting else "guest"
	if not options.wants_session():
		_finish(["start this scene with -- --host or -- --join"])
		return

	var config: GameConfig = Services.config
	config.round_duration = ROUND_DURATION
	config.round_countdown_duration = COUNTDOWN_DURATION
	config.round_resolved_duration = RESOLVED_DURATION
	config.eat_duration = EAT_DURATION
	config.eat_cooldown = EAT_COOLDOWN
	config.firearm_reload_time = RELOAD_TIME

	# The players are scripts: no device steers this instance.
	_input = StubInputService.new()
	_input.name = "ScriptedInput"
	var device_input: Node = Services.replace(InputService, _input)
	if device_input != null:
		device_input.queue_free()

	# The check has to know who plays what in which round.
	_flow.first_host_role = EXPECTED_ROUNDS[0][0]
	_flow.phase_changed.connect(_on_phase_changed)
	_flow.round_resolved.connect(_on_round_resolved)
	_flow.match_finished.connect(_on_match_finished)
	_flow.match_aborted.connect(_on_match_aborted)
	_session.messenger.register_event(EVENT_TIMER, NetMessenger.SenderRule.ANYONE)
	_session.messenger.register_event(EVENT_SCORE, NetMessenger.SenderRule.ANYONE)
	_session.messenger.subscribe(EVENT_TIMER, _on_timer_report)
	_session.messenger.subscribe(EVENT_SCORE, _on_score_report)
	_session.session_started.connect(_on_session_started)
	_session.screen_entered.connect(_on_screen_entered)

	var error: Error = options.start_session(_session)
	if error != OK:
		_finish(["could not start the session: %s" % error_string(error)])


func _process(delta: float) -> void:
	if _finished:
		return
	_total_time += delta
	if _total_time > GIVE_UP_AFTER:
		_finish(_problems() + ["gave up after %d s" % GIVE_UP_AFTER])
		return
	if not _session.is_active():
		return
	_since_press += delta
	match _flow.get_phase():
		Phase.COUNTDOWN:
			_try_to_act_early()
		Phase.ACTIVE:
			_report_timer(delta)
			_play_round(delta)
		Phase.RESULTS:
			_after_the_round(delta)


func _on_session_started() -> void:
	if _hosting:
		_session.request_screen(SceneFlowController.Screen.ROUND)


func _on_screen_entered(screen: SceneFlowController.Screen) -> void:
	if screen != SceneFlowController.Screen.LOBBY or not _lobby_requested_or_guest():
		return
	_back_in_lobby = true
	# The scene is swapped at the end of the frame.
	await get_tree().process_frame
	await get_tree().process_frame
	_finish(_problems())


func _lobby_requested_or_guest() -> bool:
	return _lobby_requested or not _hosting


# --- What both devices see -------------------------------------------------------


func _on_phase_changed(phase: MatchFlow.Phase) -> void:
	_phases_seen[phase] = true
	var may_act: bool = Services.input.is_gameplay_enabled()
	if phase != Phase.IDLE and may_act != (phase == Phase.ACTIVE):
		_input_violations += 1
	if phase == Phase.ACTIVE:
		_roles_played.append(_session.get_local_role())
		_since_timer_report = 0.0
		_copy_still_for = 0.0
	elif phase == Phase.RESULTS:
		_results_shown_for = 0.0


func _on_match_finished(outcome: MatchScore.Outcome) -> void:
	_match_outcome = outcome


func _on_match_aborted() -> void:
	_aborted = true


func _on_round_resolved(result: RoundResult) -> void:
	_results.append(result)
	print(
		(
			"SELFCHECK %s: round %d as the %s: %s %s %d to %d, %.1f s left"
			% [
				_label,
				_flow.get_round_number(),
				GameEnums.role_name(_session.get_local_role()),
				result.get_headline(),
				result.get_reason_text(),
				result.get_sheepherder_points(),
				result.get_monster_points(),
				result.time_left,
			]
		)
	)


# --- The players -----------------------------------------------------------------


## The round's stage, once both characters are on it.
func _stage() -> RoundStage:
	var scene: Node = get_tree().current_scene
	if scene == null or not scene.has_method(&"get_stage"):
		return null
	var stage: RoundStage = scene.call(&"get_stage")
	return stage if stage != null and stage.is_cast_ready() else null


## A player who presses a button in the countdown gets nothing for it.
func _try_to_act_early() -> void:
	if _since_press < PRESS_INTERVAL:
		return
	_since_press = 0.0
	var action: StringName = InputActions.EAT
	if _session.get_local_role() == Role.SHEEPHERDER:
		action = InputActions.SHOOT
	if _input.simulate_press(action):
		_input.simulate_release(action)
		_input_violations += 1
	else:
		_refused_presses += 1


func _play_round(delta: float) -> void:
	var stage: RoundStage = _stage()
	if stage == null:
		return
	var is_monster: bool = _session.get_local_role() == Role.MONSTER
	var body: SheepBody = stage.get_monster().get_body()
	var herder: Sheepherder = stage.get_sheepherder()
	var combat: CombatService = Services.combat
	match _flow.get_round_number():
		1:
			if is_monster and _eat_sheep(body):
				_kill_the_sheepherder(body, herder)
		2:
			if is_monster:
				_stand_next_to(stage, body, herder)
			else:
				_shoot_the_monster(body, herder, delta)
		4:
			if is_monster:
				_eat_sheep(body)
		5:
			if not is_monster:
				_fire_into_the_fence()
			elif _eat_sheep(body) and combat.is_ammo_depleted():
				_kill_the_sheepherder(body, herder)


## The Monster steps next to the nearest sheep and eats it. Returns whether it
## has eaten enough.
func _eat_sheep(body: SheepBody) -> bool:
	var combat: CombatService = Services.combat
	if combat.get_eaten_count() >= SHEEP_TO_EAT:
		return not combat.is_eating()
	if combat.is_eating() or combat.get_eat_cooldown_remaining() > 0.0:
		return false
	if _since_press < PRESS_INTERVAL:
		return false
	var sheep_id: int = Services.swarm.find_nearest_edible_sheep(body.global_position, FAR)
	if sheep_id < 0:
		return false
	var sheep: SheepBody = Services.swarm.get_sheep_body(sheep_id)
	body.global_position = sheep.global_position + Vector2(EAT_DISTANCE, 0.0)
	_press(InputActions.EAT)
	return false


func _kill_the_sheepherder(body: SheepBody, herder: Sheepherder) -> void:
	var combat: CombatService = Services.combat
	if not herder.is_alive() or not combat.can_kill_sheepherder():
		return
	if combat.get_eat_cooldown_remaining() > 0.0 or _since_press < PRESS_INTERVAL:
		return
	body.global_position = herder.global_position + Vector2(EAT_DISTANCE, 0.0)
	_press(InputActions.EAT)


## The Monster walks into the Sheepherder's corner, away from the flock, and
## stands where nothing is in the line of fire.
func _stand_next_to(stage: RoundStage, body: SheepBody, herder: Sheepherder) -> void:
	if _placed_in_round == _flow.get_round_number():
		return
	_placed_in_round = _flow.get_round_number()
	var arena: Arena = stage.get_arena()
	var from: Vector2 = herder.global_position
	for step: int in 8:
		var direction: Vector2 = Vector2.DOWN.rotated(step * TAU / 8.0)
		var clear: bool = true
		for distance: float in [40.0, 75.0, TARGET_DISTANCE]:
			clear = clear and arena.is_free(from + direction * distance, 40.0)
		if clear:
			body.global_position = from + direction * TARGET_DISTANCE
			return
	body.global_position = from + Vector2(0.0, TARGET_DISTANCE)


## The Sheepherder shoots once the Monster has come close and stands still.
func _shoot_the_monster(body: SheepBody, herder: Sheepherder, delta: float) -> void:
	var from: Vector2 = herder.global_position
	var target: Vector2 = body.global_position
	var step: float = target.distance_to(_copy_previous)
	_copy_previous = target
	_copy_still_for = _copy_still_for + delta if step < 0.5 else 0.0
	_input.aim_direction = from.direction_to(target)
	if (
		Services.combat.can_shoot()
		and from.distance_to(target) <= SHOT_RANGE
		and _copy_still_for >= STILL_FOR
		and _since_press >= PRESS_INTERVAL
	):
		_press(InputActions.SHOOT)


## The Sheepherder wastes every bullet on the fence behind them.
func _fire_into_the_fence() -> void:
	_input.aim_direction = Vector2(-1.0, -1.0)
	if Services.combat.can_shoot() and _since_press >= PRESS_INTERVAL:
		_press(InputActions.SHOOT)


func _press(action: StringName) -> void:
	_since_press = 0.0
	_input.simulate_press(action)
	_input.simulate_release(action)


# --- The timer -------------------------------------------------------------------


## Guest: tells the host at which moment, on this computer's clock, its timer
## will reach zero. Both instances run on the same computer, so the host can
## compare that with its own.
func _report_timer(delta: float) -> void:
	if _hosting:
		return
	_since_timer_report += delta
	if _since_timer_report < TIMER_REPORT_INTERVAL:
		return
	_since_timer_report = 0.0
	_session.messenger.send_to_host(EVENT_TIMER, [_flow.get_round_number(), _timer_ends_at()])


func _timer_ends_at() -> float:
	return Time.get_unix_time_from_system() + _flow.get_round_time_left()


func _on_timer_report(payload: Array, _sender_id: int) -> void:
	if not _hosting or _flow.get_phase() != Phase.ACTIVE:
		return
	if payload[0] != _flow.get_round_number():
		return
	var difference: float = absf(_timer_ends_at() - (payload[1] as float))
	_timer_reports += 1
	_timer_worst_difference = maxf(_timer_worst_difference, difference)


# --- Between the rounds and after the match --------------------------------------


func _after_the_round(delta: float) -> void:
	_results_shown_for += delta
	if _results_shown_for < RESULTS_READ_TIME:
		return
	if not _flow.is_match_over():
		if _hosting and _next_requested_in_round != _flow.get_round_number():
			_next_requested_in_round = _flow.get_round_number()
			_flow.request_next_round()
		return
	if not _hosting:
		if not _score_sent:
			_score_sent = true
			_session.messenger.send_to_host(EVENT_SCORE, [_flow.get_score().to_data()])
		return
	if not _lobby_requested and not _guest_score.is_empty():
		_lobby_requested = true
		_flow.request_lobby()


func _on_score_report(payload: Array, _sender_id: int) -> void:
	if _hosting:
		_guest_score = payload[0]


# --- The verdict -----------------------------------------------------------------


## Everything that did not hold.
func _problems() -> Array[String]:
	var problems: Array[String] = []
	for phase: int in [
		Phase.SETUP, Phase.SPAWN, Phase.COUNTDOWN, Phase.ACTIVE, Phase.RESOLVED, Phase.RESULTS
	]:
		if not _phases_seen.has(phase):
			problems.append("the phase %s never came" % Phase.find_key(phase))
	if _results.size() != EXPECTED_ROUNDS.size():
		problems.append(
			"%d rounds were decided, not %d" % [_results.size(), EXPECTED_ROUNDS.size()]
		)
	for index: int in mini(_results.size(), EXPECTED_ROUNDS.size()):
		problems.append_array(_round_problems(index))
	var score: MatchScore = _flow.get_score() if _back_in_lobby else null
	if _match_outcome != MatchScore.Outcome.GUEST_WIN:
		problems.append("the match ended with outcome %d, not the guest's win" % _match_outcome)
	if _input_violations > 0:
		problems.append("%d times a player could act outside an active round" % _input_violations)
	if _refused_presses == 0:
		problems.append("no button was pressed in a countdown, so nothing shows it is refused")
	if _aborted:
		problems.append("the match was aborted")
	if not _back_in_lobby:
		problems.append("the match did not end in the lobby")
	elif _flow.get_phase() != Phase.IDLE or score.get_rounds_played() != 0:
		problems.append("back in the lobby the match is still there")
	elif SceneFlow.current_screen != SceneFlowController.Screen.LOBBY:
		problems.append(
			"not in the lobby but on %s" % SceneFlowController.screen_name(SceneFlow.current_screen)
		)
	if _hosting:
		problems.append_array(_host_problems())
	elif _flow.get_clock_round_trip() < 0.0:
		problems.append("the guest never compared its clock with the host's")
	return problems


func _round_problems(index: int) -> Array[String]:
	var problems: Array[String] = []
	var expected: Array = EXPECTED_ROUNDS[index]
	var result: RoundResult = _results[index]
	var host_role: GameEnums.Role = expected[0]
	var own_role: GameEnums.Role = host_role if _hosting else GameEnums.opposite_role(host_role)
	var number: int = index + 1
	if index >= _roles_played.size() or _roles_played[index] != own_role:
		problems.append(
			"round %d was not played as the %s" % [number, GameEnums.role_name(own_role)]
		)
	if result.outcome != expected[1] or result.reason != expected[2]:
		problems.append(
			(
				"round %d ended with outcome %d for reason %d, not %d for %d"
				% [number, result.outcome, result.reason, expected[1], expected[2]]
			)
		)
	if result.get_sheepherder_points() != expected[3] or result.get_monster_points() != expected[4]:
		var herder_points: int = result.get_sheepherder_points()
		var monster_points: int = result.get_monster_points()
		var points: Array = [number, herder_points, monster_points, expected[3], expected[4]]
		problems.append("round %d ended %d to %d, not %d to %d" % points)
	if result.ammo_depleted != (number == 5):
		problems.append("round %d has the wrong word on the empty magazine" % number)
	return problems


func _host_problems() -> Array[String]:
	var problems: Array[String] = []
	var expected_reports: int = roundi(ROUND_DURATION / TIMER_REPORT_INTERVAL)
	if _timer_reports < expected_reports:
		problems.append("the guest's timer was compared only %d times" % _timer_reports)
	if _timer_worst_difference > TIMER_TOLERANCE:
		var apart: Array = [_timer_worst_difference, TIMER_TOLERANCE]
		problems.append("the timers were up to %.3f s apart, more than %.1f s" % apart)
	var tally: MatchScore = MatchScore.from_data(_guest_score)
	if tally.get_rounds_played() != EXPECTED_ROUNDS.size():
		problems.append("the guest counted %d rounds" % tally.get_rounds_played())
	if (
		tally.get_round_wins(MatchScore.Player.HOST) != EXPECTED_HOST_WINS
		or tally.get_round_wins(MatchScore.Player.GUEST) != EXPECTED_GUEST_WINS
		or tally.get_draws() != EXPECTED_DRAWS
	):
		problems.append("the guest's tally is not 1 to 3 with one draw")
	for index: int in mini(_results.size(), tally.get_rounds_played()):
		if tally.get_round(index).to_data() != _results[index].to_data():
			problems.append("the guest has another record of round %d" % (index + 1))
	return problems


func _finish(problems: Array[String]) -> void:
	if _finished:
		return
	_finished = true
	print(
		(
			"SELFCHECK %s: %d rounds, match outcome %d, %d presses refused in countdowns, %.1f s"
			% [_label, _results.size(), _match_outcome, _refused_presses, _total_time]
		)
	)
	if _hosting:
		print(
			(
				"SELFCHECK host: the guest's timer was compared %d times, at most %.3f s apart"
				% [_timer_reports, _timer_worst_difference]
			)
		)
	else:
		print(
			(
				"SELFCHECK guest: the clocks were compared over a round trip of %.3f s"
				% _flow.get_clock_round_trip()
			)
		)
	for problem: String in problems:
		print("SELFCHECK %s PROBLEM: %s" % [_label, problem])
	print("SELFCHECK %s: %s" % [_label, "PASS" if problems.is_empty() else "FAIL"])
	# Give the other instance time to see the end as well.
	await get_tree().create_timer(1.5).timeout
	get_tree().quit(0 if problems.is_empty() else 1)
