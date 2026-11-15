extends TestCase
## The Sheepherder: movement, aim, flashlight, bell, firearm requests and
## pushing sheep, on one device and across two (GDD §3.1, §3.3).

const SHEEP_SCENE: PackedScene = preload("res://entities/sheep/sheep.tscn")
const LOCAL_ID: int = 1
const OTHER_ID: int = 2


## Remembers the shots it is asked for and accepts them.
class RecordingCombatService:
	extends StubCombatService

	var requests: Array[Array] = []

	func request_shot(origin: Vector2, direction: Vector2) -> bool:
		requests.append([origin, direction])
		return true


var _input: StubInputService
var _combat: RecordingCombatService
var _swarm: StubSwarmService
var _audio: StubAudioService
var _originals: Dictionary = {}


func before_each() -> void:
	_input = StubInputService.new()
	_input.set_role(GameEnums.Role.SHEEPHERDER)
	_combat = RecordingCombatService.new(Services.config)
	_swarm = StubSwarmService.new()
	_audio = StubAudioService.new(Services.config)
	_originals[InputService] = Services.replace(InputService, _input)
	_originals[CombatService] = Services.replace(CombatService, _combat)
	_originals[SwarmService] = Services.replace(SwarmService, _swarm)
	_originals[AudioService] = Services.replace(AudioService, _audio)


func after_each() -> void:
	for contract: Script in _originals:
		Services.replace(contract, _originals[contract]).free()
	_originals.clear()


# --- One device ------------------------------------------------------------------


func test_the_sheepherder_is_a_solid_character() -> void:
	var herder: Sheepherder = _spawn()

	assert_eq(herder.collision_layer, PhysicsLayers.SHEEPHERDER)
	assert_eq(herder.collision_mask, PhysicsLayers.WORLD | PhysicsLayers.SHEEP)
	assert_eq(herder.motion_mode, CharacterBody2D.MOTION_MODE_FLOATING)
	assert_true(herder.is_in_group(Groups.SHEEPHERDER))
	assert_true(herder.is_in_group(Groups.DYNAMIC_ENTITIES))
	assert_true(herder.get_camera().enabled, "its player's camera follows it")


func test_the_companions_find_it_through_the_perk_service() -> void:
	var herder: Sheepherder = _spawn()
	assert_eq(Services.perks.get_character(GameEnums.Role.SHEEPHERDER), herder)

	remove_child(herder)

	assert_null(Services.perks.get_character(GameEnums.Role.SHEEPHERDER))


func test_it_walks_at_the_sheepherder_speed() -> void:
	var herder: Sheepherder = _spawn()
	_input.move_vector = Vector2.RIGHT

	await _physics_frames(10)

	assert_eq(herder.velocity, Vector2(Services.config.herder_move_speed, 0.0))
	assert_gt(herder.position.x, 0.0)


func test_it_faces_where_the_player_aims() -> void:
	var herder: Sheepherder = _spawn()
	_input.aim_direction = Vector2.DOWN

	await _physics_frames(1)

	assert_almost_eq(herder.rotation, Vector2.DOWN.angle())
	assert_almost_eq(herder.get_aim_direction(), Vector2.DOWN)


func test_the_flashlight_cone_follows_the_stats() -> void:
	var herder: Sheepherder = _spawn(Vector2(40.0, 30.0))
	var cone: FlashlightCone = herder.get_flashlight_cone()

	assert_eq(cone.origin, Vector2(40.0, 30.0))
	assert_almost_eq(cone.direction, Vector2.RIGHT)
	assert_eq(cone.angle_deg, 60.0)
	assert_eq(cone.length, 350.0)
	var light: FlashlightLight = herder.get_node(^"Flashlight")
	assert_eq(light.texture, FlashlightLight.cone_texture(60.0, 0.6, 12.0), "lit from the start")
	# The texture reaches to the end of the fade: 350 px and 60 % more.
	assert_almost_eq(light.texture_scale * FlashlightLight.TEXTURE_SIZE / 2.0, 560.0)
	assert_true(light.shadow_enabled, "obstacles cast shadows")

	var config: GameConfig = GameConfig.new()
	config.flashlight_cone_angle_deg = config.perk_wide_flashlight_angle_deg
	_originals[PerkService] = Services.replace(PerkService, StubPerkService.new(config))
	assert_eq(herder.get_flashlight_cone().angle_deg, 90.0, "a perk widens it")
	# A frame starts before the nodes process it, so the change shows in the next one.
	await wait_frames(2)
	assert_eq(light.texture, FlashlightLight.cone_texture(90.0, 0.6, 12.0), "the light widens too")


