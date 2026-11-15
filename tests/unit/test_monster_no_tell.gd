extends TestCase
## "No Built-in Tell" (GDD §3.2): on the Sheepherder's device the Monster is
## built, shown, heard and pushed exactly like an NPC sheep. The checklist this
## test works through is docs/no-tell-audit.md.
##
## Two devices in one process: the host's world in the main viewport, the
## guest's in a viewport of its own. Each has the real arena and the real
## flock service, whose minds are switched off so that the test can steer one
## NPC sheep (the "twin") exactly like the Monster's player steers the Monster.
## Both get the same visual seed, so every difference that is left is a tell.
##
## Every test runs twice: with the Sheepherder on the guest (Monster and flock
## both arrive over the network) and on the host (the flock is simulated on
## the Sheepherder's own device, the Monster is not).

const ARENA_SCENE: PackedScene = preload("res://systems/arena/arena.tscn")
const HOST_ID: int = SessionPair.HOST_ID
const GUEST_ID: int = SessionPair.GUEST_ID
const VISUAL_SEED: int = 4711
## Where the two start, relative to the middle of the flock's spawn area.
const TWIN_OFFSET: Vector2 = Vector2(-100.0, -120.0)
const MONSTER_OFFSET: Vector2 = Vector2(-100.0, 120.0)
## The same steps round differently 240 px apart (positions are float32).
const ROUNDING: float = 0.01
## A frame longer than this is a hitch. The two devices share one process
## here, and the snapshot the other one sends during a frame reaches this one
## only after it has drawn. The interpolation delay (0.1 s) covers that for
## every ordinary frame; a hitch uses the reserve up, on a real device as
## well, where nothing is drawn meanwhile. Such frames are not compared.
const HITCH: float = 0.04
## How many frames after a hitch are left out as well.
const FRAMES_AFTER_HITCH: int = 3


## Remembers which looping sound of which entity is switched on and off.
class RecordingAudioService:
	extends StubAudioService

	## Per entity: [code][event, playing][/code] in the order it happened.
	var switched: Dictionary[Node, Array] = {}
	var _targets: Dictionary[int, Node] = {}
	var _events: Dictionary[int, StringName] = {}

	func start_emitter(event_id: StringName, target: Node2D) -> int:
		var handle: int = super(event_id, target)
		# The sheep's sounds follow its picture, a node inside its scene.
		_targets[handle] = target.owner if target.owner != null else target
		_events[handle] = event_id
		return handle

	func set_emitter_playing(handle: int, is_playing: bool) -> void:
		if _targets.has(handle):
			var log: Array = switched.get_or_add(_targets[handle], [])
			log.append([_events[handle], is_playing])


var _pair: SessionPair
var _arenas: Dictionary[GameSession, Arena] = {}
var _swarms: Dictionary[GameSession, FlockSwarmService] = {}
var _input: StubInputService
var _audio: RecordingAudioService
var _originals: Dictionary = {}

## The session of the Sheepherder's device and of the Monster's.
var _view: GameSession
var _far: GameSession
var _monster_id: int = -1
var _twin_id: int = -1


func before_each() -> void:
	_input = StubInputService.new()
	_input.set_role(GameEnums.Role.MONSTER)
	_audio = RecordingAudioService.new(Services.config)
	_originals[InputService] = Services.replace(InputService, _input)
	_originals[AudioService] = Services.replace(AudioService, _audio)
	_originals[SwarmService] = Services.replace(SwarmService, StubSwarmService.new())
	_originals[CombatService] = Services.replace(
		CombatService, StubCombatService.new(Services.config)
	)
	_pair = SessionPair.create(self)
	var guest_viewport: SubViewport = add_child_autofree(SubViewport.new())
	_arenas[_pair.host] = add_child_autofree(ARENA_SCENE.instantiate())
	_arenas[_pair.guest] = ARENA_SCENE.instantiate()
	guest_viewport.add_child(_arenas[_pair.guest])
	for session: GameSession in [_pair.host, _pair.guest]:
		var arena: Arena = _arenas[session]
		var swarm: FlockSwarmService = add_child_autofree(FlockSwarmService.new())
		swarm.arena = arena
		swarm.setup(session, Services.perks)
		# No minds: the test steers the twin.
		swarm.set_physics_process(false)
		_swarms[session] = swarm
		Monster.register(session, arena.get_entities_layer)
		session.entities.register_kind(
			Sheepherder.KIND, Sheepherder.build.bind(session), arena.get_entities_layer
		)
	_pair.connect_both()


