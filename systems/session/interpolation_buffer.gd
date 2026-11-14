class_name InterpolationBuffer
extends RefCounted
## Time-stamped 2D transforms and the interpolation between them.
##
## Every replicated entity is drawn a little in the past, between two states
## that have already arrived. That hides the gaps and the jitter of the
## network: as long as packets arrive within the interpolation delay, motion
## is smooth. If nothing newer has arrived, the entity keeps its last course
## for at most [member max_extrapolation] seconds and then stands still.

## The number of samples kept. At 20 snapshots per second this is 1.6 s.
const MAX_SAMPLES: int = 32

## Seconds an entity keeps moving on its last course past the newest sample.
var max_extrapolation: float = 0.1

## A step longer than this between two samples is a teleport (a respawn): the
## entity jumps instead of sliding across the map.
var teleport_distance: float = 400.0

var _times: PackedFloat64Array = []
var _positions: PackedVector2Array = []
var _rotations: PackedFloat32Array = []
var _flags: PackedInt32Array = []


## Adds a sample. Samples that are not newer than the newest one are ignored,
## so late and duplicated packets do no harm. [param flags] is state that
## cannot be interpolated (e.g. "is grazing"); it travels with the transform,
## so it is shown at the same delayed moment.
func push(time: float, position: Vector2, rotation: float, flags: int = 0) -> void:
	if not _times.is_empty() and time <= _times[-1]:
		return
	_times.append(time)
	_positions.append(position)
	_rotations.append(rotation)
	_flags.append(flags)
	if _times.size() > MAX_SAMPLES:
		_times.remove_at(0)
		_positions.remove_at(0)
		_rotations.remove_at(0)
		_flags.remove_at(0)


func is_empty() -> bool:
	return _times.is_empty()


func size() -> int:
	return _times.size()


func clear() -> void:
	_times.clear()
	_positions.clear()
	_rotations.clear()
	_flags.clear()


## The time of the newest sample; 0 when empty.
func get_latest_time() -> float:
	return _times[-1] if not _times.is_empty() else 0.0


## The position at [param time]. [constant Vector2.ZERO] when empty.
func sample_position(time: float) -> Vector2:
	if _times.is_empty():
		return Vector2.ZERO
	var last: int = _times.size() - 1
	if time <= _times[0]:
		return _positions[0]
	if time >= _times[last]:
		return _extrapolated_position(time)
	var index: int = _segment_before(time)
	var from: Vector2 = _positions[index]
	var to: Vector2 = _positions[index + 1]
	if from.distance_to(to) > teleport_distance:
		return from
	return from.lerp(to, _segment_weight(index, time))


## The rotation in radians at [param time], taking the shorter way around.
## 0 when empty. Rotation is never extrapolated.
func sample_rotation(time: float) -> float:
	if _times.is_empty():
		return 0.0
	var last: int = _times.size() - 1
	if time <= _times[0]:
		return _rotations[0]
	if time >= _times[last]:
		return _rotations[last]
	var index: int = _segment_before(time)
	return lerp_angle(_rotations[index], _rotations[index + 1], _segment_weight(index, time))


## The flags at [param time]: those of the newest sample that is not after
## it. 0 when empty.
func sample_flags(time: float) -> int:
	if _times.is_empty():
		return 0
	var last: int = _times.size() - 1
	if time <= _times[0]:
		return _flags[0]
	if time >= _times[last]:
		return _flags[last]
	return _flags[_segment_before(time)]


func _extrapolated_position(time: float) -> Vector2:
	var last: int = _times.size() - 1
	if last == 0 or max_extrapolation <= 0.0:
		return _positions[last]
	var step_time: float = _times[last] - _times[last - 1]
	var step: Vector2 = _positions[last] - _positions[last - 1]
	if step_time <= 0.0 or step.length() > teleport_distance:
		return _positions[last]
	var ahead: float = minf(time - _times[last], max_extrapolation)
	return _positions[last] + step / step_time * ahead


## The index of the newest sample that is not after [param time].
func _segment_before(time: float) -> int:
	var index: int = _times.size() - 2
	while index > 0 and _times[index] > time:
		index -= 1
	return index


func _segment_weight(index: int, time: float) -> float:
	var span: float = _times[index + 1] - _times[index]
	return clampf((time - _times[index]) / span, 0.0, 1.0) if span > 0.0 else 1.0
