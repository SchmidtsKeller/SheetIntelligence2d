class_name SandboxSwarmService
extends StubSwarmService
## A [SwarmService] for sandboxes and tests until the real flock (#13): it
## knows the sheep it was given, so they can be shot, but does not move them.

var _bodies: Array[SheepBody] = []


## Adds [param body] to the flock and returns its sheep id.
func add_sheep(body: SheepBody) -> int:
	_bodies.append(body)
	living_count_changed.emit(get_living_count())
	return _bodies.size() - 1


func kill_sheep(sheep_id: int, cause: GameEnums.DeathCause) -> bool:
	if not is_sheep_alive(sheep_id):
		return false
	var body: SheepBody = _bodies[sheep_id]
	body.kill(cause)
	sheep_died.emit(sheep_id, cause, body.global_position)
	living_count_changed.emit(get_living_count())
	return true


func get_living_count() -> int:
	return get_living_sheep_ids().size()


func get_living_sheep_ids() -> Array[int]:
	var ids: Array[int] = []
	for sheep_id: int in _bodies.size():
		if is_sheep_alive(sheep_id):
			ids.append(sheep_id)
	return ids


func is_sheep_alive(sheep_id: int) -> bool:
	if sheep_id < 0 or sheep_id >= _bodies.size():
		return false
	return is_instance_valid(_bodies[sheep_id]) and _bodies[sheep_id].is_alive()


func get_sheep_body(sheep_id: int) -> Node2D:
	if sheep_id < 0 or sheep_id >= _bodies.size():
		return null
	return _bodies[sheep_id]


func get_sheep_id(body: Node2D) -> int:
	return _bodies.find(body)