func after_each() -> void:
	_pair.host.entities.despawn_all()
	await wait_frames(2)
	for contract: Script in _originals:
		Services.replace(contract, _originals[contract]).free()
	_originals.clear()
	_arenas.clear()
	_swarms.clear()


# --- 1. Built alike --------------------------------------------------------------


func test_built_like_a_sheep_with_the_sheepherder_on_the_guest() -> void:
	_stage(HOST_ID)
	_assert_built_alike()


func test_built_like_a_sheep_with_the_sheepherder_on_the_host() -> void:
	_stage(GUEST_ID)
	_assert_built_alike()


func _assert_built_alike() -> void:
	var monster: SheepBody = _seen(_monster_id)
	var twin: SheepBody = _seen(_twin_id)

	# Appearance generation: one scene, one generator, seeds drawn alike.
	assert_eq(monster.scene_file_path, twin.scene_file_path, "the same scene")
	assert_eq(monster.catalog, twin.catalog)
	assert_eq(
		monster.get_appearance().fingerprint(),
		SheepAppearanceGenerator.generate(VISUAL_SEED, monster.catalog).fingerprint(),
		"its look comes from its seed like every sheep's"
	)
	assert_eq(monster.get_appearance().fingerprint(), twin.get_appearance().fingerprint())

	# Draw order: the same y-sorted layer, the same z, the same nodes.
	assert_eq(monster.get_parent(), twin.get_parent())
	assert_eq(monster.get_parent(), _arenas[_view].get_entities_layer())
	var monster_tree: PackedStringArray = _describe_tree(monster)
	var twin_tree: PackedStringArray = _describe_tree(twin)
	var extra: PackedStringArray = []
	for line: String in monster_tree:
		if not twin_tree.has(line):
			extra.append(line)
	assert_eq(extra.size(), 1, "one node more than a sheep: %s" % [extra])
	assert_true(extra[0].begins_with("Monster "), "the Monster's logic")
	assert_eq(monster_tree.size(), twin_tree.size() + 1, "and nothing less")

	# That one node shows nothing: no picture, no children, no sound, no camera.
	var logic: Monster = Monster.of(monster)
	assert_eq(logic.get_child_count(), 0)
	assert_false(logic.controlled_locally)
	assert_null(logic.get_camera())

	# Interpolation: both are put where the network says and shown from the
	# same kind of buffer, a moment in the past.
	assert_true(monster.presented_externally)
	assert_true(twin.presented_externally)
	assert_is(monster.get_node(^"NetSync"), SheepNetSync)
	assert_eq(
		(monster.get_node(^"NetSync") as Node).get_script(),
		(twin.get_node(^"NetSync") as Node).get_script()
	)

	# Collision and groups.
	assert_eq(monster.get_groups(), twin.get_groups())
	assert_eq(monster.collision_layer, twin.collision_layer)
	assert_eq(monster.collision_mask, twin.collision_mask)

	# Reaction to the flashlight: the same target for the vision system.
	var monster_target: VisionTarget = monster.get_node(^"VisionTarget")
	var twin_target: VisionTarget = twin.get_node(^"VisionTarget")
	assert_eq(monster_target.kind, twin_target.kind)
	assert_eq(monster_target.radius, twin_target.radius)
	assert_eq(monster.get_path_to(monster_target.visual), twin.get_path_to(twin_target.visual))


# --- 2. Moves, grazes and bleats alike -------------------------------------------


func test_behaves_like_a_sheep_with_the_sheepherder_on_the_guest() -> void:
	# Both arrive in the same snapshots.
	_stage(HOST_ID)
	await _assert_behaves_alike()


func test_behaves_like_a_sheep_with_the_sheepherder_on_the_host() -> void:
	# The Monster's snapshots are sent by the other device, the flock's are
	# taken on this one; both are shown the same moment in the past.
	_stage(GUEST_ID)
	await _assert_behaves_alike()


