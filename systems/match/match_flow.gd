class_name MatchFlow
extends Node
## The match: a Best of 5 of rounds, each a small state machine that the host
## runs and both devices follow (GDD §2.1 to §2.3, docs/networking.md).
##
## [codeblock]
## SETUP → SPAWN → COUNTDOWN → ACTIVE → RESOLVED → RESULTS → SETUP → …
## [/codeblock]
## The host decides every step and writes it into the session's [SyncedState];
## both devices apply it the same way and emit [signal phase_changed]. The
## [RoundRules] decide a round from what the [CombatService] reports, the
## [MatchScore] counts the rounds. The world of a round is the [RoundStage]'s
## business: it spawns when the flow says [constant Phase.SPAWN].
##
## The flow starts a round when both devices have entered the round screen,
## shows the results screen when it is over, and ends the match when the
## session ends or the players return to the lobby. On the results screen it
## clears the perks of the round and gives the players the roles of the next
## one, so the perks for it can be chosen before its [constant Phase.SETUP]
## ends, where the flow locks them.

## The match moved on. Emitted on both devices.
signal phase_changed(phase: Phase)

## A round was decided. Emitted on both devices, after [signal phase_changed]
## with [constant Phase.RESOLVED].
signal round_resolved(result: RoundResult)

## The last round of the match is over. Emitted on both devices, when the
## results are shown.
signal match_finished(outcome: MatchScore.Outcome)

## The match ended before its last round: the session ended.
signal match_aborted

## A player said they are ready, or not anymore. Emitted on both devices.
signal ready_changed

enum Phase {
	## No match is running.
	IDLE,
	## The perk selection window before a round.
	SETUP,
	## The host spawns the flock and both characters.
	SPAWN,
	## Everybody is in place; nobody can act yet.
	COUNTDOWN,
	## The round is played and the timer runs.
	ACTIVE,
	## The round is decided; the arena stays on screen for a moment.
	RESOLVED,
	## The results screen.
	RESULTS,
}

## The phase with its round and its deadline:
## [code][sequence, phase, round number, host time it began, duration][/code].
const KEY_PHASE: StringName = &"match.phase"
## The tally with every finished round, see [method MatchScore.to_data].
const KEY_SCORE: StringName = &"match.score"

## Who is ready to go on: [code][host ready, guest ready][/code].
const KEY_READY: StringName = &"match.ready"

const EVENT_CLOCK_PING: StringName = &"match.clock_ping"
const EVENT_CLOCK_PONG: StringName = &"match.clock_pong"
## A player tells the host whether they are ready: [code][ready][/code].
const EVENT_READY: StringName = &"match.ready_request"

## The duration of a phase that lasts until the host moves on.
const OPEN_END: float = -1.0

## The combat service that reports what happens in a round. Defaults to
## [code]Services.combat[/code].
var combat: CombatService:
	get:
		return combat if combat != null else Services.combat

## The perk service: the stats of a round and the perk selection. Defaults to
## [code]Services.perks[/code].
var perks: PerkService:
	get:
		return perks if perks != null else Services.perks

## The input service the flow switches on and off. Defaults to
## [code]Services.input[/code].
var input: InputService:
	get:
		return input if input != null else Services.input

## The clock in seconds that deadlines are measured with. Tests replace it.
var clock: Callable = system_clock

## The role the host plays in the first round of a match. Without it the roles
## are drawn (GDD §2.3); checks that have to know who plays what set it.
var first_host_role: GameEnums.Role = GameEnums.Role.NONE

var _session: GameSession
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
var _clock_sync: ClockSync = ClockSync.new()

var _phase: Phase = Phase.IDLE
var _round_number: int = 0
var _score: MatchScore = MatchScore.new()
## When the phase began, on the host's clock, and how long it lasts.
var _phase_began_at: float = 0.0
var _phase_duration: float = OPEN_END
## The host's clock minus this device's, as far as the phase message tells;
## used until the clocks were compared.
var _rough_clock_offset: float = 0.0

# Host only.
var _rules: RoundRules = null
var _round_seed: int = 0
var _sequence: int = 0
var _last_tick_at: float = 0.0
var _watched_combat: CombatService = null
## Whether this device ran the match as the host; still known after the
## session is gone.
var _hosting: bool = false

# Guest only.
var _next_ping_at: float = -INF


func _init() -> void:
	_random.randomize()
	# The flow looks at the timer after everything else in a frame, so a kill
	# in the frame in which the time runs out counts (see RoundRules).
	process_priority = 100


func _process(_delta: float) -> void:
	tick()


