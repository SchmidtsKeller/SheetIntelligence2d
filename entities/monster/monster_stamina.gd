class_name MonsterStamina
extends RefCounted
## The Monster's sprint stamina (GDD §3.2, §5), counted in seconds of
## sprinting that are left.
##
## Sprinting uses it up one second per second; otherwise it refills at the
## refill rate. A Monster that ran out has to let go of the sprint button
## before it can sprint again, so holding the button does not turn every
## refilled moment straight into another step at sprint speed.

var _left: float = 0.0
var _capacity: float = 0.0
var _sprinting: bool = false
var _exhausted: bool = false


func _init(capacity: float = 0.0) -> void:
	reset(capacity)


## Fills the meter to [param capacity] seconds of sprinting.
func reset(capacity: float) -> void:
	_capacity = maxf(capacity, 0.0)
	_left = _capacity
	_sprinting = false
	_exhausted = false


## Moves the meter forward by [param delta] seconds and returns whether the
## Monster sprints during that time.
## [br][param held]: the sprint button is down. [param moving]: the Monster
## walks, so sprinting would do something; standing still costs nothing.
## [br][param capacity] and [param refill_rate] are the current stats: seconds
## of sprinting a full meter holds, and seconds regained per second.
func advance(
	delta: float, held: bool, moving: bool, capacity: float, refill_rate: float
) -> bool:
	_capacity = maxf(capacity, 0.0)
	if not held:
		_exhausted = false
	_sprinting = held and moving and not _exhausted and _left > 0.0
	if _sprinting:
		_left = maxf(_left - delta, 0.0)
		_exhausted = _left == 0.0
	else:
		_left = minf(_left + refill_rate * delta, _capacity)
	return _sprinting


## Seconds of sprinting left.
func get_left() -> float:
	return _left


## Seconds of sprinting a full meter holds.
func get_capacity() -> float:
	return _capacity


## How full the meter is, from 0 (empty) to 1 (full).
func get_ratio() -> float:
	return _left / _capacity if _capacity > 0.0 else 0.0


## Whether the last [method advance] was spent sprinting.
func is_sprinting() -> bool:
	return _sprinting


## Whether the meter ran empty and the sprint button has not been let go since.
func is_exhausted() -> bool:
	return _exhausted