func _assert_behaves_alike() -> void:
	var monster: SheepBody = _seen(_monster_id)
	var twin: SheepBody = _seen(_twin_id)
	var compare: Callable = _compare.bind(monster, twin)
	watch_signals(monster)
	watch_signals(twin)
	var wish: Vector2 = Vector2(1.0, 0.3)
	# Loading the scenes is over, snapshots flow.
	await _watch(15, compare)

	# Walk.
	_input.move_vector = wish
	_real(_twin_id).set_move_input(wish)
	var walking: Dictionary = await _watch(40, compare)
	assert_eq(monster.get_state(), SheepBody.State.WALK, "it is seen walking")
	assert_gt(_shown_offset(monster, MONSTER_OFFSET).x, 40.0)

	# Graze.
	_input.simulate_press(InputActions.GRAZE)
	_real(_twin_id).set_grazing(true)
	var grazing: Dictionary = await _watch(40, compare)
	assert_eq(monster.get_state(), SheepBody.State.GRAZE, "it is seen grazing")

	# Walk on and bleat.
	_input.simulate_release(InputActions.GRAZE)
	_real(_twin_id).set_grazing(false)
	_input.simulate_press(InputActions.BLEAT)
	_pair.host.messenger.broadcast(FlockSwarmService.EVENT_BLEAT, [_twin_id])
	assert_eq(_bleats_near(monster.global_position), 2, "one bleat sound on each device")
	assert_eq(_bleats_near(twin.global_position), 2)
	var monster_voice: AnimationPlayer = monster.get_node(^"Voice")
	var twin_voice: AnimationPlayer = twin.get_node(^"Voice")
	assert_eq(monster_voice.current_animation, String(SheepBody.ANIMATION_BLEAT))
	assert_eq(monster_voice.current_animation, twin_voice.current_animation)
	assert_eq(monster_voice.current_animation_position, twin_voice.current_animation_position)
	var leaving: Dictionary = await _watch(40, compare)

	# Stop.
	_input.move_vector = Vector2.ZERO
	_real(_twin_id).set_move_input(Vector2.ZERO)
	var stopping: Dictionary = await _watch(40, compare)
	assert_eq(monster.get_state(), SheepBody.State.IDLE)

	for phase: Dictionary in [walking, grazing, leaving, stopping]:
		assert_lte(phase["distance"], ROUNDING, "shown in the same place: %s" % phase)
		assert_lte(phase["heading"], 0.0001, "facing the same way: %s" % phase)
		assert_eq(phase["state_frames"], 0, "doing the same in every frame: %s" % phase)
		assert_eq(phase["painted_frames"], 0, "the same painted frame in every frame: %s" % phase)
		assert_gt(phase["frames"], 10, "enough frames were compared: %s" % phase)
	assert_signal_emit_count(monster, &"bleated", 1)
	assert_signal_emit_count(twin, &"bleated", 1)
	# Movement and grazing sounds: the same loops, switched in the same order.
	assert_eq(_audio.switched.get(monster, []), _audio.switched.get(twin, []))
	assert_gt((_audio.switched.get(monster, []) as Array).size(), 3)


# --- 3. Solid and pushed alike ---------------------------------------------------


func test_pushed_like_a_sheep_with_the_sheepherder_on_the_guest() -> void:
	_stage(HOST_ID)
	await _assert_pushed_alike()


func test_pushed_like_a_sheep_with_the_sheepherder_on_the_host() -> void:
	_stage(GUEST_ID)
	await _assert_pushed_alike()


func _assert_pushed_alike() -> void:
	var herder: Sheepherder = _spawn_sheepherder(Vector2(-400.0, 0.0))
	var monster: SheepBody = _seen(_monster_id)
	var twin: SheepBody = _seen(_twin_id)
	for body: SheepBody in [monster, twin]:
		var shape: CollisionShape2D = body.get_node(^"Collision")
		assert_false(shape.disabled, "solid for the Sheepherder")
	assert_eq(
		(monster.get_node(^"Collision") as CollisionShape2D).shape,
		(twin.get_node(^"Collision") as CollisionShape2D).shape
	)
	await _physics_frames(2)
	var monster_start: Vector2 = _real(_monster_id).position
	var twin_start: Vector2 = _real(_twin_id).position

	herder._push(monster, Vector2(600.0, 0.0))
	herder._push(twin, Vector2(600.0, 0.0))
	await _physics_frames(4)

	var monster_moved: Vector2 = _real(_monster_id).position - monster_start
	var twin_moved: Vector2 = _real(_twin_id).position - twin_start
	assert_gt(twin_moved.x, 5.0, "the sheep gives way")
	assert_almost_eq(monster_moved, twin_moved, ROUNDING, "and the Monster exactly as far")


# --- 4. Lit alike ----------------------------------------------------------------


func test_lit_like_a_sheep_with_the_sheepherder_on_the_guest() -> void:
	_stage(HOST_ID)
	await _assert_lit_alike()


