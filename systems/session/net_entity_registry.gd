class_name NetEntityRegistry
extends Node
## Spawns, tracks and synchronizes the replicated entities of a session.
##
## The host decides which entities exist. It spawns an entity of a registered
## kind, for an owner, with a stable id; both devices then build the same node
## from the same data. The owner is the device whose simulation moves the
## entity: the host for the flock and its own character, the guest for the
## guest's character.
##
## Several times per second each device sends one snapshot with the transform
## of every entity it owns (through the entity's [NetTransform2D]), and every
## frame each entity is shown at the same moment in the past.

## An entity exists now, on this device.
signal entity_spawned(entity_id: int, entity: Node)

## An entity is gone. It is freed right after this signal.
signal entity_despawned(entity_id: int)

const EVENT_SPAWN: StringName = &"entity.spawn"
const EVENT_DESPAWN: StringName = &"entity.despawn"

## How many recent packets the clock offset is estimated from.
const CLOCK_WINDOW: int = 40

## The node new entities are added to. The scene that shows the entities sets
## it; without one, entities become children of the registry.
var spawn_root: Node

## Snapshots per second.
var tick_rate: int = 20
## How far in the past entities are shown, in seconds.
var interpolation_delay: float = 0.1
## How long an entity keeps its course without news, in seconds.
var max_extrapolation: float = 0.1

var _messenger: NetMessenger
var _factories: Dictionary[StringName, Callable] = {}
var _entities: Dictionary[int, Node] = {}
var _owners: Dictionary[int, int] = {}
var _transforms: Dictionary[int, NetTransform2D] = {}
var _next_entity_id: int = 1

var _time: float = 0.0
var _tick: int = 0
var _tick_accumulator: float = 0.0
## Recent values of "local time minus the sender's time" of received
## snapshots. The smallest one belongs to the least delayed packet.
var _clock_offsets: PackedFloat64Array = []


func _process(delta: float) -> void:
	advance(delta)


func setup(messenger: NetMessenger) -> void:
	_messenger = messenger
	messenger.register_event(EVENT_SPAWN, NetMessenger.SenderRule.HOST_ONLY)
	messenger.register_event(EVENT_DESPAWN, NetMessenger.SenderRule.HOST_ONLY)
	messenger.subscribe(EVENT_SPAWN, _on_spawn)
	messenger.subscribe(EVENT_DESPAWN, _on_despawn)
	messenger.snapshot_received.connect(_on_snapshot)


## Teaches the registry to build entities of [param kind]. [param factory] is
## [code](entity_id: int, owner_id: int, data: Dictionary) -> Node[/code] and
## must build the same node on both devices. Register every kind on both
## devices before the host spawns one.
func register_kind(kind: StringName, factory: Callable) -> void:
	_factories[kind] = factory


## Spawns an entity on both devices and returns its id, or -1 on failure.
## Only the host may spawn. [param owner_id] is the peer id of the device
## that moves the entity; [param data] must be plain data.
func spawn(kind: StringName, owner_id: int, data: Dictionary = {}) -> int:
	if not _factories.has(kind):
		push_error("NetEntityRegistry: no factory registered for the kind '%s'." % kind)
		return -1
	# The spawn handler, which runs on this device at once, advances the id.
	var entity_id: int = _next_entity_id
	if not _messenger.broadcast(EVENT_SPAWN, [entity_id, kind, owner_id, data]):
		return -1
	return entity_id


## Removes an entity on both devices. Only the host may despawn.
func despawn(entity_id: int) -> bool:
	if not _entities.has(entity_id):
		return false
	return _messenger.broadcast(EVENT_DESPAWN, [entity_id])


## Removes every entity on both devices. Only the host may do this.
func despawn_all() -> void:
	for entity_id: int in get_entity_ids():
		despawn(entity_id)


## Removes every entity on this device only, without telling the other one.
## For the end of a session, when there is nobody left to tell.
func clear_local() -> void:
	for entity_id: int in get_entity_ids():
		_remove(entity_id)
	_next_entity_id = 1
	_tick = 0
	_tick_accumulator = 0.0
	_clock_offsets.clear()


func get_entity(entity_id: int) -> Node:
	return _entities.get(entity_id)


func get_entity_ids() -> Array[int]:
	var ids: Array[int] = []
	ids.assign(_entities.keys())
	return ids