## Connects the flow to [param session]: its state, its events and its
## screens. Called once, by the composition root.
func setup(session: GameSession) -> void:
	_session = session
	var messenger: NetMessenger = session.messenger
	messenger.register_event(EVENT_CLOCK_PING, NetMessenger.SenderRule.ANYONE)
	messenger.register_event(EVENT_CLOCK_PONG, NetMessenger.SenderRule.HOST_ONLY)
	messenger.subscribe(EVENT_CLOCK_PING, _on_clock_ping)
	messenger.subscribe(EVENT_CLOCK_PONG, _on_clock_pong)
	messenger.register_event(EVENT_READY, NetMessenger.SenderRule.ANYONE)
	messenger.subscribe(EVENT_READY, _on_ready_request)
	session.state.value_changed.connect(_on_state_changed)
	session.session_started.connect(_on_session_started)
	session.session_ended.connect(_on_session_ended)
	session.screen_entered.connect(_on_screen_entered)


# --- What the host may do --------------------------------------------------------


## Starts a match with its first round. The host plays [param host_role] in
## it, or [member first_host_role]. Without either, the players keep the roles
## they were shown and chose their perks for: the ones the session drew when it
## started (GDD §2.3: random in round 1), or for a rematch the ones drawn anew
## when the results of the last match came up. Host only, and not while a
## round is running.
func start_match(host_role: GameEnums.Role = GameEnums.Role.NONE) -> bool:
	if not _may_start_round():
		return false
	_publish_score(MatchScore.new(perks.get_stat_int(StatIds.MATCH_ROUNDS)))
	var role: GameEnums.Role = host_role
	if role == GameEnums.Role.NONE:
		role = first_host_role
	if role != GameEnums.Role.NONE:
		_session.assign_roles(role)
	elif _session.get_local_role() == GameEnums.Role.NONE:
		_session.assign_random_roles()
	_begin_round()
	return true


## Starts the next round of the match, in the roles the players got when the
## last one was over, or a new match if none is running or the last one is
## over. Host only, and not while a
## round is running. The flow calls this itself when both devices have
## entered the round screen.
func start_round() -> bool:
	if not _may_start_round():
		return false
	if _phase == Phase.IDLE or _score.is_over():
		return start_match()
	_session.assign_roles(_score.get_next_host_role())
	_begin_round()
	return true


## Takes both devices from the results to the next round. Host only.
func request_next_round() -> bool:
	if not _is_authority() or _phase != Phase.RESULTS or _score.is_over():
		return false
	return _session.request_screen(SceneFlowController.Screen.ROUND)


## Takes both devices from the results of a finished match into a new one.
## Host only.
func request_rematch() -> bool:
	if not _is_authority() or _phase != Phase.RESULTS or not _score.is_over():
		return false
	return _session.request_screen(SceneFlowController.Screen.ROUND)


## Ends the match and takes both devices back to the lobby. Host only.
func request_lobby() -> bool:
	if not _is_authority():
		return false
	_end_match()
	return _session.request_screen(SceneFlowController.Screen.LOBBY)


# --- Ready ----------------------------------------------------------------------


## Says that this device's player is ready for the next round, or not anymore.
## The players get ready in the lobby before a match and on the results screen
## between rounds; when both are, the host goes on by itself: into the match,
## to the next round, or into a rematch. Offline, the computer is always ready.
func set_ready(ready: bool) -> bool:
	if not may_get_ready():
		return false
	return _session.messenger.send_to_host(EVENT_READY, [ready])


## Whether the players are asked to get ready now: before a match, or on the
## results screen.
func may_get_ready() -> bool:
	if _session == null or not _session.is_active() or _session.is_changing_screen():
		return false
	return _phase == Phase.IDLE or _phase == Phase.RESULTS


## Whether [param player] is ready. The computer of an offline match always is.
func is_ready(player: MatchScore.Player) -> bool:
	if _session == null or not _session.is_active():
		return false
	if player == MatchScore.Player.GUEST and not _session.has_remote_player():
		return true
	var flags: Array = _session.state.get_value(KEY_READY, [false, false])
	return flags[player]


## Whether this device's player is ready.
func is_locally_ready() -> bool:
	return is_ready(get_local_player())


## Host: a player said whether they are ready.
func _on_ready_request(payload: Array, sender_id: int) -> void:
	if not _is_authority() or not may_get_ready():
		return
	var player: MatchScore.Player = (
		MatchScore.Player.HOST
		if sender_id == _session.messenger.get_local_id()
		else MatchScore.Player.GUEST
	)
	var flags: Array = _session.state.get_value(KEY_READY, [false, false]).duplicate()
	flags[player] = payload[0] == true
	_session.state.set_value(KEY_READY, flags)
	if is_ready(MatchScore.Player.HOST) and is_ready(MatchScore.Player.GUEST):
		_go_on_when_ready()


