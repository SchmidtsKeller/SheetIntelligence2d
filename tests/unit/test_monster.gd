extends TestCase
## The Monster: a sheep steered by its player, with a sprint, an attack and a
## spider form, on its own device and on the other one (GDD §3.2).

const ARENA_SCENE: PackedScene = preload("res://systems/arena/arena.tscn")
const SHEEP_SCENE: PackedScene = preload("res://entities/sheep/sheep.tscn")
const HOST_ID: int = SessionPair.HOST_ID
const GUEST_ID: int = SessionPair.GUEST_ID
const SPIDER: GameEnums.MonsterForm = GameEnums.MonsterForm.SPIDER


## Counts the attacks it is asked for and accepts them.
class RecordingCombatService:
	extends StubCombatService

	var eat_requests: int = 0

	func request_eat() -> bool:
		eat_requests += 1
		return true


## Remembers which looping sound of which sheep body is switched on.
class RecordingAudioService:
	extends StubAudioService

	var _bodies: Dictionary[int, Node] = {}
	var _loops: Dictionary[int, StringName] = {}
	var _playing: Dictionary[int, bool] = {}

	func start_emitter(event_id: StringName, target: Node2D) -> int:
		var handle: int = super(event_id, target)
		# The sheep's sounds follow its picture, a node inside its scene.
		_bodies[handle] = target.owner if target.owner != null else target
		_loops[handle] = event_id
		return handle

	func set_emitter_playing(handle: int, is_playing: bool) -> void:
		_playing[handle] = is_playing

	func is_looping(body: Node, event_id: StringName) -> bool:
		for handle: int in _loops:
			if _bodies[handle] == body and _loops[handle] == event_id:
				return _playing.get(handle, false)
		return false


var _pair: SessionPair
var _input: StubInputService
var _combat: RecordingCombatService
var _swarm: StubSwarmService
var _audio: RecordingAudioService
var _originals: Dictionary = {}


func before_each() -> void:
	_input = StubInputService.new()
	_input.set_role(GameEnums.Role.MONSTER)
	_combat = RecordingCombatService.new(Services.config)
	_swarm = StubSwarmService.new()
	_audio = RecordingAudioService.new(Services.config)
	_originals[InputService] = Services.replace(InputService, _input)
	_originals[CombatService] = Services.replace(CombatService, _combat)
	_originals[SwarmService] = Services.replace(SwarmService, _swarm)
	_originals[AudioService] = Services.replace(AudioService, _audio)
	_pair = SessionPair.create(self)
	for session: GameSession in [_pair.host, _pair.guest]:
		var root: Node2D = add_child_autofree(Node2D.new())
		Monster.register(session, func() -> Node: return root)
	_pair.connect_both()


func after_each() -> void:
	for contract: Script in _originals:
		Services.replace(contract, _originals[contract]).free()
	_originals.clear()


# --- The body --------------------------------------------------------------------


func test_the_monster_is_a_sheep_with_a_monster_in_it() -> void:
	var monster: Monster = _spawn(HOST_ID, {"seed": 77, "x": 120.0, "y": -40.0})[0]
	var body: SheepBody = monster.get_body()
	var plain: SheepBody = add_child_autofree(SHEEP_SCENE.instantiate())

	assert_eq(body.scene_file_path, SHEEP_SCENE.resource_path, "the scene of every sheep")
	assert_eq(body.get_visual_seed(), 77)
	assert_eq(body.position, Vector2(120.0, -40.0))
	assert_eq(Monster.of(body), monster)
	assert_null(Monster.of(plain))
	assert_null(Monster.of(null))
	assert_is(body.get_node(^"NetSync"), SheepNetSync, "replicated like every sheep")
	assert_eq(monster.get_form(), GameEnums.MonsterForm.SHEEP)
	assert_eq(monster.get_stamina(), 3.0)
	assert_eq(monster.get_stamina_ratio(), 1.0)


func test_its_player_sees_it_live_and_everyone_else_like_any_sheep() -> void:
	var monsters: Array[Monster] = _spawn(GUEST_ID, {}, false)
	var on_host: Monster = monsters[0]
	var on_guest: Monster = monsters[1]

	assert_true(on_guest.controlled_locally)
	assert_true(on_guest.get_body().simulated)
	assert_false(on_guest.get_body().presented_externally, "it follows the input at once")
	assert_not_null(on_guest.get_node_or_null(^"Driver"))
	assert_not_null(on_guest.get_camera())

	assert_false(on_host.controlled_locally)
	assert_false(on_host.get_body().simulated)
	assert_true(on_host.get_body().presented_externally, "through the same delay as the flock")
	assert_null(on_host.get_node_or_null(^"Driver"), "nothing steers it there")
	assert_null(on_host.get_camera())