## The peer id of the device that moves the entity; 0 for an unknown id.
func get_owner_id(entity_id: int) -> int:
	return _owners.get(entity_id, 0)


## Whether this device moves the entity.
func is_local_authority(entity_id: int) -> bool:
	return _owners.get(entity_id, 0) == _messenger.get_local_id()


## Moves time forward: sends a snapshot when one is due and shows every
## entity at its place. Called every frame.
func advance(delta: float) -> void:
	_time += delta
	_tick_accumulator += delta
	var tick_interval: float = 1.0 / tick_rate
	while _tick_accumulator >= tick_interval:
		_tick_accumulator -= tick_interval
		_tick += 1
		_send_snapshot()
	_present()


func _send_snapshot() -> void:
	var payload: Array = []
	for entity_id: int in _transforms:
		var transform: NetTransform2D = _transforms[entity_id]
		if transform.is_authority():
			payload.append(entity_id)
			payload.append_array(transform.capture(_time))
	if not payload.is_empty():
		# The sender's clock travels with the snapshot.
		_messenger.send_snapshot(_tick, [_time, payload])


func _on_snapshot(_tick_number: int, message: Array, _sender_id: int) -> void:
	var sender_time: float = message[0]
	var payload: Array = message[1]
	_clock_offsets.append(_time - sender_time)
	if _clock_offsets.size() > CLOCK_WINDOW:
		_clock_offsets.remove_at(0)
	# Each entity takes four values: id, x, y, rotation.
	for index: int in range(0, payload.size() - 3, 4):
		var transform: NetTransform2D = _transforms.get(payload[index])
		if transform != null:
			var position: Vector2 = Vector2(payload[index + 1], payload[index + 2])
			transform.receive(sender_time, position, payload[index + 3])


func _present() -> void:
	# Entities of this device are stamped with this device's clock, entities
	# of the other device with the sender's clock.
	var local_render_time: float = _time - interpolation_delay
	var remote_render_time: float = local_render_time - _clock_offset()
	for entity_id: int in _transforms:
		var transform: NetTransform2D = _transforms[entity_id]
		transform.present(local_render_time if transform.is_authority() else remote_render_time)


## How far this device's clock is ahead of the sender's, including the travel
## time of the fastest recent packet.
func _clock_offset() -> float:
	if _clock_offsets.is_empty():
		return 0.0
	var smallest: float = _clock_offsets[0]
	for offset: float in _clock_offsets:
		smallest = minf(smallest, offset)
	return smallest


func _on_spawn(payload: Array, _sender_id: int) -> void:
	var entity_id: int = payload[0]
	var kind: StringName = payload[1]
	var owner_id: int = payload[2]
	var data: Dictionary = payload[3]
	if _entities.has(entity_id):
		return
	if not _factories.has(kind):
		push_error("NetEntityRegistry: cannot spawn the unknown kind '%s'." % kind)
		return
	var entity: Node = _factories[kind].call(entity_id, owner_id, data)
	if entity == null:
		push_error("NetEntityRegistry: the factory of '%s' returned nothing." % kind)
		return
	entity.name = "%s_%d" % [kind, entity_id]
	_entities[entity_id] = entity
	_owners[entity_id] = owner_id
	var parent: Node = spawn_root if is_instance_valid(spawn_root) else self
	parent.add_child(entity)
	# An entity can also disappear with the scene it lives in.
	entity.tree_exiting.connect(_forget.bind(entity_id))
	var transform: NetTransform2D = _find_transform(entity)
	if transform != null:
		transform.configure(owner_id == _messenger.get_local_id(), max_extrapolation)
		_transforms[entity_id] = transform
	_next_entity_id = maxi(_next_entity_id, entity_id + 1)
	entity_spawned.emit(entity_id, entity)


func _on_despawn(payload: Array, _sender_id: int) -> void:
	_remove(payload[0])


func _remove(entity_id: int) -> void:
	if not _entities.has(entity_id):
		return
	var entity: Node = _entities[entity_id]
	_forget(entity_id)
	if is_instance_valid(entity):
		entity.queue_free()


func _forget(entity_id: int) -> void:
	if not _entities.has(entity_id):
		return
	_entities.erase(entity_id)
	_owners.erase(entity_id)
	_transforms.erase(entity_id)
	entity_despawned.emit(entity_id)


static func _find_transform(entity: Node) -> NetTransform2D:
	for child: Node in entity.get_children():
		if child is NetTransform2D:
			return child
	return null
