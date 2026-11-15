extends TestCase
## Light (#63): the flashlight fades out beyond its cone, lit torches light
## what is around them, and the player's view and the bots' senses follow the
## same light levels. Torches are lit by the host's word.
##
## The world: the Sheepherder at the origin, aiming right (cone 60°, 350 px,
## fading out by 560 px and 12° beside it).

const SHEEP_SCENE: PackedScene = preload("res://entities/sheep/sheep.tscn")
const TORCH_SCENE: PackedScene = preload("res://entities/torch/torch.tscn")
const ARENA_SCENE: String = "res://systems/arena/arena.tscn"

var _vision: VisionSystem
var _herder: Sheepherder
var _input: StubInputService
var _audio: StubAudioService
var _originals: Dictionary = {}


func before_each() -> void:
	_input = StubInputService.new()
	_audio = StubAudioService.new(Services.config)
	_originals[InputService] = Services.replace(InputService, _input)
	_originals[AudioService] = Services.replace(AudioService, _audio)


func after_each() -> void:
	for contract: Script in _originals:
		Services.replace(contract, _originals[contract]).free()
	_originals.clear()


# --- The shape of the light ------------------------------------------------------


func test_the_flashlight_is_full_in_its_cone_and_fades_out_beyond() -> void:
	var half_angle: float = deg_to_rad(30.0)
	var fade_angle: float = deg_to_rad(12.0)
	var level: Callable = func(offset: Vector2) -> float:
		return LightRules.cone_falloff(offset, half_angle, 350.0, 0.6, fade_angle)

	assert_eq(level.call(Vector2(10.0, 0.0)), 1.0, "near the lamp")
	assert_eq(level.call(Vector2(350.0, 0.0)), 1.0, "at the end of the cone")
	assert_eq(level.call(Vector2.from_angle(deg_to_rad(29.9)) * 200.0), 1.0, "at its side")
	assert_almost_eq(level.call(Vector2(455.0, 0.0)), 0.5, 0.001, "half way through the fade")
	assert_almost_eq(
		level.call(Vector2.from_angle(deg_to_rad(36.0)) * 200.0), 0.5, 0.001, "half way beside"
	)
	assert_eq(level.call(Vector2(560.0, 0.0)), 0.0, "where the fade ends")
	assert_eq(level.call(Vector2.from_angle(deg_to_rad(42.0)) * 200.0), 0.0)
	assert_eq(level.call(Vector2(-50.0, 0.0)), 0.0, "behind the lamp")
	assert_gt(level.call(Vector2(400.0, 0.0)), level.call(Vector2(500.0, 0.0)), "fading out")


func test_a_torch_is_full_up_to_its_radius_and_fades_out_beyond() -> void:
	assert_eq(LightRules.torch_level(Vector2.ZERO, Vector2(0.0, 200.0)), 1.0)
	assert_almost_eq(LightRules.torch_level(Vector2.ZERO, Vector2(260.0, 0.0)), 0.5, 0.001)
	assert_eq(LightRules.torch_level(Vector2.ZERO, Vector2(320.0, 0.0)), 0.0)
	assert_eq(LightRules.torch_reach(), 320.0)


# --- What the Sheepherder sees ---------------------------------------------------


func test_an_entity_in_the_fade_is_shown_as_dim_as_the_light() -> void:
	await _stage_herder()
	# Their nearest parts are about 424 and 524 px away.
	var dim: SheepBody = _sheep(Vector2(440.0, 0.0))
	var faint: SheepBody = _sheep(Vector2(540.0, 0.0))
	var gone: SheepBody = _sheep(Vector2(600.0, 0.0))
	await _decide()

	assert_almost_eq(_shown(dim), _flashlight_on(dim), 0.001, "as bright as its brightest part")
	assert_gte(_shown(dim), 0.5, "seen")
	assert_lt(_shown(dim), 0.9, "but dim")
	assert_almost_eq(_shown(faint), _flashlight_on(faint), 0.001)
	assert_gt(_shown(faint), 0.01, "faint")
	assert_lt(_shown(faint), 0.5, "not seen")
	assert_eq(_shown(gone), 0.0, "beyond the fade")
	assert_true(_vision.can_see(VisionTarget.of(dim)))
	assert_false(_vision.can_see(VisionTarget.of(faint)))