func test_the_flock_treats_it_as_one_of_its_own() -> void:
	var monster: Monster = _spawn(HOST_ID)[0]
	var body: SheepBody = monster.get_body()

	assert_true(_swarm.get_neighbours().has(body))

	_pair.host.entities.despawn(monster.entity_id)
	await wait_frames(2)
	assert_eq(_swarm.get_neighbours().size(), 0, "and forgets it when it is gone")


func test_it_starts_where_the_flock_left_a_place_free() -> void:
	var arena: Arena = add_child_autofree(ARENA_SCENE.instantiate())
	var round_seed: int = 20261114
	var slot_count: int = Services.config.flock_size + 1
	var slot: int = RoundCast.monster_slot(round_seed, slot_count)

	var data: Dictionary = Monster.spawn_data(round_seed, arena)

	var expected: Vector2 = arena.get_spawn_layout(round_seed, slot_count).sheep_positions[slot]
	assert_eq(data["seed"], RoundCast.visual_seeds(round_seed, slot_count)[slot])
	assert_eq(Vector2(data["x"], data["y"]), expected)


func test_it_lives_among_the_sheep_of_the_arena() -> void:
	var arena: Arena = add_child_autofree(ARENA_SCENE.instantiate())
	var network: StubNetworkService = add_child_autofree(StubNetworkService.new())
	var session: GameSession = add_child_autofree(GameSession.new())
	session.scene_flow = add_child_autofree(SceneFlowController.new())
	session.bind_network(network)
	session.host()
	Monster.register(session)

	var entity_id: int = session.entities.spawn(Monster.KIND, session.get_local_peer_id(), {})

	var body: Node = session.entities.get_entity(entity_id)
	assert_eq(body.get_parent(), arena.get_entities_layer(), "in the y-sorted layer")
	session.leave()
	await wait_frames(2)


# --- Moving ----------------------------------------------------------------------


func test_it_walks_as_fast_as_a_sheep() -> void:
	var monster: Monster = _spawn(HOST_ID)[0]
	_input.move_vector = Vector2.RIGHT

	await _physics_frames(60)

	assert_eq(Services.config.monster_move_speed, Services.config.sheep_move_speed)
	assert_almost_eq(monster.get_body().get_speed(), 180.0, 0.01)
	assert_false(monster.is_sprinting())
	assert_eq(monster.get_stamina(), 3.0)


func test_it_sprints_while_the_button_is_held() -> void:
	var monster: Monster = _spawn(HOST_ID)[0]
	_input.move_vector = Vector2.RIGHT
	_input.simulate_press(InputActions.SPRINT)

	await _physics_frames(60)
	assert_true(monster.is_sprinting())
	assert_almost_eq(monster.get_body().get_speed(), 270.0, 0.01)
	assert_almost_eq(monster.get_stamina(), 2.0, 0.1, "a second of the three is gone")

	_input.simulate_release(InputActions.SPRINT)
	await _physics_frames(60)
	assert_false(monster.is_sprinting())
	assert_almost_eq(monster.get_body().get_speed(), 180.0, 0.01)
	assert_almost_eq(monster.get_stamina(), 2.5, 0.1, "refilled at half the rate")


func test_the_other_device_hears_the_sprint() -> void:
	var monsters: Array[Monster] = _spawn(GUEST_ID)
	_input.move_vector = Vector2.RIGHT
	var running_frames: int = 0
	for _frame: int in 60:
		await _physics_frames(1)
		for monster: Monster in monsters:
			running_frames += int(_audio.is_looping(monster.get_body(), AudioEvents.GRASS_RUN))
	assert_eq(running_frames, 0, "walking never sounds like running, on neither device")
	for monster: Monster in monsters:
		var body: SheepBody = monster.get_body()
		assert_true(_audio.is_looping(body, AudioEvents.GRASS_MOVE), "walking like a sheep")
		assert_false(_audio.is_looping(body, AudioEvents.GRASS_RUN))

	_input.simulate_press(InputActions.SPRINT)
	await _physics_frames(45)

	# On the guest it sprints; on the host its copy is shown sprinting.
	for monster: Monster in monsters:
		var body: SheepBody = monster.get_body()
		assert_true(_audio.is_looping(body, AudioEvents.GRASS_RUN), "louder on both devices")
		assert_false(_audio.is_looping(body, AudioEvents.GRASS_MOVE))
	_input.simulate_release(InputActions.SPRINT)


