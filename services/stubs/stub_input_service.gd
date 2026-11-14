class_name StubInputService
extends InputService
## Inert [InputService]: reports no device input.
##
## Tests and sandbox scenes drive it by hand through the [code]simulate_*[/code]
## methods and the public fields. It honours role, gameplay switch and locks
## exactly as the real implementation does, because both use [InputGate].

## The movement input to report.
var move_vector: Vector2 = Vector2.ZERO
## The aim direction to report.
var aim_direction: Vector2 = Vector2.RIGHT

var _gate: InputGate = InputGate.new()
var _scheme: Scheme = Scheme.KEYBOARD_MOUSE


func _init() -> void:
	_gate.action_pressed.connect(action_pressed.emit)
	_gate.action_released.connect(action_released.emit)


## Presses [param action] as if the player did. Returns whether it was reported.
func simulate_press(action: StringName) -> bool:
	return _gate.press(action)


## Releases [param action] as if the player did.
func simulate_release(action: StringName) -> void:
	_gate.release(action)


func get_move_vector() -> Vector2:
	if not _gate.allows_movement():
		return Vector2.ZERO
	return move_vector.limit_length(1.0)


func get_aim_direction(_aim_origin: Vector2) -> Vector2:
	if aim_direction.is_zero_approx():
		return Vector2.RIGHT
	return aim_direction.normalized()


func is_action_held(action: StringName) -> bool:
	return _gate.is_held(action)


func set_role(role: GameEnums.Role) -> void:
	if _gate.set_role(role):
		role_changed.emit(role)


func get_role() -> GameEnums.Role:
	return _gate.get_role()


func set_gameplay_enabled(enabled: bool) -> void:
	if _gate.set_gameplay_enabled(enabled):
		gameplay_enabled_changed.emit(enabled)


func is_gameplay_enabled() -> bool:
	return _gate.is_gameplay_enabled()


func add_lock(action: StringName, source: StringName) -> void:
	_gate.add_lock(action, source)


func remove_lock(action: StringName, source: StringName) -> void:
	_gate.remove_lock(action, source)


func clear_locks(source: StringName) -> void:
	_gate.clear_locks(source)


func is_locked(action: StringName) -> bool:
	return _gate.is_locked(action)


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
