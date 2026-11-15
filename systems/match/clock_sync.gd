class_name ClockSync
extends RefCounted
## Estimates how far the host's clock is ahead of this device's clock, so a
## guest can show a deadline the host set (the round timer) at the right
## moment.
##
## The guest sends its time, the host answers with its own. Half of the round
## trip is taken as the way back, which is right as long as both ways take
## the same time. The fastest of the last round trips is the least disturbed
## by jitter and resends, so its answer is the one that counts.

## Round trips the estimate looks back on. Older ones are forgotten, so the
## estimate follows clocks that drift apart.
const WINDOW: int = 16

var _round_trips: PackedFloat64Array = []
var _offsets: PackedFloat64Array = []


## Adds a round trip: the question left at [param sent_at] and the answer
## with the other clock's [param remote_time] came at [param received_at],
## both on this device's clock.
func add_sample(sent_at: float, remote_time: float, received_at: float) -> void:
	var round_trip: float = received_at - sent_at
	if round_trip < 0.0:
		return
	_round_trips.append(round_trip)
	_offsets.append(remote_time + round_trip * 0.5 - received_at)
	if _round_trips.size() > WINDOW:
		_round_trips.remove_at(0)
		_offsets.remove_at(0)


## Whether an answer has come yet.
func has_samples() -> bool:
	return not _round_trips.is_empty()


## What to add to this device's clock to get the other one's; 0 before the
## first answer.
func get_offset() -> float:
	var best: int = _best()
	return _offsets[best] if best >= 0 else 0.0


## The round trip of the answer the estimate rests on; 0 before the first.
func get_round_trip() -> float:
	var best: int = _best()
	return _round_trips[best] if best >= 0 else 0.0


func reset() -> void:
	_round_trips.clear()
	_offsets.clear()


func _best() -> int:
	var best: int = -1
	for index: int in _round_trips.size():
		if best < 0 or _round_trips[index] < _round_trips[best]:
			best = index
	return best
