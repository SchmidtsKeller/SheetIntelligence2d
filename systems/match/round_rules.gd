class_name RoundRules
extends RefCounted
## The rules of one round (GDD §2.2, §2.3): who wins, when, and with how many
## points. Pure logic: it knows no scene, no session and no clock.
##
## The host's [MatchFlow] reports what happens ([code]report_…[/code]) and
## lets the time pass ([method advance]); the rules answer with the
## [RoundResult] once the round is decided.
##
## [b]Order of events.[/b] A round is decided by the first of these:
## [br]1. A lethal event, in the order the host reports them. The Monster is
## shot before its evolution and while the Sheepherder had a bullet for it:
## the Sheepherder wins. The Sheepherder is killed after the Monster ate
## enough, or by the spider: the Monster wins. The first one decides; whatever
## is reported afterwards changes nothing.
## [br]2. The timer. It is checked after the events of the same tick, so a kill
## that lands in the tick in which the time runs out still counts. On a
## timeout the player with more points wins; equal points are a draw.

var _settings: RoundSettings
var _time_left: float = 0.0
var _eaten_sheep: int = 0
var _eaten_bodies: int = 0
var _shot_sheep: int = 0
var _ammo_depleted: bool = false
var _monster_evolved: bool = false
var _result: RoundResult = null


func _init(settings: RoundSettings) -> void:
	_settings = settings
	_time_left = maxf(settings.round_duration, 0.0)


# --- Time ------------------------------------------------------------------------


## Lets [param delta] seconds pass. When the time runs out, the points decide.
func advance(delta: float) -> void:
	if is_resolved():
		return
	_time_left = maxf(_time_left - maxf(delta, 0.0), 0.0)
	if _time_left <= 0.0:
		_resolve_on_points()


## Seconds until the timeout. Stands still once the round is decided.
func get_time_left() -> float:
	return _time_left


# --- What happened ---------------------------------------------------------------


## The Monster ate a living NPC sheep. Returns whether it counted.
func report_sheep_eaten() -> bool:
	if is_resolved() or get_surviving_sheep() <= 0:
		return false
	_eaten_sheep += 1
	return true


## The Monster ate the body of a sheep the Sheepherder had shot. It gives no
## points, but counts toward the kill and the evolution.
func report_body_eaten() -> bool:
	if is_resolved() or _eaten_bodies >= _shot_sheep:
		return false
	_eaten_bodies += 1
	return true


## The Sheepherder shot an NPC sheep.
func report_sheep_shot() -> bool:
	if is_resolved() or get_surviving_sheep() <= 0:
		return false
	_shot_sheep += 1
	return true


## The Sheepherder fired the last bullet: the Monster cannot be killed anymore
## and the round goes on until a kill or the timeout.
func report_ammo_depleted() -> void:
	if not is_resolved():
		_ammo_depleted = true


## The Monster became the spider: it cannot be killed anymore.
func report_monster_evolved() -> void:
	if not is_resolved():
		_monster_evolved = true


## The Sheepherder shot the Monster. Decides the round for the Sheepherder,
## unless the Monster could not be killed. Returns whether it decided the round.
func report_monster_shot() -> bool:
	if is_resolved() or not is_monster_killable():
		return false
	_resolve(GameEnums.RoundOutcome.SHEEPHERDER_WIN, GameEnums.RoundEndReason.MONSTER_SHOT)
	return true


## The Monster killed the Sheepherder. Decides the round for the Monster,
## unless it had not eaten enough. Returns whether it decided the round.
func report_sheepherder_killed() -> bool:
	if is_resolved() or not can_monster_kill_sheepherder():
		return false
	_resolve(GameEnums.RoundOutcome.MONSTER_WIN, GameEnums.RoundEndReason.SHEEPHERDER_KILLED)
	return true


# --- The state of the round ------------------------------------------------------


## Whether the round is over.
func is_resolved() -> bool:
	return _result != null


## The record of the round; [code]null[/code] while it is running.
func get_result() -> RoundResult:
	return _result


## Whether a bullet would kill the Monster: not the spider, and not after the
## last bullet was fired.
func is_monster_killable() -> bool:
	return not _monster_evolved and not _ammo_depleted


## Whether the Monster may kill the Sheepherder: after enough sheep, or as the
## spider.
func can_monster_kill_sheepherder() -> bool:
	return _monster_evolved or get_eaten_total() >= _settings.herder_kill_threshold


## NPC sheep that are still alive.
func get_surviving_sheep() -> int:
	return _settings.flock_size - _eaten_sheep - _shot_sheep


## Sheep the Monster ate alive.
func get_eaten_sheep() -> int:
	return _eaten_sheep


## Bodies of shot sheep the Monster ate.
func get_eaten_bodies() -> int:
	return _eaten_bodies


## Everything the Monster ate, alive or shot: what its evolution counts.
func get_eaten_total() -> int:
	return _eaten_sheep + _eaten_bodies


## Sheep the Sheepherder shot.
func get_shot_sheep() -> int:
	return _shot_sheep


## What the Sheepherder would score if the round ended now.
func get_sheepherder_points() -> int:
	return (
		get_surviving_sheep() * _settings.herder_points_per_surviving_sheep
		+ _shot_sheep * _settings.herder_points_per_shot_sheep
	)


## What the Monster would score if the round ended now.
func get_monster_points() -> int:
	return _eaten_sheep * _settings.monster_points_per_eaten_sheep


# --- Internals -------------------------------------------------------------------


func _resolve_on_points() -> void:
	var herder_points: int = get_sheepherder_points()
	var monster_points: int = get_monster_points()
	var outcome: GameEnums.RoundOutcome = GameEnums.RoundOutcome.DRAW
	if herder_points > monster_points:
		outcome = GameEnums.RoundOutcome.SHEEPHERDER_WIN
	elif monster_points > herder_points:
		outcome = GameEnums.RoundOutcome.MONSTER_WIN
	_resolve(outcome, GameEnums.RoundEndReason.TIMEOUT)


func _resolve(outcome: GameEnums.RoundOutcome, reason: GameEnums.RoundEndReason) -> void:
	var result: RoundResult = RoundResult.new()
	result.outcome = outcome
	result.reason = reason
	result.surviving_sheep = get_surviving_sheep()
	result.shot_sheep = _shot_sheep
	result.eaten_sheep = _eaten_sheep
	result.eaten_bodies = _eaten_bodies
	result.herder_surviving_points = (
		get_surviving_sheep() * _settings.herder_points_per_surviving_sheep
	)
	result.herder_shot_points = _shot_sheep * _settings.herder_points_per_shot_sheep
	result.monster_eaten_points = get_monster_points()
	result.time_left = _time_left
	result.ammo_depleted = _ammo_depleted
	result.monster_evolved = _monster_evolved
	_result = result
