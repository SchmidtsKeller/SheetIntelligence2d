extends TestCase
## The tally of a match (GDD §2.3): round wins, draws, role alternation, and
## the round record as it travels to the other device.

# Aliases for enum types, so they are named like types.
# gdlint: ignore=constant-name
const Role = GameEnums.Role
# gdlint: ignore=constant-name
const RoundOutcome = GameEnums.RoundOutcome
# gdlint: ignore=constant-name
const Player = MatchScore.Player
# gdlint: ignore=constant-name
const Outcome = MatchScore.Outcome

var _score: MatchScore


func before_each() -> void:
	_score = MatchScore.new(5)


func after_each() -> void:
	_score = null


# --- Rounds ----------------------------------------------------------------------


func test_a_new_match_has_no_rounds_and_no_winner() -> void:
	assert_eq(_score.get_rounds_total(), 5)
	assert_eq(_score.get_rounds_played(), 0)
	assert_false(_score.is_over())
	assert_eq(_score.get_outcome(), Outcome.UNDECIDED)
	assert_null(_score.get_last_round())
	assert_eq(_score.get_next_host_role(), Role.NONE, "the first roles are drawn")


func test_the_winner_of_a_round_is_the_player_who_played_the_winning_role() -> void:
	_score.record_round(_round(RoundOutcome.SHEEPHERDER_WIN), Role.SHEEPHERDER)
	_score.record_round(_round(RoundOutcome.SHEEPHERDER_WIN), Role.MONSTER)
	_score.record_round(_round(RoundOutcome.MONSTER_WIN), Role.SHEEPHERDER)
	_score.record_round(_round(RoundOutcome.MONSTER_WIN), Role.MONSTER)

	assert_eq(_score.get_round_winner(0), Player.HOST)
	assert_eq(_score.get_round_winner(1), Player.GUEST)
	assert_eq(_score.get_round_winner(2), Player.GUEST)
	assert_eq(_score.get_round_winner(3), Player.HOST)
	assert_eq(_score.get_round_wins(Player.HOST), 2)
	assert_eq(_score.get_round_wins(Player.GUEST), 2)


func test_a_draw_gives_neither_player_a_round_win() -> void:
	_score.record_round(_round(RoundOutcome.DRAW), Role.SHEEPHERDER)

	assert_eq(_score.get_round_winner(0), -1)
	assert_eq(_score.get_round_wins(Player.HOST), 0)
	assert_eq(_score.get_round_wins(Player.GUEST), 0)
	assert_eq(_score.get_draws(), 1)
	assert_eq(_score.get_rounds_played(), 1, "the round was played")


func test_roles_alternate_after_every_round() -> void:
	_score.record_round(_round(RoundOutcome.DRAW), Role.MONSTER)
	assert_eq(_score.get_next_host_role(), Role.SHEEPHERDER)

	_score.record_round(_round(RoundOutcome.DRAW), _score.get_next_host_role())
	assert_eq(_score.get_next_host_role(), Role.MONSTER)

	_score.record_round(_round(RoundOutcome.DRAW), _score.get_next_host_role())
	assert_eq(_score.get_next_host_role(), Role.SHEEPHERDER)
	assert_eq(_score.get_role_in_round(0, Player.HOST), Role.MONSTER)
	assert_eq(_score.get_role_in_round(0, Player.GUEST), Role.SHEEPHERDER)
	assert_eq(_score.get_role_in_round(1, Player.HOST), Role.SHEEPHERDER)
	assert_eq(_score.get_role_in_round(2, Player.HOST), Role.MONSTER)
	assert_eq(_score.get_role_in_round(3, Player.HOST), Role.NONE, "not played yet")


func test_an_undecided_round_is_not_part_of_the_match() -> void:
	assert_false(_score.record_round(_round(RoundOutcome.UNDECIDED), Role.MONSTER))
	assert_false(_score.record_round(null, Role.MONSTER))
	assert_false(_score.record_round(_round(RoundOutcome.DRAW), Role.NONE))

	assert_eq(_score.get_rounds_played(), 0)


# --- The match -------------------------------------------------------------------


func test_three_to_two_round_wins_the_host_wins_the_match() -> void:
	_play([Player.HOST, Player.GUEST, Player.HOST, Player.GUEST, Player.HOST])

	assert_true(_score.is_over())
	assert_eq(_score.get_outcome(), Outcome.HOST_WIN)
	assert_eq(_score.get_round_wins(Player.HOST), 3)
	assert_eq(_score.get_round_wins(Player.GUEST), 2)


