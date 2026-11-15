extends TestCase
## The rules of a round (GDD §2.2, §2.3): every way a round can end, and what
## both players score. Each test names its scenario.

# Aliases for enum types, so they are named like types.
# gdlint: ignore=constant-name
const Outcome = GameEnums.RoundOutcome
# gdlint: ignore=constant-name
const Reason = GameEnums.RoundEndReason

var _settings: RoundSettings
var _rules: RoundRules


func before_each() -> void:
	_settings = RoundSettings.from_config(GameConfig.new())
	_rules = RoundRules.new(_settings)


func after_each() -> void:
	_settings = null
	_rules = null


# --- Settings --------------------------------------------------------------------


func test_settings_take_the_design_values_from_the_config() -> void:
	assert_eq(_settings.round_duration, 180.0)
	assert_eq(_settings.flock_size, 10)
	assert_eq(_settings.herder_kill_threshold, 5)
	assert_eq(_settings.herder_points_per_surviving_sheep, 1)
	assert_eq(_settings.herder_points_per_shot_sheep, -2)
	assert_eq(_settings.monster_points_per_eaten_sheep, 1)


func test_a_new_round_is_undecided_with_the_full_time_and_flock() -> void:
	assert_false(_rules.is_resolved())
	assert_null(_rules.get_result())
	assert_eq(_rules.get_time_left(), 180.0)
	assert_eq(_rules.get_surviving_sheep(), 10)
	assert_eq(_rules.get_sheepherder_points(), 10)
	assert_eq(_rules.get_monster_points(), 0)
	assert_true(_rules.is_monster_killable())
	assert_false(_rules.can_monster_kill_sheepherder())


# --- The Sheepherder wins --------------------------------------------------------


func test_monster_shot_at_once_sheepherder_wins_with_ten_points() -> void:
	_rules.advance(12.5)

	assert_true(_rules.report_monster_shot())

	var result: RoundResult = _rules.get_result()
	assert_eq(result.outcome, Outcome.SHEEPHERDER_WIN)
	assert_eq(result.reason, Reason.MONSTER_SHOT)
	assert_eq(result.get_sheepherder_points(), 10)
	assert_eq(result.get_monster_points(), 0)
	assert_eq(result.surviving_sheep, 10)
	assert_almost_eq(result.time_left, 167.5, 0.0001)


func test_monster_shot_after_it_ate_nine_sheepherder_still_wins() -> void:
	_eat(9)

	assert_true(_rules.report_monster_shot())

	var result: RoundResult = _rules.get_result()
	assert_eq(result.outcome, Outcome.SHEEPHERDER_WIN)
	assert_eq(result.get_sheepherder_points(), 1, "one sheep survived")
	assert_eq(result.get_monster_points(), 9, "points do not decide a kill")


func test_monster_shot_with_the_last_bullet_sheepherder_wins() -> void:
	# The combat service reports the hit before the empty magazine.
	_rules.report_sheep_shot()
	_rules.report_sheep_shot()

	assert_true(_rules.report_monster_shot())
	_rules.report_ammo_depleted()

	var result: RoundResult = _rules.get_result()
	assert_eq(result.outcome, Outcome.SHEEPHERDER_WIN)
	assert_false(result.ammo_depleted, "the magazine emptied after the round was decided")
	assert_eq(result.get_sheepherder_points(), 8 - 4)


func test_monster_shot_as_the_spider_does_not_count() -> void:
	_eat(10)
	_rules.report_monster_evolved()

	assert_false(_rules.is_monster_killable())
	assert_false(_rules.report_monster_shot())
	assert_false(_rules.is_resolved())


func test_monster_shot_while_eating_its_tenth_sheep_counts() -> void:
	# The spider comes when the tenth meal is finished, not when it starts.
	_eat(10)

	assert_true(_rules.is_monster_killable())
	assert_true(_rules.report_monster_shot())
	assert_eq(_rules.get_result().outcome, Outcome.SHEEPHERDER_WIN)
	assert_eq(_rules.get_result().get_monster_points(), 10)


# --- The Monster wins ------------------------------------------------------------


