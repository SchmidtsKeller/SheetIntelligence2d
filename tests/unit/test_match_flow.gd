extends TestCase
## The match flow on two devices: the host runs the phases of a round and the
## match, the guest follows, and both agree on phase, timer and results.

# Aliases for enum types, so they are named like types.
# gdlint: ignore=constant-name
const Role = GameEnums.Role
# gdlint: ignore=constant-name
const Phase = MatchFlow.Phase
# gdlint: ignore=constant-name
const Screen = SceneFlowController.Screen
# gdlint: ignore=constant-name
const Reason = GameEnums.RoundEndReason
# gdlint: ignore=constant-name
const Outcome = GameEnums.RoundOutcome

## The guest's clock shows another time than the host's, as on two devices.
const GUEST_CLOCK_OFFSET: float = -5000.0

var _pair: SessionPair
var _config: GameConfig
var _host: MatchFlow
var _guest: MatchFlow
var _host_combat: StubCombatService
var _guest_combat: StubCombatService
var _host_perks: StubPerkService
var _host_input: StubInputService
var _guest_input: StubInputService
## The time on the host's clock.
var _time: float = 0.0
## Messages on their way, when the link is delayed: [to host?, reliable, message].
var _in_transit: Array[Array] = []


func before_each() -> void:
	_time = 100.0
	_in_transit.clear()
	_config = GameConfig.new()
	_pair = SessionPair.create(self)
	_host_combat = add_child_autofree(StubCombatService.new(_config))
	_guest_combat = add_child_autofree(StubCombatService.new(_config))
	_host_perks = add_child_autofree(StubPerkService.new(_config))
	_host_input = add_child_autofree(StubInputService.new())
	_guest_input = add_child_autofree(StubInputService.new())
	_host = _create_flow(_pair.host, _host_combat, _host_perks, _host_input)
	_host.clock = func() -> float: return _time
	_guest = _create_flow(
		_pair.guest, _guest_combat, add_child_autofree(StubPerkService.new(_config)), _guest_input
	)
	_guest.clock = func() -> float: return _time + GUEST_CLOCK_OFFSET
	_pair.connect_both()


func after_each() -> void:
	_pair = null
	_host = null
	_guest = null


# --- Starting --------------------------------------------------------------------


func test_without_a_match_the_flow_is_idle() -> void:
	assert_eq(_host.get_phase(), Phase.IDLE)
	assert_false(_host.is_match_running())
	assert_eq(_host.get_round_number(), 0)
	assert_eq(_host.get_rounds_total(), 5)
	assert_null(_host.get_last_result())
	assert_eq(_host.get_round_time_left(), 0.0)
	assert_true(_host_input.is_gameplay_enabled(), "nobody touched the input")


func test_entering_the_round_screen_starts_the_match_on_both_devices() -> void:
	var drawn_role: GameEnums.Role = _pair.host.get_local_role()
	assert_ne(drawn_role, Role.NONE, "the session drew the roles when it started")

	_pair.host.request_screen(Screen.ROUND)
	await wait_frames(4)

	assert_eq(_host.get_phase(), Phase.COUNTDOWN)
	assert_eq(_guest.get_phase(), Phase.COUNTDOWN)
	assert_eq(_host.get_round_number(), 1)
	assert_eq(_guest.get_round_number(), 1)
	assert_eq(_guest.get_rounds_total(), 5)
	assert_eq(_pair.host.get_local_role(), drawn_role, "round 1 is played as the lobby showed")
	assert_eq(_pair.guest.get_local_role(), GameEnums.opposite_role(drawn_role))


func test_a_round_goes_through_setup_spawn_and_countdown() -> void:
	watch_signals(_host)
	watch_signals(_guest)

	assert_true(_host.start_match(Role.SHEEPHERDER))

	for flow: MatchFlow in [_host, _guest]:
		assert_signal_emit_count(flow, &"phase_changed", 3)
		assert_eq(get_signal_arguments(flow, &"phase_changed", 0), [Phase.SETUP])
		assert_eq(get_signal_arguments(flow, &"phase_changed", 1), [Phase.SPAWN])
		assert_eq(get_signal_arguments(flow, &"phase_changed", 2), [Phase.COUNTDOWN])
	assert_true(_host_perks.is_selection_locked(), "perks are locked before the spawn")
	assert_eq(_pair.host.get_local_role(), Role.SHEEPHERDER)
	assert_eq(_pair.guest.get_local_role(), Role.MONSTER)


