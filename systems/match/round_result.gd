class_name RoundResult
extends RefCounted
## The record of one finished round (GDD §2.2, §2.3): who won, why, and what
## both players scored.
##
## The [RoundRules] write it on the host; it travels to the guest as plain
## data ([method to_data], [method from_data]), so both devices show the same
## numbers.

var outcome: GameEnums.RoundOutcome = GameEnums.RoundOutcome.UNDECIDED
var reason: GameEnums.RoundEndReason = GameEnums.RoundEndReason.NONE

## NPC sheep alive when the round ended.
var surviving_sheep: int = 0
## NPC sheep the Sheepherder shot.
var shot_sheep: int = 0
## NPC sheep the Monster ate alive. Only these give it points.
var eaten_sheep: int = 0
## Bodies of shot sheep the Monster ate. They count for its evolution only.
var eaten_bodies: int = 0

## The Sheepherder's points for the surviving sheep.
var herder_surviving_points: int = 0
## The Sheepherder's points for the sheep they shot: zero or negative.
var herder_shot_points: int = 0
## The Monster's points for the sheep it ate alive.
var monster_eaten_points: int = 0

## Seconds that were left on the timer; 0 after a timeout.
var time_left: float = 0.0
## Whether the Sheepherder had fired the last bullet.
var ammo_depleted: bool = false
## Whether the Monster had become the spider.
var monster_evolved: bool = false


func get_sheepherder_points() -> int:
	return herder_surviving_points + herder_shot_points


func get_monster_points() -> int:
	return monster_eaten_points


## The points of the player who played [param role] in this round.
func get_points(role: GameEnums.Role) -> int:
	match role:
		GameEnums.Role.SHEEPHERDER:
			return get_sheepherder_points()
		GameEnums.Role.MONSTER:
			return get_monster_points()
		_:
			return 0


## The role that won the round; [constant GameEnums.Role.NONE] for a draw and
## for a round that was not decided.
func get_winner_role() -> GameEnums.Role:
	match outcome:
		GameEnums.RoundOutcome.SHEEPHERDER_WIN:
			return GameEnums.Role.SHEEPHERDER
		GameEnums.RoundOutcome.MONSTER_WIN:
			return GameEnums.Role.MONSTER
		_:
			return GameEnums.Role.NONE


## Whether a player won the round or it ended in a draw.
func is_decided() -> bool:
	return outcome != GameEnums.RoundOutcome.UNDECIDED


## One line for the screen: who won.
func get_headline() -> String:
	match outcome:
		GameEnums.RoundOutcome.SHEEPHERDER_WIN:
			return "The Sheepherder wins the round"
		GameEnums.RoundOutcome.MONSTER_WIN:
			return "The Monster wins the round"
		GameEnums.RoundOutcome.DRAW:
			return "Draw"
		_:
			return "The round was not decided"


## One line for the screen: why the round ended.
func get_reason_text() -> String:
	match reason:
		GameEnums.RoundEndReason.MONSTER_SHOT:
			return "The Monster was shot."
		GameEnums.RoundEndReason.SHEEPHERDER_KILLED:
			return "The Sheepherder was killed."
		GameEnums.RoundEndReason.TIMEOUT:
			return (
				"Time ran out: %d to %d points." % [get_sheepherder_points(), get_monster_points()]
			)
		GameEnums.RoundEndReason.ABORTED:
			return "The round was stopped."
		_:
			return ""


## The record as plain data, for [SyncedState].
func to_data() -> Dictionary:
	return {
		"outcome": outcome,
		"reason": reason,
		"surviving": surviving_sheep,
		"shot": shot_sheep,
		"eaten": eaten_sheep,
		"bodies": eaten_bodies,
		"surviving_points": herder_surviving_points,
		"shot_points": herder_shot_points,
		"eaten_points": monster_eaten_points,
		"time_left": time_left,
		"ammo_depleted": ammo_depleted,
		"evolved": monster_evolved,
	}


## The record that [method to_data] wrote. Missing entries keep their default.
static func from_data(data: Dictionary) -> RoundResult:
	var result: RoundResult = RoundResult.new()
	result.outcome = data.get("outcome", GameEnums.RoundOutcome.UNDECIDED)
	result.reason = data.get("reason", GameEnums.RoundEndReason.NONE)
	result.surviving_sheep = data.get("surviving", 0)
	result.shot_sheep = data.get("shot", 0)
	result.eaten_sheep = data.get("eaten", 0)
	result.eaten_bodies = data.get("bodies", 0)
	result.herder_surviving_points = data.get("surviving_points", 0)
	result.herder_shot_points = data.get("shot_points", 0)
	result.monster_eaten_points = data.get("eaten_points", 0)
	result.time_left = data.get("time_left", 0.0)
	result.ammo_depleted = data.get("ammo_depleted", false)
	result.monster_evolved = data.get("evolved", false)
	return result