func test_sheepherder_killed_after_five_eaten_sheep_monster_wins() -> void:
	_eat(5)
	_rules.advance(60.0)

	assert_true(_rules.can_monster_kill_sheepherder())
	assert_true(_rules.report_sheepherder_killed())

	var result: RoundResult = _rules.get_result()
	assert_eq(result.outcome, Outcome.MONSTER_WIN)
	assert_eq(result.reason, Reason.SHEEPHERDER_KILLED)
	assert_eq(result.get_monster_points(), 5)
	assert_eq(result.get_sheepherder_points(), 5)
	assert_eq(result.eaten_sheep, 5)
	assert_almost_eq(result.time_left, 120.0, 0.0001)


func test_sheepherder_killed_after_four_eaten_sheep_does_not_count() -> void:
	_eat(4)

	assert_false(_rules.can_monster_kill_sheepherder())
	assert_false(_rules.report_sheepherder_killed())
	assert_false(_rules.is_resolved())


func test_sheepherder_killed_by_the_spider_monster_wins() -> void:
	_eat(10)
	_rules.report_monster_evolved()

	assert_true(_rules.report_sheepherder_killed())

	var result: RoundResult = _rules.get_result()
	assert_eq(result.outcome, Outcome.MONSTER_WIN)
	assert_true(result.monster_evolved)
	assert_eq(result.get_monster_points(), 10)
	assert_eq(result.get_sheepherder_points(), 0)
	assert_eq(result.surviving_sheep, 0)


func test_shot_sheep_the_monster_ate_count_toward_the_kill_but_give_no_points() -> void:
	_eat(3)
	_rules.report_sheep_shot()
	_rules.report_sheep_shot()
	assert_true(_rules.report_body_eaten())
	assert_false(_rules.can_monster_kill_sheepherder(), "four eaten")
	assert_true(_rules.report_body_eaten())

	assert_eq(_rules.get_eaten_total(), 5)
	assert_true(_rules.report_sheepherder_killed())

	var result: RoundResult = _rules.get_result()
	assert_eq(result.outcome, Outcome.MONSTER_WIN)
	assert_eq(result.eaten_sheep, 3)
	assert_eq(result.eaten_bodies, 2)
	assert_eq(result.get_monster_points(), 3, "only the sheep it ate alive")
	assert_eq(result.get_sheepherder_points(), 5 - 4)


func test_a_body_can_only_be_eaten_if_a_sheep_was_shot() -> void:
	assert_false(_rules.report_body_eaten())

	_rules.report_sheep_shot()
	assert_true(_rules.report_body_eaten())
	assert_false(_rules.report_body_eaten(), "one body, one meal")

	assert_eq(_rules.get_eaten_bodies(), 1)


# --- Timeout ---------------------------------------------------------------------


func test_timeout_with_nothing_eaten_sheepherder_wins_ten_to_zero() -> void:
	_rules.advance(180.0)

	var result: RoundResult = _rules.get_result()
	assert_eq(result.outcome, Outcome.SHEEPHERDER_WIN)
	assert_eq(result.reason, Reason.TIMEOUT)
	assert_eq(result.get_sheepherder_points(), 10)
	assert_eq(result.get_monster_points(), 0)
	assert_eq(result.time_left, 0.0)


func test_timeout_after_four_eaten_sheep_sheepherder_wins_six_to_four() -> void:
	_eat(4)

	_rules.advance(180.0)

	assert_eq(_rules.get_result().outcome, Outcome.SHEEPHERDER_WIN)
	assert_eq(_rules.get_result().get_sheepherder_points(), 6)
	assert_eq(_rules.get_result().get_monster_points(), 4)


func test_timeout_after_five_eaten_sheep_is_a_draw_five_to_five() -> void:
	_eat(5)

	_rules.advance(180.0)

	var result: RoundResult = _rules.get_result()
	assert_eq(result.outcome, Outcome.DRAW)
	assert_eq(result.reason, Reason.TIMEOUT)
	assert_eq(result.get_sheepherder_points(), 5)
	assert_eq(result.get_monster_points(), 5)
	assert_eq(result.get_winner_role(), GameEnums.Role.NONE)


func test_timeout_after_six_eaten_sheep_monster_wins_six_to_four() -> void:
	_eat(6)

	_rules.advance(180.0)

	assert_eq(_rules.get_result().outcome, Outcome.MONSTER_WIN)
	assert_eq(_rules.get_result().get_sheepherder_points(), 4)
	assert_eq(_rules.get_result().get_monster_points(), 6)