func test_lit_like_a_sheep_with_the_sheepherder_on_the_host() -> void:
	_stage(GUEST_ID)
	await _assert_lit_alike()


func _assert_lit_alike() -> void:
	# The Sheepherder stands to the left of the two, at the same distance.
	var herder: Sheepherder = _spawn_sheepherder(Vector2(-300.0, 0.0))
	var vision: VisionSystem = VisionSystem.new()
	_arenas[_view].add_child(vision)
	vision.set_process(false)
	vision.viewer = herder
	vision.role = GameEnums.Role.SHEEPHERDER
	var monster_target: VisionTarget = _seen(_monster_id).get_node(^"VisionTarget")
	var twin_target: VisionTarget = _seen(_twin_id).get_node(^"VisionTarget")

	_input.aim_direction = Vector2.RIGHT
	await _physics_frames(2)
	vision.update(1.0)
	assert_eq(twin_target.shown, 1.0, "the sheep is in the light")
	assert_eq(monster_target.shown, twin_target.shown)

	# Half way out of the light, both are half way gone.
	_input.aim_direction = Vector2.LEFT
	await _physics_frames(2)
	vision.update(0.5 / vision.fade_speed)
	assert_almost_eq(twin_target.shown, 0.5, 0.001)
	assert_eq(monster_target.shown, twin_target.shown)
	var monster_picture: CanvasItem = monster_target.visual
	var twin_picture: CanvasItem = twin_target.visual
	assert_eq(monster_picture.modulate, twin_picture.modulate, "faded the same way")

	vision.update(1.0)
	assert_eq(twin_target.shown, 0.0, "the sheep is in the dark")
	assert_eq(monster_target.shown, twin_target.shown)


# --- Helpers ---------------------------------------------------------------------


## Spawns the Monster, steered on the device of [param monster_owner_id], and
## one NPC sheep with the same look. The other device is the Sheepherder's.
func _stage(monster_owner_id: int) -> void:
	_far = _pair.host if monster_owner_id == HOST_ID else _pair.guest
	_view = _pair.guest if monster_owner_id == HOST_ID else _pair.host
	# The Sheepherder's session runs first in every frame. Both devices share
	# one process here; this way its clock has already reached the frame in
	# which the other device sends a snapshot, as on a real second device,
	# where no packet arrives before it was sent.
	if _view.get_index() > _far.get_index():
		move_child(_view, _far.get_index())
	var middle: Vector2 = _middle()
	var twin_at: Vector2 = middle + TWIN_OFFSET
	var monster_at: Vector2 = middle + MONSTER_OFFSET
	assert_true(_arenas[_view].is_free(twin_at, 60.0), "the twin starts in the open")
	assert_true(_arenas[_view].is_free(monster_at, 60.0), "the Monster starts in the open")
	_twin_id = _pair.host.entities.spawn(
		FlockSwarmService.KIND,
		HOST_ID,
		{"seed": VISUAL_SEED, "x": twin_at.x, "y": twin_at.y, "mind": 1}
	)
	_monster_id = _pair.host.entities.spawn(
		Monster.KIND, monster_owner_id, {"seed": VISUAL_SEED, "x": monster_at.x, "y": monster_at.y}
	)


func _middle() -> Vector2:
	return _arenas[_pair.host].get_flock_spawn_area().get_center()


## The body as the Sheepherder's device has it.
func _seen(entity_id: int) -> SheepBody:
	return _view.entities.get_entity(entity_id)


## The body on the device that simulates it.
func _real(entity_id: int) -> SheepBody:
	var session: GameSession = _pair.host
	if entity_id == _monster_id:
		session = _far
	return session.entities.get_entity(entity_id)


## The Sheepherder of the Sheepherder's device, [param offset] from the middle
## between the two sheep.
func _spawn_sheepherder(offset: Vector2) -> Sheepherder:
	var at: Vector2 = _middle() + Vector2(TWIN_OFFSET.x, 0.0) + offset
	var owner_id: int = _view.messenger.get_local_id()
	var entity_id: int = _pair.host.entities.spawn(
		Sheepherder.KIND, owner_id, {"x": at.x, "y": at.y}
	)
	return _view.entities.get_entity(entity_id)


## Where the picture of [param body] is, relative to where it started.
func _shown_offset(body: SheepBody, start_offset: Vector2) -> Vector2:
	return (body.get_node(^"Facing") as Node2D).global_position - _middle() - start_offset