func test_one_to_four_round_wins_the_guest_wins_the_match() -> void:
	_play([Player.GUEST, Player.GUEST, Player.HOST, Player.GUEST, Player.GUEST])

	assert_eq(_score.get_outcome(), Outcome.GUEST_WIN)


func test_two_to_two_with_a_draw_round_is_a_match_draw() -> void:
	_play([Player.HOST, Player.GUEST, -1, Player.GUEST, Player.HOST])

	assert_true(_score.is_over())
	assert_eq(_score.get_outcome(), Outcome.DRAW)
	assert_eq(_score.get_draws(), 1)


func test_five_draw_rounds_are_a_match_draw() -> void:
	_play([-1, -1, -1, -1, -1])

	assert_eq(_score.get_outcome(), Outcome.DRAW)
	assert_eq(_score.get_draws(), 5)


func test_one_win_and_four_draws_win_the_match() -> void:
	_play([-1, -1, Player.GUEST, -1, -1])

	assert_eq(_score.get_outcome(), Outcome.GUEST_WIN)


func test_two_to_one_with_two_draws_wins_the_match() -> void:
	_play([Player.HOST, -1, Player.GUEST, -1, Player.HOST])

	assert_eq(_score.get_outcome(), Outcome.HOST_WIN)


func test_all_five_rounds_are_played_even_when_the_match_is_decided() -> void:
	_play([Player.HOST, Player.HOST, Player.HOST])

	assert_false(_score.is_over(), "three round wins do not end the match")
	assert_eq(_score.get_outcome(), Outcome.UNDECIDED)

	_play([Player.GUEST, Player.GUEST])

	assert_true(_score.is_over())
	assert_eq(_score.get_outcome(), Outcome.HOST_WIN)


func test_no_round_is_recorded_after_the_last_one() -> void:
	_play([Player.HOST, Player.HOST, Player.HOST, Player.HOST, Player.HOST])

	assert_false(_score.record_round(_round(RoundOutcome.DRAW), Role.MONSTER))

	assert_eq(_score.get_rounds_played(), 5)


func test_points_add_up_per_player_across_the_swapping_roles() -> void:
	# Round 1: the host is the Sheepherder, 6 to 4. Round 2: the host is the
	# Monster, 7 to 3 for the Sheepherder.
	_score.record_round(_timeout_round(6, 4), Role.SHEEPHERDER)
	_score.record_round(_timeout_round(7, 3), Role.MONSTER)

	assert_eq(_score.get_total_points(Player.HOST), 6 + 3)
	assert_eq(_score.get_total_points(Player.GUEST), 4 + 7)
	assert_eq(_score.get_round_wins(Player.HOST), 1)
	assert_eq(_score.get_round_wins(Player.GUEST), 1)


func test_points_do_not_decide_the_match() -> void:
	_score = MatchScore.new(1)
	var result: RoundResult = _timeout_round(-4, 9)
	result.outcome = RoundOutcome.SHEEPHERDER_WIN
	result.reason = GameEnums.RoundEndReason.MONSTER_SHOT

	_score.record_round(result, Role.SHEEPHERDER)

	assert_eq(_score.get_outcome(), Outcome.HOST_WIN, "the kill decided the round")
	assert_lt(_score.get_total_points(Player.HOST), _score.get_total_points(Player.GUEST))


func test_the_other_player() -> void:
	assert_eq(MatchScore.other_player(Player.HOST), Player.GUEST)
	assert_eq(MatchScore.other_player(Player.GUEST), Player.HOST)


# --- Plain data ------------------------------------------------------------------


func test_the_tally_survives_the_way_to_the_other_device() -> void:
	_score.record_round(_timeout_round(6, 4), Role.SHEEPHERDER)
	_score.record_round(_round(RoundOutcome.MONSTER_WIN), Role.MONSTER)
	_score.record_round(_round(RoundOutcome.DRAW), Role.SHEEPHERDER)

	# What the transport does with a message.
	var data: Dictionary = bytes_to_var(var_to_bytes(_score.to_data()))
	var copy: MatchScore = MatchScore.from_data(data)

	assert_eq(copy.get_rounds_total(), 5)
	assert_eq(copy.get_rounds_played(), 3)
	assert_eq(copy.get_round_wins(Player.HOST), 2)
	assert_eq(copy.get_round_wins(Player.GUEST), 0)
	assert_eq(copy.get_draws(), 1)
	assert_eq(copy.get_next_host_role(), Role.MONSTER)
	assert_eq(copy.get_total_points(Player.HOST), _score.get_total_points(Player.HOST))
	assert_eq(copy.to_data(), _score.to_data())