func test_the_setup_window_stays_open_for_its_duration() -> void:
	_config.round_setup_duration = 20.0

	_host.start_match(Role.SHEEPHERDER)

	assert_eq(_host.get_phase(), Phase.SETUP)
	assert_eq(_guest.get_phase(), Phase.SETUP)
	assert_false(_host_perks.is_selection_locked(), "the players still choose")
	assert_almost_eq(_guest.get_phase_time_left(), 20.0, 0.001)

	_pass(19.9)
	assert_eq(_host.get_phase(), Phase.SETUP)

	_pass(0.2)
	assert_eq(_host.get_phase(), Phase.COUNTDOWN)
	assert_eq(_guest.get_phase(), Phase.COUNTDOWN)
	assert_true(_host_perks.is_selection_locked())


func test_gameplay_input_is_on_only_while_the_round_is_active() -> void:
	_host.start_match(Role.SHEEPHERDER)

	assert_false(_host_input.is_gameplay_enabled(), "countdown")
	assert_false(_guest_input.is_gameplay_enabled(), "countdown")

	_pass(_config.round_countdown_duration)

	assert_eq(_host.get_phase(), Phase.ACTIVE)
	assert_eq(_guest.get_phase(), Phase.ACTIVE)
	assert_true(_host_input.is_gameplay_enabled())
	assert_true(_guest_input.is_gameplay_enabled())

	_host_combat.monster_shot.emit(Vector2.ZERO)
	_pass(0.1)

	assert_eq(_host.get_phase(), Phase.RESOLVED)
	assert_false(_host_input.is_gameplay_enabled(), "decided")
	assert_false(_guest_input.is_gameplay_enabled(), "decided")


func test_only_the_host_starts_and_only_between_rounds() -> void:
	assert_false(_guest.start_match(), "the guest follows")
	assert_false(_guest.start_round())
	assert_false(_guest.request_lobby())

	assert_true(_host.start_round(), "without a match this starts one")
	assert_false(_host.start_round(), "a round is running")
	assert_false(_host.start_match())
	assert_false(_host.request_next_round(), "not on the results screen")
	assert_false(_host.request_rematch())

	assert_eq(_host.get_round_number(), 1)


func test_without_a_session_nothing_starts() -> void:
	_end_session()

	assert_false(_host.start_match())
	assert_eq(_host.get_phase(), Phase.IDLE)


# --- The timer -------------------------------------------------------------------


func test_the_timer_waits_for_the_countdown_and_then_runs_down() -> void:
	_host.start_match(Role.SHEEPHERDER)

	assert_eq(_host.get_round_time_left(), 180.0)
	assert_eq(_guest.get_round_time_left(), 180.0)
	assert_almost_eq(_host.get_phase_time_left(), 3.0, 0.001)
	assert_almost_eq(_guest.get_phase_time_left(), 3.0, 0.001)

	_pass(1.0)
	assert_almost_eq(_guest.get_phase_time_left(), 2.0, 0.001)
	assert_eq(_guest.get_round_time_left(), 180.0)

	_pass(2.0)
	_pass(50.0)

	assert_almost_eq(_host.get_round_time_left(), 130.0, 0.001)
	assert_almost_eq(_guest.get_round_time_left(), 130.0, 0.001)


func test_both_devices_show_the_same_time_over_a_slow_connection() -> void:
	_delay_link()
	_host.start_match(Role.MONSTER)
	_travel(0.08)
	# With this tick the round begins, and the guest asks for the host's time.
	_pass(_config.round_countdown_duration)
	var began_at: float = _time
	_travel(0.08)
	assert_eq(_guest.get_phase(), Phase.ACTIVE)

	# Before the clocks were compared, the guest is off by the way the message
	# took.
	assert_almost_eq(_guest.get_round_time_left(), _host.get_round_time_left(), 0.081)

	# The question took 80 ms, the answer takes another 80 ms.
	_travel(0.08)

	assert_almost_eq(_guest.get_clock_round_trip(), 0.16, 0.001)
	assert_almost_eq(_guest.get_round_time_left(), _host.get_round_time_left(), 0.001)

	_pass(100.0)
	_travel(0.08)

	assert_almost_eq(_guest.get_round_time_left(), _host.get_round_time_left(), 0.001)
	assert_almost_eq(_host.get_round_time_left(), 180.0 - (_time - began_at), 0.001)


