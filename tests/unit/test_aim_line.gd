extends TestCase
## The Sheepherder's aim line: where the shot will go, for their own player
## only, without giving away a hidden sheep (#81).

const SHEEP_SCENE: PackedScene = preload("res://entities/sheep/sheep.tscn")
const LOCAL_ID: int = 1
const OTHER_ID: int = 2


## A firearm whose state the test sets.
class RifleCombatService:
	extends StubCombatService

	var shootable: bool = true
	var depleted: bool = false

	func can_shoot() -> bool:
		return shootable

	func is_ammo_depleted() -> bool:
		return depleted


var _input: StubInputService
var _combat: RifleCombatService
var _originals: Dictionary = {}


func before_each() -> void:
	_input = StubInputService.new()
	_input.set_role(GameEnums.Role.SHEEPHERDER)
	_combat = RifleCombatService.new(Services.config)
	_originals[InputService] = Services.replace(InputService, _input)
	_originals[CombatService] = Services.replace(CombatService, _combat)
	_originals[SwarmService] = Services.replace(SwarmService, StubSwarmService.new())
	_originals[AudioService] = Services.replace(AudioService, StubAudioService.new(Services.config))


func after_each() -> void:
	for contract: Script in _originals:
		Services.replace(contract, _originals[contract]).free()
	_originals.clear()


func test_only_the_sheepherders_own_player_sees_it() -> void:
	var own: Sheepherder = _spawn(LOCAL_ID)
	var remote: Sheepherder = _spawn(OTHER_ID)
	var bot: Sheepherder = _spawn(LOCAL_ID, {BotInput.DATA_KEY: true})

	assert_not_null(own.get_node_or_null(^"AimLine"))
	assert_null(remote.get_node_or_null(^"AimLine"), "never on the Monster's device")
	assert_null(bot.get_node_or_null(^"AimLine"), "a bot has no screen")


func test_it_stops_at_the_first_obstacle_and_passes_through_sheep() -> void:
	var herder: Sheepherder = _spawn(LOCAL_ID)
	var sheep: SheepBody = SHEEP_SCENE.instantiate()
	sheep.position = Vector2(150.0, 0.0)
	add_child_autofree(sheep)
	add_child_autofree(_wall(Vector2(300.0, 0.0)))
	var line: AimLine = herder.get_node(^"AimLine")

	await _physics_frames(3)
	assert_almost_eq(line.get_length(), 280.0, 0.5, "at the wall, not at the sheep")

	_input.aim_direction = Vector2.LEFT
	await _physics_frames(3)
	assert_eq(line.get_length(), AimLine.MAX_LENGTH, "nothing that way")


func test_it_is_faint_while_no_shot_is_possible_and_gone_when_empty() -> void:
	var herder: Sheepherder = _spawn(LOCAL_ID)
	var line: AimLine = herder.get_node(^"AimLine")
	await _physics_frames(2)
	assert_eq(line.get_strength(), 1.0, "ready to fire")

	_combat.shootable = false
	await _physics_frames(2)
	assert_eq(line.get_strength(), AimLine.DIM, "reloading")

	_combat.depleted = true
	await _physics_frames(2)
	assert_eq(line.get_strength(), 0.0, "the magazine is empty")


func test_it_is_gone_when_the_sheepherder_dies() -> void:
	var herder: Sheepherder = _spawn(LOCAL_ID)
	var line: AimLine = herder.get_node(^"AimLine")

	_combat.sheepherder_killed.emit(herder.position)
	await _physics_frames(2)

	assert_eq(line.get_strength(), 0.0)


func _spawn(owner_id: int, data: Dictionary = {}) -> Sheepherder:
	var herder: Sheepherder = Sheepherder.build(-1, owner_id, data)
	add_child_autofree(herder)
	return herder


## A solid block 40 px wide and 400 px high, the way obstacles block bullets.
static func _wall(at: Vector2) -> StaticBody2D:
	var wall: StaticBody2D = StaticBody2D.new()
	wall.collision_layer = PhysicsLayers.WORLD
	wall.collision_mask = 0
	wall.position = at
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = Vector2(40.0, 400.0)
	shape.shape = rectangle
	wall.add_child(shape)
	return wall


func _physics_frames(count: int) -> void:
	for _i: int in count:
		await get_tree().physics_frame