## Host: both are ready, so the match goes on.
func _go_on_when_ready() -> void:
	_clear_ready()
	if _phase == Phase.IDLE:
		_session.request_screen(SceneFlowController.Screen.ROUND)
	elif _score.is_over():
		request_rematch()
	else:
		request_next_round()


func _clear_ready() -> void:
	if _is_authority() and _session.state.get_value(KEY_READY, [false, false]) != [false, false]:
		_session.state.set_value(KEY_READY, [false, false])


# --- What both devices can ask ---------------------------------------------------


func get_phase() -> Phase:
	return _phase


## Whether a match is running: from the first round's setup to the results of
## the last one.
func is_match_running() -> bool:
	return _phase != Phase.IDLE


## The round that is played or was played last, counted from 1; 0 without a
## match.
func get_round_number() -> int:
	return _round_number


## Rounds in a match.
func get_rounds_total() -> int:
	if is_match_running():
		return _score.get_rounds_total()
	return perks.get_stat_int(StatIds.MATCH_ROUNDS)


## Seconds until the current phase ends by itself; 0 for a phase that waits
## for the host.
func get_phase_time_left() -> float:
	if _phase_duration < 0.0:
		return 0.0
	var host_now: float = _now() + _clock_offset()
	return clampf(_phase_began_at + _phase_duration - host_now, 0.0, _phase_duration)


## Seconds left on the round timer. Both devices show the same time: the
## guest knows how far its clock is from the host's.
func get_round_time_left() -> float:
	match _phase:
		Phase.SETUP, Phase.SPAWN, Phase.COUNTDOWN:
			return perks.get_stat(StatIds.ROUND_DURATION)
		Phase.ACTIVE:
			return get_phase_time_left()
		Phase.RESOLVED, Phase.RESULTS:
			var result: RoundResult = get_last_result()
			return result.time_left if result != null else 0.0
		_:
			return 0.0


## The tally of the match with the record of every finished round.
func get_score() -> MatchScore:
	return _score


## The record of the round that finished last; [code]null[/code] before the
## first round of a match is over.
func get_last_result() -> RoundResult:
	return _score.get_last_round()


## Whether the last round of the match is over.
func is_match_over() -> bool:
	return is_match_running() and _score.is_over()


## The seed of the current round: the spawn places and the looks of the
## flock. Known on the host only.
func get_round_seed() -> int:
	return _round_seed


## Which player of the match this device is.
func get_local_player() -> MatchScore.Player:
	if _session == null or _session.is_host():
		return MatchScore.Player.HOST
	return MatchScore.Player.GUEST


## How far the guest's clock comparison has come, for checks:
## the round trip of the best answer, or -1 before the first.
func get_clock_round_trip() -> float:
	return _clock_sync.get_round_trip() if _clock_sync.has_samples() else -1.0


# --- The host's state machine ----------------------------------------------------


## Moves the flow on. Runs every frame; a test with its own [member clock]
## calls it itself.
func tick() -> void:
	if _session == null or not _session.is_active():
		return
	var now: float = _now()
	if not _session.is_host():
		_ping_host(now)
		return
	var elapsed: float = now - _last_tick_at
	_last_tick_at = now
	match _phase:
		Phase.SETUP:
			if _deadline_passed(now):
				_begin_spawn()
		Phase.COUNTDOWN:
			if _deadline_passed(now):
				_enter(Phase.ACTIVE, _rules.get_time_left())
		Phase.ACTIVE:
			_rules.advance(elapsed)
			if _rules.is_resolved():
				_finish_round()
		Phase.RESOLVED:
			if _deadline_passed(now):
				_show_results()


func _may_start_round() -> bool:
	return _is_authority() and (_phase == Phase.IDLE or _phase == Phase.RESULTS)


func _is_authority() -> bool:
	return _session != null and _session.is_active() and _session.is_host()


func _deadline_passed(now: float) -> bool:
	return _phase_duration >= 0.0 and now >= _phase_began_at + _phase_duration


func _begin_round() -> void:
	_hosting = true
	_round_number = _score.get_rounds_played() + 1
	_enter(Phase.SETUP, perks.get_stat(StatIds.ROUND_SETUP_DURATION))
	if _phase_duration <= 0.0:
		_begin_spawn()


