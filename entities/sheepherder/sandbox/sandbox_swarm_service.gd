class_name SandboxSwarmService
extends StubSwarmService
## A [SwarmService] for sandboxes and tests without the real flock: it knows
## the sheep it was given, so they can be shot and eaten, but does not move
## them.

var _bodies: Array[SheepBody] = []


## Adds [param body] to the flock and returns its sheep id.
func add_sheep(body: SheepBody) -> int:
	_bodies.append(body)
	living_count_changed.emit(get_living_count())
	return _bodies.size() - 1


func kill_sheep(sheep_id: int, cause: GameEnums.DeathCause) -> bool:
	var body: SheepBody = get_sheep_body(sheep_id) as SheepBody
	if not is_instance_valid(body):
		return false
	var was_alive: bool = body.is_alive()
	if not body.kill(cause):
		return false
	if was_alive:
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


func find_nearest_living_sheep(position: Vector2, max_distance: float) -> int:
	return _find_nearest(position, max_distance, false)


func find_nearest_edible_sheep(position: Vector2, max_distance: float) -> int:
	return _find_nearest(position, max_distance, true)


func is_sheep_corpse(sheep_id: int) -> bool:
	var body: SheepBody = get_sheep_body(sheep_id) as SheepBody
	return is_instance_valid(body) and body.get_state() == SheepBody.State.CORPSE


func _find_nearest(position: Vector2, max_distance: float, with_corpses: bool) -> int:
	var nearest_id: int = -1
	var nearest_distance: float = max_distance
	for sheep_id: int in _bodies.size():
		if not (is_sheep_alive(sheep_id) or (with_corpses and is_sheep_corpse(sheep_id))):
			continue
		var distance: float = position.distance_to(_bodies[sheep_id].global_position)
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest_id = sheep_id
	return nearest_id