func test_shooting_asks_the_combat_service() -> void:
	var herder: Sheepherder = _spawn(Vector2(10.0, 20.0))
	# Aimed after the last physics step: the shot still goes where the player points.
	_input.aim_direction = Vector2.UP

	_input.simulate_press(InputActions.SHOOT)

	assert_eq(_combat.requests.size(), 1)
	assert_eq(_combat.requests[0][0], herder.global_position)
	assert_almost_eq(_combat.requests[0][1], Vector2.UP)
	assert_almost_eq(herder.get_aim_direction(), Vector2.UP, 0.0001, "and it faces there")


func test_the_bell_rings_and_cools_down() -> void:
	var config: GameConfig = GameConfig.new()
	config.bell_cooldown = 0.3
	_originals[PerkService] = Services.replace(PerkService, StubPerkService.new(config))
	var herder: Sheepherder = _spawn(Vector2(5.0, 6.0))
	watch_signals(herder)
	watch_signals(_swarm)

	_input.simulate_press(InputActions.BELL)

	assert_signal_emitted_with(_swarm, &"bell_rung", [Vector2(5.0, 6.0), 400.0])
	assert_signal_emitted_with(herder, &"bell_rung", [Vector2(5.0, 6.0), 400.0])
	assert_eq(_audio.played[-1]["event"], AudioEvents.BELL)
	assert_false(herder.can_ring_bell())
	_input.simulate_release(InputActions.BELL)
	_input.simulate_press(InputActions.BELL)
	assert_signal_emit_count(_swarm, &"bell_rung", 1, "not during the cooldown")

	await wait_seconds(0.4)
	assert_true(herder.can_ring_bell())
	assert_true(herder.ring_bell())
	assert_signal_emit_count(_swarm, &"bell_rung", 2)


func test_it_pushes_a_sheep_it_walks_into() -> void:
	var herder: Sheepherder = _spawn()
	var sheep: SheepBody = SHEEP_SCENE.instantiate()
	sheep.position = Vector2(60.0, 0.0)
	add_child_autofree(sheep)
	_input.move_vector = Vector2.RIGHT

	await _physics_frames(40)

	assert_gt(sheep.position.x, 90.0, "the sheep gave way")
	assert_gt(herder.position.x, 30.0, "the Sheepherder got through")


func test_a_remote_controlled_sheepherder_ignores_the_local_input() -> void:
	var herder: Sheepherder = Sheepherder.build(-1, OTHER_ID, {"x": 0.0, "y": 0.0})
	add_child_autofree(herder)
	_input.move_vector = Vector2.RIGHT

	await _physics_frames(5)
	_input.simulate_press(InputActions.SHOOT)

	assert_false(herder.controlled_locally)
	assert_eq(herder.position, Vector2.ZERO)
	assert_eq(_combat.requests.size(), 0)
	assert_false(herder.get_camera().enabled)


func test_a_killed_sheepherder_does_nothing_any_more() -> void:
	var herder: Sheepherder = _spawn()
	_input.move_vector = Vector2.RIGHT
	await _physics_frames(5)
	watch_signals(herder)

	_combat.sheepherder_killed.emit(herder.position)
	var at: Vector2 = herder.position
	await _physics_frames(10)
	_input.simulate_press(InputActions.SHOOT)
	_input.simulate_press(InputActions.BELL)

	assert_false(herder.is_alive())
	assert_eq(herder.position, at, "it stays where it died")
	assert_eq(herder.velocity, Vector2.ZERO)
	assert_eq(_combat.requests.size(), 0, "no shot")
	assert_false(herder.can_ring_bell())
	assert_false(herder.ring_bell())
	assert_signal_not_emitted(herder, &"bell_rung")