func test_timeout_after_one_shot_sheep_sheepherder_wins_seven_to_zero() -> void:
	_rules.report_sheep_shot()

	_rules.advance(180.0)

	var result: RoundResult = _rules.get_result()
	assert_eq(result.outcome, Outcome.SHEEPHERDER_WIN)
	assert_eq(result.herder_surviving_points, 9)
	assert_eq(result.herder_shot_points, -2)
	assert_eq(result.get_sheepherder_points(), 7)


func test_timeout_shot_sheep_penalty_turns_a_lead_into_a_loss() -> void:
	# 10 sheep: 3 eaten, 2 shot, 5 alive. Sheepherder 5 - 4 = 1, Monster 3.
	_eat(3)
	_rules.report_sheep_shot()
	_rules.report_sheep_shot()

	_rules.advance(180.0)

	var result: RoundResult = _rules.get_result()
	assert_eq(result.outcome, Outcome.MONSTER_WIN)
	assert_eq(result.get_sheepherder_points(), 1)
	assert_eq(result.get_monster_points(), 3)
	assert_eq(result.surviving_sheep, 5)
	assert_eq(result.shot_sheep, 2)


func test_timeout_shot_sheep_penalty_makes_a_draw() -> void:
	# 10 sheep: 2 eaten, 2 shot, 6 alive. Sheepherder 6 - 4 = 2, Monster 2.
	_eat(2)
	_rules.report_sheep_shot()
	_rules.report_sheep_shot()

	_rules.advance(180.0)

	assert_eq(_rules.get_result().outcome, Outcome.DRAW)
	assert_eq(_rules.get_result().get_sheepherder_points(), 2)
	assert_eq(_rules.get_result().get_monster_points(), 2)


func test_timeout_three_shot_sheep_give_the_sheepherder_a_negative_score() -> void:
	# 10 sheep: 6 eaten, 3 shot, 1 alive. Sheepherder 1 - 6 = -5, Monster 6.
	_eat(6)
	for _i: int in 3:
		_rules.report_sheep_shot()

	_rules.advance(180.0)

	assert_eq(_rules.get_result().outcome, Outcome.MONSTER_WIN)
	assert_eq(_rules.get_result().get_sheepherder_points(), -5)


func test_timeout_eaten_bodies_give_the_monster_nothing() -> void:
	# 10 sheep: 2 shot and then eaten, 8 alive. Sheepherder 8 - 4 = 4, Monster 0.
	_rules.report_sheep_shot()
	_rules.report_sheep_shot()
	_rules.report_body_eaten()
	_rules.report_body_eaten()

	_rules.advance(180.0)

	var result: RoundResult = _rules.get_result()
	assert_eq(result.outcome, Outcome.SHEEPHERDER_WIN)
	assert_eq(result.get_sheepherder_points(), 4)
	assert_eq(result.get_monster_points(), 0)
	assert_eq(result.eaten_bodies, 2)


func test_timeout_with_the_spider_alive_and_the_sheepherder_alive_points_decide() -> void:
	_eat(10)
	_rules.report_monster_evolved()

	_rules.advance(180.0)

	assert_eq(_rules.get_result().outcome, Outcome.MONSTER_WIN)
	assert_eq(_rules.get_result().reason, Reason.TIMEOUT)
	assert_eq(_rules.get_result().get_monster_points(), 10)


func test_the_time_runs_down_in_steps() -> void:
	_rules.advance(100.0)
	_rules.advance(79.5)

	assert_false(_rules.is_resolved())
	assert_almost_eq(_rules.get_time_left(), 0.5, 0.0001)

	_rules.advance(0.6)

	assert_true(_rules.is_resolved())
	assert_eq(_rules.get_time_left(), 0.0)


func test_time_does_not_run_backwards() -> void:
	_rules.advance(-5.0)

	assert_eq(_rules.get_time_left(), 180.0)


# --- Ammo depletion --------------------------------------------------------------


func test_ammo_depleted_monster_is_unkillable_and_the_round_goes_on() -> void:
	_rules.report_ammo_depleted()

	assert_false(_rules.is_monster_killable())
	assert_false(_rules.report_monster_shot())
	assert_false(_rules.is_resolved(), "the round goes on")


func test_ammo_depleted_then_timeout_points_decide() -> void:
	for _i: int in 3:
		_rules.report_sheep_shot()
	_rules.report_ammo_depleted()

	_rules.advance(180.0)

	var result: RoundResult = _rules.get_result()
	assert_eq(result.reason, Reason.TIMEOUT)
	assert_eq(result.outcome, Outcome.SHEEPHERDER_WIN)
	assert_eq(result.get_sheepherder_points(), 7 - 6)
	assert_true(result.ammo_depleted)