func test_the_guest_keeps_asking_for_the_hosts_time() -> void:
	var pings: Array[int] = [0]
	_pair.host.messenger.subscribe(
		MatchFlow.EVENT_CLOCK_PING, func(_payload: Array, _sender: int) -> void: pings[0] += 1
	)

	_guest.tick()
	_guest.tick()
	assert_eq(pings[0], 1, "not in every frame")

	_pass(_config.net_clock_sync_interval + 0.01)
	assert_eq(pings[0], 2)
	assert_almost_eq(_guest.get_clock_round_trip(), 0.0, 0.0001)
	assert_eq(_host.get_clock_round_trip(), -1.0, "the host's clock is the match's clock")


func test_the_timer_stands_still_once_the_round_is_decided() -> void:
	_start_active_round(Role.SHEEPHERDER)
	_pass(40.0)

	_host_combat.monster_shot.emit(Vector2.ZERO)
	_pass(0.5)
	_pass(2.0)

	assert_almost_eq(_host.get_round_time_left(), 140.0, 0.001)
	assert_almost_eq(_guest.get_round_time_left(), 140.0, 0.001)


# --- How a round ends ------------------------------------------------------------


func test_the_monster_is_shot_the_sheepherder_wins_on_both_devices() -> void:
	_start_active_round(Role.SHEEPHERDER)
	_host_combat.begin_round(null, null)
	_guest_combat.begin_round(null, null)
	watch_signals(_host)
	watch_signals(_guest)

	_host_combat.monster_shot.emit(Vector2.ZERO)
	assert_eq(_host.get_phase(), Phase.ACTIVE, "decided with the next tick")
	_pass(0.016)

	for flow: MatchFlow in [_host, _guest]:
		assert_eq(flow.get_phase(), Phase.RESOLVED)
		assert_signal_emit_count(flow, &"round_resolved", 1)
		var result: RoundResult = flow.get_last_result()
		assert_eq(result.outcome, Outcome.SHEEPHERDER_WIN)
		assert_eq(result.reason, Reason.MONSTER_SHOT)
		assert_eq(result.get_sheepherder_points(), 10)
		assert_eq(flow.get_score().get_round_wins(MatchScore.Player.HOST), 1)
		assert_eq(flow.get_score().get_round_wins(MatchScore.Player.GUEST), 0)
	assert_false(_host_combat.is_round_active(), "nothing can be shot or eaten anymore")
	assert_false(_guest_combat.is_round_active())
	assert_eq(_host.get_local_player(), MatchScore.Player.HOST)
	assert_eq(_guest.get_local_player(), MatchScore.Player.GUEST)


func test_the_sheepherder_is_killed_the_monster_wins() -> void:
	_start_active_round(Role.SHEEPHERDER)
	_eat(5)

	_host_combat.sheepherder_killed.emit(Vector2.ZERO)
	_pass(0.016)

	var result: RoundResult = _guest.get_last_result()
	assert_eq(result.outcome, Outcome.MONSTER_WIN)
	assert_eq(result.reason, Reason.SHEEPHERDER_KILLED)
	assert_eq(result.get_monster_points(), 5)
	assert_eq(result.get_sheepherder_points(), 5)
	assert_eq(_guest.get_score().get_round_wins(MatchScore.Player.GUEST), 1, "the guest's Monster")


func test_the_time_runs_out_and_the_points_decide() -> void:
	_start_active_round(Role.SHEEPHERDER)
	_eat(4)
	_host_combat.sheep_killed.emit(7, GameEnums.DeathCause.SHOT, Vector2.ZERO)
	_host_combat.eat_started.emit(CombatService.EatTarget.SHEEP_BODY, 7, 1.0)

	_pass(179.0)
	assert_eq(_host.get_phase(), Phase.ACTIVE)
	_pass(1.0)

	for flow: MatchFlow in [_host, _guest]:
		assert_eq(flow.get_phase(), Phase.RESOLVED)
		var result: RoundResult = flow.get_last_result()
		assert_eq(result.reason, Reason.TIMEOUT)
		assert_eq(result.outcome, Outcome.MONSTER_WIN)
		assert_eq(result.get_sheepherder_points(), 5 - 2)
		assert_eq(result.get_monster_points(), 4)
		assert_eq(result.surviving_sheep, 5)
		assert_eq(result.shot_sheep, 1)
		assert_eq(result.eaten_sheep, 4)
		assert_eq(result.eaten_bodies, 1)
		assert_eq(result.time_left, 0.0)
		assert_eq(flow.get_round_time_left(), 0.0)