## How far apart the Monster and the twin are shown right now:
## [code][distance, heading, state differs, painted frame differs][/code].
func _compare(monster: SheepBody, twin: SheepBody) -> Array:
	var monster_facing: Node2D = monster.get_node(^"Facing")
	var twin_facing: Node2D = twin.get_node(^"Facing")
	return [
		_shown_offset(monster, MONSTER_OFFSET).distance_to(_shown_offset(twin, TWIN_OFFSET)),
		absf(angle_difference(monster_facing.global_rotation, twin_facing.global_rotation)),
		monster.get_state() != twin.get_state(),
		_painted_frame(monster) != _painted_frame(twin),
	]


## Lets [param ticks] physics steps pass and looks at both sheep in every
## frame that is drawn meanwhile. Returns the largest distance and heading
## difference, and in how many frames the two were doing something different.
func _watch(ticks: int, compare: Callable) -> Dictionary:
	var worst: Dictionary = {
		"distance": 0.0, "heading": 0.0, "state_frames": 0, "painted_frames": 0, "frames": 0
	}
	var until: int = Engine.get_physics_frames() + ticks
	var skip: int = 0
	while Engine.get_physics_frames() < until:
		await get_tree().process_frame
		if get_process_delta_time() > HITCH:
			skip = FRAMES_AFTER_HITCH + 1
		if skip > 0:
			skip -= 1
			continue
		var now: Array = compare.call()
		worst["frames"] += 1
		worst["distance"] = maxf(worst["distance"], now[0])
		worst["heading"] = maxf(worst["heading"], now[1])
		worst["state_frames"] += int(now[2])
		worst["painted_frames"] += int(now[3])
	return worst


## The painted frames a sheep shows right now: animation, frame and speed of
## every animated layer.
func _painted_frame(body: SheepBody) -> String:
	var shown: PackedStringArray = []
	for node: Node in body.get_node(^"Facing").find_children("*", "AnimatedSprite2D", true, false):
		var sprite: AnimatedSprite2D = node
		shown.append(
			(
				"%s %s %d %.3f"
				% [sprite.sprite_frames, sprite.animation, sprite.frame, sprite.speed_scale]
			)
		)
	return ", ".join(shown)


func _physics_frames(count: int) -> void:
	for _i: int in count:
		await get_tree().physics_frame


## How many bleat sounds were played where the sheep at [param position] is.
## Both devices share the recording here; the copy of a sheep on the other
## device stands at most 0.1 s of walking (18 px) away from the original.
func _bleats_near(position: Vector2) -> int:
	var count: int = 0
	for entry: Dictionary in _audio.played:
		if entry["event"] == AudioEvents.BLEAT:
			count += int((entry["position"] as Vector2).distance_to(position) < 30.0)
	return count


## Everything about the sheep's nodes that could be seen or inspected, except
## where it stands.
func _describe_tree(root: Node2D) -> PackedStringArray:
	var lines: PackedStringArray = []
	var nodes: Array[Node] = [root]
	nodes.append_array(root.find_children("*", "", true, false))
	for node: Node in nodes:
		var line: String = (
			"%s %s %s %s"
			% [root.get_path_to(node), node.get_class(), node.get_script(), node.get_groups()]
		)
		if node is CanvasItem:
			var item: CanvasItem = node
			line += (
				" visible=%s z=%d rel=%s ysort=%s top=%s modulate=%s self=%s"
				% [
					item.visible,
					item.z_index,
					item.z_as_relative,
					item.y_sort_enabled,
					item.top_level,
					item.modulate,
					item.self_modulate,
				]
			)
		if node is Node2D and node != root:
			var node_2d: Node2D = node
			var at: Vector2 = node_2d.position
			if node_2d.top_level:
				at = (node_2d.global_position - root.global_position).snappedf(ROUNDING)
			line += " at=%s rot=%s scale=%s" % [at, node_2d.rotation, node_2d.scale]
		if node is Sprite2D:
			line += " texture=%s" % (node as Sprite2D).texture
		if node is AnimatedSprite2D:
			line += " frames=%s" % (node as AnimatedSprite2D).sprite_frames
		if node is CollisionObject2D:
			var solid: CollisionObject2D = node
			line += " layer=%d mask=%d" % [solid.collision_layer, solid.collision_mask]
		if node is CollisionShape2D:
			var shape: CollisionShape2D = node
			line += " shape=%s disabled=%s" % [shape.shape, shape.disabled]
		if node is AnimationPlayer:
			var player: AnimationPlayer = node
			line += " playing=%s" % player.current_animation
		lines.append(line)
	return lines