## The perk selection is over: the round gets its numbers, its seed and its
## cast.
func _begin_spawn() -> void:
	# The combat service reads the magazine size when the round begins on a
	# device, so the perks are locked before anything is spawned.
	perks.lock_selection()
	_round_seed = _random.randi()
	_rules = RoundRules.new(_read_settings())
	_watch_combat()
	# The stage spawns the flock and the characters while this is emitted.
	_enter(Phase.SPAWN, OPEN_END)
	_enter(Phase.COUNTDOWN, perks.get_stat(StatIds.ROUND_COUNTDOWN_DURATION))


func _finish_round() -> void:
	_unwatch_combat()
	var score: MatchScore = MatchScore.from_data(_score.to_data())
	score.record_round(_rules.get_result(), _session.get_local_role())
	_rules = null
	_publish_score(score)
	_enter(Phase.RESOLVED, perks.get_stat(StatIds.ROUND_RESOLVED_DURATION))


func _show_results() -> void:
	_enter(Phase.RESULTS, OPEN_END)
	if not _session.request_screen(SceneFlowController.Screen.RESULTS):
		_prepare_next_round()


## The round's world is gone. Its perks end, and the players get the roles of
## the next round (GDD §2.3: they swap after every round), so that each can
## choose a perk for the role they are about to play. After the last round
## they are drawn anew for a rematch.
func _prepare_next_round() -> void:
	if _phase != Phase.RESULTS:
		return
	_clear_ready()
	if _score.is_over():
		_session.assign_random_roles()
	else:
		_session.assign_roles(_score.get_next_host_role())
	perks.clear_selection()


## The host ends the match for both devices.
func _end_match() -> void:
	if _phase == Phase.IDLE:
		return
	_unwatch_combat()
	_rules = null
	if perks.is_selection_locked():
		perks.clear_selection()
	_hosting = false
	_round_number = 0
	_publish_score(MatchScore.new())
	_enter(Phase.IDLE, OPEN_END)


func _read_settings() -> RoundSettings:
	var settings: RoundSettings = RoundSettings.new()
	settings.round_duration = perks.get_stat(StatIds.ROUND_DURATION)
	settings.flock_size = perks.get_stat_int(StatIds.FLOCK_SIZE)
	settings.herder_kill_threshold = perks.get_stat_int(StatIds.HERDER_KILL_THRESHOLD)
	settings.herder_points_per_surviving_sheep = perks.get_stat_int(
		StatIds.HERDER_POINTS_PER_SURVIVING_SHEEP
	)
	settings.herder_points_per_shot_sheep = perks.get_stat_int(StatIds.HERDER_POINTS_PER_SHOT_SHEEP)
	settings.monster_points_per_eaten_sheep = perks.get_stat_int(
		StatIds.MONSTER_POINTS_PER_EATEN_SHEEP
	)
	return settings


# --- Replication -----------------------------------------------------------------


## Host: tells both devices that [param phase] begins now.
func _enter(phase: Phase, duration: float) -> void:
	_sequence += 1
	_last_tick_at = _now()
	_session.state.set_value(
		KEY_PHASE, [_sequence, phase, _round_number, _last_tick_at, maxf(duration, OPEN_END)]
	)


func _publish_score(score: MatchScore) -> void:
	_session.state.set_value(KEY_SCORE, score.to_data())


func _on_state_changed(key: StringName, value: Variant) -> void:
	match key:
		KEY_SCORE:
			_score = MatchScore.from_data(value)
		KEY_PHASE:
			_apply_phase(value)
		KEY_READY:
			ready_changed.emit()


## Both devices: the match moved on.
func _apply_phase(data: Array) -> void:
	_phase = data[1]
	_round_number = data[2]
	_phase_began_at = data[3]
	_phase_duration = data[4]
	_rough_clock_offset = _phase_began_at - _now()
	# Without a match the input is nobody's business: sandboxes use it freely.
	input.set_gameplay_enabled(_phase == Phase.ACTIVE or _phase == Phase.IDLE)
	if _phase == Phase.RESOLVED or _phase == Phase.IDLE:
		combat.end_round()
	phase_changed.emit(_phase)
	if _phase == Phase.RESOLVED and get_last_result() != null:
		round_resolved.emit(get_last_result())
	elif _phase == Phase.RESULTS and _score.is_over():
		match_finished.emit(_score.get_outcome())


# --- What happens in a round (host) ----------------------------------------------


func _watch_combat() -> void:
	_unwatch_combat()
	_watched_combat = combat
	_watched_combat.sheep_killed.connect(_on_sheep_killed)
	_watched_combat.eat_started.connect(_on_eat_started)
	_watched_combat.ammo_depleted.connect(_on_ammo_depleted)
	_watched_combat.monster_form_changed.connect(_on_monster_form_changed)
	_watched_combat.monster_shot.connect(_on_monster_shot)
	_watched_combat.sheepherder_killed.connect(_on_sheepherder_killed)