# --- Two devices -----------------------------------------------------------------


func test_a_guest_rings_the_bell_through_the_host() -> void:
	var pair: SessionPair = _pair_with_kinds()
	var spawned: Array[Sheepherder] = _herders_of(pair)
	pair.host.entities.spawn(Sheepherder.KIND, SessionPair.GUEST_ID, {"x": 50.0, "y": 0.0})
	var on_host: Sheepherder = spawned[0]
	var on_guest: Sheepherder = spawned[1]
	watch_signals(on_host)
	watch_signals(on_guest)
	watch_signals(_swarm)

	assert_false(on_host.controlled_locally)
	assert_true(on_guest.controlled_locally)
	assert_true(on_guest.ring_bell())

	assert_signal_emit_count(on_host, &"bell_rung", 1)
	assert_signal_emit_count(on_guest, &"bell_rung", 1)
	assert_signal_emit_count(_swarm, &"bell_rung", 1, "only the host's flock reacts")
	assert_false(on_guest.can_ring_bell(), "both devices start the cooldown")
	assert_false(on_host.can_ring_bell())


func test_a_push_reaches_the_device_that_simulates_the_sheep() -> void:
	var pair: SessionPair = _pair_with_kinds()
	var spawned: Array[Sheepherder] = _herders_of(pair)
	var sheep_id: int = pair.host.entities.spawn(&"test_sheep", SessionPair.HOST_ID, {})
	pair.host.entities.spawn(Sheepherder.KIND, SessionPair.GUEST_ID, {"x": 0.0, "y": 300.0})
	var on_host: SheepBody = pair.host.entities.get_entity(sheep_id)
	var copy_on_guest: SheepBody = pair.guest.entities.get_entity(sheep_id)
	await _physics_frames(1)

	spawned[1]._push(copy_on_guest, Vector2(600.0, 0.0))
	await _physics_frames(3)

	assert_gt(on_host.position.x, 5.0, "the host moved its sheep")


# --- Helpers ---------------------------------------------------------------------


func _spawn(at: Vector2 = Vector2.ZERO) -> Sheepherder:
	var herder: Sheepherder = Sheepherder.build(-1, LOCAL_ID, {"x": at.x, "y": at.y})
	add_child_autofree(herder)
	return herder


func _physics_frames(count: int) -> void:
	for _i: int in count:
		await get_tree().physics_frame


## Two connected sessions that both know how to build a Sheepherder and a test
## sheep. The guest's copy of a sheep has no collision, so the two copies,
## which share one physics world here, do not push each other.
func _pair_with_kinds() -> SessionPair:
	var pair: SessionPair = SessionPair.create(self)
	for session: GameSession in [pair.host, pair.guest]:
		session.entities.spawn_root = add_child_autofree(Node2D.new())
		session.entities.register_kind(Sheepherder.KIND, Sheepherder.build.bind(session))
		session.entities.register_kind(&"test_sheep", _build_test_sheep.bind(session == pair.guest))
	pair.connect_both()
	return pair


func _build_test_sheep(_id: int, _owner: int, _data: Dictionary, ghost: bool) -> Node:
	var sheep: SheepBody = SHEEP_SCENE.instantiate()
	sheep.add_child(NetTransform2D.new())
	if ghost:
		sheep.collision_layer = 0
		sheep.collision_mask = 0
	return sheep


## Fills an array with the Sheepherders as they spawn: host first, then guest.
func _herders_of(pair: SessionPair) -> Array[Sheepherder]:
	var herders: Array[Sheepherder] = []
	for session: GameSession in [pair.host, pair.guest]:
		session.entities.entity_spawned.connect(
			func(_entity_id: int, entity: Node) -> void:
				if entity is Sheepherder:
					herders.append(entity)
		)
	return herders