func test_the_bots_see_by_the_same_light() -> void:
	await _stage_herder()
	var dim: SheepBody = _sheep(Vector2(440.0, 0.0))
	var faint: SheepBody = _sheep(Vector2(540.0, 0.0))
	var dark: SheepBody = _sheep(Vector2(0.0, -400.0))
	var torch: Torch = _torch(Vector2(0.0, -500.0))
	await _decide()

	for sheep: SheepBody in [dim, faint, dark]:
		assert_eq(
			BotSenses.herder_sees(_herder, sheep),
			_vision.can_see(VisionTarget.of(sheep)),
			"the bot and the player agree on %s" % sheep.position
		)
	assert_false(BotSenses.herder_sees(_herder, dark), "nothing lights it yet")

	torch.light()
	_vision.update(1.0)
	assert_true(BotSenses.herder_sees(_herder, dark), "the torch lights it")
	assert_true(_vision.can_see(VisionTarget.of(dark)))


func test_a_torch_flares_up_and_then_crackles() -> void:
	var torch: Torch = _torch(Vector2(0.0, -500.0))
	assert_false(_audio.is_looping(AudioEvents.TORCH_BURN), "an unlit torch is silent")

	torch.light()

	assert_true(_audio.is_looping(AudioEvents.TORCH_BURN))
	var flares: Array[Vector2] = []
	for entry: Dictionary in _audio.played:
		if entry["event"] == AudioEvents.TORCH_IGNITE:
			flares.append(entry["position"])
	assert_eq(flares, [torch.global_position] as Array[Vector2])


func test_a_lit_torch_reveals_what_is_around_it() -> void:
	await _stage_herder()
	var torch: Torch = _torch(Vector2(0.0, -500.0))
	var near: SheepBody = _sheep(Vector2(0.0, -400.0))
	var far: SheepBody = _sheep(Vector2(0.0, -900.0))
	await _decide()
	assert_eq(_shown(near), 0.0, "an unlit torch lights nothing")

	torch.light()
	_vision.update(1.0)

	assert_true(torch.is_lit())
	assert_eq(_shown(near), 1.0, "in the torch's light")
	assert_eq(_shown(far), 0.0, "beyond it")


func test_a_torch_does_not_light_through_obstacles() -> void:
	await _stage_herder()
	_wall(Rect2(-100.0, -460.0, 200.0, 20.0))
	var torch: Torch = _torch(Vector2(0.0, -500.0))
	var behind_wall: SheepBody = _sheep(Vector2(0.0, -380.0))
	torch.light()
	await _decide()

	assert_eq(_shown(behind_wall), 0.0)


func test_the_night_is_darker_not_black() -> void:
	await _stage_herder()
	await _decide()

	var darkness: Color = (_vision.get_node(^"Darkness") as CanvasModulate).color
	assert_gt(darkness.get_luminance(), 0.2, "the scenery stays readable")
	assert_lt(darkness.get_luminance(), 0.6, "but it is clearly night")


func test_the_monster_sees_no_differently_by_torchlight() -> void:
	await _stage_herder()
	var torch: Torch = _torch(Vector2(0.0, -500.0))
	var monster: SheepBody = _sheep(Vector2(400.0, 300.0))
	var sheep: SheepBody = _sheep(Vector2(0.0, -400.0))
	torch.light()
	_vision.viewer = monster
	_vision.role = GameEnums.Role.MONSTER
	await _decide()

	assert_eq(_shown(sheep), 1.0, "the Monster sees all that no obstacle hides")


# --- Torches in the arena --------------------------------------------------------


func test_the_torches_stand_in_the_open_away_from_the_starts() -> void:
	var arena: Arena = add_child_autofree((load(ARENA_SCENE) as PackedScene).instantiate())
	await get_tree().physics_frame
	var torches: Array[Torch] = arena.get_torches()
	var reach: float = LightRules.torch_reach()

	assert_gt(torches.size(), 3, "a few torches")
	for torch: Torch in torches:
		assert_true(arena.is_free(torch.global_position, 30.0), "%s is in the open" % torch.name)
		assert_false(torch.is_lit(), "%s starts unlit" % torch.name)
		assert_true(torch.is_in_group(Groups.STATIC_SCENERY))
		var spawn: Rect2 = arena.get_sheepherder_spawn_area()
		assert_false(spawn.grow(reach).has_point(torch.global_position), "far from the corner")
		var flock: Rect2 = arena.get_flock_spawn_area()
		assert_false(flock.grow(reach).has_point(torch.global_position), "far from the flock")


