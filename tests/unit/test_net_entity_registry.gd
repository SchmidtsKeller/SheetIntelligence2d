extends TestCase
## Replicated entities: spawned by the host with stable ids, moved by their
## owner, shown smoothly on the other device.

const HOST_ID: int = SessionPair.HOST_ID
const GUEST_ID: int = SessionPair.GUEST_ID
const KIND: StringName = &"test_entity"
## One frame of the simulated game loop.
const FRAME: float = 1.0 / 60.0

var _host_messenger: NetMessenger
var _guest_messenger: NetMessenger
var _host: NetEntityRegistry
var _guest: NetEntityRegistry


func before_each() -> void:
	_host_messenger = add_child_autofree(NetMessenger.new())
	_guest_messenger = add_child_autofree(NetMessenger.new())
	_host_messenger.configure(HOST_ID, GUEST_ID, true)
	_guest_messenger.configure(GUEST_ID, HOST_ID, false)
	SessionPair.link(_host_messenger, _guest_messenger)
	_host = _create_registry(_host_messenger)
	_guest = _create_registry(_guest_messenger)


func after_each() -> void:
	_host.clear_local()
	_guest.clear_local()


# --- Spawning --------------------------------------------------------------------


func test_spawn_creates_the_same_entity_on_both_devices() -> void:
	var entity_id: int = _host.spawn(KIND, HOST_ID, {"x": 120.0, "y": 80.0})

	var on_host: Node2D = _host.get_entity(entity_id)
	var on_guest: Node2D = _guest.get_entity(entity_id)
	assert_gt(entity_id, 0)
	assert_not_null(on_host)
	assert_not_null(on_guest)
	assert_eq(on_host.name, on_guest.name, "the same node name on both devices")
	assert_eq(on_host.position, Vector2(120.0, 80.0))
	assert_eq(on_guest.position, Vector2(120.0, 80.0))


func test_entity_ids_are_stable_and_unique() -> void:
	var first: int = _host.spawn(KIND, HOST_ID)
	var second: int = _host.spawn(KIND, GUEST_ID)
	var third: int = _host.spawn(KIND, HOST_ID)

	assert_eq([first, second, third], [1, 2, 3])
	assert_eq(_host.get_entity_ids(), [1, 2, 3])
	assert_eq(_guest.get_entity_ids(), [1, 2, 3])


func test_each_device_knows_who_owns_an_entity() -> void:
	var host_owned: int = _host.spawn(KIND, HOST_ID)
	var guest_owned: int = _host.spawn(KIND, GUEST_ID)

	assert_eq(_guest.get_owner_id(host_owned), HOST_ID)
	assert_eq(_host.get_owner_id(guest_owned), GUEST_ID)
	assert_true(_host.is_local_authority(host_owned))
	assert_false(_host.is_local_authority(guest_owned))
	assert_true(_guest.is_local_authority(guest_owned))
	assert_false(_guest.is_local_authority(host_owned))
	assert_eq(_host.get_owner_id(99), 0, "unknown id")


func test_spawn_is_announced() -> void:
	watch_signals(_guest)

	var entity_id: int = _host.spawn(KIND, HOST_ID)

	assert_signal_emitted_with(_guest, &"entity_spawned", [entity_id, _guest.get_entity(entity_id)])


func test_guest_cannot_spawn() -> void:
	expect_error("only the host may send")

	assert_eq(_guest.spawn(KIND, GUEST_ID), -1)

	assert_eq(_host.get_entity_ids(), [])
	assert_eq(_guest.get_entity_ids(), [])


func test_unknown_kind_cannot_be_spawned() -> void:
	expect_error("no factory registered for the kind 'ghost'")

	assert_eq(_host.spawn(&"ghost", HOST_ID), -1)


func test_entities_are_added_to_the_spawn_root() -> void:
	var world: Node2D = add_child_autofree(Node2D.new())
	_host.spawn_root = world

	var entity_id: int = _host.spawn(KIND, HOST_ID)

	assert_eq(_host.get_entity(entity_id).get_parent(), world)
	assert_eq(_guest.get_entity(entity_id).get_parent(), _guest, "no root set: the registry itself")


func test_despawn_removes_the_entity_on_both_devices() -> void:
	var entity_id: int = _host.spawn(KIND, HOST_ID)
	watch_signals(_guest)

	assert_true(_host.despawn(entity_id))

	assert_null(_host.get_entity(entity_id))
	assert_null(_guest.get_entity(entity_id))
	assert_signal_emitted_with(_guest, &"entity_despawned", [entity_id])
	assert_false(_host.despawn(entity_id), "already gone")


func test_despawn_all_empties_both_devices() -> void:
	_host.spawn(KIND, HOST_ID)
	_host.spawn(KIND, GUEST_ID)

	_host.despawn_all()

	assert_eq(_host.get_entity_ids(), [])
	assert_eq(_guest.get_entity_ids(), [])


func test_clear_local_affects_only_this_device_and_restarts_the_ids() -> void:
	_host.spawn(KIND, HOST_ID)

	_guest.clear_local()

	assert_eq(_guest.get_entity_ids(), [])
	assert_eq(_host.get_entity_ids(), [1])


# --- Movement ----------------------------------------------------------------------


