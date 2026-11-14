class_name StubInputService
extends InputService
## Inert [InputService]: reports no device input.
##
## Tests and sandbox scenes drive it by hand through the [code]simulate_*[/code]
## methods and the public fields. It honours role, gameplay switch and locks
## exactly as the contract describes, so code written against it behaves the
## same with the real implementation.

## The movement input to report.
var move_vector: Vector2 = Vector2.ZERO
## The aim direction to report.
var aim_direction: Vector2 = Vector2.RIGHT

var _role: GameEnums.Role = GameEnums.Role.NONE
var _gameplay_enabled: bool = true
var _scheme: Scheme = Scheme.KEYBOARD_MOUSE
var _held: Dictionary[StringName, bool] = {}
var _locks: Dictionary[StringName, Array] = {}


## Presses [param action] as if the player did. Returns whether it was reported.
func simulate_press(action: StringName) -> bool:
	if not _is_reportable(action) or _held.has(action):
		return false
	_held[action] = true
	action_pressed.emit(action)
	return true


## Releases [param action] as if the player did.
func simulate_release(action: StringName) -> void:
	if _held.erase(action):
		action_released.emit(action)


func get_move_vector() -> Vector2:
	if not _gameplay_enabled or is_locked(InputActions.MOVE):
		return Vector2.ZERO
	return move_vector.limit_length(1.0)


func get_aim_direction(_aim_origin: Vector2) -> Vector2:
	if aim_direction.is_zero_approx():
		return Vector2.RIGHT
	return aim_direction.normalized()


func is_action_held(action: StringName) -> bool:
	return _held.has(action)


func set_role(role: GameEnums.Role) -> void:
	if role == _role:
		return
	_role = role
	_release_unreportable()
	role_changed.emit(role)


func get_role() -> GameEnums.Role:
	return _role


func set_gameplay_enabled(enabled: bool) -> void:
	if enabled == _gameplay_enabled:
		return
	_gameplay_enabled = enabled
	_release_unreportable()
	gameplay_enabled_changed.emit(enabled)


func is_gameplay_enabled() -> bool:
	return _gameplay_enabled


func add_lock(action: StringName, source: StringName) -> void:
	var sources: Array = _locks.get_or_add(action, [])
	if not sources.has(source):
		sources.append(source)
	_release_unreportable()


func remove_lock(action: StringName, source: StringName) -> void:
	if not _locks.has(action):
		return
	var sources: Array = _locks[action]
	sources.erase(source)
	if sources.is_empty():
		_locks.erase(action)


func clear_locks(source: StringName) -> void:
	for action: StringName in _locks.keys():
		remove_lock(action, source)


func is_locked(action: StringName) -> bool:
	return _locks.has(action)


func get_scheme() -> Scheme:
	return _scheme


func set_scheme_override(scheme: Scheme) -> void:
	_set_scheme(scheme)


func clear_scheme_override() -> void:
	_set_scheme(Scheme.KEYBOARD_MOUSE)


func _set_scheme(scheme: Scheme) -> void:
	if scheme == _scheme:
		return
	_scheme = scheme
	scheme_changed.emit(scheme)


func _is_reportable(action: StringName) -> bool:
	return (
		_gameplay_enabled
		and not is_locked(action)
		and InputActions.abilities_for(_role).has(action)
	)


func _release_unreportable() -> void:
	for action: StringName in _held.keys():
		if not _is_reportable(action):
			simulate_release(action)