func test_a_sheepherder_lights_a_torch_by_walking_up_to_it() -> void:
	var arena: Arena = add_child_autofree((load(ARENA_SCENE) as PackedScene).instantiate())
	var torches: Array[Torch] = arena.get_torches()
	var target: Torch = torches[1]
	var herder: Sheepherder = Sheepherder.build(-1, Services.session.messenger.get_local_id(), {})
	herder.position = target.global_position + Vector2(50.0, 0.0)
	arena.get_entities_layer().add_child(herder)
	await _physics_frames(2)

	assert_true(target.is_lit(), "the torch next to the Sheepherder")
	for torch: Torch in torches:
		if torch != target:
			assert_false(torch.is_lit(), "%s is too far" % torch.name)

	Services.combat.sheepherder_killed.emit(herder.global_position)
	herder.position = torches[2].global_position
	await _physics_frames(2)
	assert_false(torches[2].is_lit(), "a dead Sheepherder lights nothing")
	herder.queue_free()


func test_only_the_host_decides_when_a_torch_is_lit() -> void:
	var pair: SessionPair = SessionPair.create(self)
	pair.connect_both()
	pair.host.messenger.register_event(Arena.EVENT_TORCH_LIT, NetMessenger.SenderRule.HOST_ONLY)
	var arena: Arena = (load(ARENA_SCENE) as PackedScene).instantiate()
	arena.session = pair.guest
	add_child_autofree(arena)
	var torches: Array[Torch] = arena.get_torches()
	# A Sheepherder next to a torch on the guest's device: the guest waits.
	var herder: Sheepherder = Sheepherder.build(-1, SessionPair.GUEST_ID, {}, pair.guest)
	herder.position = torches[0].global_position
	arena.get_entities_layer().add_child(herder)
	await _physics_frames(2)
	assert_false(torches[0].is_lit(), "the guest does not decide")

	pair.host.messenger.broadcast(Arena.EVENT_TORCH_LIT, [3])
	assert_true(torches[3].is_lit(), "the host's word lights it")
	expect_error("only the host may send")
	assert_false(pair.guest.messenger.broadcast(Arena.EVENT_TORCH_LIT, [4]))
	assert_false(torches[4].is_lit(), "the guest cannot announce one")
	herder.queue_free()


# --- Helpers ---------------------------------------------------------------------


func _stage_herder() -> void:
	_herder = Sheepherder.build(-1, Services.session.messenger.get_local_id(), {})
	add_child_autofree(_herder)
	_vision = VisionSystem.new()
	add_child_autofree(_vision)
	_vision.set_process(false)
	_vision.role = GameEnums.Role.SHEEPHERDER
	_vision.viewer = _herder
	_input.aim_direction = Vector2.RIGHT
	await get_tree().physics_frame


## Lets physics see the bodies, then decides everything without fading.
func _decide() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	_vision.update(1.0)


func _sheep(at: Vector2) -> SheepBody:
	var sheep: SheepBody = SHEEP_SCENE.instantiate()
	sheep.position = at
	add_child_autofree(sheep)
	return sheep


func _torch(at: Vector2) -> Torch:
	var torch: Torch = TORCH_SCENE.instantiate()
	torch.position = at
	add_child_autofree(torch)
	return torch


func _shown(sheep: SheepBody) -> float:
	return VisionTarget.of(sheep).shown


func _wall(rect: Rect2) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.position = rect.get_center()
	body.collision_layer = PhysicsLayers.WORLD
	body.collision_mask = 0
	body.add_to_group(Groups.OBSTACLES)
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = rect.size
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child_autofree(body)


func _physics_frames(count: int) -> void:
	for _i: int in count:
		await get_tree().physics_frame


## The brightest flashlight level on any part of [param sheep].
func _flashlight_on(sheep: SheepBody) -> float:
	var cone: FlashlightCone = _herder.get_flashlight_cone()
	var best: float = 0.0
	for point: Vector2 in VisionTarget.of(sheep).get_sample_points():
		best = maxf(best, LightRules.flashlight_level(cone, point))
	return best
