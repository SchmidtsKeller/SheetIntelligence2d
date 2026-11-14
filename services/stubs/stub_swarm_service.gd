class_name StubSwarmService
extends SwarmService
## Empty [SwarmService]: a field without sheep.
##
## Spawning creates nothing, so every query answers for an empty flock. Bell
## rings are still announced, so code that reacts to the bell can be exercised.

var _neighbours: Array[Node2D] = []


func spawn_flock(_round_seed: int) -> void:
	living_count_changed.emit(0)


func despawn_flock() -> void:
	pass


func ring_bell(origin: Vector2, radius: float) -> void:
	bell_rung.emit(origin, radius)


func kill_sheep(_sheep_id: int, _cause: GameEnums.DeathCause) -> bool:
	return false


func get_living_count() -> int:
	return 0


func get_living_sheep_ids() -> Array[int]:
	return []


func is_sheep_alive(_sheep_id: int) -> bool:
	return false


func get_sheep_body(_sheep_id: int) -> Node2D:
	return null


func get_sheep_id(_body: Node2D) -> int:
	return -1


func find_nearest_living_sheep(_position: Vector2, _max_distance: float) -> int:
	return -1


func find_nearest_edible_sheep(_position: Vector2, _max_distance: float) -> int:
	return -1


func is_sheep_corpse(_sheep_id: int) -> bool:
	return false


func register_neighbour(body: Node2D) -> void:
	if body != null and not _neighbours.has(body):
		_neighbours.append(body)


func unregister_neighbour(body: Node2D) -> void:
	_neighbours.erase(body)


## The neighbours registered so far, for tests.
func get_neighbours() -> Array[Node2D]:
	return _neighbours.duplicate()