func _unwatch_combat() -> void:
	if not is_instance_valid(_watched_combat):
		_watched_combat = null
		return
	_watched_combat.sheep_killed.disconnect(_on_sheep_killed)
	_watched_combat.eat_started.disconnect(_on_eat_started)
	_watched_combat.ammo_depleted.disconnect(_on_ammo_depleted)
	_watched_combat.monster_form_changed.disconnect(_on_monster_form_changed)
	_watched_combat.monster_shot.disconnect(_on_monster_shot)
	_watched_combat.sheepherder_killed.disconnect(_on_sheepherder_killed)
	_watched_combat = null


func _is_round_active() -> bool:
	return _phase == Phase.ACTIVE and _rules != null


func _on_sheep_killed(_sheep_id: int, cause: GameEnums.DeathCause, _position: Vector2) -> void:
	if not _is_round_active():
		return
	if cause == GameEnums.DeathCause.EATEN:
		_rules.report_sheep_eaten()
	else:
		_rules.report_sheep_shot()


func _on_eat_started(target: CombatService.EatTarget, _target_id: int, _duration: float) -> void:
	if _is_round_active() and target == CombatService.EatTarget.SHEEP_BODY:
		_rules.report_body_eaten()


func _on_ammo_depleted() -> void:
	if _is_round_active():
		_rules.report_ammo_depleted()


func _on_monster_form_changed(form: GameEnums.MonsterForm) -> void:
	if _is_round_active() and form == GameEnums.MonsterForm.SPIDER:
		_rules.report_monster_evolved()


## The round is not finished here but in the next [method tick], so the
## combat service is done with the kill before the round ends under it.
func _on_monster_shot(_position: Vector2) -> void:
	if _is_round_active() and not _rules.report_monster_shot():
		push_error("MatchFlow: the Monster was shot, but the rules say it could not be.")


func _on_sheepherder_killed(_position: Vector2) -> void:
	if _is_round_active() and not _rules.report_sheepherder_killed():
		push_error("MatchFlow: the Sheepherder was killed, but the rules say they could not be.")


# --- Session ---------------------------------------------------------------------


func _on_session_started() -> void:
	_clock_sync.reset()
	_next_ping_at = -INF


## A match cannot go on without the other player.
func _on_session_ended(_reason: NetworkService.DisconnectReason, _message: String) -> void:
	_clock_sync.reset()
	if _phase == Phase.IDLE:
		return
	_unwatch_combat()
	_rules = null
	_phase = Phase.IDLE
	_round_number = 0
	_phase_duration = OPEN_END
	_score = MatchScore.new()
	combat.end_round()
	input.set_gameplay_enabled(true)
	if _hosting and perks.is_selection_locked():
		perks.clear_selection()
	_hosting = false
	phase_changed.emit(_phase)
	match_aborted.emit()


func _on_screen_entered(screen: SceneFlowController.Screen) -> void:
	if not _is_authority():
		return
	match screen:
		SceneFlowController.Screen.ROUND:
			start_round()
		SceneFlowController.Screen.RESULTS:
			_prepare_next_round()
		SceneFlowController.Screen.LOBBY:
			# However the players got here, the match is over.
			_end_match()
			_clear_ready()


# --- Clock -----------------------------------------------------------------------


func _now() -> float:
	return clock.call()


## The clock the flow uses unless a test gives it another: seconds since the
## application started.
static func system_clock() -> float:
	return Time.get_ticks_usec() / 1000000.0


## What to add to this device's clock to get the host's.
func _clock_offset() -> float:
	if _session == null or _session.is_host():
		return 0.0
	return _clock_sync.get_offset() if _clock_sync.has_samples() else _rough_clock_offset


## Guest: asks the host for its time now and then.
func _ping_host(now: float) -> void:
	if now < _next_ping_at or not _session.has_remote_player():
		return
	_next_ping_at = now + perks.get_stat(StatIds.NET_CLOCK_SYNC_INTERVAL)
	_session.messenger.send_to_host(EVENT_CLOCK_PING, [now])


func _on_clock_ping(payload: Array, _sender_id: int) -> void:
	if _session.is_host() and _session.has_remote_player():
		_session.messenger.send_to_remote(EVENT_CLOCK_PONG, [payload[0], _now()])


func _on_clock_pong(payload: Array, _sender_id: int) -> void:
	if not _session.is_host():
		_clock_sync.add_sample(payload[0], payload[1], _now())