func test_entity_moved_by_the_host_follows_on_the_guest() -> void:
	var entity_id: int = _host.spawn(KIND, HOST_ID, {"x": 0.0, "y": 0.0})
	var on_host: Node2D = _host.get_entity(entity_id)
	var on_guest: Node2D = _guest.get_entity(entity_id)

	# 180 px/s to the right for one second.
	for frame: int in 60:
		on_host.position.x += 180.0 * FRAME
		_step_both()

	# The guest shows the entity one interpolation delay in the past.
	var expected: float = on_host.position.x - 180.0 * _guest.interpolation_delay
	assert_almost_eq(on_guest.position.x, expected, 180.0 * 0.06, "close behind the host")
	assert_gt(on_guest.position.x, 100.0)


func test_entity_moved_by_the_guest_follows_on_the_host() -> void:
	var entity_id: int = _host.spawn(KIND, GUEST_ID, {"x": 0.0, "y": 0.0})
	var on_guest: Node2D = _guest.get_entity(entity_id)
	var on_host: Node2D = _host.get_entity(entity_id)

	for frame: int in 60:
		on_guest.position.y -= 180.0 * FRAME
		_step_both()

	assert_lt(on_host.position.y, -100.0, "replication works in both directions")


func test_remote_entity_moves_smoothly_between_snapshots() -> void:
	var entity_id: int = _host.spawn(KIND, HOST_ID, {"x": 0.0, "y": 0.0})
	var on_host: Node2D = _host.get_entity(entity_id)
	var on_guest: Node2D = _guest.get_entity(entity_id)
	for frame: int in 30:
		on_host.position.x += 180.0 * FRAME
		_step_both()

	# Snapshots arrive 20 times per second, frames are drawn 60 times: the
	# guest must still see the same step in every frame, not a jump every third.
	var previous: float = on_guest.position.x
	for frame: int in 30:
		on_host.position.x += 180.0 * FRAME
		_step_both()
		var step: float = on_guest.position.x - previous
		assert_almost_eq(step, 180.0 * FRAME, 0.05, "frame %d" % frame)
		previous = on_guest.position.x


func test_rotation_is_replicated() -> void:
	var entity_id: int = _host.spawn(KIND, HOST_ID)
	var on_host: Node2D = _host.get_entity(entity_id)

	on_host.rotation = 1.2
	for frame: int in 30:
		_step_both()

	assert_almost_eq((_guest.get_entity(entity_id) as Node2D).rotation, 1.2, 0.001)


func test_remote_entity_survives_lost_snapshots() -> void:
	var entity_id: int = _host.spawn(KIND, HOST_ID, {"x": 0.0, "y": 0.0})
	var on_host: Node2D = _host.get_entity(entity_id)
	var on_guest: Node2D = _guest.get_entity(entity_id)
	_guest_messenger.sim_loss = 0.3

	for frame: int in 120:
		on_host.position.x += 180.0 * FRAME
		_step_both()

	assert_almost_eq(
		on_guest.position.x, on_host.position.x, 60.0, "it keeps up despite the losses"
	)


func test_owner_is_not_moved_by_its_own_snapshots() -> void:
	var entity_id: int = _host.spawn(KIND, HOST_ID, {"x": 50.0, "y": 0.0})
	var on_host: Node2D = _host.get_entity(entity_id)

	on_host.position = Vector2(300.0, 0.0)
	for frame: int in 10:
		_step_both()

	assert_eq(on_host.position, Vector2(300.0, 0.0), "the simulation owns the position")


func test_delayed_visual_shows_the_owner_the_same_delay_as_everyone_else() -> void:
	# Uniform presentation: an entity this device simulates must not look
	# any more current than one that arrives over the network.
	var entity_id: int = _host.spawn(KIND, HOST_ID, {"x": 0.0, "y": 0.0, "delayed_visual": true})
	var on_host: Node2D = _host.get_entity(entity_id)
	var host_visual: Node2D = on_host.get_node(^"Visual")
	var guest_visual: Node2D = _guest.get_entity(entity_id).get_node(^"Visual")

	for frame: int in 60:
		on_host.position.x += 180.0 * FRAME
		_step_both()

	assert_lt(host_visual.global_position.x, on_host.position.x - 5.0, "behind the simulation")
	assert_almost_eq(
		host_visual.global_position.x,
		guest_visual.global_position.x,
		180.0 * 0.06,
		"host and guest see the entity at (nearly) the same place"
	)


func _create_registry(messenger: NetMessenger) -> NetEntityRegistry:
	var registry: NetEntityRegistry = add_child_autofree(NetEntityRegistry.new())
	# Tests move time themselves.
	registry.set_process(false)
	messenger.set_process(false)
	registry.setup(messenger)
	registry.register_kind(KIND, _build_entity)
	return registry


func _step_both() -> void:
	_host.advance(FRAME)
	_guest.advance(FRAME)
	_host_messenger.advance(FRAME)
	_guest_messenger.advance(FRAME)


static func _build_entity(_entity_id: int, _owner_id: int, data: Dictionary) -> Node:
	var entity: Node2D = Node2D.new()
	entity.position = Vector2(data.get("x", 0.0), data.get("y", 0.0))
	var visual: Node2D = Node2D.new()
	visual.name = "Visual"
	entity.add_child(visual)
	var transform: NetTransform2D = NetTransform2D.new()
	if data.get("delayed_visual", false):
		transform.delayed_visual = visual
	entity.add_child(transform)
	return entity
