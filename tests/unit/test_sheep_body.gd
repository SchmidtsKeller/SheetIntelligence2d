extends TestCase
## The shared sheep body: look, steering, states, death and the guarantee that
## a sheep never shows who steers it (GDD §3.2, §3.3).

const SHEEP_SCENE: PackedScene = preload("res://entities/sheep/sheep.tscn")


## Remembers which emitters are playing.
class RecordingAudioService:
	extends StubAudioService

	var playing: Dictionary[int, bool] = {}

	func set_emitter_playing(handle: int, is_playing: bool) -> void:
		playing[handle] = is_playing


var _audio: RecordingAudioService
var _original_audio: Node


func before_each() -> void:
	_audio = RecordingAudioService.new(Services.config)
	_original_audio = Services.replace(AudioService, _audio)


func after_each() -> void:
	Services.replace(AudioService, _original_audio)
	_audio.free()


# --- Scene -------------------------------------------------------------------------

func test_a_sheep_is_a_solid_sheep_like_entity() -> void:
	var sheep: SheepBody = _spawn()
	var hit_area: Area2D = sheep.get_node(^"Facing/HitArea")

	assert_true(sheep.is_in_group(Groups.SHEEP_LIKE))
	assert_true(sheep.is_in_group(Groups.DYNAMIC_ENTITIES))
	assert_eq(sheep.collision_layer, PhysicsLayers.SHEEP)
	assert_eq(sheep.collision_mask, PhysicsLayers.WORLD | PhysicsLayers.SHEEP | PhysicsLayers.SHEEPHERDER)
	assert_eq(sheep.motion_mode, CharacterBody2D.MOTION_MODE_FLOATING)
	assert_eq(hit_area.collision_layer, PhysicsLayers.HITBOX)
	assert_eq(sheep.get_state(), SheepBody.State.IDLE)


func test_the_layers_show_the_look_of_the_seed() -> void:
	var sheep: SheepBody = _spawn(4242)
	var expected: SheepAppearance = SheepAppearanceGenerator.generate(4242, sheep.catalog)

	assert_eq(sheep.get_appearance().fingerprint(), expected.fingerprint())
	for slot_index: int in sheep.catalog.slots.size():
		var slot: SheepAppearanceSlot = sheep.catalog.slots[slot_index]
		var layer: Sprite2D = _layer(sheep, slot)
		var part_index: int = expected.part_indices[slot_index]
		assert_eq(layer.visible, part_index != SheepAppearance.NONE, "layer '%s' visible" % slot.id)
		if part_index == SheepAppearance.NONE:
			continue
		var part: SheepAppearancePart = slot.parts[part_index]
		assert_eq(layer.texture, part.texture)
		var tint_index: int = expected.tint_indices[slot_index]
		assert_eq(layer.self_modulate, part.tints[tint_index] if tint_index != SheepAppearance.NONE else Color.WHITE)


func test_the_look_can_change_after_the_sheep_is_in_the_tree() -> void:
	var sheep: SheepBody = _spawn(1)

	sheep.set_visual_seed(2)

	assert_eq(sheep.get_visual_seed(), 2)
	assert_eq(sheep.get_appearance().fingerprint(), SheepAppearanceGenerator.generate(2, sheep.catalog).fingerprint())


# --- Steering ----------------------------------------------------------------------

func test_a_steered_sheep_walks_and_faces_where_it_goes() -> void:
	var sheep: SheepBody = _spawn()
	watch_signals(sheep)

	sheep.set_move_input(Vector2.DOWN)
	await _physics_frames(30)

	assert_eq(sheep.get_state(), SheepBody.State.WALK)
	assert_signal_emitted_with(sheep, &"state_changed", [SheepBody.State.WALK])
	assert_gt(sheep.position.y, 0.0)
	assert_almost_eq(sheep.get_heading(), Vector2.DOWN.angle(), 0.001)
	assert_almost_eq((sheep.get_node(^"Facing") as Node2D).rotation, sheep.get_heading())
	assert_lte(sheep.get_speed(), Services.config.sheep_move_speed)


func test_a_sheep_that_stops_goes_back_to_idle() -> void:
	var sheep: SheepBody = _spawn()
	sheep.set_move_input(Vector2.RIGHT)
	await _physics_frames(20)

	sheep.set_move_input(Vector2.ZERO)
	await _physics_frames(30)

	assert_eq(sheep.get_state(), SheepBody.State.IDLE)
	assert_eq(sheep.get_speed(), 0.0)


func test_a_grazing_sheep_stands_still() -> void:
	var sheep: SheepBody = _spawn()

	assert_true(sheep.set_grazing(true))
	sheep.set_move_input(Vector2.RIGHT)
	await _physics_frames(20)

	assert_eq(sheep.get_state(), SheepBody.State.GRAZE)
	assert_eq(sheep.position, Vector2.ZERO)

	sheep.set_grazing(false)
	await _physics_frames(20)
	assert_eq(sheep.get_state(), SheepBody.State.WALK)
	assert_gt(sheep.position.x, 0.0)


