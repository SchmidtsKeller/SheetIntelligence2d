extends TestCase
## What each player can see (GDD §3.1, §3.2): the Sheepherder only what the
## flashlight lights, the Monster everything an obstacle does not hide.
##
## The world: a wall at x 250..270, y -100..100; the Sheepherder at the origin,
## aiming right (cone 60°, 350 px, fading out by 560 px and 12° beside it).

const SHEEP_SCENE: PackedScene = preload("res://entities/sheep/sheep.tscn")
const BLOOD_SCENE: PackedScene = preload("res://entities/evidence/blood_decal.tscn")

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
	_wall(Rect2(250.0, -100.0, 20.0, 200.0))
	_herder = Sheepherder.build(-1, Services.session.messenger.get_local_id(), {})
	add_child_autofree(_herder)
	_vision = VisionSystem.new()
	add_child_autofree(_vision)
	# The tests decide when time passes.
	_vision.set_process(false)


func after_each() -> void:
	for contract: Script in _originals:
		Services.replace(contract, _originals[contract]).free()
	_originals.clear()


# --- Sheepherder -----------------------------------------------------------------


func test_the_sheepherder_sees_only_what_the_cone_lights() -> void:
	var lit: SheepBody = _sheep(Vector2(200.0, 0.0))
	var beside: SheepBody = _sheep(Vector2(0.0, 300.0))
	var behind_wall: SheepBody = _sheep(Vector2(310.0, 0.0))
	var too_far: SheepBody = _sheep(Vector2(500.0, 30.0))
	await _decide_as(GameEnums.Role.SHEEPHERDER)

	assert_eq(_shown(lit), 1.0, "in the cone")
	assert_eq(_shown(beside), 0.0, "outside the cone")
	assert_eq(_shown(behind_wall), 0.0, "in the wall's shadow")
	assert_eq(_shown(too_far), 0.0, "beyond the cone's length")
	assert_eq(_herder_alpha(), 1.0, "the player always sees themself")
	assert_true(_darkness().visible)


func test_part_of_a_sheep_in_the_cone_is_enough() -> void:
	# The center lies 33° off the aim, outside the 30° half angle; the edge is in.
	var edge: SheepBody = _sheep(Vector2.from_angle(deg_to_rad(33.0)) * 150.0)
	await _decide_as(GameEnums.Role.SHEEPHERDER)

	assert_eq(_shown(edge), 1.0)


func test_a_wider_cone_reveals_more() -> void:
	# Its nearest part is 44.8° off the aim: beyond the 30° half angle and its
	# 12° fade, but inside the 45° half angle of the wide cone.
	var sheep: SheepBody = _sheep(Vector2.from_angle(deg_to_rad(48.0)) * 200.0)
	await _decide_as(GameEnums.Role.SHEEPHERDER)
	assert_eq(_shown(sheep), 0.0)

	var config: GameConfig = GameConfig.new()
	config.flashlight_cone_angle_deg = config.perk_wide_flashlight_angle_deg
	_originals[PerkService] = Services.replace(PerkService, StubPerkService.new(config))
	_vision.update(1.0)

	assert_eq(_shown(sheep), 1.0)


func test_blood_shows_only_in_the_light() -> void:
	var lit: Node2D = _blood(Vector2(150.0, 0.0))
	var dark: Node2D = _blood(Vector2(0.0, -200.0))
	await _decide_as(GameEnums.Role.SHEEPHERDER)

	assert_eq(lit.modulate.a, 1.0)
	assert_eq(dark.modulate.a, 0.0)


func test_entities_fade_instead_of_popping() -> void:
	var sheep: SheepBody = _sheep(Vector2(0.0, 300.0))
	await _decide_as(GameEnums.Role.SHEEPHERDER)
	assert_eq(_shown(sheep), 0.0)

	_input.aim_direction = Vector2.DOWN
	await get_tree().physics_frame
	await get_tree().physics_frame
	_vision.update(0.05)

	assert_almost_eq(_shown(sheep), 0.4, 0.001, "on its way in")
	_vision.update(0.1)
	assert_eq(_shown(sheep), 1.0)


# --- Monster ---------------------------------------------------------------------


