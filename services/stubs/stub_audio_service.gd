class_name StubAudioService
extends AudioService
## Silent [AudioService]: plays nothing, remembers everything.
##
## Each requested sound is recorded in [member played], so tests can assert
## that gameplay code triggered the right event at the right place.

## One entry per requested sound: [code]{"event": StringName, "position":
## Vector2, "positional": bool}[/code].
var played: Array[Dictionary] = []

var _config: GameConfig
var _listener: Node2D
var _bus_volumes: Dictionary[StringName, float] = {}
var _emitters: Dictionary[int, StringName] = {}
var _next_handle: int = 1


func _init(config: GameConfig = null) -> void:
	_config = config if config != null else GameConfig.new()


func play_event(event_id: StringName, world_position: Vector2) -> void:
	played.append({"event": event_id, "position": world_position, "positional": true})
	event_played.emit(event_id, world_position)


func play_ui(event_id: StringName) -> void:
	played.append({"event": event_id, "position": Vector2.ZERO, "positional": false})


func start_emitter(event_id: StringName, _target: Node2D) -> int:
	var handle: int = _next_handle
	_next_handle += 1
	_emitters[handle] = event_id
	return handle


func set_emitter_playing(_handle: int, _playing: bool) -> void:
	pass


func stop_emitter(handle: int, _fade_seconds: float = 0.0) -> void:
	_emitters.erase(handle)


func stop_all(_fade_seconds: float = 0.0) -> void:
	_emitters.clear()


## The number of emitters that were started and not stopped, for tests.
func get_emitter_count() -> int:
	return _emitters.size()


func set_listener(listener: Node2D) -> void:
	_listener = listener


func get_listener() -> Node2D:
	return _listener if is_instance_valid(_listener) else null


func get_hearing_range(event_id: StringName) -> float:
	match AudioEvents.range_class_of(event_id):
		GameEnums.HearingRange.WHOLE_MAP:
			return INF
		GameEnums.HearingRange.LOUD:
			return _config.hearing_range_loud
		_:
			return _config.hearing_range_quiet


func set_bus_volume(bus: StringName, linear_volume: float) -> void:
	_bus_volumes[bus] = clampf(linear_volume, 0.0, 1.0)


func get_bus_volume(bus: StringName) -> float:
	return _bus_volumes.get(bus, 1.0)