func test_a_bleat_is_heard_where_the_sheep_is() -> void:
	var sheep: SheepBody = _spawn(0, Vector2(30.0, 40.0))
	watch_signals(sheep)

	assert_true(sheep.bleat())
	assert_false(sheep.bleat(), "no second bleat while bleating")

	assert_signal_emit_count(sheep, &"bleated", 1)
	assert_eq(_events(&"bleat"), [Vector2(30.0, 40.0)])


func test_a_sheep_can_bleat_again_once_the_bleat_is_over() -> void:
	var sheep: SheepBody = _spawn()
	sheep.bleat()

	await wait_seconds(0.8)

	assert_true(sheep.bleat())


func test_a_pushed_sheep_moves_even_while_grazing() -> void:
	var sheep: SheepBody = _spawn()
	sheep.set_grazing(true)

	for _i: int in 10:
		sheep.push(Vector2(120.0, 0.0))
		await _physics_frames(1)

	assert_gt(sheep.position.x, 10.0)
	assert_eq(sheep.get_state(), SheepBody.State.GRAZE)


func test_sounds_follow_what_the_sheep_does() -> void:
	var sheep: SheepBody = _spawn()
	var move_emitter: int = 1
	var graze_emitter: int = 2
	assert_eq(_audio.get_emitter_count(), 2, "rustle and grazing emitters")

	sheep.set_move_input(Vector2.RIGHT)
	await _physics_frames(5)
	assert_true(_audio.playing.get(move_emitter, false), "rustle while walking")
	assert_false(_audio.playing.get(graze_emitter, false))

	sheep.set_grazing(true)
	assert_false(_audio.playing[move_emitter])
	assert_true(_audio.playing[graze_emitter], "munching while grazing")

	sheep.kill(GameEnums.DeathCause.SHOT)
	assert_false(_audio.playing[move_emitter])
	assert_false(_audio.playing[graze_emitter])


# --- Death -------------------------------------------------------------------------

func test_a_shot_sheep_leaves_a_body() -> void:
	var sheep: SheepBody = _spawn()
	watch_signals(sheep)

	assert_true(sheep.kill(GameEnums.DeathCause.SHOT))
	await _physics_frames(2)

	assert_eq(sheep.get_state(), SheepBody.State.CORPSE)
	assert_false(sheep.is_alive())
	assert_signal_emitted_with(sheep, &"died", [GameEnums.DeathCause.SHOT])
	assert_true(sheep.visible, "the body stays")
	assert_true((sheep.get_node(^"Collision") as CollisionShape2D).disabled, "a body does not block")
	assert_true((sheep.get_node(^"Facing/HitArea/Shape") as CollisionShape2D).disabled, "a body stops no bullet")


func test_a_body_ignores_steering_and_pushes() -> void:
	var sheep: SheepBody = _spawn()
	sheep.kill(GameEnums.DeathCause.SHOT)

	sheep.set_move_input(Vector2.RIGHT)
	sheep.push(Vector2(500.0, 0.0))
	await _physics_frames(10)

	assert_eq(sheep.position, Vector2.ZERO)
	assert_false(sheep.set_grazing(true))
	assert_false(sheep.bleat())


func test_the_body_of_a_shot_sheep_can_be_eaten() -> void:
	var sheep: SheepBody = _spawn()
	watch_signals(sheep)
	sheep.kill(GameEnums.DeathCause.SHOT)

	assert_true(sheep.kill(GameEnums.DeathCause.EATEN))

	assert_eq(sheep.get_state(), SheepBody.State.EATEN)
	assert_signal_emit_count(sheep, &"died", 1)
	await wait_seconds(Services.config.eat_duration + 0.3)
	assert_false(sheep.visible, "nothing is left but the blood")


func test_an_eaten_sheep_disappears_once_the_eating_is_over() -> void:
	var sheep: SheepBody = _spawn()
	watch_signals(sheep)

	assert_true(sheep.kill(GameEnums.DeathCause.EATEN))
	assert_signal_emitted_with(sheep, &"died", [GameEnums.DeathCause.EATEN])
	await wait_seconds(Services.config.eat_duration * 0.5)
	assert_true(sheep.visible, "still being eaten")

	await wait_seconds(Services.config.eat_duration * 0.5 + 0.3)
	assert_false(sheep.visible)


func test_the_eaten_animation_follows_the_effective_eat_duration() -> void:
	var config: GameConfig = GameConfig.new()
	config.eat_duration = 0.4
	var perks: StubPerkService = StubPerkService.new(config)
	var original_perks: Node = Services.replace(PerkService, perks)
	var sheep: SheepBody = _spawn()

	sheep.kill(GameEnums.DeathCause.EATEN)
	await wait_seconds(0.7)

	assert_false(sheep.visible)
	Services.replace(PerkService, original_perks)
	perks.free()