func test_the_monster_sees_all_but_what_obstacles_hide() -> void:
	var monster: SheepBody = _sheep(Vector2(400.0, 0.0))
	var in_sight: SheepBody = _sheep(Vector2(400.0, 250.0))
	var blood: Node2D = _blood(Vector2(100.0, 0.0))
	await _decide_as(GameEnums.Role.MONSTER, monster)

	assert_eq(_shown(monster), 1.0, "itself")
	assert_eq(_shown(in_sight), 1.0)
	assert_eq(_herder_alpha(), 0.0, "the Sheepherder behind the wall")
	assert_eq(blood.modulate.a, 1.0, "the Monster sees all of the ground")
	assert_false(_darkness().visible, "no darkness")


func test_effects_are_hidden_with_their_entity() -> void:
	var monster: SheepBody = _sheep(Vector2(400.0, 0.0))
	await _decide_as(GameEnums.Role.MONSTER, monster)

	Services.combat.shot_fired.emit(Vector2.ZERO, Vector2(250.0, 0.0), 0)

	var effects: Array[Node] = _herder.get_children().filter(
		func(child: Node) -> bool: return child is ShotEffect
	)
	assert_eq(effects.size(), 1)
	assert_false((effects[0] as CanvasItem).visible, "the muzzle flash behind the wall")


func test_a_cloaked_monster_is_seen_only_by_its_own_player_faded() -> void:
	var monster: SheepBody = _sheep(Vector2(200.0, 0.0))
	VisionTarget.of(monster).cloaked = true

	await _decide_as(GameEnums.Role.SHEEPHERDER)
	assert_eq(_shown(monster), 0.0, "inside the cone, yet invisible")

	await _decide_as(GameEnums.Role.MONSTER, monster)
	assert_almost_eq(_shown(monster), VisionTarget.CLOAKED_ALPHA, 0.001, "its player sees it faded")

	await _decide_as(GameEnums.Role.NONE)
	assert_eq(_shown(monster), 0.0, "nobody else sees it")

	VisionTarget.of(monster).cloaked = false
	await _decide_as(GameEnums.Role.SHEEPHERDER)
	assert_eq(_shown(monster), 1.0, "visible again")


func test_without_a_role_everything_is_shown() -> void:
	var sheep: SheepBody = _sheep(Vector2(310.0, 0.0))
	await _decide_as(GameEnums.Role.NONE)

	assert_eq(_shown(sheep), 1.0)
	assert_false(_darkness().visible)


# --- Blood -----------------------------------------------------------------------


func test_blood_is_left_where_the_combat_service_reports_it() -> void:
	var decals: Node2D = add_child_autofree(Node2D.new())
	var spawner: BloodDecalSpawner = BloodDecalSpawner.new()
	spawner.decals = decals
	add_child_autofree(spawner)

	Services.combat.blood_spilled.emit(Vector2(30.0, 40.0))
	Services.combat.blood_spilled.emit(Vector2(30.0, 40.0))

	assert_eq(decals.get_child_count(), 2)
	var first: Node2D = decals.get_child(0)
	assert_eq(first.position, Vector2(30.0, 40.0))
	assert_eq(first.rotation, (decals.get_child(1) as Node2D).rotation, "same place, same mark")
	assert_true(first.is_in_group(Groups.DYNAMIC_ENTITIES))


# --- Helpers ---------------------------------------------------------------------


## Lets physics see the bodies, then decides everything without fading.
func _decide_as(role: GameEnums.Role, viewer: Node2D = null) -> void:
	_vision.role = role
	_vision.viewer = viewer if viewer != null else _herder
	await get_tree().physics_frame
	await get_tree().physics_frame
	_vision.update(1.0)


func _sheep(at: Vector2) -> SheepBody:
	var sheep: SheepBody = SHEEP_SCENE.instantiate()
	sheep.position = at
	add_child_autofree(sheep)
	return sheep


func _blood(at: Vector2) -> Node2D:
	var blood: Node2D = BLOOD_SCENE.instantiate()
	blood.position = at
	add_child_autofree(blood)
	return blood


func _shown(sheep: SheepBody) -> float:
	return (sheep.get_node(^"Facing") as CanvasItem).modulate.a


func _herder_alpha() -> float:
	return (_herder.get_node(^"Art") as CanvasItem).modulate.a


func _darkness() -> CanvasModulate:
	return _vision.get_node(^"Darkness")


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