func test_equal_points_at_the_timeout_are_a_draw_without_a_round_win() -> void:
	_start_active_round(Role.MONSTER)
	_eat(5)

	_pass(180.0)

	assert_eq(_guest.get_last_result().outcome, Outcome.DRAW)
	assert_eq(_guest.get_score().get_draws(), 1)
	assert_eq(_guest.get_score().get_round_wins(MatchScore.Player.HOST), 0)
	assert_eq(_guest.get_score().get_round_wins(MatchScore.Player.GUEST), 0)


func test_after_the_last_bullet_the_round_goes_on_to_the_timeout() -> void:
	_start_active_round(Role.SHEEPHERDER)

	_host_combat.ammo_depleted.emit()
	_pass(100.0)
	assert_eq(_host.get_phase(), Phase.ACTIVE, "the round continues")

	_pass(80.0)

	var result: RoundResult = _guest.get_last_result()
	assert_eq(result.reason, Reason.TIMEOUT)
	assert_true(result.ammo_depleted)
	assert_eq(result.outcome, Outcome.SHEEPHERDER_WIN)


func test_the_spider_kills_the_sheepherder() -> void:
	_start_active_round(Role.SHEEPHERDER)
	_eat(10)
	_host_combat.monster_form_changed.emit(GameEnums.MonsterForm.SPIDER)

	_host_combat.sheepherder_killed.emit(Vector2.ZERO)
	_pass(0.016)

	var result: RoundResult = _guest.get_last_result()
	assert_eq(result.outcome, Outcome.MONSTER_WIN)
	assert_true(result.monster_evolved)
	assert_eq(result.get_monster_points(), 10)


func test_a_kill_in_the_tick_the_time_runs_out_beats_the_timeout() -> void:
	_start_active_round(Role.SHEEPHERDER)
	_pass(179.99)

	# The time is over, but the host has not looked at the clock yet.
	_time += 0.02
	_host_combat.monster_shot.emit(Vector2.ZERO)
	_host.tick()

	assert_eq(_guest.get_last_result().reason, Reason.MONSTER_SHOT)
	assert_eq(_guest.get_last_result().outcome, Outcome.SHEEPHERDER_WIN)


func test_nothing_counts_before_the_round_is_active() -> void:
	_host.start_match(Role.SHEEPHERDER)

	_host_combat.monster_shot.emit(Vector2.ZERO)
	_host_combat.sheep_killed.emit(1, GameEnums.DeathCause.EATEN, Vector2.ZERO)
	_pass(_config.round_countdown_duration)
	_pass(180.0)

	assert_eq(_host.get_last_result().reason, Reason.TIMEOUT)
	assert_eq(_host.get_last_result().get_sheepherder_points(), 10)


func test_a_kill_the_rules_do_not_allow_is_reported_and_ignored() -> void:
	_start_active_round(Role.SHEEPHERDER)
	_eat(2)
	expect_error("the rules say they could not be")

	_host_combat.sheepherder_killed.emit(Vector2.ZERO)
	_pass(0.016)

	assert_eq(_host.get_phase(), Phase.ACTIVE)


func test_the_guests_combat_service_decides_nothing() -> void:
	_start_active_round(Role.SHEEPHERDER)

	_guest_combat.monster_shot.emit(Vector2.ZERO)
	_pass(0.016)

	assert_eq(_host.get_phase(), Phase.ACTIVE)
	assert_eq(_guest.get_phase(), Phase.ACTIVE)


# --- Results and the next round --------------------------------------------------


func test_after_a_moment_both_devices_see_the_results() -> void:
	_start_active_round(Role.SHEEPHERDER)
	_host_combat.monster_shot.emit(Vector2.ZERO)
	_pass(0.016)
	_pass(_config.round_resolved_duration - 0.1)
	assert_eq(_host.get_phase(), Phase.RESOLVED)

	_pass(0.2)
	assert_eq(_host.get_phase(), Phase.RESULTS)
	assert_true(_host_perks.is_selection_locked(), "the round's world is still on screen")
	assert_eq(_pair.host.get_local_role(), Role.SHEEPHERDER)

	await wait_frames(4)

	assert_eq(_host.get_phase(), Phase.RESULTS)
	assert_eq(_guest.get_phase(), Phase.RESULTS)
	assert_eq(_pair.host_flow.current_screen, Screen.RESULTS)
	assert_eq(_pair.guest_flow.current_screen, Screen.RESULTS)
	assert_false(_host_perks.is_selection_locked(), "the perks of the round are gone")
	assert_false(_host.is_match_over())