func test_ammo_depleted_then_the_monster_kills_the_sheepherder() -> void:
	_rules.report_ammo_depleted()
	_eat(5)

	assert_true(_rules.report_sheepherder_killed())

	assert_eq(_rules.get_result().outcome, Outcome.MONSTER_WIN)
	assert_true(_rules.get_result().ammo_depleted)


# --- Order of events -------------------------------------------------------------


func test_same_tick_the_first_lethal_event_decides() -> void:
	_eat(5)

	assert_true(_rules.report_monster_shot())
	assert_false(_rules.report_sheepherder_killed(), "the round is already decided")

	assert_eq(_rules.get_result().outcome, Outcome.SHEEPHERDER_WIN)


func test_same_tick_the_kill_of_the_sheepherder_first_decides_for_the_monster() -> void:
	_eat(5)

	assert_true(_rules.report_sheepherder_killed())
	assert_false(_rules.report_monster_shot())

	assert_eq(_rules.get_result().outcome, Outcome.MONSTER_WIN)


func test_same_tick_a_kill_beats_the_timeout() -> void:
	_rules.advance(179.99)

	# The host reports the events of a tick before it lets the time pass.
	assert_true(_rules.report_monster_shot())
	_rules.advance(0.02)

	assert_eq(_rules.get_result().reason, Reason.MONSTER_SHOT)
	assert_almost_eq(_rules.get_result().time_left, 0.01, 0.0001)


func test_after_the_timeout_a_kill_changes_nothing() -> void:
	_eat(5)
	_rules.advance(180.0)

	assert_false(_rules.report_sheepherder_killed())
	assert_false(_rules.report_monster_shot())

	assert_eq(_rules.get_result().outcome, Outcome.DRAW)


func test_a_decided_round_does_not_change_anymore() -> void:
	_rules.report_monster_shot()
	var result: RoundResult = _rules.get_result()

	assert_false(_rules.report_sheep_eaten())
	assert_false(_rules.report_sheep_shot())
	_rules.report_monster_evolved()
	_rules.report_ammo_depleted()
	_rules.advance(500.0)

	assert_eq(_rules.get_result(), result, "the same record")
	assert_eq(result.get_sheepherder_points(), 10)
	assert_eq(_rules.get_time_left(), 180.0, "the timer stands still")


# --- Bounds ----------------------------------------------------------------------


func test_all_sheep_dead_and_nobody_won_the_round_runs_to_the_timeout() -> void:
	_eat(7)
	for _i: int in 3:
		_rules.report_sheep_shot()

	assert_eq(_rules.get_surviving_sheep(), 0)
	assert_false(_rules.is_resolved())

	_rules.advance(180.0)

	assert_eq(_rules.get_result().outcome, Outcome.MONSTER_WIN)
	assert_eq(_rules.get_result().get_sheepherder_points(), -6)
	assert_eq(_rules.get_result().get_monster_points(), 7)


func test_no_more_sheep_can_die_than_the_flock_has() -> void:
	_eat(10)

	assert_false(_rules.report_sheep_eaten())
	assert_false(_rules.report_sheep_shot())

	assert_eq(_rules.get_eaten_sheep(), 10)
	assert_eq(_rules.get_shot_sheep(), 0)
	assert_eq(_rules.get_surviving_sheep(), 0)


func test_other_numbers_change_the_score() -> void:
	_settings.flock_size = 6
	_settings.herder_points_per_surviving_sheep = 2
	_settings.herder_points_per_shot_sheep = -3
	_settings.monster_points_per_eaten_sheep = 4
	_settings.round_duration = 30.0
	_rules = RoundRules.new(_settings)
	_eat(2)
	_rules.report_sheep_shot()

	_rules.advance(30.0)

	var result: RoundResult = _rules.get_result()
	assert_eq(result.get_sheepherder_points(), 3 * 2 - 3)
	assert_eq(result.get_monster_points(), 8)
	assert_eq(result.outcome, Outcome.MONSTER_WIN)


func test_another_kill_threshold_unlocks_the_kill_earlier() -> void:
	_settings.herder_kill_threshold = 2
	_rules = RoundRules.new(_settings)
	_eat(2)

	assert_true(_rules.report_sheepherder_killed())


func _eat(count: int) -> void:
	for _i: int in count:
		_rules.report_sheep_eaten()
