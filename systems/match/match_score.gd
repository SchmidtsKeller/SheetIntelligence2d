class_name MatchScore
extends RefCounted
## The tally of a match (GDD §2.3): a fixed number of rounds, decided by round
## wins. Pure logic, like the [RoundRules].
##
## The roles swap after every round, so the tally counts for the two
## [enum Player]s, the host and the guest, and remembers which role the host
## played in each round. All rounds are played, also when one player cannot
## be caught up anymore. Equal round wins after the last round are a draw.

## The two players of a match, whatever role they play in a round.
enum Player {
	HOST,
	GUEST,
}

## How a match stands or ended.
enum Outcome {
	## Rounds are still to be played.
	UNDECIDED,
	HOST_WIN,
	GUEST_WIN,
	## Both players won the same number of rounds.
	DRAW,
}

var _rounds_total: int = 0
var _results: Array[RoundResult] = []
var _host_roles: Array[GameEnums.Role] = []


func _init(rounds_total: int = 0) -> void:
	_rounds_total = maxi(rounds_total, 0)


## The other player.
static func other_player(player: Player) -> Player:
	return Player.GUEST if player == Player.HOST else Player.HOST


# --- Recording -------------------------------------------------------------------


## Adds a finished round in which the host played [param host_role]. Returns
## [code]false[/code] once all rounds are played, or if the round was not
## decided: a round that was stopped is not part of the match.
func record_round(result: RoundResult, host_role: GameEnums.Role) -> bool:
	if is_over() or result == null or not result.is_decided():
		return false
	if host_role == GameEnums.Role.NONE:
		return false
	_results.append(result)
	_host_roles.append(host_role)
	return true


# --- The rounds ------------------------------------------------------------------


## Rounds in the match.
func get_rounds_total() -> int:
	return _rounds_total


## Rounds that are finished.
func get_rounds_played() -> int:
	return _results.size()


## The record of the round with [param index], counted from 0.
func get_round(index: int) -> RoundResult:
	return _results[index] if index >= 0 and index < _results.size() else null


## The record of the round that finished last; [code]null[/code] before the
## first one.
func get_last_round() -> RoundResult:
	return get_round(_results.size() - 1)


## The role [param player] played in the round with [param index].
func get_role_in_round(index: int, player: Player) -> GameEnums.Role:
	if index < 0 or index >= _host_roles.size():
		return GameEnums.Role.NONE
	var host_role: GameEnums.Role = _host_roles[index]
	return host_role if player == Player.HOST else GameEnums.opposite_role(host_role)


## The player who won the round with [param index], or -1 for a draw.
func get_round_winner(index: int) -> int:
	var result: RoundResult = get_round(index)
	if result == null or result.get_winner_role() == GameEnums.Role.NONE:
		return -1
	if result.get_winner_role() == get_role_in_round(index, Player.HOST):
		return Player.HOST
	return Player.GUEST


## The role the host plays in the next round: the other one than in the last
## round (GDD §2.3). [constant GameEnums.Role.NONE] before the first round,
## where the roles are drawn.
func get_next_host_role() -> GameEnums.Role:
	if _host_roles.is_empty():
		return GameEnums.Role.NONE
	return GameEnums.opposite_role(_host_roles[-1])


# --- The standing ----------------------------------------------------------------


## Rounds [param player] won.
func get_round_wins(player: Player) -> int:
	var wins: int = 0
	for index: int in _results.size():
		if get_round_winner(index) == player:
			wins += 1
	return wins


## Rounds that ended in a draw. They give neither player a round win.
func get_draws() -> int:
	var draws: int = 0
	for result: RoundResult in _results:
		if result.outcome == GameEnums.RoundOutcome.DRAW:
			draws += 1
	return draws


## The points [param player] scored in all rounds. They are shown, but only
## round wins decide the match.
func get_total_points(player: Player) -> int:
	var points: int = 0
	for index: int in _results.size():
		points += _results[index].get_points(get_role_in_round(index, player))
	return points


## Whether all rounds are played.
func is_over() -> bool:
	return _results.size() >= _rounds_total


## Who won the match; [constant Outcome.UNDECIDED] while rounds are left.
func get_outcome() -> Outcome:
	if not is_over():
		return Outcome.UNDECIDED
	var host_wins: int = get_round_wins(Player.HOST)
	var guest_wins: int = get_round_wins(Player.GUEST)
	if host_wins > guest_wins:
		return Outcome.HOST_WIN
	if guest_wins > host_wins:
		return Outcome.GUEST_WIN
	return Outcome.DRAW


# --- Plain data ------------------------------------------------------------------


## The tally as plain data, for [SyncedState].
func to_data() -> Dictionary:
	var rounds: Array = []
	for index: int in _results.size():
		rounds.append({"host_role": _host_roles[index], "result": _results[index].to_data()})
	return {"total": _rounds_total, "rounds": rounds}


## The tally that [method to_data] wrote.
static func from_data(data: Dictionary) -> MatchScore:
	var score: MatchScore = MatchScore.new(data.get("total", 0))
	var rounds: Array = data.get("rounds", [])
	for entry: Dictionary in rounds:
		score.record_round(
			RoundResult.from_data(entry.get("result", {})),
			entry.get("host_role", GameEnums.Role.NONE)
		)
	return score