func test_on_the_results_screen_the_players_have_the_roles_of_the_next_round() -> void:
	await _play_round(Role.SHEEPHERDER, Role.SHEEPHERDER)

	# So each of them can choose a perk for the role they are about to play.
	assert_eq(_pair.host.get_local_role(), Role.MONSTER)
	assert_eq(_pair.guest.get_local_role(), Role.SHEEPHERDER)
	assert_eq(_host.get_score().get_role_in_round(0, MatchScore.Player.HOST), Role.SHEEPHERDER)
	assert_eq(_guest.get_score().get_role_in_round(0, MatchScore.Player.GUEST), Role.MONSTER)


func test_after_the_last_round_the_roles_of_a_rematch_are_drawn() -> void:
	_config.match_rounds = 1
	# The results screen comes up at the end of this.
	await _play_round(Role.SHEEPHERDER, Role.SHEEPHERDER)

	assert_true(_host.is_match_over())
	var host_role: GameEnums.Role = _pair.host.get_local_role()
	assert_ne(host_role, Role.NONE)
	assert_eq(_pair.guest.get_local_role(), GameEnums.opposite_role(host_role))
	assert_false(_host_perks.is_selection_locked())


func test_a_players_own_perks_follow_them_through_the_swap() -> void:
	# A choice is asked of the host and answered, as over a real connection.
	_delay_link()
	var host_perks: SessionPerkService = _create_perks(
		_pair.host, [PerkIds.WIDE_FLASHLIGHT, PerkIds.INVISIBILITY]
	)
	var guest_perks: SessionPerkService = _create_perks(
		_pair.guest, [PerkIds.LONG_FLASHLIGHT, PerkIds.FASTER_CONSUMPTION]
	)
	_host.perks = host_perks
	_guest.perks = guest_perks
	_pair.host.assign_roles(Role.SHEEPHERDER)
	# In the lobby both pick a perk for the role they were given.
	host_perks.clear_selection()
	await _settle()

	_pair.host.request_screen(Screen.ROUND)
	await _settle()

	for perks: SessionPerkService in [host_perks, guest_perks]:
		assert_true(perks.is_selection_locked())
		assert_eq(perks.get_selected_perk(Role.SHEEPHERDER), PerkIds.WIDE_FLASHLIGHT)
		assert_eq(perks.get_selected_perk(Role.MONSTER), PerkIds.FASTER_CONSUMPTION)

	await _play_round(Role.NONE, Role.SHEEPHERDER)
	await _settle()

	# On the results screen the roles are swapped, and each picks again.
	assert_eq(_pair.guest.get_local_role(), Role.SHEEPHERDER)
	for perks: SessionPerkService in [host_perks, guest_perks]:
		assert_false(perks.is_selection_locked())
		assert_eq(perks.get_selected_perk(Role.MONSTER), PerkIds.INVISIBILITY, "the host's")
		assert_eq(perks.get_selected_perk(Role.SHEEPHERDER), PerkIds.LONG_FLASHLIGHT, "the guest's")

	_host.request_next_round()
	await _settle()

	for perks: SessionPerkService in [host_perks, guest_perks]:
		assert_true(perks.is_selection_locked(), "locked for round 2")
		assert_eq(perks.get_selected_perk(Role.MONSTER), PerkIds.INVISIBILITY)
		assert_eq(perks.get_selected_perk(Role.SHEEPHERDER), PerkIds.LONG_FLASHLIGHT)


func test_the_next_round_swaps_the_roles() -> void:
	await _play_round(Role.SHEEPHERDER, Role.SHEEPHERDER)

	assert_true(_host.request_next_round())
	await wait_frames(4)

	assert_eq(_pair.host_flow.current_screen, Screen.ROUND)
	assert_eq(_pair.guest_flow.current_screen, Screen.ROUND)
	assert_eq(_host.get_phase(), Phase.COUNTDOWN)
	assert_eq(_host.get_round_number(), 2)
	assert_eq(_guest.get_round_number(), 2)
	assert_eq(_pair.host.get_local_role(), Role.MONSTER)
	assert_eq(_pair.guest.get_local_role(), Role.SHEEPHERDER)
	assert_eq(_host.get_round_time_left(), 180.0, "a fresh timer")