func test_a_round_record_survives_the_way_to_the_other_device() -> void:
	var rules: RoundRules = RoundRules.new(RoundSettings.from_config(GameConfig.new()))
	for _i: int in 4:
		rules.report_sheep_eaten()
	rules.report_sheep_shot()
	rules.report_body_eaten()
	rules.report_ammo_depleted()
	rules.advance(42.25)
	rules.report_sheepherder_killed()
	var result: RoundResult = rules.get_result()

	var copy: RoundResult = RoundResult.from_data(bytes_to_var(var_to_bytes(result.to_data())))

	assert_eq(copy.outcome, RoundOutcome.MONSTER_WIN)
	assert_eq(copy.reason, GameEnums.RoundEndReason.SHEEPHERDER_KILLED)
	assert_eq(copy.surviving_sheep, 5)
	assert_eq(copy.shot_sheep, 1)
	assert_eq(copy.eaten_sheep, 4)
	assert_eq(copy.eaten_bodies, 1)
	assert_eq(copy.get_sheepherder_points(), 3)
	assert_eq(copy.get_monster_points(), 4)
	assert_eq(copy.get_points(Role.SHEEPHERDER), 3)
	assert_eq(copy.get_points(Role.MONSTER), 4)
	assert_eq(copy.get_points(Role.NONE), 0)
	assert_almost_eq(copy.time_left, 137.75, 0.0001)
	assert_true(copy.ammo_depleted)
	assert_false(copy.monster_evolved)
	assert_eq(copy.get_winner_role(), Role.MONSTER)
	assert_eq(copy.to_data(), result.to_data())


func test_a_round_record_says_who_won_and_why() -> void:
	var timeout: RoundResult = _timeout_round(6, 4)

	assert_eq(timeout.get_headline(), "The Sheepherder wins the round")
	assert_eq(timeout.get_reason_text(), "Time ran out: 6 to 4 points.")
	assert_eq(_round(RoundOutcome.DRAW).get_headline(), "Draw")
	assert_true(_round(RoundOutcome.MONSTER_WIN).is_decided())
	assert_false(RoundResult.new().is_decided())
	assert_eq(RoundResult.new().get_winner_role(), Role.NONE)


# --- Helpers ---------------------------------------------------------------------


func _round(outcome: GameEnums.RoundOutcome) -> RoundResult:
	var result: RoundResult = RoundResult.new()
	result.outcome = outcome
	return result


## A round that ran out with [param herder_points] to [param monster_points].
func _timeout_round(herder_points: int, monster_points: int) -> RoundResult:
	var result: RoundResult = RoundResult.new()
	result.reason = GameEnums.RoundEndReason.TIMEOUT
	result.herder_surviving_points = herder_points
	result.monster_eaten_points = monster_points
	if herder_points > monster_points:
		result.outcome = RoundOutcome.SHEEPHERDER_WIN
	elif monster_points > herder_points:
		result.outcome = RoundOutcome.MONSTER_WIN
	else:
		result.outcome = RoundOutcome.DRAW
	return result


## Plays rounds with alternating roles that [param winners] win; -1 is a draw.
func _play(winners: Array[int]) -> void:
	for winner: int in winners:
		var host_role: GameEnums.Role = _score.get_next_host_role()
		if host_role == Role.NONE:
			host_role = Role.SHEEPHERDER
		var outcome: GameEnums.RoundOutcome = RoundOutcome.DRAW
		if winner == Player.HOST:
			outcome = (
				RoundOutcome.SHEEPHERDER_WIN
				if host_role == Role.SHEEPHERDER
				else RoundOutcome.MONSTER_WIN
			)
		elif winner == Player.GUEST:
			outcome = (
				RoundOutcome.MONSTER_WIN
				if host_role == Role.SHEEPHERDER
				else RoundOutcome.SHEEPHERDER_WIN
			)
		_score.record_round(_round(outcome), host_role)