func test_a_sheep_cannot_die_twice() -> void:
	var sheep: SheepBody = _spawn()
	sheep.kill(GameEnums.DeathCause.EATEN)

	assert_false(sheep.kill(GameEnums.DeathCause.SHOT))
	assert_false(sheep.kill(GameEnums.DeathCause.EATEN))


# --- No tell -----------------------------------------------------------------------

func test_a_player_steered_sheep_is_indistinguishable_from_a_script_steered_one() -> void:
	var input: StubInputService = StubInputService.new()
	var original_input: Node = Services.replace(InputService, input)
	input.set_role(GameEnums.Role.MONSTER)
	var by_script: SheepBody = _spawn(7, Vector2(0.0, 0.0))
	var by_player: SheepBody = _spawn(7, Vector2(0.0, 400.0))
	var driver: SheepPlayerDriver = SheepPlayerDriver.new()
	driver.body = by_player
	add_child_autofree(driver)
	var wish: Vector2 = Vector2(1.0, 0.3)

	by_script.set_move_input(wish)
	input.move_vector = wish
	await _physics_frames(20)
	by_script.set_grazing(true)
	input.simulate_press(InputActions.GRAZE)
	await _physics_frames(15)
	by_script.set_grazing(false)
	input.simulate_release(InputActions.GRAZE)
	by_script.bleat()
	input.simulate_press(InputActions.BLEAT)
	await _physics_frames(10)

	assert_eq(_describe_tree(by_player), _describe_tree(by_script), "node structure, draw order and pose")
	assert_eq(by_player.velocity, by_script.velocity, "motion")
	# Positions are float32: the same steps round differently 400 px apart.
	assert_almost_eq(by_player.position - Vector2(0.0, 400.0), by_script.position, 0.01, "path")
	assert_eq(by_player.get_heading(), by_script.get_heading())
	assert_eq(by_player.get_state(), by_script.get_state())
	for player_name: NodePath in [^"Animation", ^"Voice"]:
		var scripted: AnimationPlayer = by_script.get_node(player_name)
		var played: AnimationPlayer = by_player.get_node(player_name)
		assert_eq(played.current_animation, scripted.current_animation, "%s animation" % player_name)
		assert_eq(played.current_animation_position, scripted.current_animation_position, "%s timing" % player_name)
	assert_eq(_events_near(by_player.position), _events_near(by_script.position), "sounds")
	assert_eq(_events(&"bleat").size(), 2)
	Services.replace(InputService, original_input)
	input.free()


# --- Helpers -----------------------------------------------------------------------

func _spawn(visual_seed: int = 0, at: Vector2 = Vector2.ZERO) -> SheepBody:
	var sheep: SheepBody = SHEEP_SCENE.instantiate()
	sheep.set_visual_seed(visual_seed)
	sheep.position = at
	add_child_autofree(sheep)
	return sheep


func _physics_frames(count: int) -> void:
	for _i: int in count:
		await get_tree().physics_frame


func _layer(sheep: SheepBody, slot: SheepAppearanceSlot) -> Sprite2D:
	var anchor: String = "Facing/Pose/Visual/Head/HeadPose" if slot.anchor == SheepAppearanceSlot.Anchor.HEAD else "Facing/Pose/Visual/Body"
	return sheep.get_node("%s/%s" % [anchor, String(slot.id).to_pascal_case()])


## Positions of the positional sound events with [param event_id].
func _events(event_id: StringName) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for entry: Dictionary in _audio.played:
		if entry["event"] == event_id:
			positions.append(entry["position"])
	return positions


## The ids of the sound events played within 100 px of [param position].
func _events_near(position: Vector2) -> Array[StringName]:
	var ids: Array[StringName] = []
	for entry: Dictionary in _audio.played:
		if (entry["position"] as Vector2).distance_to(position) < 100.0:
			ids.append(entry["event"])
	return ids


## Everything about the sheep's nodes that could be seen or inspected, except
## the root's own position.
func _describe_tree(root: Node) -> PackedStringArray:
	var lines: PackedStringArray = []
	var nodes: Array[Node] = [root]
	nodes.append_array(root.find_children("*", "", true, false))
	for node: Node in nodes:
		var line: String = "%s %s %s %s" % [root.get_path_to(node), node.get_class(), node.get_script(), node.get_groups()]
		if node is CanvasItem:
			var item: CanvasItem = node
			line += " visible=%s z=%d rel=%s ysort=%s modulate=%s self=%s" % [
				item.visible, item.z_index, item.z_as_relative, item.y_sort_enabled, item.modulate, item.self_modulate,
			]
		if node is Node2D and node != root:
			var node_2d: Node2D = node
			line += " at=%s rot=%s scale=%s" % [node_2d.position, node_2d.rotation, node_2d.scale]
		if node is Sprite2D:
			line += " texture=%s" % (node as Sprite2D).texture
		lines.append(line)
	return lines