func test_a_best_of_five_is_played_to_the_end_and_counted() -> void:
	watch_signals(_host)
	watch_signals(_guest)
	# The host starts as the Sheepherder and the roles swap every round.
	# Round 1: the host's Sheepherder wins. Round 2: the guest's Sheepherder
	# wins. Round 3: the guest's Monster wins. Round 4: a draw. Round 5: the
	# host's Sheepherder wins.
	var winners: Array[GameEnums.Role] = [
		Role.SHEEPHERDER, Role.SHEEPHERDER, Role.MONSTER, Role.NONE, Role.SHEEPHERDER
	]
	for index: int in winners.size():
		var first: GameEnums.Role = Role.SHEEPHERDER if index == 0 else Role.NONE
		await _play_round(first, winners[index])
		assert_eq(_host.get_score().get_rounds_played(), index + 1)
		if index < winners.size() - 1:
			assert_signal_not_emitted(_host, &"match_finished")
			assert_false(_host.request_rematch(), "the match is not over")
			assert_true(_host.request_next_round())
			await wait_frames(4)

	for flow: MatchFlow in [_host, _guest]:
		assert_true(flow.is_match_over())
		assert_eq(flow.get_score().get_round_wins(MatchScore.Player.HOST), 2)
		assert_eq(flow.get_score().get_round_wins(MatchScore.Player.GUEST), 2)
		assert_eq(flow.get_score().get_draws(), 1)
		assert_eq(flow.get_score().get_outcome(), MatchScore.Outcome.DRAW)
		assert_signal_emit_count(flow, &"match_finished", 1)
		assert_signal_emitted_with(flow, &"match_finished", [MatchScore.Outcome.DRAW])
		assert_signal_emit_count(flow, &"round_resolved", 5)
		for round_index: int in 5:
			var expected: GameEnums.Role = Role.MONSTER
			if round_index % 2 == 0:
				expected = Role.SHEEPHERDER
			assert_eq(
				flow.get_score().get_role_in_round(round_index, MatchScore.Player.HOST), expected
			)
	assert_eq(_guest.get_score().to_data(), _host.get_score().to_data(), "the same records")
	assert_false(_host.request_next_round(), "there is no sixth round")


func test_a_rematch_starts_a_new_match_from_nothing() -> void:
	_config.match_rounds = 1
	await _play_round(Role.MONSTER, Role.MONSTER)
	assert_true(_host.is_match_over())
	assert_eq(_host.get_score().get_outcome(), MatchScore.Outcome.HOST_WIN)

	assert_true(_host.request_rematch())
	await wait_frames(4)

	for flow: MatchFlow in [_host, _guest]:
		assert_eq(flow.get_phase(), Phase.COUNTDOWN)
		assert_eq(flow.get_round_number(), 1)
		assert_eq(flow.get_score().get_rounds_played(), 0)
		assert_null(flow.get_last_result())
		assert_false(flow.is_match_over())


# --- Ready ----------------------------------------------------------------------


func test_the_match_starts_when_both_players_are_ready_in_the_lobby() -> void:
	watch_signals(_guest)

	assert_true(_host.set_ready(true))
	await wait_frames(2)

	assert_true(_guest.is_ready(MatchScore.Player.HOST), "the guest sees it")
	assert_false(_guest.is_locally_ready())
	assert_signal_emitted(_guest, &"ready_changed")
	assert_eq(_host.get_phase(), Phase.IDLE, "one player is not enough")

	assert_true(_guest.set_ready(true))
	await wait_frames(4)

	for flow: MatchFlow in [_host, _guest]:
		assert_eq(flow.get_phase(), Phase.COUNTDOWN)
		assert_eq(flow.get_round_number(), 1)
		assert_false(flow.is_ready(MatchScore.Player.HOST), "a new round asks anew")
		assert_false(flow.is_ready(MatchScore.Player.GUEST))


func test_a_player_can_take_back_their_ready() -> void:
	_guest.set_ready(true)
	await wait_frames(2)

	_guest.set_ready(false)
	await wait_frames(2)
	_host.set_ready(true)
	await wait_frames(4)

	assert_false(_host.is_ready(MatchScore.Player.GUEST))
	assert_eq(_host.get_phase(), Phase.IDLE)


func test_nobody_gets_ready_during_a_round() -> void:
	await _start_active_round(Role.SHEEPHERDER)

	assert_false(_host.may_get_ready())
	assert_false(_guest.set_ready(true))
	assert_false(_host.set_ready(true))
	assert_false(_host.is_ready(MatchScore.Player.HOST))


func test_both_ready_on_the_results_starts_the_next_round() -> void:
	await _play_round(Role.SHEEPHERDER, Role.SHEEPHERDER)
	assert_eq(_host.get_phase(), Phase.RESULTS)
	assert_true(_guest.may_get_ready())

	_host.set_ready(true)
	_guest.set_ready(true)
	await wait_frames(6)

	for flow: MatchFlow in [_host, _guest]:
		assert_eq(flow.get_round_number(), 2)
		assert_eq(flow.get_phase(), Phase.COUNTDOWN)
	assert_eq(_pair.host.get_local_role(), Role.MONSTER, "the roles swapped")