func test_the_sprint_ends_when_the_stamina_is_used_up() -> void:
	var config: GameConfig = GameConfig.new()
	config.monster_sprint_stamina = 0.5
	var perks: StubPerkService = StubPerkService.new(config)
	_originals[PerkService] = Services.replace(PerkService, perks)
	var monster: Monster = _spawn(HOST_ID)[0]
	_input.move_vector = Vector2.RIGHT
	_input.simulate_press(InputActions.SPRINT)

	await _physics_frames(20)
	assert_true(monster.is_sprinting())
	assert_eq(monster.get_stamina_capacity(), 0.5)

	await _physics_frames(70)
	assert_false(monster.is_sprinting(), "half a second is over")
	assert_almost_eq(monster.get_body().get_speed(), 180.0, 0.01, "back to sheep speed")
	assert_lt(monster.get_stamina(), 0.5, "the button is still down")


func test_sprinting_on_the_spot_costs_nothing() -> void:
	var monster: Monster = _spawn(HOST_ID)[0]
	_input.simulate_press(InputActions.SPRINT)

	await _physics_frames(30)

	assert_false(monster.is_sprinting())
	assert_eq(monster.get_stamina(), 3.0)


func test_a_grazing_monster_stands_still() -> void:
	var monster: Monster = _spawn(HOST_ID)[0]
	var body: SheepBody = monster.get_body()
	_input.simulate_press(InputActions.GRAZE)
	_input.simulate_press(InputActions.SPRINT)
	_input.move_vector = Vector2.RIGHT

	await _physics_frames(30)
	assert_eq(body.get_state(), SheepBody.State.GRAZE)
	assert_eq(body.position, Vector2.ZERO)
	assert_eq(monster.get_stamina(), 3.0, "and uses no stamina")

	_input.simulate_release(InputActions.GRAZE)
	await _physics_frames(30)
	assert_gt(body.position.x, 0.0)


func test_the_camera_keeps_the_monster_in_the_middle() -> void:
	var monster: Monster = _spawn(HOST_ID, {"x": 3000.0, "y": -2000.0})[0]
	var camera: Camera2D = monster.get_camera()
	_input.move_vector = Vector2.LEFT

	await _physics_frames(30)

	assert_true(camera.is_current())
	assert_eq(camera.global_position, monster.get_body().global_position)
	assert_eq(camera.limit_left, -10000000, "no limits: also in the middle at the borders")
	assert_eq(camera.limit_bottom, 10000000)
	var expected_zoom: float = ViewRules.camera_zoom(
		get_viewport().get_visible_rect().size, Services.config.get_view_max_world_size()
	)
	assert_almost_eq(camera.zoom.x, expected_zoom, 0.0001)


# --- Mimicry ---------------------------------------------------------------------


func test_the_bleat_button_bleats() -> void:
	var monster: Monster = _spawn(HOST_ID)[0]
	watch_signals(monster.get_body())

	_input.simulate_press(InputActions.BLEAT)

	assert_signal_emit_count(monster.get_body(), &"bleated", 1)


func test_the_other_device_hears_the_bleat() -> void:
	var monsters: Array[Monster] = _spawn(GUEST_ID)
	watch_signals(monsters[0].get_body())
	watch_signals(monsters[1].get_body())

	_input.simulate_press(InputActions.BLEAT)

	assert_signal_emit_count(monsters[1].get_body(), &"bleated", 1)
	assert_signal_emit_count(monsters[0].get_body(), &"bleated", 1, "and does not send it back")
	assert_eq(_events(AudioEvents.BLEAT).size(), 2)


func test_a_bleat_of_the_host_reaches_the_guest() -> void:
	var monsters: Array[Monster] = _spawn(HOST_ID)
	watch_signals(monsters[1].get_body())

	_input.simulate_press(InputActions.BLEAT)

	assert_signal_emit_count(monsters[1].get_body(), &"bleated", 1)


# --- The attack ------------------------------------------------------------------


func test_the_eat_button_asks_for_an_attack() -> void:
	_spawn(HOST_ID)

	_input.simulate_press(InputActions.EAT)
	_input.simulate_press(InputActions.GRAZE)

	assert_eq(_combat.eat_requests, 1, "once, from the device of the Monster")


func test_eating_holds_the_monster_on_both_devices() -> void:
	var monsters: Array[Monster] = _spawn(HOST_ID)
	var body: SheepBody = monsters[0].get_body()
	_input.move_vector = Vector2.RIGHT
	await _physics_frames(20)

	_combat.eat_started.emit(CombatService.EatTarget.SHEEP, 3, 0.5)
	var at: Vector2 = body.position
	await _physics_frames(10)

	assert_eq(body.get_state(), SheepBody.State.DEVOUR)
	assert_eq(monsters[1].get_body().get_state(), SheepBody.State.DEVOUR)
	assert_eq(body.position, at)

	await _physics_frames(40)
	assert_gt(body.position.x, at.x, "after the meal it walks on")


