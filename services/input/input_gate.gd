class_name InputGate
extends RefCounted
## Decides which ability actions get through to the game, and remembers which
## are held.
##
## An action is only reported when gameplay input is on, the action belongs to
## the current role, and nothing locks it. When one of these conditions stops
## being true while the action is held, the action is released: a consumer
## always gets a release for every press. Every [InputService] implementation
## shares this logic, so they all behave the same.

signal action_pressed(action: StringName)
signal action_released(action: StringName)

var _role: GameEnums.Role = GameEnums.Role.NONE
var _gameplay_enabled: bool = true
var _held: Dictionary[StringName, bool] = {}
## Action (or pseudo-action) → the sources that lock it.
var _locks: Dictionary[StringName, Array] = {}


## Reports [param action] as pressed, if it may be. Returns whether it was.
func press(action: StringName) -> bool:
	if _held.has(action) or not is_reportable(action):
		return false
	_held[action] = true
	action_pressed.emit(action)
	return true


## Reports [param action] as released, if it was held.
func release(action: StringName) -> void:
	if _held.erase(action):
		action_released.emit(action)


## Releases every held action.
func release_all() -> void:
	for action: StringName in _held.keys():
		release(action)


func is_held(action: StringName) -> bool:
	return _held.has(action)


## Whether [param action] would be reported right now.
func is_reportable(action: StringName) -> bool:
	return (
		_gameplay_enabled
		and not is_locked(action)
		and InputActions.abilities_for(_role).has(action)
	)


## Whether movement input counts right now.
func allows_movement() -> bool:
	return _gameplay_enabled and not is_locked(InputActions.MOVE)


## Whether the aim may change right now. Otherwise it keeps its direction.
func allows_aiming() -> bool:
	return _gameplay_enabled and not is_locked(InputActions.AIM)


func get_role() -> GameEnums.Role:
	return _role


## Returns whether the role changed.
func set_role(role: GameEnums.Role) -> bool:
	if role == _role:
		return false
	_role = role
	_release_unreportable()
	return true


func is_gameplay_enabled() -> bool:
	return _gameplay_enabled


## Returns whether the setting changed.
func set_gameplay_enabled(enabled: bool) -> bool:
	if enabled == _gameplay_enabled:
		return false
	_gameplay_enabled = enabled
	_release_unreportable()
	return true


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


func _release_unreportable() -> void:
	for action: StringName in _held.keys():
		if not is_reportable(action):
			release(action)