func test_both_ready_after_the_last_round_starts_a_rematch_in_the_roles_shown() -> void:
	_config.match_rounds = 1
	await _play_round(Role.MONSTER, Role.MONSTER)
	assert_true(_host.is_match_over())
	# The rematch's roles are drawn when the results come up, so that the
	# players choose their perks for the roles they will play.
	var shown: GameEnums.Role = _pair.host.get_local_role()
	assert_eq(_pair.guest.get_local_role(), GameEnums.opposite_role(shown))

	_host.set_ready(true)
	_guest.set_ready(true)
	await wait_frames(6)

	for flow: MatchFlow in [_host, _guest]:
		assert_eq(flow.get_round_number(), 1)
		assert_eq(flow.get_score().get_rounds_played(), 0)
	assert_eq(_pair.host.get_local_role(), shown)


func test_alone_the_computer_is_always_ready() -> void:
	var session: GameSession = add_child_autofree(GameSession.new())
	var network: StubNetworkService = add_child_autofree(StubNetworkService.new())
	session.scene_flow = _pair.host_flow
	session.bind_network(network)
	session.host()
	var flow: MatchFlow = _create_flow(session, _host_combat, _host_perks, _host_input)

	assert_true(flow.is_ready(MatchScore.Player.GUEST))
	assert_false(flow.is_ready(MatchScore.Player.HOST))
	session.leave()


# --- The end of a match ----------------------------------------------------------


func test_a_disconnect_during_a_round_ends_the_match_on_both_devices() -> void:
	await _play_round(Role.SHEEPHERDER, Role.SHEEPHERDER)
	_host.request_next_round()
	await wait_frames(4)
	_pass(_config.round_countdown_duration)
	_host_combat.begin_round(null, null)
	_guest_combat.begin_round(null, null)
	assert_eq(_guest.get_phase(), Phase.ACTIVE)
	watch_signals(_host)
	watch_signals(_guest)

	_end_session()

	for flow: MatchFlow in [_host, _guest]:
		assert_eq(flow.get_phase(), Phase.IDLE)
		assert_false(flow.is_match_running())
		assert_eq(flow.get_round_number(), 0)
		assert_eq(flow.get_score().get_rounds_played(), 0, "the tally is gone")
		assert_null(flow.get_last_result())
		assert_signal_emit_count(flow, &"match_aborted", 1)
		assert_signal_emitted_with(flow, &"phase_changed", [Phase.IDLE])
		assert_signal_not_emitted(flow, &"round_resolved")
	assert_true(_host_input.is_gameplay_enabled(), "the input is free again")
	assert_true(_guest_input.is_gameplay_enabled())
	assert_false(_host_combat.is_round_active())
	assert_false(_guest_combat.is_round_active())
	assert_false(_host_perks.is_selection_locked())
	assert_eq(_pair.host_flow.current_screen, Screen.LOBBY)
	assert_eq(_pair.guest_flow.current_screen, Screen.LOBBY)

	# What the combat service still reports falls on deaf ears.
	_host_combat.monster_shot.emit(Vector2.ZERO)
	_pass(1.0)
	assert_eq(_host.get_phase(), Phase.IDLE)


func test_a_disconnect_without_a_match_aborts_nothing() -> void:
	watch_signals(_host)

	_end_session()

	assert_signal_not_emitted(_host, &"match_aborted")
	assert_signal_not_emitted(_host, &"phase_changed")


func test_after_a_disconnect_a_new_session_plays_a_new_match() -> void:
	_start_active_round(Role.SHEEPHERDER)
	_end_session()

	_pair.connect_both()
	assert_true(_host.start_match(Role.MONSTER))

	assert_eq(_guest.get_phase(), Phase.COUNTDOWN)
	assert_eq(_guest.get_round_number(), 1)
	assert_eq(_pair.guest.get_local_role(), Role.SHEEPHERDER)


func test_the_host_takes_both_devices_back_to_the_lobby() -> void:
	_start_active_round(Role.SHEEPHERDER)
	_host_combat.begin_round(null, null)

	assert_true(_host.request_lobby())
	await wait_frames(4)

	for flow: MatchFlow in [_host, _guest]:
		assert_eq(flow.get_phase(), Phase.IDLE)
		assert_eq(flow.get_score().get_rounds_played(), 0)
	assert_eq(_pair.host_flow.current_screen, Screen.LOBBY)
	assert_eq(_pair.guest_flow.current_screen, Screen.LOBBY)
	assert_true(_guest_input.is_gameplay_enabled())
	assert_false(_host_combat.is_round_active())
	assert_false(_host_perks.is_selection_locked())
	assert_true(_pair.host.is_active(), "the session goes on")