func test_eating_uses_no_stamina() -> void:
	var monster: Monster = _spawn(HOST_ID)[0]
	_input.move_vector = Vector2.RIGHT
	_input.simulate_press(InputActions.SPRINT)
	_combat.eat_started.emit(CombatService.EatTarget.SHEEP, 3, 1.0)

	await _physics_frames(30)

	assert_false(monster.is_sprinting())
	assert_eq(monster.get_stamina(), 3.0)


func test_a_shot_monster_lies_like_a_shot_sheep() -> void:
	var monsters: Array[Monster] = _spawn(HOST_ID)
	_input.move_vector = Vector2.RIGHT
	await _physics_frames(10)

	_combat.monster_shot.emit(monsters[0].get_body().position)
	var at: Vector2 = monsters[0].get_body().position
	await _physics_frames(20)

	for monster: Monster in monsters:
		assert_eq(monster.get_body().get_state(), SheepBody.State.CORPSE)
	assert_eq(monsters[0].get_body().position, at)


# --- The spider ------------------------------------------------------------------


func test_the_spider_replaces_the_sheep_on_both_devices() -> void:
	var monsters: Array[Monster] = _spawn(HOST_ID)

	_combat.monster_form_changed.emit(SPIDER)

	for monster: Monster in monsters:
		var body: SheepBody = monster.get_body()
		assert_eq(monster.get_form(), SPIDER)
		assert_is(body.get_node_or_null(^"Facing/Spider"), SpiderVisual)
		assert_false((body.get_node(^"Facing/Pose") as Node2D).visible, "the sheep is gone")
		assert_eq(
			(body.get_node(^"VisionTarget") as VisionTarget).radius,
			SpiderVisual.RADIUS,
			"seen as the large thing it is"
		)


func test_the_spider_runs_at_300_without_stamina() -> void:
	var monster: Monster = _spawn(HOST_ID)[0]
	_combat.monster_form_changed.emit(SPIDER)
	_input.move_vector = Vector2.RIGHT
	_input.simulate_press(InputActions.SPRINT)

	await _physics_frames(60)

	assert_almost_eq(monster.get_body().get_speed(), 300.0, 0.01)
	assert_false(monster.is_sprinting(), "it has no sprint")
	assert_eq(monster.get_stamina(), 3.0)


func test_the_spider_neither_grazes_nor_bleats() -> void:
	var monster: Monster = _spawn(HOST_ID)[0]
	var body: SheepBody = monster.get_body()
	_input.simulate_press(InputActions.GRAZE)
	assert_true(body.is_grazing())
	watch_signals(body)

	_combat.monster_form_changed.emit(SPIDER)
	assert_false(body.is_grazing(), "it stops grazing when it changes")

	_input.simulate_release(InputActions.GRAZE)
	_input.simulate_press(InputActions.GRAZE)
	_input.simulate_press(InputActions.BLEAT)
	assert_false(body.is_grazing())
	assert_signal_not_emitted(body, &"bleated")


func test_the_spider_still_attacks() -> void:
	_spawn(HOST_ID)
	_combat.monster_form_changed.emit(SPIDER)

	_input.simulate_press(InputActions.EAT)

	assert_eq(_combat.eat_requests, 1)


func test_a_new_round_brings_the_sheep_back() -> void:
	var monster: Monster = _spawn(HOST_ID)[0]
	var body: SheepBody = monster.get_body()
	_combat.monster_form_changed.emit(SPIDER)

	_combat.monster_form_changed.emit(GameEnums.MonsterForm.SHEEP)
	_input.simulate_press(InputActions.GRAZE)

	assert_eq(monster.get_form(), GameEnums.MonsterForm.SHEEP)
	assert_true((body.get_node(^"Facing/Pose") as Node2D).visible)
	assert_eq((body.get_node(^"VisionTarget") as VisionTarget).radius, 22.0)
	assert_true(body.is_grazing())


# --- Helpers ---------------------------------------------------------------------


## Spawns the Monster of [param owner_id] and returns it as the host and as the
## guest have it. With [param ghost], the copy on the other device has no
## collision, so the two copies, which share one physics world here, do not
## push each other.
func _spawn(owner_id: int, data: Dictionary = {}, ghost: bool = true) -> Array[Monster]:
	var entity_id: int = _pair.host.entities.spawn(Monster.KIND, owner_id, data)
	var monsters: Array[Monster] = []
	for session: GameSession in [_pair.host, _pair.guest]:
		var body: SheepBody = session.entities.get_entity(entity_id)
		var monster: Monster = Monster.of(body)
		if ghost and not monster.controlled_locally:
			body.collision_layer = 0
			body.collision_mask = 0
		monsters.append(monster)
	return monsters


func _physics_frames(count: int) -> void:
	for _i: int in count:
		await get_tree().physics_frame


func _events(event_id: StringName) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for entry: Dictionary in _audio.played:
		if entry["event"] == event_id:
			positions.append(entry["position"])
	return positions
