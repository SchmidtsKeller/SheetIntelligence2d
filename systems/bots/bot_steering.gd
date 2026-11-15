class_name BotSteering
extends RefCounted
## Steers a bot's character toward a point with a stick, the way a player
## would: straight at it, and around whatever it runs into.
##
## When the character has hardly moved for a while although it was meant to,
## it walks off at an angle for a moment, to the other side each time.

## Close enough to the point to stop.
const ARRIVED: float = 12.0
## How often it checks whether it is stuck, and what counts as stuck.
const CHECK_INTERVAL: float = 0.8
const STUCK_DISTANCE: float = 12.0
## How long and at which angle it walks around an obstacle.
const SIDESTEP_TIME: float = 0.7
const SIDESTEP_ANGLE: float = 1.25

var _check_left: float = CHECK_INTERVAL
var _checked_at: Vector2 = Vector2.INF
var _sidestep_left: float = 0.0
var _sidestep_sign: float = 1.0


## The stick for walking from [param from] toward [param to] and stopping
## [param stop_at] away from it.
func toward(from: Vector2, to: Vector2, delta: float, stop_at: float = ARRIVED) -> Vector2:
	if from.distance_to(to) <= maxf(stop_at, ARRIVED):
		reset(from)
		return Vector2.ZERO
	return _around_obstacles(from, from.direction_to(to), delta)


## The stick for walking from [param from] away from [param danger].
func away_from(from: Vector2, danger: Vector2, delta: float) -> Vector2:
	var direction: Vector2 = danger.direction_to(from)
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	return _around_obstacles(from, direction, delta)


## Forgets whether it was stuck, for a new walk from [param from].
func reset(from: Vector2) -> void:
	_check_left = CHECK_INTERVAL
	_checked_at = from
	_sidestep_left = 0.0


func _around_obstacles(from: Vector2, direction: Vector2, delta: float) -> Vector2:
	if _checked_at == Vector2.INF:
		_checked_at = from
	_check_left -= delta
	if _check_left <= 0.0:
		if from.distance_to(_checked_at) < STUCK_DISTANCE:
			_sidestep_left = SIDESTEP_TIME
			_sidestep_sign = -_sidestep_sign
		_check_left = CHECK_INTERVAL
		_checked_at = from
	if _sidestep_left > 0.0:
		_sidestep_left -= delta
		return direction.rotated(SIDESTEP_ANGLE * _sidestep_sign)
	return direction