func test_reaching_the_lobby_another_way_ends_the_match_too() -> void:
	await _play_round(Role.SHEEPHERDER, Role.SHEEPHERDER)

	_pair.host.request_screen(Screen.LOBBY)
	await wait_frames(4)

	assert_eq(_host.get_phase(), Phase.IDLE)
	assert_eq(_guest.get_phase(), Phase.IDLE)

	_pair.host.request_screen(Screen.ROUND)
	await wait_frames(4)

	assert_eq(_guest.get_round_number(), 1, "a new match")
	assert_eq(_guest.get_score().get_rounds_played(), 0)


# --- Helpers ---------------------------------------------------------------------


func _create_flow(
	session: GameSession, combat: CombatService, perks: PerkService, input: InputService
) -> MatchFlow:
	var flow: MatchFlow = MatchFlow.new()
	flow.combat = combat
	flow.perks = perks
	flow.input = input
	flow.setup(session)
	# The tests let the time pass themselves.
	flow.set_process(false)
	return add_child_autofree(flow)


## A real perk service for [param session], whose player wants
## [param launch_perks].
func _create_perks(session: GameSession, launch_perks: Array[StringName]) -> SessionPerkService:
	var perks: SessionPerkService = SessionPerkService.new(_config, PerkCatalog.load_default())
	perks.launch_perks = launch_perks
	add_child_autofree(perks)
	perks.setup(session)
	perks.set_process(false)
	return perks


## Lets [param seconds] pass on both clocks and both flows look at them.
func _pass(seconds: float) -> void:
	_time += seconds
	_host.tick()
	_guest.tick()


## Starts a match in which the host plays [param host_role] first and skips
## the countdown.
func _start_active_round(host_role: GameEnums.Role) -> void:
	_host.start_match(host_role)
	_pass(_config.round_countdown_duration)


func _eat(count: int) -> void:
	for index: int in count:
		_host_combat.sheep_killed.emit(index, GameEnums.DeathCause.EATEN, Vector2.ZERO)


## Plays the round that is due to the results screen. [param first_host_role]
## starts a match; without it the round screen must have been entered.
## [param winner] wins by a kill; without a winner the round is a 5 to 5 draw.
func _play_round(first_host_role: GameEnums.Role, winner: GameEnums.Role) -> void:
	if first_host_role != Role.NONE:
		_host.start_match(first_host_role)
	_pass(_config.round_countdown_duration)
	_eat(5)
	match winner:
		Role.SHEEPHERDER:
			_host_combat.monster_shot.emit(Vector2.ZERO)
		Role.MONSTER:
			_host_combat.sheepherder_killed.emit(Vector2.ZERO)
		_:
			_pass(_config.round_duration)
	_pass(0.016)
	_pass(_config.round_resolved_duration)
	await wait_frames(4)


func _end_session() -> void:
	_pair.host_network.simulate_ended(NetworkService.DisconnectReason.REMOTE_CLOSE, "Gone.")
	_pair.guest_network.simulate_ended(NetworkService.DisconnectReason.REMOTE_CLOSE, "Gone.")


## Messages no longer arrive at once: they wait for [method _travel].
func _delay_link() -> void:
	_pair.host.messenger.transmitter = func(reliable: bool, message: Array) -> void:
		_in_transit.append([false, reliable, message.duplicate(true)])
	_pair.guest.messenger.transmitter = func(reliable: bool, message: Array) -> void:
		_in_transit.append([true, reliable, message.duplicate(true)])


## Lets [param seconds] pass and then delivers what was on its way.
func _travel(seconds: float) -> void:
	_time += seconds
	var arriving: Array[Array] = _in_transit.duplicate()
	_in_transit.clear()
	for entry: Array in arriving:
		if entry[0]:
			_pair.host.messenger.receive(entry[1], entry[2], SessionPair.GUEST_ID)
		else:
			_pair.guest.messenger.receive(entry[1], entry[2], SessionPair.HOST_ID)


## With a delayed link: delivers what is on its way, and what that causes,
## until both devices have settled.
func _settle() -> void:
	for _turn: int in 3:
		while not _in_transit.is_empty():
			_travel(0.0)
		await wait_frames(3)
